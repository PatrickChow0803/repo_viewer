import 'package:freezed_annotation/freezed_annotation.dart';

// domain layer only holds entities and failures
// since when dealing with auth, the only data type we'll have is the token string
// since it's just one simple data type, we can opt out to not make an entity class for auth

// ptf = part freezed to tell the generator the name of the file to generate
// to use the code generator type this in the terminal
// flutter pub run build_runner watch --delete-conflicting-outputs
part 'auth_failure.freezed.dart';

// This class will hold all the different failures that can occur when dealing with auth
// Therefore make this a union class so that you can handel each case
// Use fun snippet to make your life easy

@freezed
class AuthFailure with _$AuthFailure {
  const AuthFailure._();
  // since there's usually a response from the server if there's a failure, add an optional parameter String?
  const factory AuthFailure.server([String? message]) = _Server;
  const factory AuthFailure.storage() = _Storage;
}
