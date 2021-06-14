import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:oauth2/oauth2.dart';
import 'package:repo_viewer/auth/domain/auth_failure.dart';
import 'package:repo_viewer/auth/infrastructure/credentials_storage/credentials_storage.dart';
import 'package:http/http.dart' as http;
import 'package:repo_viewer/core/shared/encoders.dart';
import 'package:repo_viewer/core/infrastructure/dio_extensions.dart';

// this class is needed because Github will return the access token as
// url format coded response. But we want the response to be in json format.
// therefore you need to add Accept: application/json to the header
// But we can't just edit the code in packages so we need to make our own

class GithubOAuthHttpClient extends http.BaseClient {
  final httpClient = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Accept'] = 'application/json';
    return httpClient.send(request);
  }
}

class GithubAuthenticator {
  final CredentialsStorage _credentialsStorage;
  final Dio _dio;

  GithubAuthenticator(this._credentialsStorage, this._dio);

  // https://github.com/settings/applications/1643784
  // copy paste the client ID
  static const clientId = '9f84f39cc97e134f7ec0';

  // need to generate your own clientSecret from https://github.com/settings/applications/1643784
  static final clientSecret = dotenv.env['CLIENT_SECRET'];

  // scopes taken from https://github.com/settings/tokens
  static const scopes = ['read:user', 'repo'];

  // https://docs.github.com/en/developers/apps/building-oauth-apps/authorizing-oauth-apps
  // for reference
  // since oauth2 package operates with URIs and not just plain strings,
  // need to convert the String to an URI
  static final authorizationEndpoint =
      Uri.parse('https://github.com/login/oauth/authorize');

  static final tokenEndpoint =
      Uri.parse('https://github.com/login/oauth/access_token');

  // https://docs.github.com/en/rest/reference/apps#delete-an-app-token reference
  // endpoint to delete the access tokens. Called when a user signs off.
  static final revocationEndpoint =
      Uri.parse('https://api.github.com/applications/$clientId/token');

  // https://github.com/settings/applications/1643784
  // copy paste the Authorization callback URL
  // this is for the web online. This has no impact on the mobile side.
  static final redirectUrl = Uri.parse('http://localhost:3000/callback');

  // Credentials hold the access token
  // once signed in, store the credentials on the device so that the
  // authentication form doen't need to be displayed each time
  // Credentials can be null therefore add the ? to the return type
  Future<Credentials?> getSignedInCredentials() async {
    // since .read can throw a PlatformException, wrap it in a try block
    try {
      final storedCredentials = await _credentialsStorage.read();
      // some oauth makes the tokens refresh. If they can refresh, then they can expire
      // Github doesn't refresh tokens but many oauth2 does do it.
      // This code below is what to do if they do refresh.
      if (storedCredentials != null) {
        if (storedCredentials.canRefresh && storedCredentials.isExpired) {
          final failureOrCredentials = await refresh(storedCredentials);
          return failureOrCredentials.fold((l) => null, (r) => r);
        }
      }
      return storedCredentials;
    } on PlatformException {
      return null;
    }
  }

  // if credentials isn't null, then it means that the user is currently signed in
  // which therefore returns true
  Future<bool> isSignedIn() =>
      getSignedInCredentials().then((credentials) => credentials != null);

  // the signing in process
  AuthorizationCodeGrant createGrant() {
    return AuthorizationCodeGrant(
      clientId,
      authorizationEndpoint,
      tokenEndpoint,
      secret: clientSecret,
      httpClient: GithubOAuthHttpClient(),
    );
  }

  // Authorization means that the user will input their username and password
  // as if they were signing in regularly to github
  // then, if the log is sucessful, they'll be redirected to the redirectUrl which
  // is 'http://localhost:3000/callback'
  Uri getAuthorizationUrl(AuthorizationCodeGrant grant) {
    return grant.getAuthorizationUrl(redirectUrl, scopes: scopes);
  }

  // Unit means void. It comes from Dartz
  // Use Unit here when you want to transform exceptions into failures when using the Either type
  // return type could be Future<void> if you were to handel exceptions the normal way(Not using failures, just regular exceptions)
  // Therefore when this method fails, it should return an AuthFailure
  // when it passes, it should return nothing
  // this method is used to actually get and save the access token
  // since handleAuthorizationResponse can return a FormatException or an AuthorizationException
  // place this inside of a try catch
  Future<Either<AuthFailure, Unit>> handleAuthorizationResponse(
    AuthorizationCodeGrant grant,
    Map<String, String> queryParams,
  ) async {
    try {
      final httpClient = await grant.handleAuthorizationResponse(queryParams);
      await _credentialsStorage.save(httpClient.credentials);
      // return nothing if successful
      return right(unit);
    } on FormatException {
      return left(const AuthFailure.server());
    } on AuthorizationException catch (e) {
      return left(AuthFailure.server('${e.error}: ${e.description}'));
    } on PlatformException {
      return left(const AuthFailure.storage());
    }
  }

  // called when the user signs out
  // the only things that's really needed is the await _credentialsStorage.clear()
  // everything else is to delete the access token so that it can't be used anymore
  Future<Either<AuthFailure, Unit>> signOut() async {
    final accessToken = await _credentialsStorage
        .read()
        .then((credentials) => credentials?.accessToken);

    final usernameAndPassword =
        stringToBase64.encode('$clientId:$clientSecret');
    // nested try block so that the _credentialsStorage.clear() is independent
    try {
      try {
        _dio.deleteUri(
          revocationEndpoint,
          data: {
            'access_token': accessToken,
          },
          options: Options(
            headers: {
              'Authorization': 'basic $usernameAndPassword',
            },
          ),
        );
      } on DioError catch (e) {
        if (e.isNoConnectionError) {
          // Ignoring
        } else {
          rethrow;
        }
      }
      await _credentialsStorage.clear();
      return right(unit);
    } on PlatformException {
      return left(const AuthFailure.storage());
    }
  }

  Future<Either<AuthFailure, Credentials>> refresh(
    // old credentials
    Credentials credentials,
  ) async {
    try {
      final refreshedCredentials = await credentials.refresh(
        identifier: clientId,
        secret: clientSecret,
        httpClient: GithubOAuthHttpClient(),
      );
      await _credentialsStorage.save(refreshedCredentials);
      return right(refreshedCredentials);
    } on FormatException {
      return left(const AuthFailure.server());
    } on AuthorizationException catch (e) {
      return left(AuthFailure.server('${e.error}: ${e.description}'));
    } on PlatformException {
      return left(const AuthFailure.storage());
    }
  }
}
