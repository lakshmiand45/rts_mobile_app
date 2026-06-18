import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';

class RoleManagementApi {
  final ApiService _apiService;

  RoleManagementApi(this._apiService);

  /// Fetches management-specific filter options
  /// Path: /management/requests/filters
  Future<Map<String, dynamic>> fetchManagementFilters() async {
    debugPrint('DEBUG: RoleManagementApi - Entering fetchManagementFilters');
    final response = await _apiService.get('/management/requests/filters');
    debugPrint('DEBUG: RoleManagementApi fetchManagementFilters statusCode: ${response.body}');
    final decoded = json.decode(response.body);
    debugPrint('DEBUG: RoleManagementApi fetchManagementFilters decoded: $decoded');
    // Extract 'data' if nested, similar to fetchRequestById
    return (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
  }

  /// Fetches requests for management with optional filters
  /// Path: /management/requests
  Future<Map<String, dynamic>> fetchManagementRequests({
    int page = 1,
    int limit = 20,
    Map<String, String>? filters,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      ...?filters,
    };
    final queryString = Uri(queryParameters: queryParams).query;
    debugPrint('DEBUG: RoleManagementApi fetchManagementRequests queryString: $queryString');
    final response = await _apiService.get('/management/requests?$queryString');
    final decoded = json.decode(response.body);
    debugPrint('DEBUG: RoleManagementApi fetchManagementRequests decoded: $decoded');
    return decoded;
  }

  /// Fetches a single request by ID
  /// Path: /management/requests/:id
  Future<Map<String, dynamic>> fetchRequestById(String id) async {
    final response = await _apiService.get('/management/requests/$id');
    final decoded = json.decode(response.body);
    return (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
  }

  /// Specialized Management Approval Actions
  /// Updated to match API: PATCH /management/requests/:id/approval
  Future<Map<String, dynamic>> approveRequest(String id, String comment) async {
    final response = await _apiService.patch('/management/requests/$id/approval', {
      'decision': 'Approved',
      'comment': comment,
    });
    final decoded = json.decode(response.body);
    return decoded;
  }

  Future<Map<String, dynamic>> rejectRequest(String id, String comment) async {
    final response = await _apiService.patch('/management/requests/$id/approval', {
      'decision': 'Rejected',
      'comment': comment,
    });
    final decoded = json.decode(response.body);
    return decoded;
  }

  Future<Map<String, dynamic>> checkingRequest(String id, {required String comment, required DateTime deadline, required String reason}) async {
    final response = await _apiService.patch('/management/requests/$id/approval', {
      'decision': 'Checking',
      'comment': comment,
    });
    final decoded = json.decode(response.body);
    return decoded;
  }

  Future<Map<String, dynamic>> closeRequest(String id, String comment) async {
    final response = await _apiService.patch('/management/requests/$id/close', {'comment': comment});
    final decoded = json.decode(response.body);
    return decoded;
  }
}

final roleManagementApiProvider = Provider<RoleManagementApi>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return RoleManagementApi(apiService);
});
