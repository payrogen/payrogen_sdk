import 'dart:convert';

import 'package:payrogen_sdk/payrogen_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('InMemorySecureShareStorage', () {
    late InMemorySecureShareStorage storage;

    setUp(() {
      storage = InMemorySecureShareStorage();
    });

    test('storeShareA stores the share for the user', () async {
      await storage.storeShareA(userId: 'user_1', shareA: 'share_data_1');

      expect(storage.store['user_1'], 'share_data_1');
    });

    test('retrieveShareA returns stored share', () async {
      await storage.storeShareA(userId: 'user_1', shareA: 'share_data_1');

      final result = await storage.retrieveShareA(userId: 'user_1');

      expect(result, 'share_data_1');
    });

    test('retrieveShareA returns null for non-existent user', () async {
      final result = await storage.retrieveShareA(userId: 'unknown_user');

      expect(result, isNull);
    });

    test('hasShareA returns true when share exists', () async {
      await storage.storeShareA(userId: 'user_1', shareA: 'data');

      expect(await storage.hasShareA(userId: 'user_1'), isTrue);
    });

    test('hasShareA returns false when share does not exist', () async {
      expect(await storage.hasShareA(userId: 'user_1'), isFalse);
    });

    test('deleteShareA removes the stored share', () async {
      await storage.storeShareA(userId: 'user_1', shareA: 'data');
      await storage.deleteShareA(userId: 'user_1');

      expect(await storage.retrieveShareA(userId: 'user_1'), isNull);
      expect(await storage.hasShareA(userId: 'user_1'), isFalse);
    });

    test('deleteShareA is no-op for non-existent user', () async {
      // Should not throw
      await storage.deleteShareA(userId: 'non_existent');
    });

    test('storeShareA overwrites existing share', () async {
      await storage.storeShareA(userId: 'user_1', shareA: 'old_data');
      await storage.storeShareA(userId: 'user_1', shareA: 'new_data');

      final result = await storage.retrieveShareA(userId: 'user_1');
      expect(result, 'new_data');
    });

    test('clear removes all stored shares', () async {
      await storage.storeShareA(userId: 'user_1', shareA: 'data_1');
      await storage.storeShareA(userId: 'user_2', shareA: 'data_2');

      storage.clear();

      expect(await storage.hasShareA(userId: 'user_1'), isFalse);
      expect(await storage.hasShareA(userId: 'user_2'), isFalse);
    });

    test('stores shares independently per user', () async {
      await storage.storeShareA(userId: 'user_1', shareA: 'data_1');
      await storage.storeShareA(userId: 'user_2', shareA: 'data_2');

      expect(await storage.retrieveShareA(userId: 'user_1'), 'data_1');
      expect(await storage.retrieveShareA(userId: 'user_2'), 'data_2');
    });
  });

  group('PayRogen with SecureShareStorage', () {
    late InMemorySecureShareStorage storage;

    setUp(() {
      storage = InMemorySecureShareStorage();
    });

    test('createWallet auto-stores Share_A when storage is configured',
        () async {
      final now = DateTime.now().toIso8601String();
      final payrogen = await createAuthenticatedPayRogen(
        secureStorage: storage,
        additionalResponses: {
          '/v1/wallets/create': http.Response(
            jsonEncode({
              'public_address': 'So1anaAddr3ss',
              'user_id': 'user_123',
              'share_a': 'encrypted_share_a_value',
              'created_at': now,
            }),
            200,
          ),
        },
      );

      await payrogen.createWallet(userId: 'user_123');

      // Verify Share_A was stored in secure storage
      final storedShare = await storage.retrieveShareA(userId: 'user_123');
      expect(storedShare, 'encrypted_share_a_value');
      payrogen.dispose();
    });

    test('createWallet does not store Share_A when storage is null', () async {
      final now = DateTime.now().toIso8601String();
      final payrogen = await createAuthenticatedPayRogen(
        additionalResponses: {
          '/v1/wallets/create': http.Response(
            jsonEncode({
              'public_address': 'So1anaAddr3ss',
              'user_id': 'user_123',
              'share_a': 'encrypted_share_a_value',
              'created_at': now,
            }),
            200,
          ),
        },
      );

      // Should not throw even without storage
      final wallet = await payrogen.createWallet(userId: 'user_123');
      expect(wallet.shareA, 'encrypted_share_a_value');
      payrogen.dispose();
    });

    test('getShareA retrieves stored Share_A transparently', () async {
      final now = DateTime.now().toIso8601String();
      final payrogen = await createAuthenticatedPayRogen(
        secureStorage: storage,
        additionalResponses: {
          '/v1/wallets/create': http.Response(
            jsonEncode({
              'public_address': 'So1anaAddr3ss',
              'user_id': 'user_456',
              'share_a': 'my_secret_share',
              'created_at': now,
            }),
            200,
          ),
        },
      );

      await payrogen.createWallet(userId: 'user_456');

      // Retrieve transparently
      final shareA = await payrogen.getShareA(userId: 'user_456');
      expect(shareA, 'my_secret_share');
      payrogen.dispose();
    });

    test('getShareA returns null when storage is not configured', () async {
      final payrogen = await createAuthenticatedPayRogen();

      final shareA = await payrogen.getShareA(userId: 'user_123');
      expect(shareA, isNull);
      payrogen.dispose();
    });

    test('getShareA returns null for user without stored share', () async {
      final payrogen = await createAuthenticatedPayRogen(
        secureStorage: storage,
      );

      final shareA = await payrogen.getShareA(userId: 'non_existent');
      expect(shareA, isNull);
      payrogen.dispose();
    });

    test('wallet recovery stores new Share_A', () async {
      final payrogen = await createAuthenticatedPayRogen(
        secureStorage: storage,
        additionalResponses: {
          '/v1/wallets/recover': http.Response(
            jsonEncode({
              'public_address': 'recovered_addr',
              'share_a': 'new_device_share_a',
              'success': true,
              'message': 'Wallet recovered',
            }),
            200,
          ),
        },
      );

      await payrogen.recoverWallet(
        userId: 'user_789',
        phrase: 'recovery phrase',
      );

      // After recovery, new Share_A should be stored
      final shareA = await storage.retrieveShareA(userId: 'user_789');
      expect(shareA, 'new_device_share_a');
      payrogen.dispose();
    });
  });
}
