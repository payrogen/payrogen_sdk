import 'dart:convert';

import 'package:payrogen_sdk/payrogen_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('PayRogen - Multi-Chain Wallet', () {
    test('createMultiChainWallet creates a wallet for specified chain',
        () async {
      final now = DateTime.now().toIso8601String();
      final payrogen = await createAuthenticatedPayRogen(
        additionalResponses: {
          '/v1/wallets/create': http.Response(
            jsonEncode({
              'public_address': '0x1234567890abcdef1234567890abcdef12345678',
              'user_id': 'user_456',
              'share_a': 'encrypted_share_a_evm',
              'created_at': now,
            }),
            200,
          ),
        },
      );

      final wallet =
          await payrogen.createMultiChainWallet(chainType: 'ethereum');

      expect(wallet.publicAddress,
          '0x1234567890abcdef1234567890abcdef12345678');
      expect(wallet.userId, 'user_456');
      expect(wallet.shareA, 'encrypted_share_a_evm');
      payrogen.dispose();
    });

    test('createMultiChainWallet sends chain_type in request body', () async {
      final now = DateTime.now().toIso8601String();
      Map<String, dynamic>? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/v1/auth/session') {
          return http.Response(
            jsonEncode({'session_token': 'token'}),
            200,
          );
        }
        if (request.url.path == '/v1/wallets/create') {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'public_address': 'addr_polygon',
              'user_id': 'user_1',
              'share_a': 'share_data',
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

      await payrogen.createMultiChainWallet(chainType: 'polygon');

      expect(capturedBody?['chain_type'], 'polygon');
      payrogen.dispose();
      mockClient.close();
    });

    test('createMultiChainWallet throws for empty chainType', () async {
      final payrogen = await createAuthenticatedPayRogen();

      expect(
        () => payrogen.createMultiChainWallet(chainType: ''),
        throwsA(isA<PayRogenValidationException>()),
      );
      payrogen.dispose();
    });

    test('createMultiChainWallet stores Share_A in secure storage', () async {
      final now = DateTime.now().toIso8601String();
      final storage = InMemorySecureShareStorage();
      final payrogen = await createAuthenticatedPayRogen(
        additionalResponses: {
          '/v1/wallets/create': http.Response(
            jsonEncode({
              'public_address': 'addr_btc',
              'user_id': 'user_btc_1',
              'share_a': 'share_a_bitcoin',
              'created_at': now,
            }),
            200,
          ),
        },
        secureStorage: storage,
      );

      await payrogen.createMultiChainWallet(chainType: 'bitcoin');

      final storedShare =
          await storage.retrieveShareA(userId: 'user_btc_1');
      expect(storedShare, 'share_a_bitcoin');
      payrogen.dispose();
    });
  });

  group('PayRogen - External Wallets', () {
    test('addExternalWallet registers an address and returns model', () async {
      final now = DateTime.now();
      final cooldownUntil = now.add(const Duration(hours: 24));
      final payrogen = await createAuthenticatedPayRogen(
        additionalResponses: {
          '/v1/external-wallets': http.Response(
            jsonEncode({
              'id': 'ew_123',
              'label': 'Binance Hot Wallet',
              'address': 'So1anaAddr3ss1234567890abcdef',
              'chain_type': 'solana',
              'is_verified': false,
              'cooldown_until': cooldownUntil.toIso8601String(),
              'created_at': now.toIso8601String(),
            }),
            200,
          ),
        },
      );

      final wallet = await payrogen.addExternalWallet(
        label: 'Binance Hot Wallet',
        address: 'So1anaAddr3ss1234567890abcdef',
        chainType: 'solana',
      );

      expect(wallet.id, 'ew_123');
      expect(wallet.label, 'Binance Hot Wallet');
      expect(wallet.address, 'So1anaAddr3ss1234567890abcdef');
      expect(wallet.chainType, 'solana');
      expect(wallet.isVerified, false);
      expect(wallet.cooldownUntil, isNotNull);
      payrogen.dispose();
    });

    test('addExternalWallet throws for empty label', () async {
      final payrogen = await createAuthenticatedPayRogen();

      expect(
        () => payrogen.addExternalWallet(
          label: '',
          address: 'some_address',
          chainType: 'solana',
        ),
        throwsA(isA<PayRogenValidationException>()),
      );
      payrogen.dispose();
    });

    test('addExternalWallet throws for empty address', () async {
      final payrogen = await createAuthenticatedPayRogen();

      expect(
        () => payrogen.addExternalWallet(
          label: 'My Wallet',
          address: '',
          chainType: 'solana',
        ),
        throwsA(isA<PayRogenValidationException>()),
      );
      payrogen.dispose();
    });

    test('addExternalWallet throws for empty chainType', () async {
      final payrogen = await createAuthenticatedPayRogen();

      expect(
        () => payrogen.addExternalWallet(
          label: 'My Wallet',
          address: 'some_address',
          chainType: '',
        ),
        throwsA(isA<PayRogenValidationException>()),
      );
      payrogen.dispose();
    });

    test('listExternalWallets returns list with cooldown status', () async {
      final now = DateTime.now();
      final pastCooldown = now.subtract(const Duration(hours: 1));
      final futureCooldown = now.add(const Duration(hours: 12));
      final payrogen = await createAuthenticatedPayRogen(
        additionalResponses: {
          '/v1/external-wallets': http.Response(
            jsonEncode({
              'external_wallets': [
                {
                  'id': 'ew_1',
                  'label': 'Binance',
                  'address': 'addr_1',
                  'chain_type': 'solana',
                  'is_verified': true,
                  'cooldown_until': pastCooldown.toIso8601String(),
                  'created_at': now.toIso8601String(),
                },
                {
                  'id': 'ew_2',
                  'label': 'MetaMask',
                  'address': '0xaddr2',
                  'chain_type': 'ethereum',
                  'is_verified': false,
                  'cooldown_until': futureCooldown.toIso8601String(),
                  'created_at': now.toIso8601String(),
                },
              ],
            }),
            200,
          ),
        },
      );

      final wallets = await payrogen.listExternalWallets();

      expect(wallets.length, 2);
      expect(wallets[0].label, 'Binance');
      expect(wallets[0].isCooldownComplete, true);
      expect(wallets[1].label, 'MetaMask');
      expect(wallets[1].isCooldownComplete, false);
      payrogen.dispose();
    });

    test('removeExternalWallet sends DELETE request', () async {
      String? deletedPath;
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/v1/auth/session') {
          return http.Response(
            jsonEncode({'session_token': 'token'}),
            200,
          );
        }
        if (request.method == 'DELETE' &&
            request.url.path.startsWith('/v1/external-wallets/')) {
          deletedPath = request.url.path;
          return http.Response(
            jsonEncode({'success': true}),
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

      await payrogen.removeExternalWallet(walletId: 'ew_123');

      expect(deletedPath, '/v1/external-wallets/ew_123');
      payrogen.dispose();
      mockClient.close();
    });

    test('removeExternalWallet throws for empty walletId', () async {
      final payrogen = await createAuthenticatedPayRogen();

      expect(
        () => payrogen.removeExternalWallet(walletId: ''),
        throwsA(isA<PayRogenValidationException>()),
      );
      payrogen.dispose();
    });
  });

  group('PayRogen - Withdrawal', () {
    test('withdraw sends correct request and returns result', () async {
      final now = DateTime.now().toIso8601String();
      Map<String, dynamic>? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/v1/auth/session') {
          return http.Response(
            jsonEncode({'session_token': 'token'}),
            200,
          );
        }
        if (request.url.path == '/v1/withdrawals') {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'transaction_id': 'tx_wd_001',
              'signature': 'sig_withdrawal_123',
              'status': 'initiated',
              'amount': 50.0,
              'token_symbol': 'USDT',
              'network_fee': 0.005,
              'external_wallet_id': 'ew_123',
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

      final result = await payrogen.withdraw(
        externalWalletId: 'ew_123',
        amount: 50.0,
        tokenSymbol: 'USDT',
      );

      expect(result.transactionId, 'tx_wd_001');
      expect(result.status, 'initiated');
      expect(result.amount, 50.0);
      expect(result.tokenSymbol, 'USDT');
      expect(result.networkFee, 0.005);
      expect(result.externalWalletId, 'ew_123');
      expect(capturedBody?['external_wallet_id'], 'ew_123');
      expect(capturedBody?['amount'], 50.0);
      expect(capturedBody?['token_symbol'], 'USDT');
      payrogen.dispose();
      mockClient.close();
    });

    test('withdraw throws for empty externalWalletId', () async {
      final payrogen = await createAuthenticatedPayRogen();

      expect(
        () => payrogen.withdraw(
          externalWalletId: '',
          amount: 10.0,
          tokenSymbol: 'USDT',
        ),
        throwsA(isA<PayRogenValidationException>()),
      );
      payrogen.dispose();
    });

    test('withdraw throws for zero amount', () async {
      final payrogen = await createAuthenticatedPayRogen();

      expect(
        () => payrogen.withdraw(
          externalWalletId: 'ew_123',
          amount: 0,
          tokenSymbol: 'USDT',
        ),
        throwsA(isA<PayRogenValidationException>()),
      );
      payrogen.dispose();
    });

    test('withdraw throws for negative amount', () async {
      final payrogen = await createAuthenticatedPayRogen();

      expect(
        () => payrogen.withdraw(
          externalWalletId: 'ew_123',
          amount: -5.0,
          tokenSymbol: 'USDT',
        ),
        throwsA(isA<PayRogenValidationException>()),
      );
      payrogen.dispose();
    });

    test('withdraw throws for empty tokenSymbol', () async {
      final payrogen = await createAuthenticatedPayRogen();

      expect(
        () => payrogen.withdraw(
          externalWalletId: 'ew_123',
          amount: 10.0,
          tokenSymbol: '',
        ),
        throwsA(isA<PayRogenValidationException>()),
      );
      payrogen.dispose();
    });
  });

  group('PayRogen - Fee Estimation', () {
    test('estimateWithdrawalFee returns fee breakdown', () async {
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/v1/auth/session') {
          return http.Response(
            jsonEncode({'session_token': 'token'}),
            200,
          );
        }
        if (request.url.path == '/v1/withdrawals/fee-estimate') {
          return http.Response(
            jsonEncode({
              'network_fee': 0.00025,
              'network_fee_in_token': 0.05,
              'fee_token': 'SOL',
              'chain_type': 'solana',
              'token': 'USDT',
              'amount': 100.0,
              'amount_after_fees': 99.95,
              'estimated_confirmation_seconds': 30,
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

      final estimate = await payrogen.estimateWithdrawalFee(
        chainType: 'solana',
        token: 'USDT',
        amount: 100.0,
      );

      expect(estimate.networkFee, 0.00025);
      expect(estimate.networkFeeInToken, 0.05);
      expect(estimate.feeToken, 'SOL');
      expect(estimate.chainType, 'solana');
      expect(estimate.token, 'USDT');
      expect(estimate.amount, 100.0);
      expect(estimate.amountAfterFees, 99.95);
      expect(estimate.estimatedConfirmationSeconds, 30);
      payrogen.dispose();
      mockClient.close();
    });

    test('estimateWithdrawalFee throws for empty chainType', () async {
      final payrogen = await createAuthenticatedPayRogen();

      expect(
        () => payrogen.estimateWithdrawalFee(
          chainType: '',
          token: 'USDT',
          amount: 100.0,
        ),
        throwsA(isA<PayRogenValidationException>()),
      );
      payrogen.dispose();
    });

    test('estimateWithdrawalFee throws for empty token', () async {
      final payrogen = await createAuthenticatedPayRogen();

      expect(
        () => payrogen.estimateWithdrawalFee(
          chainType: 'solana',
          token: '',
          amount: 100.0,
        ),
        throwsA(isA<PayRogenValidationException>()),
      );
      payrogen.dispose();
    });

    test('estimateWithdrawalFee throws for zero amount', () async {
      final payrogen = await createAuthenticatedPayRogen();

      expect(
        () => payrogen.estimateWithdrawalFee(
          chainType: 'solana',
          token: 'USDT',
          amount: 0,
        ),
        throwsA(isA<PayRogenValidationException>()),
      );
      payrogen.dispose();
    });
  });

  group('ExternalWallet model', () {
    test('isCooldownComplete returns true when cooldown has passed', () {
      final wallet = ExternalWallet(
        id: 'ew_1',
        label: 'Test',
        address: 'addr',
        chainType: 'solana',
        isVerified: true,
        cooldownUntil: DateTime.now().subtract(const Duration(hours: 1)),
        createdAt: DateTime.now().subtract(const Duration(hours: 25)),
      );

      expect(wallet.isCooldownComplete, true);
    });

    test('isCooldownComplete returns false when cooldown is active', () {
      final wallet = ExternalWallet(
        id: 'ew_2',
        label: 'Test',
        address: 'addr',
        chainType: 'solana',
        isVerified: false,
        cooldownUntil: DateTime.now().add(const Duration(hours: 12)),
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      );

      expect(wallet.isCooldownComplete, false);
    });

    test('isCooldownComplete returns true when cooldownUntil is null', () {
      final wallet = ExternalWallet(
        id: 'ew_3',
        label: 'Test',
        address: 'addr',
        chainType: 'solana',
        isVerified: true,
        cooldownUntil: null,
        createdAt: DateTime.now(),
      );

      expect(wallet.isCooldownComplete, true);
    });
  });
}
