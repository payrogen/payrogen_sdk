/// Result of a wallet recovery operation.
class RecoveryResult {
  /// The recovered wallet's public address.
  final String publicAddress;

  /// The new Share_A for device storage.
  final String shareA;

  /// Whether recovery was successful.
  final bool success;

  /// Human-readable message about the recovery.
  final String message;

  const RecoveryResult({
    required this.publicAddress,
    required this.shareA,
    required this.success,
    required this.message,
  });

  factory RecoveryResult.fromJson(Map<String, dynamic> json) {
    return RecoveryResult(
      publicAddress: json['public_address'] as String,
      shareA: json['share_a'] as String,
      success: json['success'] as bool,
      message: json['message'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'public_address': publicAddress,
        'share_a': shareA,
        'success': success,
        'message': message,
      };
}
