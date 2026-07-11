/// Estimated fees for a withdrawal operation.
class FeeEstimate {
  /// The blockchain network fee (gas fee) in the native token.
  final double networkFee;

  /// The network fee expressed in the withdrawal token for display purposes.
  final double networkFeeInToken;

  /// The token symbol for the network fee.
  final String feeToken;

  /// The chain type this estimate is for.
  final String chainType;

  /// The requested withdrawal token.
  final String token;

  /// The requested withdrawal amount.
  final double amount;

  /// The amount the recipient will receive after fees.
  final double amountAfterFees;

  /// Estimated time for the withdrawal to confirm (in seconds).
  final int estimatedConfirmationSeconds;

  const FeeEstimate({
    required this.networkFee,
    required this.networkFeeInToken,
    required this.feeToken,
    required this.chainType,
    required this.token,
    required this.amount,
    required this.amountAfterFees,
    required this.estimatedConfirmationSeconds,
  });

  factory FeeEstimate.fromJson(Map<String, dynamic> json) {
    return FeeEstimate(
      networkFee: (json['network_fee'] as num).toDouble(),
      networkFeeInToken: (json['network_fee_in_token'] as num).toDouble(),
      feeToken: json['fee_token'] as String,
      chainType: json['chain_type'] as String,
      token: json['token'] as String,
      amount: (json['amount'] as num).toDouble(),
      amountAfterFees: (json['amount_after_fees'] as num).toDouble(),
      estimatedConfirmationSeconds:
          json['estimated_confirmation_seconds'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'network_fee': networkFee,
        'network_fee_in_token': networkFeeInToken,
        'fee_token': feeToken,
        'chain_type': chainType,
        'token': token,
        'amount': amount,
        'amount_after_fees': amountAfterFees,
        'estimated_confirmation_seconds': estimatedConfirmationSeconds,
      };
}
