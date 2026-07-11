/// Client-side chain and network mismatch pre-flight validation.
///
/// Replicates the Gateway's address detection logic to catch mismatches
/// before the request reaches the server, providing immediate user feedback.
/// (Requirement 32.9)
class NetworkMismatchValidator {
  // Solana: Base58, 32-44 characters, no 0/O/I/l
  static final _solanaAddressRegex =
      RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$');

  // EVM: 0x-prefixed, exactly 42 hex characters
  static final _evmAddressRegex = RegExp(r'^0x[0-9a-fA-F]{40}$');

  // Bitcoin P2PKH: starts with 1, 25-34 chars
  static final _btcP2PKHRegex = RegExp(r'^1[1-9A-HJ-NP-Za-km-z]{24,33}$');

  // Bitcoin P2SH: starts with 3, 25-34 chars
  static final _btcP2SHRegex = RegExp(r'^3[1-9A-HJ-NP-Za-km-z]{24,33}$');

  // Bitcoin Bech32: starts with bc1, 42-62 chars
  static final _btcBech32Regex = RegExp(r'^bc1[0-9a-z]{38,58}$');

  /// Detects the most likely blockchain chain type from an address format.
  ///
  /// Returns a [DetectedChain] with the inferred chain type and a confidence
  /// score (0.0 to 1.0).
  ///
  /// Detection rules (matching the server-side algorithm):
  /// - `0x` prefix + 40 hex chars → EVM (Ethereum, Polygon, Arbitrum)
  /// - `bc1` prefix → Bitcoin (Bech32)
  /// - `1` or `3` prefix (Base58Check) → Bitcoin (P2PKH/P2SH)
  /// - Base58, 32-44 chars → Solana
  static DetectedChain detectAddressChain(String address) {
    if (address.isEmpty) {
      return const DetectedChain(chainType: 'unknown', confidence: 0.0);
    }

    if (_evmAddressRegex.hasMatch(address)) {
      return const DetectedChain(chainType: 'evm', confidence: 0.95);
    }

    if (_btcBech32Regex.hasMatch(address)) {
      return const DetectedChain(chainType: 'bitcoin', confidence: 0.99);
    }

    if (_btcP2PKHRegex.hasMatch(address) ||
        _btcP2SHRegex.hasMatch(address)) {
      return const DetectedChain(chainType: 'bitcoin', confidence: 0.95);
    }

    if (_solanaAddressRegex.hasMatch(address)) {
      return const DetectedChain(chainType: 'solana', confidence: 0.90);
    }

    return const DetectedChain(chainType: 'unknown', confidence: 0.0);
  }

  /// Validates that the source chain, destination address, and token are
  /// consistent (i.e., no network mismatch).
  ///
  /// Call this before submitting payment or withdrawal requests to catch
  /// mismatches client-side with immediate user feedback.
  ///
  /// [sourceChain] - The chain type of the source wallet (e.g., 'solana',
  ///   'ethereum', 'polygon', 'bitcoin').
  /// [destinationAddress] - The destination address to validate.
  /// [tokenSymbol] - The token being sent (e.g., 'USDT', 'SOL').
  ///
  /// Throws [PayRogenNetworkMismatchException] if a mismatch is detected.
  static void validateNetworkConsistency({
    required String sourceChain,
    required String destinationAddress,
    required String tokenSymbol,
  }) {
    final detected = detectAddressChain(destinationAddress);

    // Only enforce if we have reasonable confidence in detection
    if (detected.confidence < 0.90) {
      // Cannot determine destination chain with confidence; let server validate
      return;
    }

    // Normalize source chain to the family used in detection
    final normalizedSource = _normalizeChainFamily(sourceChain);
    final detectedChain = detected.chainType;

    if (normalizedSource != detectedChain) {
      final sourceDisplay = _chainDisplayName(sourceChain);
      final detectedDisplay = _chainDisplayName(detectedChain);

      throw PayRogenNetworkMismatchException(
        sourceChain: sourceChain,
        detectedChain: detectedChain,
        tokenSymbol: tokenSymbol,
        message: 'You are trying to send $tokenSymbol on $sourceDisplay '
            'to a $detectedDisplay address. '
            'This would result in lost funds. '
            'Please use a $sourceDisplay address or switch to '
            '$tokenSymbol ($detectedDisplay).',
      );
    }
  }

  /// Normalizes specific EVM chain names to the "evm" family.
  ///
  /// The address detection can only tell us "evm" vs "solana" vs "bitcoin".
  /// Ethereum, Polygon, Arbitrum all use the same 0x address format.
  static String _normalizeChainFamily(String chainType) {
    switch (chainType.toLowerCase()) {
      case 'ethereum':
      case 'polygon':
      case 'arbitrum':
      case 'evm':
        return 'evm';
      case 'solana':
        return 'solana';
      case 'bitcoin':
        return 'bitcoin';
      default:
        return chainType.toLowerCase();
    }
  }

  /// Returns a human-readable display name for a chain type.
  static String _chainDisplayName(String chainType) {
    switch (chainType.toLowerCase()) {
      case 'solana':
        return 'Solana';
      case 'evm':
        return 'EVM (Ethereum/Polygon/Arbitrum)';
      case 'ethereum':
        return 'Ethereum';
      case 'polygon':
        return 'Polygon';
      case 'arbitrum':
        return 'Arbitrum';
      case 'bitcoin':
        return 'Bitcoin';
      default:
        return chainType;
    }
  }
}

/// Represents a detected chain type from address format analysis.
class DetectedChain {
  /// The inferred chain type (e.g., 'solana', 'evm', 'bitcoin', 'unknown').
  final String chainType;

  /// Confidence score from 0.0 (no match) to 1.0 (certain).
  final double confidence;

  const DetectedChain({
    required this.chainType,
    required this.confidence,
  });

  @override
  String toString() => 'DetectedChain($chainType, confidence: $confidence)';
}

/// Thrown when a network mismatch is detected during client-side validation.
///
/// This exception blocks submission and provides a user-friendly message
/// explaining the mismatch and how to correct it. (Requirement 32.9)
class PayRogenNetworkMismatchException implements Exception {
  /// The chain type of the source wallet.
  final String sourceChain;

  /// The chain type detected from the destination address format.
  final String detectedChain;

  /// The token symbol involved in the mismatch.
  final String tokenSymbol;

  /// A clear, non-technical message explaining the mismatch and the correct
  /// action to take.
  final String message;

  const PayRogenNetworkMismatchException({
    required this.sourceChain,
    required this.detectedChain,
    required this.tokenSymbol,
    required this.message,
  });

  @override
  String toString() =>
      'PayRogenNetworkMismatchException: $message '
      '(source: $sourceChain, detected: $detectedChain, token: $tokenSymbol)';
}
