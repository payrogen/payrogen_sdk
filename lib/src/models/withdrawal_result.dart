/// Result of a withdrawal operation.
class WithdrawalResult {
  /// Unique transaction identifier for this withdrawal.
  final String transactionId;

  /// On-chain transaction signature (available after submission).
  final String? signature;

  /// Current withdrawal status (initiated, confirmed, failed).
  final String status;

  /// The amount withdrawn.
  final double amount;

  /// Token symbol of the withdrawal.
  final String tokenSymbol;

  /// Network fee charged for this withdrawal.
  final double networkFee;

  /// The destination external wallet ID.
  final String externalWalletId;

  /// Timestamp when the withdrawal was created.
  final DateTime createdAt;

  const WithdrawalResult({
    required this.transactionId,
    this.signature,
    required this.status,
    required this.amount,
    required this.tokenSymbol,
    required this.networkFee,
    required this.externalWalletId,
    required this.createdAt,
  });

  factory WithdrawalResult.fromJson(Map<String, dynamic> json) {
    return WithdrawalResult(
      transactionId: json['transaction_id'] as String,
      signature: json['signature'] as String?,
      status: json['status'] as String,
      amount: (json['amount'] as num).toDouble(),
      tokenSymbol: json['token_symbol'] as String,
      networkFee: (json['network_fee'] as num).toDouble(),
      externalWalletId: json['external_wallet_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'transaction_id': transactionId,
        'signature': signature,
        'status': status,
        'amount': amount,
        'token_symbol': tokenSymbol,
        'network_fee': networkFee,
        'external_wallet_id': externalWalletId,
        'created_at': createdAt.toIso8601String(),
      };
}
