import 'dart:io';

import 'package:dio/dio.dart';

extension DioErrorX on DioError {
  bool get isNoConnectionError {
    return this.type == DioErrorType.other && this.error is SocketException;
  }
}
