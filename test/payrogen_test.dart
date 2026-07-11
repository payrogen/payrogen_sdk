import 'dart:convert';

import 'package:payrogen_sdk/payrogen_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('PayRogen', () {
    group('init', () {
      test('authenticates and returns PayRogen instance', () async {
        final payrogen = await createAuthenticatedPayRogen();

        expect(payrogen, isA<PayRogen>());
        payrogen.dispose();
      });

      test('throws PayRogenAuthException on 401', () async {
        final mockClient = http_testing.MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': {'code': 'AUTH_FAILED', 'message': 'Invalid API key'}
            }),
            401,
          );
        });

        expect(
          () => PayRogen.initWithClient(
            apiKey: 'ck_sandbox_invalid',
            environment: PayRogenEnvironment.sandbox,
            httpClient: mockClient,
          ),
          throwsA(isA<PayRogenAuthException>()),
        );
      });
    });

    group('createWallet', () {
      test('creates a wallet and returns Wallet model', () async {
        final now = DateTime.now().toIso8601String();
        final payrogen = await createAuthenticatedPayRogen(
          additionalResponses: {
            '/v1/wallets/create': http.Response(
              jsonEncode({
                'public_address': 'So1anaAddr3ss1234567890abcdefghijk',
                'user_id': 'user_123',
                'share_a': 'encrypted_share_a_data',
                'created_at': now,
              }),
              200,
            ),
          },
        );

        final wallet = await payrogen.createWallet(userId: 'user_123');

        expect(wallet.publicAddress, 'So1anaAddr3ss1234567890abcdefghijk');
        expect(wallet.userId, 'user_123');
        expect(wallet.shareA, 'encrypted_share_a_data');
        payrogen.dispose();
      });

      test('throws validation error for empty userId', () async {
        final payrogen = await createAuthenticatedPayRogen();

        expect(
          () => payrogen.createWallet(userId: ''),
          throwsA(isA<PayRogenValidationException>()),
        );
        payrogen.dispose();
      });
    });

    group('payDirect', () {
      test('executes a direct payment and returns PaymentResult', () async {
        final now = DateTime.now().toIso8601String();
        final payrogen = await createAuthenticatedPayRogen(
          additionalResponses: {
            '/v1/payments/direct': http.Response(
              jsonEncode({
                'transaction_id': 'tx_abc123',
                'signature': 'sig_xyz789',
                'status': 'confirmed',
                'amount': 100.0,
                'currency': 'USDT',
                'created_at': now,
              }),
              200,
            ),
          },
        );

        final result = await payrogen.payDirect(
          amount: 100.0,
          currency: 'USDT',
          from: 'payer_address_123',
          to: 'receiver_address_456',
          splits: {
            'receiver_address_456': 9000,
            'platform_address': 1000,
          },
        );

        expect(result.transactionId, 'tx_abc123');
        expect(result.signature, 'sig_xyz789');
        expect(result.status, 'confirmed');
        expect(result.amount, 100.0);
        expect(result.currency, 'USDT');
        payrogen.dispose();
      });

      test('includes idempotency key and metadata when provided', () async {
        final now = DateTime.now().toIso8601String();
        Map<String, dynamic>? capturedBody;

        final mockClient = http_testing.MockClient((request) async {
          if (request.url.path == '/v1/auth/session') {
            return http.Response(
              jsonEncode({'session_token': 'token'}),
              200,
            );
          }
          if (request.url.path == '/v1/payments/direct') {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'transaction_id': 'tx_1',
                'signature': 'sig_1',
                'status': 'confirmed',
                'amount': 50.0,
                'currency': 'USDT',
                'created_at': now,
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

        await payrogen.payDirect(
          amount: 50.0,
          currency: 'USDT',
          from: 'payer',
          to: 'receiver',
          splits: {'receiver': 10000},
          idempotencyKey: 'idem_123',
          metadata: {'order_id': 'order_456'},
        );

        expect(capturedBody?['idempotency_key'], 'idem_123');
        expect(capturedBody?['metadata'], {'order_id': 'order_456'});
        payrogen.dispose();
        mockClient.close();
      });
    });

    group('payEscrow', () {
      test('creates an escrow payment and returns EscrowResult', () async {
        final now = DateTime.now();
        final timeout = now.add(const Duration(hours: 24));
        final payrogen = await createAuthenticatedPayRogen(
          additionalResponses: {
            '/v1/payments/escrow': http.Response(
              jsonEncode({
                'escrow_id': 'esc_abc123',
                'transaction_id': 'tx_def456',
                'status': 'locked',
                'amount': 200.0,
                'currency': 'USDT',
                'locked_at': now.toIso8601String(),
                'timeout_at': timeout.toIso8601String(),
              }),
              200,
            ),
          },
        );

        final result = await payrogen.payEscrow(
          amount: 200.0,
          currency: 'USDT',
          payer: 'buyer_address',
          serviceProvider: 'seller_address',
          platform: 'platform_address',
          splits: {
            'seller_address': 8500,
            'platform_address': 1000,
            'payrogen_treasury': 500,
          },
        );

        expect(result.escrowId, 'esc_abc123');
        expect(result.status, 'locked');
        expect(result.amount, 200.0);
        payrogen.dispose();
      });
    });

    group('recoverWallet', () {
      test('recovers a wallet and returns RecoveryResult', () async {
        final payrogen = await createAuthenticatedPayRogen(
          additionalResponses: {
            '/v1/wallets/recover': http.Response(
              jsonEncode({
                'public_address': 'recovered_address_123',
                'share_a': 'new_share_a_data',
                'success': true,
                'message': 'Wallet recovered successfully',
              }),
              200,
            ),
          },
        );

        final result = await payrogen.recoverWallet(
          userId: 'user_123',
          phrase: 'my recovery phrase words',
        );

        expect(result.publicAddress, 'recovered_address_123');
        expect(result.shareA, 'new_share_a_data');
        expect(result.success, true);
        payrogen.dispose();
      });

      test('throws validation error for empty userId', () async {
        final payrogen = await createAuthenticatedPayRogen();

        expect(
          () => payrogen.recoverWallet(userId: '', phrase: 'some phrase'),
          throwsA(isA<PayRogenValidationException>()),
        );
        payrogen.dispose();
      });

      test('throws validation error for empty phrase', () async {
        final payrogen = await createAuthenticatedPayRogen();

        expect(
          () => payrogen.recoverWallet(userId: 'user_123', phrase: ''),
          throwsA(isA<PayRogenValidationException>()),
        );
        payrogen.dispose();
      });
    });

    group('3 method calls maximum per operation', () {
      test('wallet creation requires only 2 calls: init + createWallet',
          () async {
        // Requirement 9.1: no more than 3 method calls per operation
        // Wallet creation: init() -> createWallet() = 2 calls
        final now = DateTime.now().toIso8601String();
        final payrogen = await createAuthenticatedPayRogen(
          additionalResponses: {
            '/v1/wallets/create': http.Response(
              jsonEncode({
                'public_address': 'addr_123',
                'user_id': 'user_1',
                'share_a': 'share_data',
                'created_at': now,
              }),
              200,
            ),
          },
        );

        // Only 2 method calls needed:
        // 1. PayRogen.init() (already done above)
        // 2. createWallet()
        final wallet = await payrogen.createWallet(userId: 'user_1');
        expect(wallet.publicAddress, isNotEmpty);
        payrogen.dispose();
      });

      test('direct payment requires only 2 calls: init + payDirect', () async {
        // Requirement 9.1: no more than 3 method calls per operation
        // Direct payment: init() -> payDirect() = 2 calls
        final now = DateTime.now().toIso8601String();
        final payrogen = await createAuthenticatedPayRogen(
          additionalResponses: {
            '/v1/payments/direct': http.Response(
              jsonEncode({
                'transaction_id': 'tx_1',
                'signature': 'sig_1',
                'status': 'confirmed',
                'amount': 10.0,
                'currency': 'USDT',
                'created_at': now,
              }),
              200,
            ),
          },
        );

        // Only 2 method calls needed:
        // 1. PayRogen.init() (already done above)
        // 2. payDirect()
        final result = await payrogen.payDirect(
          amount: 10.0,
          currency: 'USDT',
          from: 'from_addr',
          to: 'to_addr',
          splits: {'to_addr': 10000},
        );
        expect(result.transactionId, isNotEmpty);
        payrogen.dispose();
      });
    });
  });
}
