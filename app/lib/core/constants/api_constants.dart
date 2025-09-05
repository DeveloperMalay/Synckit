class ApiConstants {
  // For Android Emulator: use 'http://10.0.2.2:3000/api'
  // For iOS Simulator or physical device: use 'http://192.168.0.108:3000/api'
  static const String baseUrl = 'http://10.0.2.2:3000/api';
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}