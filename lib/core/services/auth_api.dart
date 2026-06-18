import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';

class AuthApi {
  final ApiService _apiService;

  AuthApi(this._apiService);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _apiService.post('/auth/login', {
      'email': email,
      'password': password,
    });
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> selectRole(Map<String, dynamic> roleData) async {
    final response = await _apiService.post('/auth/select-role', roleData);
    return json.decode(response.body);
  }

  Future<void> logout() async {
    await _apiService.post('/auth/logout', {});
  }

  Future<Map<String, dynamic>> switchRole(String role, String dept) async {
    final response = await _apiService.post('/auth/switch-role', {
      'role': role,
      'dept': dept,
    });
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _apiService.post('/auth/forgot-password', {'email': email});
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> resetPassword(String token, String newPassword) async {
    final response = await _apiService.post('/auth/reset-password/$token', {'password': newPassword});
    return json.decode(response.body);
  }
  
  void setToken(String token) {
    _apiService.setToken(token);
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return AuthApi(apiService);
});
