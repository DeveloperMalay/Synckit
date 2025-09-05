import 'package:equatable/equatable.dart';

class AuthResponse extends Equatable {
  final String token;
  
  const AuthResponse({required this.token});
  
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'token': token,
    };
  }
  
  @override
  List<Object?> get props => [token];
}