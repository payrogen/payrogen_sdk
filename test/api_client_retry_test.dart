import 'dart:convert';
import 'dart:io';

import 'package:payrogen_sdk/payrogen_sdk.dart';
import 'package:payrogen_sdk/src/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiClient - Offline Retry Integration', () {
    test('retries on network failure and succeeds on subsequent attempt',
        () async {
      var requestCount = 0;

      final mockClient = http_testing.MockClient((request) async {
        requestCount++;
        if (request.url.path == '/v1/auth/session') {
          return http.Response(
            jsonEncode({'session_token': 'test_token'}),
            200,
          );
        }
        if (request.url.path == '/v1/wallets/create') {
          if (requestCount <= 2) {
            // First attempt on the actual request fails with network error
            throw const SocketException('Connection refused');
          }
          return http.Response(
            jsonEncode({
              'public_address': 'addr_recovered',
              'user_id': 'user_1',
              'share_a': 'share_data',
              'created_at': DateTime.now().toIso8601String(),
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'error': {'code': 'NOT_FOUND', 'message': 'Not found'}
          }),
          404,
        );
      });

      final retryQueue = OfflineRetryQueue(
        baseDelayMs: 10, // Fast for testing
        maxAttempts: 3,
        delayFunction: (duration) async {}, // No actual delay in tests
      );

      final apiClient = ApiClient(
        apiKey: 'ck_sandbox_test',
        environment: PayRogenEnvironment.sandbox,
        httpClient: mockClient,
        retryQueue: retryQueue,
      );

      await apiClient.authenticate();

      final result = await apiClient.post(
        '/v1/wallets/create',
        body: {'user_id': 'user_1'},
      );

      expect(result['public_address'], 'addr_recovered');
    });

    test('throws PayRogenNetworkException after exhausting retries',
        () async {
      var authDone = false;

      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/v1/auth/session') {
          authDone = true;
          return http.Response(
            jsonEncode({'session_token': 'test_token'}),
            200,
          );
        }
        // All subsequent requests fail with network error
        throw const SocketException('Connection refused');
      });

      final retryQueue = OfflineRetryQueue(
        baseDelayMs: 10,
        maxAttempts: 3,
        delayFunction: (duration) async {},
      );

      final apiClient = ApiClient(
        apiKey: 'ck_sandbox_test',
        environment: PayRogenEnvironment.sandbox,
        httpClient: mockClient,
        retryQueue: retryQueue,
      );

      await apiClient.authenticate();
      expect(authDone, true);

      expect(
        () => apiClient.post('/v1/wallets/create', body: {'user_id': 'u1'}),
        throwsA(isA<Exception>()),
      );
    });

    test('does not retry on PayRogenException (non-network errors)',
        () async {
      var requestCount = 0;

      final mockClient = http_testing.MockClient((request) async {
        requestCount++;
        if (request.url.path == '/v1/auth/session') {
          return http.Response(
            jsonEncode({'session_token': 'test_token'}),
            200,
          );
        }
        // Return a validation error — should NOT be retried
        return http.Response(
          jsonEncode({
            'error': {'code': 'VALIDATION', 'message': 'Invalid input'}
          }),
          400,
        );
      });

      final retryQueue = OfflineRetryQueue(
        baseDelayMs: 10,
        maxAttempts: 3,
        delayFunction: (duration) async {},
      );

      final apiClient = ApiClient(
        apiKey: 'ck_sandbox_test',
        environment: PayRogenEnvironment.sandbox,
        httpClient: mockClient,
        retryQueue: retryQueue,
      );

      await apiClient.authenticate();

      await expectLater(
        () => apiClient.post('/v1/payments/direct', body: {}),
        throwsA(isA<PayRogenValidationException>()),
      );

      // Should only be called twice: once for auth, once for the request
      expect(requestCount, 2);
    });

    test('does not retry on rate limit exception', () async {
      var requestCount = 0;

      final mockClient = http_testing.MockClient((request) async {
        requestCount++;
        if (request.url.path == '/v1/auth/session') {
          return http.Response(
            jsonEncode({'session_token': 'test_token'}),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'error': {'code': 'RATE_LIMITED', 'message': 'Too many requests'}
          }),
          429,
          headers: {'retry-after': '30'},
        );
      });

      final retryQueue = OfflineRetryQueue(
        baseDelayMs: 10,
        maxAttempts: 3,
        delayFunction: (duration) async {},
      );

      final apiClient = ApiClient(
        apiKey: 'ck_sandbox_test',
        environment: PayRogenEnvironment.sandbox,
        httpClient: mockClient,
        retryQueue: retryQueue,
      );

      await apiClient.authenticate();

      await expectLater(
        () => apiClient.post('/v1/payments/direct', body: {}),
        throwsA(isA<PayRogenRateLimitException>()),
      );

      // Should only be called twice: once for auth, once for the request
      expect(requestCount, 2);
    });
  });

  group('Duress Phrase Transparency (Requirement 9.5)', () {
    test('recoverWallet sends phrase without any SDK-level inspection',
        () async {
      String? capturedPhrase;

      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/v1/auth/session') {
          return http.Response(
            jsonEncode({'session_token': 'test_token'}),
            200,
          );
        }
        if (request.url.path == '/v1/wallets/recover') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          capturedPhrase = body['phrase'] as String?;
          // Gateway returns identical response regardless of duress
          return http.Response(
            jsonEncode({
              'public_address': 'recovered_addr_123',
              'share_a': 'new_share_a',
              'success': true,
              'message': 'Wallet recovered successfully',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'error': {'code': 'NOT_FOUND', 'message': 'Not found'}
          }),
          404,
        );
      });

      final payrogen = await PayRogen.initWithClient(
        apiKey: 'ck_sandbox_test',
        environment: PayRogenEnvironment.sandbox,
        httpClient: mockClient,
      );

      // Use a duress phrase — SDK should pass it transparently
      final result = await payrogen.recoverWallet(
        userId: 'user_123',
        phrase: 'my duress phrase trigger word',
      );

      // Verify phrase was sent as-is without modification
      expect(capturedPhrase, 'my duress phrase trigger word');
      // Verify response is returned normally (no SDK-level indicators)
      expect(result.publicAddress, 'recovered_addr_123');
      expect(result.shareA, 'new_share_a');
      expect(result.success, true);
      expect(result.message, 'Wallet recovered successfully');

      payrogen.dispose();
    });

    test('SDK returns identical response structure for normal and duress phrase',
        () async {
      // Both normal and duress phrases get identical Gateway responses
      // The SDK should not differentiate between them in any way
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/v1/auth/session') {
          return http.Response(
            jsonEncode({'session_token': 'test_token'}),
            200,
          );
        }
        if (request.url.path == '/v1/wallets/recover') {
          return http.Response(
            jsonEncode({
              'public_address': 'addr_xyz',
              'share_a': 'share_data',
              'success': true,
              'message': 'Wallet recovered successfully',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'error': {'code': 'NOT_FOUND', 'message': 'Not found'}
          }),
          404,
        );
      });

      final payrogen = await PayRogen.initWithClient(
        apiKey: 'ck_sandbox_test',
        environment: PayRogenEnvironment.sandbox,
        httpClient: mockClient,
      );

      // Normal recovery
      final normalResult = await payrogen.recoverWallet(
        userId: 'user_1',
        phrase: 'normal recovery phrase',
      );

      // Duress recovery — identical behavior from SDK perspective
      final duressResult = await payrogen.recoverWallet(
        userId: 'user_1',
        phrase: 'duress trigger phrase',
      );

      // Both results should be structurally identical
      expect(normalResult.publicAddress, duressResult.publicAddress);
      expect(normalResult.shareA, duressResult.shareA);
      expect(normalResult.success, duressResult.success);
      expect(normalResult.message, duressResult.message);

      payrogen.dispose();
    });
  });
}
