/// Represents a PayRogen non-custodial wallet.
class Wallet {
  /// The Solana public address of the wallet.
  final String publicAddress;

  /// The user ID associated with this wallet.
  final String userId;

  /// The encrypted Share_A for device storage.
  final String shareA;

  /// Timestamp when the wallet was created.
  final DateTime createdAt;

  const Wallet({
    required this.publicAddress,
    required this.userId,
    required this.shareA,
    required this.createdAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      publicAddress: json['public_address'] as String,
      userId: json['user_id'] as String,
      shareA: json['share_a'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'public_address': publicAddress,
        'user_id': userId,
        'share_a': shareA,
        'created_at': createdAt.toIso8601String(),
      };
}
