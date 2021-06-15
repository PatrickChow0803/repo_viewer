import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:repo_viewer/auth/domain/auth_failure.dart';
import 'package:repo_viewer/auth/infrastructure/github_authenticator.dart';

part 'auth_notifier.freezed.dart';

// states come out from the application layer and they're useful in the presentation layer
// application layer is responsible for transforming the infrastructure data into something
// the presentation layer can understand

@freezed
class AuthState with _$AuthState {
  const AuthState._();
  // initial state since don't know if the user is authenticated or not on start up
  // getSignedInCredentials is being called during this
  const factory AuthState.initial() = _Initial;
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.authenticated() = _Authenticated;
  const factory AuthState.failure(AuthFailure failure) = _Failure;
}

// Uri is the redirect url
typedef AuthUriCallback = Future<Uri> Function(Uri authorizationUrl);

class AuthNotifier extends StateNotifier<AuthState> {
  final GithubAuthenticator _authenticator;
  AuthNotifier(this._authenticator) : super(const AuthState.initial());

  // transform from the infrastructure layer into something understandable in the application layer
  Future<void> checkAndUpdateAuthState() async {
    // if the user is signed in, make the state authenticated else opposite
    state = (await _authenticator.isSignedIn())
        ? const AuthState.authenticated()
        : const AuthState.unauthenticated();
  }

  Future<void> signIn(AuthUriCallback authorizeCallback) async {
    final grant = _authenticator.createGrant();
    final redirectUrl =
        await authorizeCallback(_authenticator.getAuthorizationUrl(grant));

    final failureOrSuccess = await _authenticator.handleAuthorizationResponse(
        grant, redirectUrl.queryParameters);

    state = failureOrSuccess.fold(
      (l) => AuthState.failure(l),
      (r) => const AuthState.authenticated(),
    );

    grant.close();
  }
}
