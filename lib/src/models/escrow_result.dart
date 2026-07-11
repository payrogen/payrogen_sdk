/// Result of an escrow payment operation.
class EscrowResult {
  /// Unique escrow identifier.
  final String escrowId;

  /// Unique transaction identifier.
  final String transactionId;

  /// Current escrow status (locked, released, refunded, disputed).
  final String status;

  /// The escrowed amount.
  final double amount;

  /// Currency of the escrow.
  final String currency;

  /// Timestamp when the escrow was locked.
  final DateTime lockedAt;

  /// Timestamp when the escrow will timeout.
  final DateTime timeoutAt;

  const EscrowResult({
    required this.escrowId,
    required this.transactionId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.lockedAt,
    required this.timeoutAt,
  });

  factory EscrowResult.fromJson(Map<String, dynamic> json) {
    return EscrowResult(
      escrowId: json['escrow_id'] as String,
      transactionId: json['transaction_id'] as String,
      status: json['status'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      lockedAt: DateTime.parse(json['locked_at'] as String),
      timeoutAt: DateTime.parse(json['timeout_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'escrow_id': escrowId,
        'transaction_id': transactionId,
        'status': status,
        'amount': amount,
        'currency': currency,
        'locked_at': lockedAt.toIso8601String(),
        'timeout_at': timeoutAt.toIso8601String(),
      };
}
