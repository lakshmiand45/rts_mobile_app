import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';

class PushNotificationsApi {
  final ApiService _apiService;

  PushNotificationsApi(this._apiService);

  /// Registers the FCM token with the backend
  /// POST /push/fcm-register
  Future<dynamic> registerToken(String token) async {
    final response = await _apiService.post('/push/fcm-register', {
      'token': token,
    });
    return json.decode(response.body);
  }

  /// Unregisters the FCM token from the backend
  /// POST /push/fcm-unregister
  Future<dynamic> unregisterToken(String token) async {
    final response = await _apiService.post('/push/fcm-unregister', {
      'token': token,
    });
    return json.decode(response.body);
  }

  /// Sends a test notification to the current user
  /// POST /push/fcm-test
  Future<dynamic> sendTestNotification(String title, String body) async {
    final response = await _apiService.post('/push/fcm-test', {
      'title': title,
      'body': body,
    });
    return json.decode(response.body);
  }
}

final pushNotificationsApiProvider = Provider<PushNotificationsApi>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return PushNotificationsApi(apiService);
});