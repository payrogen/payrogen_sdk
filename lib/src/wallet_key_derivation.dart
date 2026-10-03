import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pinenacl/ed25519.dart';

/// Base58 alphabet used by Solana (Bitcoin-style).
const _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

/// Deterministic wallet key derivation for non-custodial wallets.
///
/// Derives a Solana Ed25519 keypair from the user's email + password using
/// PBKDF2-HMAC-SHA512. The private key is never stored on any server —
/// it's regenerated client-side whenever the user authenticates.
///
/// Recovery: If the user reinstalls the app, logging in with the same
/// email + password produces the exact same keypair.
class WalletKeyDerivation {
  /// Derive a Solana keypair from user credentials.
  ///
  /// Uses PBKDF2-HMAC-SHA512 with 100,000 iterations to derive a 32-byte seed,
  /// then generates an Ed25519 signing key from that seed.
  ///
  /// [email] — user's email (lowercased, trimmed)
  /// [password] — user's password
  /// [appSalt] — app-level salt (e.g., "instafoody-solana-wallet-v1")
  ///
  /// Returns a [DerivedWallet] with the public address and private key.
  static DerivedWallet deriveKeypair({
    required String email,
    required String password,
    String appSalt = 'instafoody-solana-wallet-v1',
  }) {
    // Normalize inputs
    final normalizedEmail = email.trim().toLowerCase();

    // Create the PBKDF2 input: email + password combined
    final inputKey = utf8.encode('$normalizedEmail:$password');

    // Salt: app-specific constant + email to prevent cross-app collisions
    final salt = utf8.encode('$appSalt:$normalizedEmail');

    // PBKDF2-HMAC-SHA512, 100,000 iterations → 32 bytes
    final seed = _pbkdf2Sha512(inputKey, salt, iterations: 100000, keyLength: 32);

    // Generate Ed25519 signing key from the 32-byte seed
    final signingKey = SigningKey(seed: seed);
    final publicKey = signingKey.verifyKey;

    // Solana private key format: 64 bytes (32-byte seed + 32-byte public key)
    final privateKeyBytes = Uint8List(64);
    privateKeyBytes.setAll(0, seed);
    privateKeyBytes.setAll(32, publicKey.asTypedList);

    return DerivedWallet(
      publicAddress: _base58Encode(publicKey.asTypedList),
      privateKeyBase58: _base58Encode(privateKeyBytes),
      seedBytes: seed,
    );
  }

  /// PBKDF2-HMAC-SHA512 implementation.
  static Uint8List _pbkdf2Sha512(
    List<int> password,
    List<int> salt, {
    required int iterations,
    required int keyLength,
  }) {
    final hmacSha512 = Hmac(sha512, password);
    final blocks = (keyLength / 64).ceil();
    final result = Uint8List(keyLength);
    var offset = 0;

    for (var blockIndex = 1; blockIndex <= blocks; blockIndex++) {
      // U1 = HMAC(password, salt || INT(blockIndex))
      final blockSalt = Uint8List(salt.length + 4);
      blockSalt.setAll(0, salt);
      blockSalt[salt.length] = (blockIndex >> 24) & 0xff;
      blockSalt[salt.length + 1] = (blockIndex >> 16) & 0xff;
      blockSalt[salt.length + 2] = (blockIndex >> 8) & 0xff;
      blockSalt[salt.length + 3] = blockIndex & 0xff;

      var u = hmacSha512.convert(blockSalt).bytes;
      final block = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = hmacSha512.convert(u).bytes;
        for (var j = 0; j < block.length; j++) {
          block[j] ^= u[j];
        }
      }

      final copyLen = (offset + 64 > keyLength) ? keyLength - offset : 64;
      result.setAll(offset, block.sublist(0, copyLen));
      offset += copyLen;
    }

    return result;
  }

  /// Base58 encode (Solana/Bitcoin style).
  static String _base58Encode(Uint8List data) {
    var value = BigInt.zero;
    for (final byte in data) {
      value = (value << 8) | BigInt.from(byte);
    }

    final result = StringBuffer();
    while (value > BigInt.zero) {
      final remainder = (value % BigInt.from(58)).toInt();
      value = value ~/ BigInt.from(58);
      result.write(_base58Alphabet[remainder]);
    }

    // Add leading '1's for leading zero bytes
    for (final byte in data) {
      if (byte == 0) {
        result.write('1');
      } else {
        break;
      }
    }

    return result.toString().split('').reversed.join();
  }
}

/// Result of a deterministic wallet derivation.
class DerivedWallet {
  /// The Solana public address (base58).
  final String publicAddress;

  /// The full private key in base58 (64 bytes: seed + pubkey), importable into Solflare.
  final String privateKeyBase58;

  /// The raw 32-byte seed (for internal use).
  final Uint8List seedBytes;

  const DerivedWallet({
    required this.publicAddress,
    required this.privateKeyBase58,
    required this.seedBytes,
  });
}
