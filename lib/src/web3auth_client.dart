import 'package:http/http.dart' as http;

import 'models/environment.dart';

/// Abstraction for retrieving Share_B from the Web3Auth authentication
/// provider.
///
/// Share_B is the SSS key share held by Web3Auth, tied to the user's social
/// login credentials. It is retrieved during transaction signing to
/// reconstruct the private key alongside Share_A (device).
abstract class Web3AuthClient {
  /// Retrieves Share_B for the given [userId].
  ///
  /// Returns the share as a hex-encoded string.
  /// Throws [Web3AuthException] if retrieval fails.
  Future<String> retrieveShareB({required String userId});
}

/// Exception thrown when Web3Auth operations fail.
class Web3AuthException implements Exception {
  /// Human-readable description of the failure.
  final String message;

  /// The underlying error, if available.
  final Object? cause;

  const Web3AuthException({
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'Web3AuthException: $message';
}

/// HTTP-based implementation of [Web3AuthClient] that retrieves Share_B
/// from the Web3Auth service via the Gateway API.
class HttpWeb3AuthClient implements Web3AuthClient {
  final http.Client _httpClient;
  final String _baseUrl;
  final String _apiKey;
  final String? _sessionToken;

  HttpWeb3AuthClient({
    required http.Client httpClient,
    required PayRogenEnvironment environment,
    required String apiKey,
    String? sessionToken,
  })  : _httpClient = httpClient,
        _baseUrl = environment == PayRogenEnvironment.sandbox
            ? 'https://sandbox-api.payrogen.com'
            : 'https://api.payrogen.com',
        _apiKey = apiKey,
        _sessionToken = sessionToken;

  @override
  Future<String> retrieveShareB({required String userId}) async {
    final uri = Uri.parse('$_baseUrl/v1/web3auth/share-b');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-API-Key': _apiKey,
    };

    if (_sessionToken != null) {
      headers['Authorization'] = 'Bearer $_sessionToken';
    }

    try {
      final response = await _httpClient.post(
        uri,
        headers: headers,
        body: '{"user_id":"$userId"}',
      );

      if (response.statusCode == 200) {
        // Response body contains the share_b field
        final body = response.body;
        // Simple JSON parsing to avoid importing dart:convert here
        final shareB = _extractField(body, 'share_b');
        if (shareB == null || shareB.isEmpty) {
          throw const Web3AuthException(
            message: 'Share_B not found in response',
          );
        }
        return shareB;
      }

      throw Web3AuthException(
        message:
            'Failed to retrieve Share_B: HTTP ${response.statusCode}',
      );
    } on Web3AuthException {
      rethrow;
    } on Exception catch (e) {
      throw Web3AuthException(
        message: 'Network error retrieving Share_B',
        cause: e,
      );
    }
  }

  /// Extract a string field value from a JSON response body.
  String? _extractField(String json, String field) {
    final pattern = '"$field":"';
    final start = json.indexOf(pattern);
    if (start == -1) return null;
    final valueStart = start + pattern.length;
    final valueEnd = json.indexOf('"', valueStart);
    if (valueEnd == -1) return null;
    return json.substring(valueStart, valueEnd);
  }
}
