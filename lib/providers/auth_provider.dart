import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../core/services/api_service.dart';

class AuthState {
  final UserModel? user;
  final bool needsRoleSelection;
  final String? tempToken;
  final List<dynamic>? availableRoles;
  final bool isLoading;

  AuthState({
    this.user,
    this.needsRoleSelection = false,
    this.tempToken,
    this.availableRoles,
    this.isLoading = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? needsRoleSelection,
    String? tempToken,
    List<dynamic>? availableRoles,
    bool? isLoading,
  }) {
    return AuthState(
      user: user ?? this.user,
      needsRoleSelection: needsRoleSelection ?? this.needsRoleSelection,
      tempToken: tempToken ?? this.tempToken,
      availableRoles: availableRoles ?? this.availableRoles,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  AuthNotifier(this._apiService) : super(AuthState()) {
    _loadUser();

  }

  static const String _userKey = 'logged_in_user';
  static const String _tokenKey = 'auth_token';
  static const String _rolesKey = 'available_roles';

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    final token = prefs.getString(_tokenKey);
    final rolesJson = prefs.getString(_rolesKey);

    if (token != null) {
      _apiService.setToken(token);
    }

    List<dynamic>? availableRoles;
    if (rolesJson != null) {
      try {
        availableRoles = json.decode(rolesJson);
      } catch (e) {
        debugPrint('DEBUG: Error decoding roles: $e');
      }
    }

    if (userJson != null) {
      final user = UserModel.fromJson(userJson);
      state = state.copyWith(user: user, availableRoles: availableRoles);

    }
  }







  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      state = state.copyWith(isLoading: true);
      final response = await _apiService.post('/auth/login', {
        'email': email,
        'password': password,
      });

      final responseData = json.decode(response.body);

      if (responseData['needsRoleSelection'] == true) {
        state = state.copyWith(
          isLoading: false,
          needsRoleSelection: true,
          tempToken: responseData['tempToken'],
          availableRoles: responseData['availableRoles'],
        );
        return {'success': true, 'needsRoleSelection': true};
      }

      final String token = responseData['token'] ?? responseData['data']?['token'];
      final user = UserModel.fromMap(responseData['user'] ?? responseData['data']?['user']);
      final availableRoles = responseData['availableRoles'] ?? responseData['data']?['availableRoles'];

      await _finalizeLogin(user, token, availableRoles: availableRoles);
      return {'success': true, 'needsRoleSelection': false};
    } catch (e) {
      debugPrint('DEBUG: Login Error: $e');
      state = state.copyWith(isLoading: false);
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> selectRole(Map<String, dynamic> roleData) async {
    try {
      state = state.copyWith(isLoading: true);

      if (state.tempToken != null) {
        _apiService.setToken(state.tempToken!);
      }

      final response = await _apiService.post('/auth/select-role', roleData);
      final responseData = json.decode(response.body);

      final data = responseData['data'] ?? responseData;

      final String? token = data['token'];
      if (token == null || token.isEmpty) {
        throw 'Session expired. Please log in again.';
      }

      final userMap = data['user'];
      if (userMap == null) {
        throw 'User details missing from server response.';
      }

      final user = UserModel.fromMap(userMap);
      final availableRoles = data['availableRoles'] ?? state.availableRoles;

      await _finalizeLogin(user, token, availableRoles: availableRoles);
      return {'success': true};
    } catch (e) {
      debugPrint('DEBUG: Select Role Error: $e');
      state = state.copyWith(isLoading: false);
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> _finalizeLogin(UserModel user, String token, {List<dynamic>? availableRoles}) async {
    state = state.copyWith(
      user: user,
      isLoading: false,
      needsRoleSelection: false,
      tempToken: null,
      availableRoles: availableRoles,
    );
    _apiService.setToken(token);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, user.toJson());
    await prefs.setString(_tokenKey, token);
    if (availableRoles != null) {
      await prefs.setString(_rolesKey, json.encode(availableRoles));
    }


  }

  Future<void> logout() async {
    if (state.isLoading) return;

    try {
      state = state.copyWith(isLoading: true);


      await _apiService.post('/auth/logout', {});
    } catch (e) {
      debugPrint('DEBUG: Logout API Error: $e');
    } finally {
      state = AuthState();
      _apiService.setToken('');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_tokenKey);
      await prefs.remove(_rolesKey);


    }
  }

  // Rest of the methods (forgotPassword, resetPassword, switchRole) remain the same...
  Future<bool> switchRole(String role, String dept) async {
    try {
      state = state.copyWith(isLoading: true);
      final response = await _apiService.post('/auth/switch-role', {'role': role, 'dept': dept});
      final responseData = json.decode(response.body);
      final data = responseData['data'] ?? responseData;
      final String token = data['token'];
      final user = UserModel.fromMap(data['user']);
      final availableRoles = data['availableRoles'] ?? state.availableRoles;
      await _finalizeLogin(user, token, availableRoles: availableRoles);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _apiService.post('/auth/forgot-password', {'email': email});
      final responseData = json.decode(response.body);
      return {'success': true, 'message': responseData['message'] ?? 'Reset link sent if email exists.'};
    } catch (e) { return {'success': false, 'message': e.toString()}; }
  }

  Future<Map<String, dynamic>> resetPassword(String token, String newPassword) async {
    try {
      final response = await _apiService.post('/auth/reset-password/$token', {'password': newPassword});
      final responseData = json.decode(response.body);
      return {'success': true, 'message': responseData['message'] ?? 'Password reset successfully.'};
    } catch (e) { return {'success': false, 'message': e.toString()}; }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return AuthNotifier(apiService);
});