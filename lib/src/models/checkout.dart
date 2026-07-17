/// Checkout models for the PayRogen payment UI.
library;

/// Payment method options available in the checkout flow.
enum PaymentMethod {
  /// Pay with crypto from a wallet (shows QR code + address).
  crypto,

  /// Pay with credit/debit card, Apple Pay, or Google Pay (via Crossmint on-ramp).
  card,
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

  /// Description shown to the customer.
  final String? description;

  /// Order/reference ID for the merchant's records.
  final String? orderId;

  /// Customer email (required for card payments).
  final String? customerEmail;

  /// Allowed payment methods. Defaults to both crypto and card.
  final List<PaymentMethod> allowedMethods;

  /// Crossmint client API key (required for card payments).
  final String? crossmintClientKey;

  const CheckoutConfig({
    required this.amount,
    required this.currency,
    required this.receiveToken,
    required this.merchantWalletAddress,
    this.chain = 'solana',
    this.description,
    this.orderId,
    this.customerEmail,
    this.allowedMethods = const [PaymentMethod.crypto, PaymentMethod.card],
    this.crossmintClientKey,
  });
}

/// Result of a completed checkout.
class CheckoutResult {
  /// Whether the payment was successful.
  final bool success;

  /// The payment method used.
  final PaymentMethod method;

  /// Transaction signature (for crypto payments).
  final String? txSignature;

  /// Crossmint order ID (for card payments).
  final String? crossmintOrderId;

  /// Amount paid in the receive token.
  final String? amountPaid;

  /// Error message if payment failed.
  final String? error;

  const CheckoutResult({
    required this.success,
    required this.method,
    this.txSignature,
    this.crossmintOrderId,
    this.amountPaid,
    this.error,
  });
}
