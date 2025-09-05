import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../models/auth_response.dart';

class AuthRepository {
  final DioClient _dioClient;
  
  AuthRepository({DioClient? dioClient}) 
      : _dioClient = dioClient ?? DioClient();
  
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dioClient.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      
      final authResponse = AuthResponse.fromJson(response.data);
      await TokenStorage.saveToken(authResponse.token);
      
      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<AuthResponse> register({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final response = await _dioClient.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          if (name != null) 'name': name,
        },
      );
      
      final authResponse = AuthResponse.fromJson(response.data);
      await TokenStorage.saveToken(authResponse.token);
      
      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<void> logout() async {
    await TokenStorage.clearToken();
  }
  
  String _handleError(DioException error) {
    if (error.response?.data != null && error.response?.data['error'] != null) {
      return error.response!.data['error'];
    }
    
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout';
      case DioExceptionType.connectionError:
        return 'Connection error';
      default:
        return 'Something went wrong';
    }
  }
}