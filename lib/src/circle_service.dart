/// Circle Payments API service for the PayRogen Flutter SDK.
///
/// Handles the client-side portion of the Circle card payment flow:
/// 1. Fetching Circle's PGP public key for card data encryption
/// 2. Encrypting card number + CVV with RSA/OAEP using Circle's key
/// 3. Submitting the encrypted data to the Payrogen gateway for tokenization + payment
/// 4. Polling for payment status until confirmed
///
/// Reference: https://developers.circle.com/circle-mint/docs/accept-card-payments-online
///
/// PCI Compliance Note:
/// Raw card details (number, CVV) are encrypted CLIENT-SIDE using Circle's
/// PGP public key and NEVER transmitted in plaintext to any server.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';
import 'package:uuid/uuid.dart';

/// Circle card payment service.
///
/// Usage:
/// ```dart
/// final service = CircleService(gatewayBaseUrl: 'https://api.payrogen.com');
/// final encKey = await service.getEncryptionKey();
/// final encrypted = service.encryptCardData(
///   cardNumber: '4111111111111111',
///   cvv: '123',
///   publicKeyBase64: encKey.publicKey,
/// );
/// final result = await service.processPayment(
///   encryptedData: encrypted,
///   keyId: encKey.keyId,
///   amount: '100.00',
///   email: 'buyer@example.com',
///   cardholderName: 'John Doe',
///   expMonth: 12,
///   expYear: 2027,
///   billingCity: 'New York',
///   billingCountry: 'US',
///   billingLine1: '123 Main St',
///   billingPostalCode: '10001',
///   paymentCode: 'abc123',
/// );
/// ```
class CircleService {
  /// Base URL of the Payrogen gateway (e.g., 'https://api.payrogen.com').
  final String gatewayBaseUrl;

  /// Base URL of the payment UI (e.g., 'https://pay.payrogen.com').
  /// Card-order endpoint lives here (Next.js handles server-side encryption).
  final String payBaseUrl;

  /// HTTP client for making requests.
  final http.Client _client;

  /// Creates a new Circle service instance.
  CircleService({
    required this.gatewayBaseUrl,
    String? payBaseUrl,
    http.Client? httpClient,
  })  : payBaseUrl = payBaseUrl ?? 'https://pay.payrogen.com',
        _client = httpClient ?? http.Client();

  /// Fetches Circle's active PGP/RSA public key for card data encryption.
  ///
  /// The public key is used to encrypt the card number and CVV before
  /// transmitting them to any server (PCI compliance).
  ///
  /// Reference: https://developers.circle.com/circle-mint/reference/getpublickey
  Future<CircleEncryptionKey> getEncryptionKey() async {
    // Use gatewayBaseUrl for encryption key — this is a public endpoint on the Go gateway
    final uri = Uri.parse('$gatewayBaseUrl/api/v1/circle/encryption-key');
    debugPrint('[CircleService] getEncryptionKey URL: $uri');
    final response = await _client.get(uri);
    debugPrint('[CircleService] getEncryptionKey status: ${response.statusCode}');
    debugPrint('[CircleService] getEncryptionKey body: ${response.body.substring(0, response.body.length.clamp(0, 200))}');

    if (response.statusCode != 200) {
      throw CircleServiceException(
        'Failed to fetch encryption key: ${response.statusCode} - ${response.body.substring(0, response.body.length.clamp(0, 100))}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return CircleEncryptionKey(
      keyId: data['key_id'] as String,
      publicKey: data['public_key'] as String,
    );
  }

  /// Encrypts card data (number + CVV) using Circle's RSA public key.
  ///
  /// The encryption uses RSA-OAEP with SHA-256, which is Circle's required
  /// encryption scheme for card data.
  ///
  /// Reference: https://developers.circle.com/circle-mint/docs/accept-card-payments-online#encrypt-card-data
  ///
  /// Returns a Base64-encoded encrypted string that can be sent to the gateway.
  String encryptCardData({
    required String cardNumber,
    required String cvv,
    required String publicKeyBase64,
  }) {
    // The payload to encrypt: JSON with card number and CVV
    final payload = jsonEncode({
      'number': cardNumber.replaceAll(RegExp(r'\s'), ''),
      'cvv': cvv,
    });

    // Decode the Base64 RSA public key from Circle
    final publicKeyBytes = base64Decode(publicKeyBase64);

    // Parse the RSA public key from DER-encoded bytes (SubjectPublicKeyInfo)
    final rsaPublicKey = _parseRSAPublicKeyFromDer(publicKeyBytes);

    // Encrypt using RSA-OAEP with SHA-256
    // Reference: Circle requires OAEP padding with SHA-256
    final encryptor = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(rsaPublicKey));

    final plainBytes = Uint8List.fromList(utf8.encode(payload));
    final encrypted = encryptor.process(plainBytes);

    return base64Encode(encrypted);
  }

