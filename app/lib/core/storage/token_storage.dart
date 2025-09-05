import 'package:flutter/foundation.dart';

class TokenStorage {
  static String? _token;
  
  static String? get token => _token;
  
  static Future<void> saveToken(String token) async {
    _token = token;
    // TODO: Implement secure storage with flutter_secure_storage
    debugPrint('Token saved');
  }
  
  static Future<void> clearToken() async {
    _token = null;
    // TODO: Clear from secure storage
    debugPrint('Token cleared');
  }
  
  static bool get hasToken => _token != null;
}