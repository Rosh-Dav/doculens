import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:image_picker/image_picker.dart';

class ApiService {
  ApiService({String? baseUrl})
    : _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://127.0.0.1:8000/api',
          );

  final String _baseUrl;

  Future<Map<String, dynamic>> analyze({String? text, XFile? image}) async {
    final uri = Uri.parse('$_baseUrl/analyze');
    final request = http.MultipartRequest('POST', uri);

    if (text != null && text.trim().isNotEmpty) {
      request.fields['text'] = text.trim();
    }

    if (image != null) {
      final bytes = await image.readAsBytes();
      final name = image.name;
      final extension = name.split('.').last.toLowerCase();
      final mimeType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: name,
        contentType: _parseMediaType(mimeType),
      ));
    }

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    final decoded = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body) as Map<String, dynamic>;

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw ApiException(
        decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            'Request failed (${streamed.statusCode})',
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> createTask({
    required Map<String, dynamic> inspection,
  }) async {
    final action =
        ((inspection['recommended_actions'] as List?)?.firstOrNull
                as Map?)?['action']
            as String? ??
        'Inspect ${inspection['machine_id'] ?? 'equipment'}.';
    return _jsonRequest('POST', '/tasks', {
      'inspection_id': inspection['inspection_id'],
      'title': action,
      'machine_id': inspection['machine_id'],
      'priority': inspection['risk_priority'] ?? 'MEDIUM',
      'notes': 'Created from DocuLens inspection.',
    });
  }

  Future<List<Map<String, dynamic>>> history(String path, String key) async {
    final response = await http.get(Uri.parse('$_baseUrl$path'));
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Request failed (${response.statusCode})');
    }
    return (decoded[key] as List? ?? [])
        .cast<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> _jsonRequest(
    String method,
    String path,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            'Request failed (${response.statusCode})',
      );
    }
    return decoded;
  }
}

/// Simple MediaType parser for http.MultipartFile
MediaType _parseMediaType(String mimeType) {
  final parts = mimeType.split('/');
  return MediaType(parts[0], parts.length > 1 ? parts[1] : 'octet-stream');
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
