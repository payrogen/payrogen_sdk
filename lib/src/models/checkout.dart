/// Checkout models for the PayRogen payment UI.
library;

/// Payment method options available in the checkout flow.
enum PaymentMethod {
  /// Pay with crypto from a wallet (shows QR code + address).
  crypto,

  /// Pay with credit/debit card, Apple Pay, or Google Pay (via Crossmint or Halliday on-ramp).
  card,
}

/// Card payment provider options.
enum CardProvider {
  /// Crossmint embedded checkout (client-side SDK).
  crossmint,

  /// Halliday hosted funding page (redirect/iframe).
  halliday,

  /// Circle direct card payment (headless, client-side encryption).
  /// Reference: https://developers.circle.com/circle-mint/docs/accept-card-payments-online
  circle,
}

/// Configuration for a checkout session.
class CheckoutConfig {
  /// Amount in the merchant's local currency (e.g., 50.00).
  final double amount;

  /// Currency code (e.g., 'USD', 'NGN', 'EUR').
  final String currency;

  /// Token the merchant wants to receive (e.g., 'USDC').
  final String receiveToken;

  /// The merchant's wallet address to receive payment.
  final String merchantWalletAddress;

  /// The blockchain chain (e.g., 'solana').
  final String chain;

  /// Merchant/business name shown in the header.
  final String? merchantName;

  /// Description shown to the customer.
  final String? description;

  /// Order/reference ID for the merchant's records.
  final String? orderId;

  /// Customer email (required for card payments).
  final String? customerEmail;

  /// Allowed payment methods. Defaults to both crypto and card.
  final List<PaymentMethod> allowedMethods;

  /// Crossmint client API key (required for Crossmint card payments).
  final String? crossmintClientKey;

  /// Active card provider. Defaults to circle (headless card-to-USDC).
  final CardProvider? cardProvider;

  /// Split configuration: map of wallet addresses to basis points (must sum to 10000).
  final Map<String, int>? splits;

  /// Whether this is an escrow payment.
  final bool escrow;

  /// Escrow timeout duration. Auto-releases after this period if buyer doesn't act.
  final Duration? escrowTimeout;

  /// Arbitrary metadata to attach to the transaction.
  final Map<String, dynamic>? metadata;

  /// Optional accent color to override the default theme primary color.
  final int? accentColorValue;

  const CheckoutConfig({
    required this.amount,
    required this.currency,
    required this.receiveToken,
    required this.merchantWalletAddress,
    this.chain = 'solana',
    this.merchantName,
    this.description,
    this.orderId,
    this.customerEmail,
    this.allowedMethods = const [PaymentMethod.crypto, PaymentMethod.card],
    this.crossmintClientKey,
    this.cardProvider = CardProvider.circle,
    this.splits,
    this.escrow = false,
    this.escrowTimeout,
    this.metadata,
    this.accentColorValue,
  });
}

/// Result of a completed checkout.
class PayRogenCheckoutResult {
  /// Whether the payment was successful.
  final bool success;

  /// Whether the user cancelled the checkout.
  final bool cancelled;

  /// The payment method used.
  final PaymentMethod? method;

  /// Solana transaction signature (for crypto payments).
  final String? signature;

  /// Escrow ID (only if escrow: true was set in config).
  final String? escrowId;

  /// Payer's wallet address.
  final String? walletAddress;

  /// Amount paid.
  final double amount;

  /// Currency/token used.
  final String currency;

  /// Crossmint order ID (for Crossmint card payments).
  final String? crossmintOrderId;

  /// Halliday payment ID (for Halliday card payments).
  final String? hallidayPaymentId;

  /// Halliday funding page URL (for Halliday card payments).
  final String? hallidayFundingUrl;

  /// Circle payment ID (for Circle card payments).
  final String? circlePaymentId;

  /// Error message if payment failed.
  final String? error;

  /// Metadata passed through from the config.
  final Map<String, dynamic>? metadata;

  const PayRogenCheckoutResult({
    required this.success,
    this.cancelled = false,
    this.method,
    this.signature,
    this.escrowId,
    this.walletAddress,
    this.amount = 0,
    this.currency = '',
    this.crossmintOrderId,
    this.hallidayPaymentId,
    this.hallidayFundingUrl,
    this.circlePaymentId,
    this.error,
    this.metadata,
  });

  /// Factory for a cancelled result.
  factory PayRogenCheckoutResult.cancelled() =>
      const PayRogenCheckoutResult(success: false, cancelled: true);
}

/// Legacy alias for backward compatibility.
typedef CheckoutResult = PayRogenCheckoutResult;
