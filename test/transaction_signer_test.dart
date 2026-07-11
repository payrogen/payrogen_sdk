import 'dart:typed_data';

import 'package:payrogen_sdk/src/secure_storage.dart';
import 'package:payrogen_sdk/src/transaction_signer.dart';
import 'package:payrogen_sdk/src/web3auth_client.dart';
import 'package:flutter_test/flutter_test.dart';

// --- Mock implementations ---

class MockSecureShareStorage implements SecureShareStorage {
  final Map<String, String> _store = {};
  int retrieveCallCount = 0;

  @override
  Future<void> storeShareA({
    required String userId,
    required String shareA,
  }) async {
    _store[userId] = shareA;
  }

  @override
  Future<String?> retrieveShareA({required String userId}) async {
    retrieveCallCount++;
    return _store[userId];
  }

  @override
  Future<void> deleteShareA({required String userId}) async {
    _store.remove(userId);
  }

  @override
  Future<bool> hasShareA({required String userId}) async {
    return _store.containsKey(userId);
  }
}

class MockWeb3AuthClient implements Web3AuthClient {
  String? shareBToReturn;
  bool shouldThrow = false;
  int retrieveCallCount = 0;

  @override
  Future<String> retrieveShareB({required String userId}) async {
    retrieveCallCount++;
    if (shouldThrow) {
      throw const Web3AuthException(message: 'Mock retrieval error');
    }
    return shareBToReturn ?? '';
  }
}

class MockShareCombiner implements ShareCombiner {
  Uint8List? keyToReturn;
  bool shouldThrow = false;
  int combineCallCount = 0;
  Uint8List? lastShareA;
  Uint8List? lastShareB;

  @override
  Uint8List combine({
    required Uint8List shareA,
    required Uint8List shareB,
  }) {
    combineCallCount++;
    lastShareA = shareA;
    lastShareB = shareB;
    if (shouldThrow) {
      throw const TransactionSigningException(
        message: 'Mock combine error',
      );
    }
    return keyToReturn ?? Uint8List(32);
  }
}

class MockEd25519Signer implements Ed25519Signer {
  bool shouldThrow = false;
  int signCallCount = 0;
  Uint8List? lastPrivateKey;
  Uint8List? lastMessage;

  @override
  SignedTransaction sign({
    required Uint8List privateKey,
    required Uint8List message,
  }) {
    signCallCount++;
    lastPrivateKey = Uint8List.fromList(privateKey);
    lastMessage = Uint8List.fromList(message);
    if (shouldThrow) {
      throw const TransactionSigningException(
        message: 'Mock signing error',
      );
    }
    return SignedTransaction(
      signature: Uint8List(64)..fillRange(0, 64, 0xAB),
      publicKey: Uint8List(32)..fillRange(0, 32, 0xCD),
    );
  }
}

