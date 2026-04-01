import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';

class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.payload,
    this.rawBody,
  });

  final String message;
  final int? statusCode;
  final Object? payload;
  final String? rawBody;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  bool get isOffline => statusCode == null;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message, payload: $payload, rawBody: $rawBody)';
}

class ApiMultipartFile {
  const ApiMultipartFile({
    required this.field,
    required this.bytes,
    required this.filename,
    this.contentType,
  });

  final String field;
  final List<int> bytes;
  final String filename;
  final String? contentType;
}

class ApiClient {
  ApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
  }) {
    return _send(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
    Map<String, Object?> body = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
  }) {
    return _send(
      method: 'POST',
      path: path,
      queryParameters: queryParameters,
      body: body,
      headers: headers,
    );
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
    Map<String, Object?> fields = const <String, Object?>{},
    List<ApiMultipartFile> files = const <ApiMultipartFile>[],
    Map<String, String> headers = const <String, String>{},
  }) {
    return _sendMultipart(
      method: 'POST',
      path: path,
      queryParameters: queryParameters,
      fields: fields,
      files: files,
      headers: headers,
    );
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required String path,
    Map<String, Object?> queryParameters = const <String, Object?>{},
    Map<String, Object?>? body,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final uri = _buildUri(path, queryParameters);

    try {
      final http.Response response;

      _logRequest(
        method: method,
        uri: uri,
        headers: _headers(headers),
        body: body,
      );

      if (method == 'GET') {
        response = await _httpClient.get(uri, headers: _headers(headers));
      } else if (method == 'POST') {
        response = await _httpClient.post(
          uri,
          headers: _headers(headers),
          body: jsonEncode(body ?? const <String, Object?>{}),
        );
      } else {
        throw ApiException(message: 'HTTP method tidak didukung: $method');
      }

      _logResponse(response);

      return _decodeResponse(response);
    } on ApiException {
      rethrow;
    } on http.ClientException catch (error) {
      throw ApiException(message: 'Koneksi ke server gagal: ${error.message}');
    } catch (error) {
      throw ApiException(message: 'Permintaan ke server gagal: $error');
    }
  }

  Future<Map<String, dynamic>> _sendMultipart({
    required String method,
    required String path,
    Map<String, Object?> queryParameters = const <String, Object?>{},
    Map<String, Object?> fields = const <String, Object?>{},
    List<ApiMultipartFile> files = const <ApiMultipartFile>[],
    Map<String, String> headers = const <String, String>{},
  }) async {
    final uri = _buildUri(path, queryParameters);

    try {
      if (method != 'POST') {
        throw ApiException(message: 'HTTP multipart tidak didukung: $method');
      }

      final request = http.MultipartRequest(method, uri)
        ..headers.addAll(_multipartHeaders(headers));

      final normalizedFields = <String, String>{};

      for (final entry in fields.entries) {
        final value = entry.value;
        if (value == null) {
          continue;
        }

        final text = value.toString().trim();
        if (text.isEmpty) {
          continue;
        }

        request.fields[entry.key] = text;
        normalizedFields[entry.key] = text;
      }

      for (final file in files) {
        request.files.add(
          http.MultipartFile.fromBytes(
            file.field,
            file.bytes,
            filename: file.filename,
            contentType: _tryParseMediaType(file.contentType),
          ),
        );
      }

      _logMultipartRequest(
        method: method,
        uri: uri,
        headers: request.headers,
        fields: normalizedFields,
        files: files,
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      _logResponse(response);

      return _decodeResponse(response);
    } on ApiException {
      rethrow;
    } on http.ClientException catch (error) {
      throw ApiException(message: 'Koneksi ke server gagal: ${error.message}');
    } catch (error) {
      throw ApiException(message: 'Permintaan ke server gagal: $error');
    }
  }

  Uri _buildUri(String path, Map<String, Object?> queryParameters) {
    final baseUri = Uri.parse(AppConfig.baseUrl);
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;

    final segments = <String>[
      ...baseUri.pathSegments.where((segment) => segment.isNotEmpty),
      ...normalizedPath.split('/').where((segment) => segment.isNotEmpty),
    ];

    final filteredQuery = <String, String>{};
    for (final entry in queryParameters.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }

      filteredQuery[entry.key] = value.toString();
    }

    return baseUri.replace(
      pathSegments: segments,
      queryParameters: filteredQuery.isEmpty ? null : filteredQuery,
    );
  }

  Map<String, String> _headers(Map<String, String> headers) {
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...headers,
    };
  }

  Map<String, String> _multipartHeaders(Map<String, String> headers) {
    return <String, String>{'Accept': 'application/json', ...headers};
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = response.body.trim();
    final payload = _tryDecodeJson(body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (payload is Map<String, dynamic>) {
        if (payload['success'] == true) {
          final data = payload['data'];
          if (data is Map<String, dynamic>) {
            return data;
          }

          return <String, dynamic>{};
        }

        return payload;
      }

      if (body.isEmpty) {
        return <String, dynamic>{};
      }

      throw ApiException(
        message: 'Response server tidak valid.',
        statusCode: response.statusCode,
        payload: payload,
        rawBody: body,
      );
    }

    final message = payload is Map<String, dynamic>
        ? _errorMessageFromPayload(payload)
        : 'Permintaan gagal (${response.statusCode}).';

    throw ApiException(
      message: message,
      statusCode: response.statusCode,
      payload: payload,
      rawBody: body,
    );
  }

  String _errorMessageFromPayload(Map<String, dynamic> payload) {
    if (payload['success'] == false) {
      final wrappedMessage = payload['message'];
      if (wrappedMessage is String && wrappedMessage.trim().isNotEmpty) {
        return wrappedMessage;
      }
    }

    final directMessage = payload['message'];
    if (directMessage is String && directMessage.trim().isNotEmpty) {
      return directMessage;
    }

    final errors = payload['errors'];
    if (errors is Map<String, dynamic>) {
      final firstError = errors.values
          .whereType<List>()
          .expand((value) => value)
          .whereType<String>()
          .cast<String?>()
          .firstWhere(
            (value) => value != null && value.trim().isNotEmpty,
            orElse: () => null,
          );

      if (firstError != null) {
        return firstError;
      }
    }

    return 'Permintaan ke server gagal.';
  }

  Object? _tryDecodeJson(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  MediaType? _tryParseMediaType(String? value) {
    if (value == null) {
      return null;
    }

    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }

    try {
      return MediaType.parse(text);
    } catch (_) {
      return null;
    }
  }

  void _logRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Object? body,
  }) {
    debugPrint('API REQUEST => $method $uri');
    debugPrint('API REQUEST HEADERS => $headers');
    if (body != null) {
      debugPrint('API REQUEST BODY => $body');
    }
  }

  void _logMultipartRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, String> fields,
    required List<ApiMultipartFile> files,
  }) {
    debugPrint('API MULTIPART REQUEST => $method $uri');
    debugPrint('API MULTIPART HEADERS => $headers');
    debugPrint('API MULTIPART FIELDS => $fields');
    debugPrint(
      'API MULTIPART FILES => ${files.map((file) => {'field': file.field, 'filename': file.filename, 'contentType': file.contentType, 'bytesLength': file.bytes.length}).toList()}',
    );
  }

  void _logResponse(http.Response response) {
    debugPrint('API RESPONSE STATUS => ${response.statusCode}');
    debugPrint('API RESPONSE BODY => ${response.body}');
  }

  void dispose() {
    _httpClient.close();
  }
}
