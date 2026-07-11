import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'models/environment.dart';
import 'offline_retry_queue.dart';

/// Internal HTTP client for communicating with the PayRogen Gateway API.
class ApiClient {
  final String _apiKey;
  final PayRogenEnvironment _environment;
  final http.Client _httpClient;

  /// Offline retry queue for handling network failures.
  final OfflineRetryQueue _retryQueue;

  /// Session token obtained from authentication.
  String? _sessionToken;

  /// Whether the client has been authenticated.
  bool get isAuthenticated => _sessionToken != null;

  /// Exposes the retry queue for testing and monitoring.
  OfflineRetryQueue get retryQueue => _retryQueue;

  /// Base URL determined by environment.
  String get baseUrl {
    switch (_environment) {
      case PayRogenEnvironment.sandbox:
        return 'https://sandbox-api.payrogen.com';
      case PayRogenEnvironment.live:
        return 'https://api.payrogen.com';
    }
  }

  ApiClient({
    required String apiKey,
    required PayRogenEnvironment environment,
    http.Client? httpClient,
    OfflineRetryQueue? retryQueue,
  })  : _apiKey = apiKey,
        _environment = environment,
        _httpClient = httpClient ?? http.Client(),
        _retryQueue = retryQueue ?? OfflineRetryQueue();

  /// Authenticate with the Gateway and cache the session token.
  Future<void> authenticate() async {
    final response = await _request(
      'POST',
      '/v1/auth/session',
      body: {'api_key': _apiKey},
      authenticated: false,
    );
    _sessionToken = response['session_token'] as String;
  }

  /// Send a POST request to the Gateway.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _request('POST', path, body: body);
  }

  /// Send a GET request to the Gateway.
  Future<Map<String, dynamic>> get(String path) async {
    return _request('GET', path);
  }

  /// Send a DELETE request to the Gateway.
  Future<Map<String, dynamic>> delete(String path) async {
    return _request('DELETE', path);
  }

  /// Internal request method with retry logic.
  ///
  /// On network failures (Gateway unreachable), queues the operation in the
  /// OfflineRetryQueue and retries with exponential backoff (1s, 2s, 4s)
  /// up to 3 attempts before returning an error. (Requirement 9.6)
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-API-Key': _apiKey,
    };

    if (authenticated && _sessionToken != null) {
      headers['Authorization'] = 'Bearer $_sessionToken';
    }

    try {
      return await _executeRequest(method, uri, headers, body);
    } on PayRogenRateLimitException {
      rethrow;
    } on PayRogenException {
      rethrow;
    } on Exception {
      // Network failure detected — queue for retry with exponential backoff
      return _retryQueue.enqueue<Map<String, dynamic>>(
        () => _executeRequest(method, uri, headers, body),
      );
    }
  }

  /// Execute a single HTTP request.
  Future<Map<String, dynamic>> _executeRequest(
    String method,
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic>? body,
  ) async {
    http.Response response;

    if (method == 'POST') {
      response = await _httpClient.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    } else if (method == 'DELETE') {
      response = await _httpClient.delete(uri, headers: headers);
    } else {
      response = await _httpClient.get(uri, headers: headers);
    }

    return _handleResponse(response);
  }

  /// Handle the HTTP response and return parsed JSON or throw an exception.
  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    switch (response.statusCode) {
      case 401:
        throw const PayRogenAuthException();
      case 429:
        final retryAfter = int.tryParse(
              response.headers['retry-after'] ?? '60',
            ) ??
            60;
        throw PayRogenRateLimitException(
          retryAfter: Duration(seconds: retryAfter),
        );
      case 400:
        final error = body['error'] as Map<String, dynamic>?;
        throw PayRogenValidationException(
          message: error?['message'] as String? ?? 'Validation error',
          details: error?['details'] as Map<String, dynamic>?,
        );
      default:
        final error = body['error'] as Map<String, dynamic>?;
        throw PayRogenException(
          code: error?['code'] as String? ?? 'UNKNOWN',
          message: error?['message'] as String? ?? 'An error occurred',
          statusCode: response.statusCode,
        );
    }
  }

  /// Close the HTTP client.
  void close() {
    _httpClient.close();
  }
}
