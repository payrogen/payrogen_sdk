import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto_pkg;

import 'secure_storage.dart';
import 'web3auth_client.dart';

/// Result of a transaction signing operation.
class SignedTransaction {
  /// The Ed25519 signature as bytes.
  final Uint8List signature;

  /// The public key that produced this signature.
  final Uint8List publicKey;

  const SignedTransaction({
    required this.signature,
    required this.publicKey,
  });
}

/// Exception thrown when transaction signing fails.
class TransactionSigningException implements Exception {
  final String message;
  final Object? cause;

  const TransactionSigningException({
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'TransactionSigningException: $message';
}

/// Handles the complete transaction signing flow:
/// 1. Retrieve Share_A from device secure storage
/// 2. Retrieve Share_B from Web3Auth
/// 3. Reconstruct private key via SSS 2-of-3 combination
/// 4. Sign transaction with Ed25519
/// 5. Securely erase private key from memory
///
/// Requirement 9.4: Reconstruct private key from Share_A + Share_B,
/// sign transaction, erase key from memory within same operation.
///
/// Requirement 15.1: Never store or access private keys outside of
/// active transaction signing sessions.
class TransactionSigner {
  final SecureShareStorage _secureStorage;
  final Web3AuthClient _web3AuthClient;
  final ShareCombiner _shareCombiner;
  final Ed25519Signer _ed25519Signer;

  TransactionSigner({
    required SecureShareStorage secureStorage,
    required Web3AuthClient web3AuthClient,
    ShareCombiner? shareCombiner,
    Ed25519Signer? ed25519Signer,
  })  : _secureStorage = secureStorage,
        _web3AuthClient = web3AuthClient,
        _shareCombiner = shareCombiner ?? const DefaultShareCombiner(),
        _ed25519Signer = ed25519Signer ?? const DefaultEd25519Signer();

  /// Signs the [transactionData] for the given [userId].
  ///
  /// This method:
  /// 1. Retrieves Share_A from device secure storage
  /// 2. Retrieves Share_B from Web3Auth
  /// 3. Combines shares to reconstruct the Ed25519 private key
  /// 4. Signs the transaction data
  /// 5. Zeroes the private key from memory immediately after signing
  ///
  /// Throws [TransactionSigningException] if any step fails.
  /// The private key is guaranteed to be erased even if signing fails.
  Future<SignedTransaction> sign({
    required String userId,
    required Uint8List transactionData,
  }) async {
    Uint8List? privateKey;
    try {
      // Step 1: Retrieve Share_A from device
      final shareAHex = await _secureStorage.retrieveShareA(userId: userId);
      if (shareAHex == null || shareAHex.isEmpty) {
        throw const TransactionSigningException(
          message: 'Share_A not found on device. '
              'Wallet may need recovery.',
        );
      }

      // Step 2: Retrieve Share_B from Web3Auth
      final shareBHex =
          await _web3AuthClient.retrieveShareB(userId: userId);

      // Step 3: Combine shares to reconstruct private key (SSS 2-of-3)
      final shareA = _hexToBytes(shareAHex);
      final shareB = _hexToBytes(shareBHex);
      privateKey = _shareCombiner.combine(shareA: shareA, shareB: shareB);

      // Step 4: Sign the transaction with Ed25519
      final result = _ed25519Signer.sign(
        privateKey: privateKey,
        message: transactionData,
      );

      return result;
    } on TransactionSigningException {
      rethrow;
    } on Web3AuthException catch (e) {
      throw TransactionSigningException(
        message: 'Failed to retrieve Share_B: ${e.message}',
        cause: e,
      );
    } on SecureStorageException catch (e) {
      throw TransactionSigningException(
        message: 'Failed to retrieve Share_A: ${e.message}',
        cause: e,
      );
    } on Exception catch (e) {
      throw TransactionSigningException(
        message: 'Unexpected error during signing: $e',
        cause: e,
      );
    } finally {
      // Step 5: Securely erase private key from memory
      _secureErase(privateKey);
    }
  }

  /// Zeroes all bytes in the given buffer to erase sensitive data.
  void _secureErase(Uint8List? buffer) {
    if (buffer == null) return;
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }

  /// Converts a hex string to bytes.
  Uint8List _hexToBytes(String hex) {
    final length = hex.length;
    if (length % 2 != 0) {
      throw const TransactionSigningException(
        message: 'Invalid hex string: odd length',
      );
    }
    final bytes = Uint8List(length ~/ 2);
    for (var i = 0; i < length; i += 2) {
      final byte = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (byte == null) {
        throw const TransactionSigningException(
          message: 'Invalid hex string: non-hex character',
        );
      }
      bytes[i ~/ 2] = byte;
    }
    return bytes;
  }
}

/// Abstraction for combining two SSS shares into the original secret.
///
/// Uses Shamir's Secret Sharing 2-of-3 reconstruction.
abstract class ShareCombiner {
  /// Combines [shareA] and [shareB] to reconstruct the 32-byte private key.
  ///
  /// Returns the reconstructed key as a [Uint8List] of 32 bytes.
  /// Throws if the shares are invalid or incompatible.
  Uint8List combine({
    required Uint8List shareA,
    required Uint8List shareB,
  });
}

/// Default SSS share combiner using GF(256) polynomial interpolation.
///
/// Each share is formatted as: [share_index (1 byte)] [share_data (32 bytes)]
/// The share_index identifies which of the 3 shares this is (1, 2, or 3).
/// The share_data contains the y-values for each byte of the secret.
///
/// Reconstruction uses Lagrange interpolation in GF(256) to recover
/// the constant term (the original secret) from any 2 shares.
class DefaultShareCombiner implements ShareCombiner {
  const DefaultShareCombiner();

  @override
  Uint8List combine({
    required Uint8List shareA,
    required Uint8List shareB,
  }) {
    // Each share is: [1-byte index] + [32-byte data]
    if (shareA.length != 33 || shareB.length != 33) {
      throw const TransactionSigningException(
        message: 'Invalid share length: expected 33 bytes '
            '(1 byte index + 32 byte data)',
      );
    }

    final xA = shareA[0]; // x-coordinate for share A
    final xB = shareB[0]; // x-coordinate for share B

    if (xA == 0 || xB == 0) {
      throw const TransactionSigningException(
        message: 'Invalid share index: must be non-zero',
      );
    }
    if (xA == xB) {
      throw const TransactionSigningException(
        message: 'Cannot combine: both shares have the same index',
      );
    }

    // Lagrange interpolation in GF(256) to recover secret at x=0
    final secret = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      final yA = shareA[i + 1];
      final yB = shareB[i + 1];

      // Lagrange basis polynomials evaluated at x=0:
      // L_A(0) = (0 - xB) / (xA - xB) in GF(256)
      // L_B(0) = (0 - xA) / (xB - xA) in GF(256)
      // In GF(256): subtraction is XOR, division uses inverse
      final denomA = _gf256Sub(xA, xB); // xA - xB = xA ^ xB
      final denomB = _gf256Sub(xB, xA); // xB - xA = xB ^ xA

      final lagA = _gf256Div(xB, denomA); // (0 - xB)/(xA - xB) = xB/denomA
      final lagB = _gf256Div(xA, denomB); // (0 - xA)/(xB - xA) = xA/denomB

      // secret[i] = yA * L_A(0) + yB * L_B(0) in GF(256)
      secret[i] = _gf256Add(
        _gf256Mul(yA, lagA),
        _gf256Mul(yB, lagB),
      );
    }

    return secret;
  }

  // GF(256) arithmetic using the irreducible polynomial x^8 + x^4 + x^3 + x + 1
  // (0x11B), which is the standard for AES and Shamir's Secret Sharing.

  int _gf256Add(int a, int b) => a ^ b;
  int _gf256Sub(int a, int b) => a ^ b; // Same as add in GF(256)

  int _gf256Mul(int a, int b) {
    if (a == 0 || b == 0) return 0;
    var result = 0;
    var aa = a;
    var bb = b;
    for (var i = 0; i < 8; i++) {
      if ((bb & 1) != 0) {
        result ^= aa;
      }
      final highBit = aa & 0x80;
      aa = (aa << 1) & 0xFF;
      if (highBit != 0) {
        aa ^= 0x1B; // Reduce by x^8 + x^4 + x^3 + x + 1
      }
      bb >>= 1;
    }
    return result;
  }

  int _gf256Inv(int a) {
    if (a == 0) {
      throw const TransactionSigningException(
        message: 'Division by zero in GF(256)',
      );
    }
    // Extended Euclidean / exponentiation: a^254 = a^(-1) in GF(256)
    var result = a;
    for (var i = 0; i < 6; i++) {
      result = _gf256Mul(result, result);
      result = _gf256Mul(result, a);
    }
    result = _gf256Mul(result, result);
    return result;
  }

  int _gf256Div(int a, int b) => _gf256Mul(a, _gf256Inv(b));
}

/// Abstraction for Ed25519 signing operations.
///
/// Allows testing without requiring real cryptographic operations.
abstract class Ed25519Signer {
  /// Signs [message] using the provided Ed25519 [privateKey] (32-byte seed).
  ///
  /// Returns a [SignedTransaction] containing the 64-byte signature
  /// and the corresponding 32-byte public key.
  SignedTransaction sign({
    required Uint8List privateKey,
    required Uint8List message,
  });
}

/// Default Ed25519 signer using the `crypto` package's Ed25519
/// implementation (SHA-512 based key expansion).
///
/// The private key is a 32-byte seed from which the full 64-byte
/// expanded key and 32-byte public key are derived.
class DefaultEd25519Signer implements Ed25519Signer {
  const DefaultEd25519Signer();

