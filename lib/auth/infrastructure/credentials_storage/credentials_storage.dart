import 'package:oauth2/oauth2.dart';

// Making this class abstract because web wont be able to use the
// Flutter_Secure_Storage package. Once implementing for the web platform,
// not going to have to rewrite a bunch of code.

abstract class CredentialsStorage {
  // can be null since the user may not be authenticated
  // get's the credentials that are saved onto the device
  Future<Credentials?> read();

  // saves the credentials onto the device
  Future<void> save(Credentials credentials);

  // wipes the credentials for when the user signs out
  Future<void> clear();
}
