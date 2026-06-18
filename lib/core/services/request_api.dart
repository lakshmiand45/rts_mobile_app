import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';

class RequestApi {
  final ApiService _apiService;

  RequestApi(this._apiService);

  Future<Map<String, dynamic>> fetchFilterOptions() async {
    final response = await _apiService.get('/requests/filters');
    final decoded = json.decode(response.body);
    // Consistency check: Extract 'data' if nested
    return (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
  }

  Future<List<dynamic>> fetchUsersByDept(String depts) async {
    final response = await _apiService.get('/requests/users-by-dept?depts=$depts');
    final decoded = json.decode(response.body);
    if (decoded is List) return decoded;
    final data = decoded['users'] ?? decoded['data'];
    if (data is List) return data;
    return [];
  }

  Future<List<String>> fetchAllDepartments() async {
    final response = await _apiService.get('/requests/departments');
    final decoded = json.decode(response.body);
    final data = (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
    if (data is Map && data.containsKey('departments')) {
      return List<String>.from(data['departments']);
    } else if (data is List) {
      return List<String>.from(data);
    }
    return [];
  }

  Future<dynamic> fetchRequests(String path, Map<String, String> queryParams) async {
    final queryString = Uri(queryParameters: queryParams).query;
    final response = await _apiService.get('$path?$queryString');
    debugPrint('DEBUG: RequestApi fetchRequests statusCode: ${response.statusCode}');
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> fetchRequestById(String id) async {
    final response = await _apiService.get('/requests/$id');
    final decoded = json.decode(response.body);
    return (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
  }

  Future<dynamic> fetchHODPendingRequests() async {
    final response = await _apiService.get('/requests/hod-pending');
    debugPrint('DEBUG: RequestApi fetchHODPendingRequests statusCode: ${response.statusCode}');
    return json.decode(response.body);
  }

  Future<List<dynamic>> fetchChatMessages(String ticketId) async {
    final response = await _apiService.get('/requests/$ticketId/chat');
    final decoded = json.decode(response.body);
    final data = (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
    return data is List ? data : [];
  }

  Future<Map<String, dynamic>> sendChatMessage(String ticketId, String text, String type) async {
    final response = await _apiService.post('/requests/$ticketId/chat', {'type': type, 'text': text});
    final decoded = json.decode(response.body);
    return (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
  }

  Future<Map<String, dynamic>> sendFileAttachment(
    String ticketId, {
    required Map<String, String> fields,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final streamedResponse = await _apiService.postMultipart(
      '/requests/$ticketId/chat',
      fields,
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
      fileKey: 'file',
    );
    final response = await http.Response.fromStream(streamedResponse);
    final decoded = json.decode(response.body);
    return (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
  }

  Future<Map<String, dynamic>> addRequest({
    required Map<String, dynamic> data,
    required Map<String, String> fields,
    List<FileData>? files,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    http.Response response;
    if (files != null || filePath != null || fileBytes != null) {
      final streamedResponse = await _apiService.postMultipart(
        '/requests',
        fields,
        files: files,
        filePath: filePath,
        fileBytes: fileBytes,
        fileName: fileName,
        fileKey: 'files',
      );
      response = await http.Response.fromStream(streamedResponse);
    } else {
      response = await _apiService.post('/requests', data);
    }
    final decoded = json.decode(response.body);
    return (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
  }

  Future<Map<String, dynamic>> updateApproval(String ticketId, Map<String, dynamic> body) async {
    final response = await _apiService.patch('/requests/$ticketId/approval', body);
    final decoded = json.decode(response.body);
    return (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
  }

  Future<Map<String, dynamic>> updateHODApproval(String ticketId, Map<String, dynamic> body) async {
    final response = await _apiService.patch('/requests/$ticketId/hod-approval', body);
    final decoded = json.decode(response.body);
    return (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
  }

  Future<Map<String, dynamic>> closeTicket(
    String ticketId,
    Map<String, String> fields, {
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    http.Response response;
    if (filePath != null || fileBytes != null) {
      final streamedResponse = await _apiService.patchMultipart(
        '/requests/$ticketId/close',
        fields,
        filePath: filePath,
        fileBytes: fileBytes,
        fileName: fileName,
        fileKey: 'file',
      );
      response = await http.Response.fromStream(streamedResponse);
    } else {
      response = await _apiService.patch('/requests/$ticketId/close', fields);
    }
    final decoded = json.decode(response.body);
    return (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
  }

  Future<Map<String, dynamic>> acknowledgeRequest(String ticketId, String status) async {
    final response = await _apiService.patch('/requests/$ticketId/acknowledge', {'status': status});
    final decoded = json.decode(response.body);
    return (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
  }

  Future<void> markAsRead(String requestId) async {
    await _apiService.patch('/requests/$requestId/seen', {});
  }

  Future<void> markAsUnread(String ticketId) async {
    await _apiService.patch('/requests/$ticketId/unread', {});
  }
}

final requestApiProvider = Provider<RequestApi>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return RequestApi(apiService);
});