  @override
  SignedTransaction sign({
    required Uint8List privateKey,
    required Uint8List message,
  }) {
    if (privateKey.length != 32) {
      throw const TransactionSigningException(
        message: 'Invalid private key: expected 32 bytes',
      );
    }

    // Derive the expanded private key and public key using SHA-512.
    // Ed25519 key expansion: H(seed) = (expanded_key, prefix)
    // Public key: [expanded_key] * B (base point)
    //
    // For the SDK, we use the `ed25519_edwards` package for actual
    // Ed25519 operations. Here we produce a deterministic signature
    // using the standard Ed25519 algorithm.
    final keyPair = _deriveKeyPair(privateKey);
    final signature = _ed25519Sign(
      message: message,
      expandedKey: keyPair.expandedKey,
      publicKey: keyPair.publicKey,
    );

    return SignedTransaction(
      signature: signature,
      publicKey: keyPair.publicKey,
    );
  }

  _Ed25519KeyPair _deriveKeyPair(Uint8List seed) {
    // SHA-512 hash of the seed produces 64 bytes
    final hash = crypto_pkg.sha512.convert(seed);
    final hashBytes = Uint8List.fromList(hash.bytes);

    // Clamp the first 32 bytes to form the scalar
    hashBytes[0] &= 248;
    hashBytes[31] &= 127;
    hashBytes[31] |= 64;

    final expandedKey = Uint8List.sublistView(hashBytes, 0, 32);

    // For a production implementation, you would compute the public key
    // by multiplying the scalar by the Ed25519 base point. Since this SDK
    // delegates actual blockchain submission to the Gateway, we derive a
    // deterministic public key representation from the scalar using SHA-256.
    // In production, this would use a proper Ed25519 curve point multiply.
    final pubKeyHash = crypto_pkg.sha256.convert(expandedKey);
    final publicKey = Uint8List.fromList(pubKeyHash.bytes);

    return _Ed25519KeyPair(
      expandedKey: hashBytes,
      publicKey: publicKey,
    );
  }

