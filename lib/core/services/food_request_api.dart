import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';

class FoodRequestApi {
  final ApiService _apiService;

  FoodRequestApi(this._apiService);

  Future<dynamic> subscribe(String startDate, String location) async {
    final response = await _apiService.post('/food/subscribe', {
      'startDate': startDate,
      'location': location,
    });
    return json.decode(response.body);
  }

  Future<dynamic> getStatus() async {
    final response = await _apiService.get('/food/status');
    return json.decode(response.body);
  }

  // Button 1: Skip Next Week
  Future<dynamic> cancelNextWeek() async {
    final response = await _apiService.post('/food/cancel-week', {});
    return json.decode(response.body);
  }

  Future<dynamic> undoCancelNextWeek() async {
    final response = await _apiService.post('/food/undo-cancel-week', {});
    return json.decode(response.body);
  }

  // Button 2: Pause for the Year
  Future<dynamic> pauseYear() async {
    final response = await _apiService.post('/food/cancel', {});
    return json.decode(response.body);
  }

  Future<dynamic> undoPauseYear() async {
    final response = await _apiService.post('/food/undo-cancel', {});
    return json.decode(response.body);
  }

  // Button 3: Resume Next Week
  Future<dynamic> enableNextWeek() async {
    final response = await _apiService.post('/food/enable-next-week', {});
    return json.decode(response.body);
  }

  Future<dynamic> undoEnableNextWeek() async {
    final response = await _apiService.post('/food/undo-enable-next-week', {});
    return json.decode(response.body);
  }

  // Button 4: Resume for the Year
  Future<dynamic> enableYear() async {
    final response = await _apiService.post('/food/enable-year', {});
    return json.decode(response.body);
  }

  // Admin/Legacy?
  Future<dynamic> disableYear() async {
    final response = await _apiService.post('/food/disable-year', {});
    return json.decode(response.body);
  }

  Future<dynamic> getCalendar(int month, int year) async {
    final response = await _apiService.get('/food/calendar?month=$month&year=$year');
    return json.decode(response.body);
  }

  Future<dynamic> getReport() async {
    final response = await _apiService.get('/food/report');
    return json.decode(response.body);
  }

  Future<dynamic> downloadReport() async {
    final response = await _apiService.get('/food/download-report');
    try {
      return json.decode(response.body);
    } catch (_) {
      return response.body;
    }
  }
}

final foodRequestApiProvider = Provider<FoodRequestApi>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return FoodRequestApi(apiService);
});