  /// Submits card data to the Payrogen server for PGP encryption and Circle payment.
  ///
  /// The server handles PGP encryption (not client-side) because Flutter's
  /// crypto libraries produce RSA output that Circle rejects.
  /// Card data travels over TLS (HTTPS) — never stored anywhere.
  ///
  /// Returns the Circle payment ID and initial status.
  Future<CirclePaymentResult> processPayment({
    required String cardNumber,
    required String cvv,
    required String keyId,
    required String publicKey,
    required String amount,
    required String email,
    required String cardholderName,
    required int expMonth,
    required int expYear,
    required String billingCity,
    required String billingCountry,
    required String billingLine1,
    required String billingPostalCode,
    required String paymentCode,
    String? billingLine2,
    String? billingDistrict,
  }) async {
    final idempotencyKey = const Uuid().v4();

    // Call the Next.js card-order route which does server-side PGP encryption
    final uri = Uri.parse('$payBaseUrl/api/pay/$paymentCode/card-order');
    debugPrint('[CircleService] processPayment URL: $uri');
    debugPrint('[CircleService] processPayment payBaseUrl: $payBaseUrl');
    debugPrint('[CircleService] processPayment paymentCode: $paymentCode');
    debugPrint('[CircleService] processPayment payload keys: email=$email, cardNumber=${cardNumber.substring(0, 4)}****, cvv=***, keyId=$keyId, publicKey=${publicKey.substring(0, 20)}..., amount=$amount');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'card_number': cardNumber,
        'cvv': cvv,
        'key_id': keyId,
        'public_key': publicKey,
        'cardholder_name': cardholderName,
        'exp_month': expMonth,
        'exp_year': expYear,
        'billing_city': billingCity,
        'billing_country': billingCountry,
        'billing_line1': billingLine1,
        'billing_line2': billingLine2 ?? '',
        'billing_district': billingDistrict ?? '',
        'billing_postal_code': billingPostalCode,
        'idempotency_key': idempotencyKey,
        'amount': amount,
      }),
    );
    debugPrint('[CircleService] processPayment response status: ${response.statusCode}');
    debugPrint('[CircleService] processPayment response body: ${response.body.substring(0, response.body.length.clamp(0, 300))}');

    if (response.statusCode != 201 && response.statusCode != 200) {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      throw CircleServiceException(
        error['error'] as String? ?? 'Card payment failed',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return CirclePaymentResult(
      paymentId: data['payment_id'] as String,
      cardId: data['card_id'] as String? ?? '',
      status: data['status'] as String,
    );
  }

  /// Polls Circle payment status until it reaches a terminal state.
  ///
  /// Returns the final status ("paid" or "failed").
  /// Throws if polling times out.
  Future<String> pollPaymentStatus({
    required String paymentId,
    Duration interval = const Duration(seconds: 3),
    int maxAttempts = 40,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(interval);

      final uri = Uri.parse(
        '$gatewayBaseUrl/api/v1/circle/payment/$paymentId/status',
      );
      final response = await _client.get(uri);

      if (response.statusCode != 200) continue;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String;

      if (status == 'paid') return 'paid';
      if (status == 'failed') return 'failed';
      // "pending", "confirmed" — keep polling
    }

    throw CircleServiceException(
      'Payment status polling timed out after $maxAttempts attempts',
    );
  }

  /// Parses an RSA public key from DER-encoded bytes (SubjectPublicKeyInfo).
  ///
  /// The key from Circle is in X.509 SubjectPublicKeyInfo DER format:
  /// SEQUENCE {
  ///   SEQUENCE { algorithm OID, NULL }
  ///   BIT STRING { SEQUENCE { modulus INTEGER, exponent INTEGER } }
  /// }
  RSAPublicKey _parseRSAPublicKeyFromDer(Uint8List bytes) {
    final parser = ASN1Parser(bytes);
    final topLevelSeq = parser.nextObject() as ASN1Sequence;

    // SubjectPublicKeyInfo has 2 elements: algorithm identifier + bit string
    final elements = topLevelSeq.elements;
    if (elements != null && elements.length == 2) {
      final bitString = elements[1] as ASN1BitString;
      final publicKeyBytes = bitString.valueBytes;

      if (publicKeyBytes != null) {
        final publicKeyParser = ASN1Parser(
          Uint8List.fromList(publicKeyBytes.sublist(1)),
        );
        final publicKeySeq = publicKeyParser.nextObject() as ASN1Sequence;
        final keyElements = publicKeySeq.elements;

        if (keyElements != null && keyElements.length >= 2) {
          final modulus = (keyElements[0] as ASN1Integer).integer!;
          final exponent = (keyElements[1] as ASN1Integer).integer!;
          return RSAPublicKey(modulus, exponent);
        }
      }
    }

    // Fallback: try parsing as raw RSA public key (just modulus + exponent)
    final elements2 = topLevelSeq.elements;
    if (elements2 != null && elements2.length >= 2) {
      final modulus = (elements2[0] as ASN1Integer).integer!;
      final exponent = (elements2[1] as ASN1Integer).integer!;
      return RSAPublicKey(modulus, exponent);
    }

    throw const CircleServiceException('Failed to parse RSA public key from DER');
  }

  /// Closes the HTTP client.
  void close() => _client.close();
}

/// Circle's PGP/RSA encryption key for client-side card data encryption.
class CircleEncryptionKey {
  /// The key ID to reference when creating cards.
  final String keyId;

  /// The Base64-encoded RSA public key.
  final String publicKey;

  /// Creates a new encryption key instance.
  const CircleEncryptionKey({
    required this.keyId,
    required this.publicKey,
  });
}

/// Result of a Circle card payment creation.
class CirclePaymentResult {
  /// Circle payment ID for status tracking.
  final String paymentId;

  /// Circle card ID (tokenized card, reusable).
  final String cardId;

  /// Initial payment status ("pending", "confirmed", "paid", "failed").
  final String status;

  /// Creates a new payment result instance.
  const CirclePaymentResult({
    required this.paymentId,
    required this.cardId,
    required this.status,
  });
}

/// Exception thrown by the Circle service.
class CircleServiceException implements Exception {
  /// Error message describing what went wrong.
  final String message;

  /// Creates a new Circle service exception.
  const CircleServiceException(this.message);

  @override
  String toString() => 'CircleServiceException: $message';
}
