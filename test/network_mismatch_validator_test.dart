import 'package:payrogen_sdk/payrogen_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('NetworkMismatchValidator - detectAddressChain', () {
    test('detects EVM address (0x-prefixed, 42 hex chars)', () {
      final result = NetworkMismatchValidator.detectAddressChain(
        '0x1234567890abcdef1234567890abcdef12345678',
      );
      expect(result.chainType, 'evm');
      expect(result.confidence, 0.95);
    });

    test('detects EVM address with mixed case', () {
      final result = NetworkMismatchValidator.detectAddressChain(
        '0xABCDEF1234567890abcdef1234567890ABCDEF12',
      );
      expect(result.chainType, 'evm');
      expect(result.confidence, 0.95);
    });

    test('detects Bitcoin Bech32 address (bc1 prefix)', () {
      final result = NetworkMismatchValidator.detectAddressChain(
        'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4',
      );
      expect(result.chainType, 'bitcoin');
      expect(result.confidence, 0.99);
    });

    test('detects Bitcoin P2PKH address (starts with 1)', () {
      final result = NetworkMismatchValidator.detectAddressChain(
        '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2',
      );
      expect(result.chainType, 'bitcoin');
      expect(result.confidence, 0.95);
    });

    test('detects Bitcoin P2SH address (starts with 3)', () {
      final result = NetworkMismatchValidator.detectAddressChain(
        '3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy',
      );
      expect(result.chainType, 'bitcoin');
      expect(result.confidence, 0.95);
    });

    test('detects Solana address (Base58, 32-44 chars)', () {
      final result = NetworkMismatchValidator.detectAddressChain(
        '7EcDhSYGxXyscszYEp35KHN8vvw3svAuLKTzXwCFLtV',
      );
      expect(result.chainType, 'solana');
      expect(result.confidence, 0.90);
    });

    test('detects another Solana address', () {
      final result = NetworkMismatchValidator.detectAddressChain(
        'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      );
      expect(result.chainType, 'solana');
      expect(result.confidence, 0.90);
    });

    test('returns unknown for empty string', () {
      final result = NetworkMismatchValidator.detectAddressChain('');
      expect(result.chainType, 'unknown');
      expect(result.confidence, 0.0);
    });

    test('returns unknown for very short string', () {
      final result = NetworkMismatchValidator.detectAddressChain('abc');
      expect(result.chainType, 'unknown');
      expect(result.confidence, 0.0);
    });

    test('returns unknown for invalid address format', () {
      final result = NetworkMismatchValidator.detectAddressChain(
        'not-a-valid-address!!@@##',
      );
      expect(result.chainType, 'unknown');
      expect(result.confidence, 0.0);
    });

    test('does not confuse 0x prefix with too few chars as EVM', () {
      final result = NetworkMismatchValidator.detectAddressChain('0x1234');
      expect(result.chainType, isNot('evm'));
    });

    test('does not confuse 0x prefix with too many chars as EVM', () {
      final result = NetworkMismatchValidator.detectAddressChain(
        '0x1234567890abcdef1234567890abcdef1234567890',
      );
      expect(result.chainType, isNot('evm'));
    });
  });

  group('NetworkMismatchValidator - validateNetworkConsistency', () {
    test('passes when Solana wallet sends to Solana address', () {
      // Should not throw
      NetworkMismatchValidator.validateNetworkConsistency(
        sourceChain: 'solana',
        destinationAddress: '7EcDhSYGxXyscszYEp35KHN8vvw3svAuLKTzXwCFLtV',
        tokenSymbol: 'USDT',
      );
    });

    test('passes when Ethereum wallet sends to EVM address', () {
      NetworkMismatchValidator.validateNetworkConsistency(
        sourceChain: 'ethereum',
        destinationAddress: '0x1234567890abcdef1234567890abcdef12345678',
        tokenSymbol: 'USDT',
      );
    });

    test('passes when Polygon wallet sends to EVM address', () {
      NetworkMismatchValidator.validateNetworkConsistency(
        sourceChain: 'polygon',
        destinationAddress: '0x1234567890abcdef1234567890abcdef12345678',
        tokenSymbol: 'USDC',
      );
    });

    test('passes when Bitcoin wallet sends to Bitcoin address', () {
      NetworkMismatchValidator.validateNetworkConsistency(
        sourceChain: 'bitcoin',
        destinationAddress: 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4',
        tokenSymbol: 'BTC',
      );
    });

    test('throws when Solana wallet sends to EVM address', () {
      expect(
        () => NetworkMismatchValidator.validateNetworkConsistency(
          sourceChain: 'solana',
          destinationAddress: '0x1234567890abcdef1234567890abcdef12345678',
          tokenSymbol: 'USDT',
        ),
        throwsA(isA<PayRogenNetworkMismatchException>()),
      );
    });

    test('throws when Solana wallet sends to Bitcoin address', () {
      expect(
        () => NetworkMismatchValidator.validateNetworkConsistency(
          sourceChain: 'solana',
          destinationAddress:
              'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4',
          tokenSymbol: 'USDT',
        ),
        throwsA(isA<PayRogenNetworkMismatchException>()),
      );
    });

    test('throws when Ethereum wallet sends to Solana address', () {
      expect(
        () => NetworkMismatchValidator.validateNetworkConsistency(
          sourceChain: 'ethereum',
          destinationAddress:
              '7EcDhSYGxXyscszYEp35KHN8vvw3svAuLKTzXwCFLtV',
          tokenSymbol: 'USDT',
        ),
        throwsA(isA<PayRogenNetworkMismatchException>()),
      );
    });

    test('throws when Bitcoin wallet sends to EVM address', () {
      expect(
        () => NetworkMismatchValidator.validateNetworkConsistency(
          sourceChain: 'bitcoin',
          destinationAddress: '0x1234567890abcdef1234567890abcdef12345678',
          tokenSymbol: 'BTC',
        ),
        throwsA(isA<PayRogenNetworkMismatchException>()),
      );
    });

    test('exception contains correct source and detected chains', () {
      try {
        NetworkMismatchValidator.validateNetworkConsistency(
          sourceChain: 'solana',
          destinationAddress: '0x1234567890abcdef1234567890abcdef12345678',
          tokenSymbol: 'USDT',
        );
        fail('Expected PayRogenNetworkMismatchException');
      } on PayRogenNetworkMismatchException catch (e) {
        expect(e.sourceChain, 'solana');
        expect(e.detectedChain, 'evm');
        expect(e.tokenSymbol, 'USDT');
        expect(e.message, contains('USDT'));
        expect(e.message, contains('Solana'));
        expect(e.message, contains('lost funds'));
      }
    });

    test('exception message mentions token and chains clearly', () {
      try {
        NetworkMismatchValidator.validateNetworkConsistency(
          sourceChain: 'polygon',
          destinationAddress: '7EcDhSYGxXyscszYEp35KHN8vvw3svAuLKTzXwCFLtV',
          tokenSymbol: 'USDC',
        );
        fail('Expected PayRogenNetworkMismatchException');
      } on PayRogenNetworkMismatchException catch (e) {
        expect(e.sourceChain, 'polygon');
        expect(e.detectedChain, 'solana');
        expect(e.tokenSymbol, 'USDC');
        expect(e.message, contains('USDC'));
        expect(e.message, contains('Polygon'));
        expect(e.message, contains('Solana'));
        expect(e.message, contains('lost funds'));
      }
    });

    test('does not throw for unrecognized address format (low confidence)',
        () {
      // Short/invalid address — confidence will be 0.0, so validation passes
      // (let server handle it)
      NetworkMismatchValidator.validateNetworkConsistency(
        sourceChain: 'solana',
        destinationAddress: 'short',
        tokenSymbol: 'USDT',
      );
    });

    test('Arbitrum wallet treated as EVM family (passes for EVM address)', () {
      NetworkMismatchValidator.validateNetworkConsistency(
        sourceChain: 'arbitrum',
        destinationAddress: '0x1234567890abcdef1234567890abcdef12345678',
        tokenSymbol: 'ETH',
      );
    });
  });

  group('PayRogen - network mismatch integration', () {
    test('payDirect throws mismatch when sourceChain mismatches destination',
        () async {
      final payrogen = await createAuthenticatedPayRogen();

      expect(
        () => payrogen.payDirect(
          amount: 100.0,
          currency: 'USDT',
          from: '7EcDhSYGxXyscszYEp35KHN8vvw3svAuLKTzXwCFLtV',
          to: '0x1234567890abcdef1234567890abcdef12345678',
          splits: {'seller': 9000, 'platform': 1000},
          sourceChain: 'solana',
        ),
        throwsA(isA<PayRogenNetworkMismatchException>()),
      );
      payrogen.dispose();
    });

    test('payEscrow throws mismatch when sourceChain mismatches destination',
        () async {
      final payrogen = await createAuthenticatedPayRogen();

      expect(
        () => payrogen.payEscrow(
          amount: 50.0,
          currency: 'USDT',
          payer: '7EcDhSYGxXyscszYEp35KHN8vvw3svAuLKTzXwCFLtV',
          serviceProvider: '0x1234567890abcdef1234567890abcdef12345678',
          platform: '7EcDhSYGxXyscszYEp35KHN8vvw3svAuLKTzXwCFLtV',
          splits: {'seller': 9000, 'platform': 1000},
          sourceChain: 'solana',
        ),
        throwsA(isA<PayRogenNetworkMismatchException>()),
      );
      payrogen.dispose();
    });

    test('validateNetworkConsistency method on PayRogen instance throws on mismatch',
        () async {
      final payrogen = await createAuthenticatedPayRogen();

      expect(
        () => payrogen.validateNetworkConsistency(
          sourceChain: 'solana',
          destinationAddress: '0x1234567890abcdef1234567890abcdef12345678',
          tokenSymbol: 'USDT',
        ),
        throwsA(isA<PayRogenNetworkMismatchException>()),
      );
      payrogen.dispose();
    });

    test('validateNetworkConsistency passes for matching chains', () async {
      final payrogen = await createAuthenticatedPayRogen();

      // Should not throw
      payrogen.validateNetworkConsistency(
        sourceChain: 'solana',
        destinationAddress: '7EcDhSYGxXyscszYEp35KHN8vvw3svAuLKTzXwCFLtV',
        tokenSymbol: 'USDT',
      );
      payrogen.dispose();
    });

    test('payDirect works without sourceChain (no pre-flight validation)',
        () async {
      final payrogen = await createAuthenticatedPayRogen(
        additionalResponses: {
          '/v1/payments/direct': _mockPaymentResponse(),
        },
      );

      // No sourceChain provided — should not perform client-side validation
      final result = await payrogen.payDirect(
        amount: 100.0,
        currency: 'USDT',
        from: '7EcDhSYGxXyscszYEp35KHN8vvw3svAuLKTzXwCFLtV',
        to: '0x1234567890abcdef1234567890abcdef12345678',
        splits: {'seller': 9000, 'platform': 1000},
      );

      expect(result.transactionId, 'tx_123');
      payrogen.dispose();
    });
  });

  group('PayRogenNetworkMismatchException', () {
    test('toString includes all relevant details', () {
      const exception = PayRogenNetworkMismatchException(
        sourceChain: 'solana',
        detectedChain: 'evm',
        tokenSymbol: 'USDT',
        message: 'Test mismatch message',
      );

      final str = exception.toString();
      expect(str, contains('solana'));
      expect(str, contains('evm'));
      expect(str, contains('USDT'));
      expect(str, contains('Test mismatch message'));
    });

    test('fields are correctly set', () {
      const exception = PayRogenNetworkMismatchException(
        sourceChain: 'polygon',
        detectedChain: 'bitcoin',
        tokenSymbol: 'USDC',
        message: 'Custom message',
      );

      expect(exception.sourceChain, 'polygon');
      expect(exception.detectedChain, 'bitcoin');
      expect(exception.tokenSymbol, 'USDC');
      expect(exception.message, 'Custom message');
    });
  });

  group('DetectedChain', () {
    test('toString includes type and confidence', () {
      const detected = DetectedChain(chainType: 'solana', confidence: 0.90);
      expect(detected.toString(), contains('solana'));
      expect(detected.toString(), contains('0.9'));
    });
  });
}

http.Response _mockPaymentResponse() {
  return http.Response(
    '{"transaction_id":"tx_123","signature":"sig_abc","status":"pending","amount":100.0,"currency":"USDT","splits":{"seller":9000,"platform":1000},"created_at":"${DateTime.now().toIso8601String()}"}',
    200,
  );
}