/// Helper to produce a 33-byte hex share: 1-byte index + 32-byte data
String makeShareHex(int index, List<int> data32) {
  final bytes = [index, ...data32];
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  late MockSecureShareStorage mockStorage;
  late MockWeb3AuthClient mockWeb3Auth;
  late MockShareCombiner mockCombiner;
  late MockEd25519Signer mockSigner;
  late TransactionSigner transactionSigner;

  setUp(() {
    mockStorage = MockSecureShareStorage();
    mockWeb3Auth = MockWeb3AuthClient();
    mockCombiner = MockShareCombiner();
    mockSigner = MockEd25519Signer();
    transactionSigner = TransactionSigner(
      secureStorage: mockStorage,
      web3AuthClient: mockWeb3Auth,
      shareCombiner: mockCombiner,
      ed25519Signer: mockSigner,
    );
  });

  group('TransactionSigner', () {
    group('sign - happy path', () {
      test('completes signing flow with valid shares', () async {
        // Setup
        final shareAHex = makeShareHex(1, List.filled(32, 0x11));
        final shareBHex = makeShareHex(2, List.filled(32, 0x22));
        final privateKey = Uint8List(32)..fillRange(0, 32, 0x99);
        final txData = Uint8List.fromList([1, 2, 3, 4, 5]);

        await mockStorage.storeShareA(
          userId: 'user1',
          shareA: shareAHex,
        );
        mockWeb3Auth.shareBToReturn = shareBHex;
        mockCombiner.keyToReturn = privateKey;

        // Act
        final result = await transactionSigner.sign(
          userId: 'user1',
          transactionData: txData,
        );

        // Assert
        expect(result.signature.length, 64);
        expect(result.publicKey.length, 32);
        expect(mockStorage.retrieveCallCount, 1);
        expect(mockWeb3Auth.retrieveCallCount, 1);
        expect(mockCombiner.combineCallCount, 1);
        expect(mockSigner.signCallCount, 1);
      });

      test('passes correct shares to combiner', () async {
        final shareAHex = makeShareHex(1, List.filled(32, 0xAA));
        final shareBHex = makeShareHex(2, List.filled(32, 0xBB));
        final privateKey = Uint8List(32);

        await mockStorage.storeShareA(
          userId: 'user1',
          shareA: shareAHex,
        );
        mockWeb3Auth.shareBToReturn = shareBHex;
        mockCombiner.keyToReturn = privateKey;

        await transactionSigner.sign(
          userId: 'user1',
          transactionData: Uint8List(10),
        );

        // Verify shares were decoded and passed correctly
        expect(mockCombiner.lastShareA![0], 1); // index
        expect(mockCombiner.lastShareA![1], 0xAA); // first data byte
        expect(mockCombiner.lastShareB![0], 2); // index
        expect(mockCombiner.lastShareB![1], 0xBB); // first data byte
      });

      test('passes correct transaction data to signer', () async {
        final shareAHex = makeShareHex(1, List.filled(32, 0x11));
        final shareBHex = makeShareHex(2, List.filled(32, 0x22));
        final txData = Uint8List.fromList([10, 20, 30, 40, 50]);

        await mockStorage.storeShareA(
          userId: 'user1',
          shareA: shareAHex,
        );
        mockWeb3Auth.shareBToReturn = shareBHex;
        mockCombiner.keyToReturn = Uint8List(32);

        await transactionSigner.sign(
          userId: 'user1',
          transactionData: txData,
        );

        expect(mockSigner.lastMessage, txData);
      });
    });

    group('sign - secure memory erasure', () {
      test('erases private key from memory after successful signing',
          () async {
        final shareAHex = makeShareHex(1, List.filled(32, 0x11));
        final shareBHex = makeShareHex(2, List.filled(32, 0x22));
        final privateKey = Uint8List(32)..fillRange(0, 32, 0xFF);

        await mockStorage.storeShareA(
          userId: 'user1',
          shareA: shareAHex,
        );
        mockWeb3Auth.shareBToReturn = shareBHex;
        mockCombiner.keyToReturn = privateKey;

        await transactionSigner.sign(
          userId: 'user1',
          transactionData: Uint8List(5),
        );

        // The private key buffer should be zeroed
        expect(privateKey.every((b) => b == 0), isTrue);
      });

      test('erases private key from memory even when signing fails',
          () async {
        final shareAHex = makeShareHex(1, List.filled(32, 0x11));
        final shareBHex = makeShareHex(2, List.filled(32, 0x22));
        final privateKey = Uint8List(32)..fillRange(0, 32, 0xFF);

        await mockStorage.storeShareA(
          userId: 'user1',
          shareA: shareAHex,
        );
        mockWeb3Auth.shareBToReturn = shareBHex;
        mockCombiner.keyToReturn = privateKey;
        mockSigner.shouldThrow = true;

        expect(
          () => transactionSigner.sign(
            userId: 'user1',
            transactionData: Uint8List(5),
          ),
          throwsA(isA<TransactionSigningException>()),
        );

        // Even with a signing failure, the key must be zeroed
        // We need to await the future to ensure finally block runs
        try {
          await transactionSigner.sign(
            userId: 'user1',
            transactionData: Uint8List(5),
          );
        } catch (_) {}

        expect(privateKey.every((b) => b == 0), isTrue);
      });
    });

    group('sign - error handling', () {
      test('throws when Share_A is not found', () async {
        // No share stored for user
        mockWeb3Auth.shareBToReturn = makeShareHex(2, List.filled(32, 0x22));

        expect(
          () => transactionSigner.sign(
            userId: 'unknown_user',
            transactionData: Uint8List(5),
          ),
          throwsA(
            isA<TransactionSigningException>().having(
              (e) => e.message,
              'message',
              contains('Share_A not found'),
            ),
          ),
        );
      });

      test('throws when Web3Auth fails to retrieve Share_B', () async {
        final shareAHex = makeShareHex(1, List.filled(32, 0x11));
        await mockStorage.storeShareA(
          userId: 'user1',
          shareA: shareAHex,
        );
        mockWeb3Auth.shouldThrow = true;

        expect(
          () => transactionSigner.sign(
            userId: 'user1',
            transactionData: Uint8List(5),
          ),
          throwsA(
            isA<TransactionSigningException>().having(
              (e) => e.message,
              'message',
              contains('Failed to retrieve Share_B'),
            ),
          ),
        );
      });

      test('throws when share combination fails', () async {
        final shareAHex = makeShareHex(1, List.filled(32, 0x11));
        final shareBHex = makeShareHex(2, List.filled(32, 0x22));

        await mockStorage.storeShareA(
          userId: 'user1',
          shareA: shareAHex,
        );
        mockWeb3Auth.shareBToReturn = shareBHex;
        mockCombiner.shouldThrow = true;

        expect(
          () => transactionSigner.sign(
            userId: 'user1',
            transactionData: Uint8List(5),
          ),
          throwsA(isA<TransactionSigningException>()),
        );
      });
    });

    group('DefaultShareCombiner', () {
      const combiner = DefaultShareCombiner();

      test('rejects shares with wrong length', () {
        expect(
          () => combiner.combine(
            shareA: Uint8List(10),
            shareB: Uint8List(33),
          ),
          throwsA(
            isA<TransactionSigningException>().having(
              (e) => e.message,
              'message',
              contains('Invalid share length'),
            ),
          ),
        );
      });

      test('rejects shares with zero index', () {
        final shareA = Uint8List(33); // index = 0
        final shareB = Uint8List(33)..[0] = 2;

        expect(
          () => combiner.combine(shareA: shareA, shareB: shareB),
          throwsA(
            isA<TransactionSigningException>().having(
              (e) => e.message,
              'message',
              contains('must be non-zero'),
            ),
          ),
        );
      });

      test('rejects shares with same index', () {
        final shareA = Uint8List(33)..[0] = 1;
        final shareB = Uint8List(33)..[0] = 1;

        expect(
          () => combiner.combine(shareA: shareA, shareB: shareB),
          throwsA(
            isA<TransactionSigningException>().having(
              (e) => e.message,
              'message',
              contains('same index'),
            ),
          ),
        );
      });

      test('produces deterministic output for same shares', () {
        // Create two shares with known data
        final shareA = Uint8List(33);
        shareA[0] = 1;
        for (var i = 1; i < 33; i++) {
          shareA[i] = i;
        }

        final shareB = Uint8List(33);
        shareB[0] = 2;
        for (var i = 1; i < 33; i++) {
          shareB[i] = (i * 2) & 0xFF;
        }

        final result1 = combiner.combine(shareA: shareA, shareB: shareB);
        final result2 = combiner.combine(shareA: shareA, shareB: shareB);

        expect(result1, equals(result2));
        expect(result1.length, 32);
      });

      test('different share pairs produce different keys', () {
        final shareA = Uint8List(33);
        shareA[0] = 1;
        for (var i = 1; i < 33; i++) {
          shareA[i] = i;
        }

        final shareB1 = Uint8List(33);
        shareB1[0] = 2;
        for (var i = 1; i < 33; i++) {
          shareB1[i] = (i * 2) & 0xFF;
        }

        final shareB2 = Uint8List(33);
        shareB2[0] = 3;
        for (var i = 1; i < 33; i++) {
          shareB2[i] = (i * 3) & 0xFF;
        }

        final result1 = combiner.combine(shareA: shareA, shareB: shareB1);
        final result2 = combiner.combine(shareA: shareA, shareB: shareB2);

        // Different shares should produce different keys
        expect(result1, isNot(equals(result2)));
      });
    });

    group('DefaultEd25519Signer', () {
      const signer = DefaultEd25519Signer();

      test('produces 64-byte signature', () {
        final privateKey = Uint8List(32)..fillRange(0, 32, 0x42);
        final message = Uint8List.fromList([1, 2, 3, 4, 5]);

        final result = signer.sign(
          privateKey: privateKey,
          message: message,
        );

        expect(result.signature.length, 64);
        expect(result.publicKey.length, 32);
      });

      test('produces deterministic signatures', () {
        final privateKey = Uint8List(32)..fillRange(0, 32, 0x42);
        final message = Uint8List.fromList([1, 2, 3, 4, 5]);

        final result1 = signer.sign(
          privateKey: privateKey,
          message: message,
        );
        final result2 = signer.sign(
          privateKey: privateKey,
          message: message,
        );

        expect(result1.signature, equals(result2.signature));
        expect(result1.publicKey, equals(result2.publicKey));
      });

      test('different messages produce different signatures', () {
        final privateKey = Uint8List(32)..fillRange(0, 32, 0x42);
        final msg1 = Uint8List.fromList([1, 2, 3]);
        final msg2 = Uint8List.fromList([4, 5, 6]);

        final result1 = signer.sign(privateKey: privateKey, message: msg1);
        final result2 = signer.sign(privateKey: privateKey, message: msg2);

        expect(result1.signature, isNot(equals(result2.signature)));
      });

      test('different keys produce different signatures', () {
        final key1 = Uint8List(32)..fillRange(0, 32, 0x01);
        final key2 = Uint8List(32)..fillRange(0, 32, 0x02);
        final message = Uint8List.fromList([1, 2, 3]);

        final result1 = signer.sign(privateKey: key1, message: message);
        final result2 = signer.sign(privateKey: key2, message: message);

        expect(result1.signature, isNot(equals(result2.signature)));
        expect(result1.publicKey, isNot(equals(result2.publicKey)));
      });

      test('throws for invalid key length', () {
        final badKey = Uint8List(16); // Too short
        final message = Uint8List.fromList([1, 2, 3]);

        expect(
          () => signer.sign(privateKey: badKey, message: message),
          throwsA(
            isA<TransactionSigningException>().having(
              (e) => e.message,
              'message',
              contains('expected 32 bytes'),
            ),
          ),
        );
      });
    });

    group('hex conversion', () {
      test('valid hex shares are properly decoded', () async {
        // Create a known share hex string
        final shareAData = List.filled(32, 0x55);
        final shareAHex = makeShareHex(1, shareAData);
        final shareBHex = makeShareHex(2, List.filled(32, 0x66));

        await mockStorage.storeShareA(
          userId: 'user1',
          shareA: shareAHex,
        );
        mockWeb3Auth.shareBToReturn = shareBHex;
        mockCombiner.keyToReturn = Uint8List(32);

        await transactionSigner.sign(
          userId: 'user1',
          transactionData: Uint8List(5),
        );

        // Verify the hex was correctly decoded
        expect(mockCombiner.lastShareA!.length, 33);
        expect(mockCombiner.lastShareA![0], 1);
        expect(mockCombiner.lastShareA![1], 0x55);
      });
    });
  });
}
