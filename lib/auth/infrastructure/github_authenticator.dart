import 'package:oauth2/oauth2.dart';

class GithubAuthenticator {
  // Credentials hold the access token
  // once signed in, store the credentials on the device so that the
  // authentication form doen't need to be displayed each time
  Future<Credentials> getSignedInCredentials() async {}
}
