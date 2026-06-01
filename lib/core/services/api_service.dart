import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FileData {
  final String? path;
  final Uint8List? bytes;
  final String name;

  FileData({this.path, this.bytes, required this.name});
}

class ApiService {
  // Use a getter to ensure the value is retrieved from dotenv after it's loaded in main.dart
  String get baseUrl => '${dotenv.env['API_BASE_URL'] ?? 'http://192.168.1.218:5000'}/api';
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
        List<FileData>? files,
        String fileKey = 'files',
      }) async {
    return _multipartRequest(
      'POST',
      endpoint,
      fields,
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
      files: files,
      fileKey: fileKey,
    );
  }

  Future<http.StreamedResponse> patchMultipart(
      String endpoint,
      Map<String, String> fields, {
        String? filePath,
        Uint8List? fileBytes,
        String? fileName,
        List<FileData>? files,
        String fileKey = 'file',
      }) async {
    return _multipartRequest(
      'PATCH',
      endpoint,
      fields,
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
      files: files,
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
        List<FileData>? files,
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

      if (files != null && files.isNotEmpty) {
        for (var file in files) {
          if (file.bytes != null) {
            final sanitizedName = _sanitizeFileName(file.name);
            final contentType = _getMediaType(sanitizedName);
            request.files.add(http.MultipartFile.fromBytes(
              fileKey,
              file.bytes!,
              filename: sanitizedName,
              contentType: contentType,
            ));
          } else if (file.path != null) {
            final sanitizedName = _sanitizeFileName(file.name);
            final contentType = _getMediaType(sanitizedName);
            request.files.add(await http.MultipartFile.fromPath(
              fileKey,
              file.path!,
              filename: sanitizedName,
              contentType: contentType,
            ));
          }
        }
      } else if (fileBytes != null && fileName != null) {
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
      case 'doc':
      case 'docx':
        return MediaType('application', 'vnd.openxmlformats-officedocument.wordprocessingml.document');
      case 'xls':
      case 'xlsx':
        return MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      case 'csv':
        return MediaType('text', 'csv');
      case 'mp3':
        return MediaType('audio', 'mpeg');
      case 'wav':
        return MediaType('audio', 'wav');
      case 'mp4a':
        return MediaType('audio', 'mp4');
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