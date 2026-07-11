import 'dart:convert';

import 'package:payrogen_sdk/payrogen_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

/// Creates a mock HTTP client that returns pre-configured responses.
http_testing.MockClient createMockClient({
  required Map<String, http.Response> responses,
}) {
  final mockClient = http_testing.MockClient((request) async {
    final path = request.url.path;
    if (responses.containsKey(path)) {
      return responses[path]!;
    }
    return http.Response(
      jsonEncode({
        'error': {'code': 'NOT_FOUND', 'message': 'Endpoint not found'}
      }),
      404,
    );
  });

  _currentMockClient = mockClient;
  return mockClient;
}

/// Creates a PayRogen instance that is already authenticated for testing.
Future<PayRogen> createAuthenticatedPayRogen({
  Map<String, http.Response>? additionalResponses,
  SecureShareStorage? secureStorage,
}) async {
  final responses = <String, http.Response>{
    '/v1/auth/session': http.Response(
      jsonEncode({'session_token': 'test_session_token'}),
      200,
    ),
    ...?additionalResponses,
  };

  createMockClient(responses: responses);

  return PayRogen.initWithClient(
    apiKey: 'ck_sandbox_testkey',
    environment: PayRogenEnvironment.sandbox,
    httpClient: _currentMockClient!,
    secureStorage: secureStorage,
  );
}

http_testing.MockClient? _currentMockClient;
