import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('REQUEST[${options.method}] => PATH: ${options.path}');
      debugPrint('Headers: ${options.headers}');
      if (options.data != null) {
        debugPrint('Body: ${options.data}');
      }
    }
    super.onRequest(options, handler);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');
      debugPrint('Data: ${response.data}');
    }
    super.onResponse(response, handler);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}');
      debugPrint('Message: ${err.message}');
      if (err.response?.data != null) {
        debugPrint('Error data: ${err.response?.data}');
      }
    }
    super.onError(err, handler);
  }
}