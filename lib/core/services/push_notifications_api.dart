import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';

class NotificationsApi {
  final ApiService _apiService;

  NotificationsApi(this._apiService);

  Future<String> getVapidPublicKey() async {
    final response = await _apiService.get('/push/vapid-public-key');
    final data = json.decode(response.body);
    return data['publicKey'];
  }

  Future<bool> subscribe(Map<String, dynamic> subscription) async {
    final response = await _apiService.post('/push/subscribe', subscription);
    final data = json.decode(response.body);
    return data['success'] ?? false;
  }

  Future<bool> unsubscribe(String endpoint) async {
    final response = await _apiService.post('/push/unsubscribe', {'endpoint': endpoint});
    final data = json.decode(response.body);
    return data['success'] ?? false;
  }

  Future<void> triggerReminder() async {
    await _apiService.post('/push/trigger-reminder', {});
  }
}

final notificationsApiProvider = Provider<NotificationsApi>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return NotificationsApi(apiService);
});
