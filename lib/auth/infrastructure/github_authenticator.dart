import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:oauth2/oauth2.dart';
import 'package:repo_viewer/auth/infrastructure/credentials_storage/credentials_storage.dart';

class GithubAuthenticator {
  final CredentialsStorage _credentialsStorage;

  GithubAuthenticator(this._credentialsStorage);

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
          // TODO: refresh
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

  AuthorizationCodeGrant createGrant() {
    return AuthorizationCodeGrant(
      clientId,
      authorizationEndpoint,
      tokenEndpoint,
      secret: clientSecret,
    );
  }

  Uri getAuthorizationUrl(AuthorizationCodeGrant grant) {
    return grant.getAuthorizationUrl(redirectUrl, scopes: scopes);
  }
}
