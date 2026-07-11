/// Result of a direct payment operation.
class PaymentResult {
  /// Unique transaction identifier.
  final String transactionId;

  /// On-chain transaction signature.
  final String signature;

  /// Current transaction status.
  final String status;

  /// The amount that was paid.
  final double amount;

  /// Currency of the payment.
  final String currency;

  /// Timestamp when the transaction was created.
  final DateTime createdAt;

  const PaymentResult({
    required this.transactionId,
    required this.signature,
    required this.status,
    required this.amount,
    required this.currency,
    required this.createdAt,
  });

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      transactionId: json['transaction_id'] as String,
      signature: json['signature'] as String,
      status: json['status'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'transaction_id': transactionId,
        'signature': signature,
        'status': status,
        'amount': amount,
        'currency': currency,
        'created_at': createdAt.toIso8601String(),
      };
}
