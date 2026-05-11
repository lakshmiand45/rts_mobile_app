import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  final String baseUrl = 'http://192.168.1.128:5000/api';
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Future<http.Response> get(String endpoint) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await http.get(url, headers: _getHeaders());
      return _handleResponse(response);
    } on SocketException {
      throw 'Check your network connection';
    } catch (e) {
      throw e.toString();
    }
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: json.encode(data),
      );
      return _handleResponse(response);
    } on SocketException {
      throw 'Check your network connection';
    } catch (e) {
      rethrow;
    }
  }

  Future<http.Response> patch(String endpoint, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await http.patch(
        url,
        headers: _getHeaders(),
        body: json.encode(data),
      );
      return _handleResponse(response);
    } on SocketException {
      throw 'Check your network connection';
    } catch (e) {
      rethrow;
    }
  }

  Future<http.StreamedResponse> postMultipart(
    String endpoint, 
    Map<String, String> fields, {
    String? filePath, 
    Uint8List? fileBytes, 
    String? fileName, 
    String fileKey = 'file',
  }) async {
    return _multipartRequest(
      'POST', 
      endpoint, 
      fields, 
      filePath: filePath, 
      fileBytes: fileBytes, 
      fileName: fileName, 
      fileKey: fileKey,
    );
  }

  Future<http.StreamedResponse> patchMultipart(
    String endpoint, 
    Map<String, String> fields, {
    String? filePath, 
    Uint8List? fileBytes, 
    String? fileName, 
    String fileKey = 'file',
  }) async {
    return _multipartRequest(
      'PATCH', 
      endpoint, 
      fields, 
      filePath: filePath, 
      fileBytes: fileBytes, 
      fileName: fileName, 
      fileKey: fileKey,
    );
  }

  Future<http.StreamedResponse> _multipartRequest(
    String method, 
    String endpoint, 
    Map<String, String> fields, {
    String? filePath, 
    Uint8List? fileBytes, 
    String? fileName, 
    required String fileKey,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      var request = http.MultipartRequest(method, url);
      
      request.headers.addAll({
        if (_token != null) 'Authorization': 'Bearer $_token',
        'Accept': 'application/json',
      });
      
      request.fields.addAll(fields);

      if (fileBytes != null && fileName != null) {
        final sanitizedName = _sanitizeFileName(fileName);
        final contentType = _getMediaType(sanitizedName);
        request.files.add(http.MultipartFile.fromBytes(
          fileKey, 
          fileBytes, 
          filename: sanitizedName,
          contentType: contentType,
        ));
      } else if (filePath != null) {
        final originalName = filePath.split('/').last;
        final sanitizedName = _sanitizeFileName(originalName);
        final contentType = _getMediaType(sanitizedName);
        request.files.add(await http.MultipartFile.fromPath(
          fileKey, 
          filePath,
          filename: sanitizedName,
          contentType: contentType,
        ));
      }

      return await request.send();
    } on SocketException {
      throw 'Check your network connection';
    } catch (e) {
      rethrow;
    }
  }

  String _sanitizeFileName(String name) {
    String extension = '';
    if (name.contains('.')) {
      extension = '.${name.split('.').last}';
    }
    String baseName = name.split('.').first;
    baseName = baseName.replaceAll(RegExp(r'[^\w\s-]'), '_').replaceAll(' ', '_');
    if (baseName.length > 30) baseName = baseName.substring(0, 30);
    return '$baseName$extension';
  }

  MediaType _getMediaType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'pdf':
        return MediaType('application', 'pdf');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  http.Response _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    switch (response.statusCode) {
      case 400:
        throw 'Invalid request. Please check your data.';
      case 401:
        throw 'Invalid credentials. Please try again.';
      case 403:
        throw 'You do not have permission to perform this action.';
      case 404:
        throw 'Requested resource not found.';
      case 409:
        throw 'This action has already been performed or there is a conflict.';
      case 500:
        throw 'Server error. Please try again later.';
      default:
        throw 'Something went wrong. Status: ${response.statusCode}';
    }
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});
