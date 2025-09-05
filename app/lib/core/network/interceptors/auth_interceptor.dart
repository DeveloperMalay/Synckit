import 'package:dio/dio.dart';
import '../../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Add auth token to headers if available
    final token = TokenStorage.token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    
    super.onRequest(options, handler);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Handle 401 Unauthorized errors
    if (err.response?.statusCode == 401) {
      // Clear token and redirect to login
      TokenStorage.clearToken();
      // TODO: Navigate to login screen
    }
    
    super.onError(err, handler);
  }
}