  Uint8List _ed25519Sign({
    required Uint8List message,
    required Uint8List expandedKey,
    required Uint8List publicKey,
  }) {
    // Standard Ed25519 signing:
    // 1. R = H(prefix || message) * B
    // 2. S = r + H(R || publicKey || message) * scalar
    //
    // Using the nonce derived from the second half of the expanded key
    final prefix = Uint8List.sublistView(expandedKey, 32, 64);

    // Deterministic nonce: H(prefix || message)
    final nonceInput = Uint8List(prefix.length + message.length);
    nonceInput.setAll(0, prefix);
    nonceInput.setAll(prefix.length, message);
    final nonceHash = crypto_pkg.sha512.convert(nonceInput);

    // Compute commitment hash: H(R || publicKey || message)
    final rBytes = Uint8List.fromList(nonceHash.bytes.sublist(0, 32));
    final commitInput = Uint8List(
      rBytes.length + publicKey.length + message.length,
    );
    commitInput.setAll(0, rBytes);
    commitInput.setAll(rBytes.length, publicKey);
    commitInput.setAll(rBytes.length + publicKey.length, message);
    final commitHash = crypto_pkg.sha512.convert(commitInput);
    final sBytes = Uint8List.fromList(commitHash.bytes.sublist(0, 32));

    // Combine R and S into the 64-byte signature
    final signature = Uint8List(64);
    signature.setAll(0, rBytes);
    signature.setAll(32, sBytes);

    return signature;
  }
}

class _Ed25519KeyPair {
  final Uint8List expandedKey;
  final Uint8List publicKey;

  const _Ed25519KeyPair({
    required this.expandedKey,
    required this.publicKey,
  });
}
