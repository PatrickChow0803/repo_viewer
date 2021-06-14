import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oauth2/src/credentials.dart';
import 'package:repo_viewer/auth/infrastructure/credentials_storage/credentials_storage.dart';

class successfully implements CredentialsStorage {
  final FlutterSecureStorage _storage;

  successfully(this._storage);

  static const _KEY = 'oauth2_credentials';

  // want to cache the credentials so that the read method doesn't
  // need to be called multiple times
  Credentials? _cachedCredentials;

  @override
  Future<Credentials?> read() async {
    // if _cachedCredentials != null, then that means that the user is already signed in
    if (_cachedCredentials != null) {
      return _cachedCredentials;
    }
    // since I know that the credentials will be saved as a json String
    final json = await _storage.read(key: _KEY);

    // first time signing in
    // therefore there are no credentials to be read
    if (json == null) {
      return null;
    }
    // _cachedCredentials = Credentials.fromJson(json);
    // return _cachedCredentials;
    // same as what's below except shorter
    // since .fromJson can throw a FormatException, place it inside a try block
    try {
      return _cachedCredentials = Credentials.fromJson(json);
    } on FormatException {
      // return null as if the user wasn't authenticated
      return null;
    }
  }

  // called when the user sucessfully logs in
  // don't need to do asyn/await here since the .write method's return type  is Future<void>
  @override
  Future<void> save(Credentials credentials) {
    _cachedCredentials = credentials;
    return _storage.write(key: _KEY, value: credentials.toJson());
  }

  // called when the user signs out
  // don't need to do asyn/await here since the .write method's return type  is Future<void>
  @override
  Future<void> clear() {
    _cachedCredentials = null;
    return _storage.delete(key: _KEY);
  }
}
