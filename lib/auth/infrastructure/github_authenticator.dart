import 'package:flutter/services.dart';
import 'package:oauth2/oauth2.dart';
import 'package:repo_viewer/auth/infrastructure/credentials_storage/credentials_storage.dart';

class GithubAuthenticator {
  final CredentialsStorage _credentialsStorage;

  GithubAuthenticator(this._credentialsStorage);
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
  Future<bool> isSignedIn() =>
      getSignedInCredentials().then((credentials) => credentials != null);
}
