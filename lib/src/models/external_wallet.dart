/// Represents an external wallet address registered as a trusted withdrawal destination.
class ExternalWallet {
  /// Unique identifier for this external wallet entry.
  final String id;

  /// User-defined label for the address (e.g., "Binance Hot Wallet").
  final String label;

  /// The blockchain address.
  final String address;

  /// The chain type (e.g., "solana", "ethereum", "polygon", "bitcoin").
  final String chainType;

  /// Whether the address has been verified.
  final bool isVerified;

  /// Timestamp until which the address is in cooldown (cannot be used for withdrawals).
  final DateTime? cooldownUntil;

  /// Whether the cooldown period has elapsed and the wallet can be used.
  bool get isCooldownComplete {
    final cooldown = cooldownUntil;
    if (cooldown == null) return true;
    return DateTime.now().isAfter(cooldown);
  }

  /// Timestamp when the external wallet was added.
  final DateTime createdAt;

  const ExternalWallet({
    required this.id,
    required this.label,
    required this.address,
    required this.chainType,
    required this.isVerified,
    this.cooldownUntil,
    required this.createdAt,
  });

  factory ExternalWallet.fromJson(Map<String, dynamic> json) {
    return ExternalWallet(
      id: json['id'] as String,
      label: json['label'] as String,
      address: json['address'] as String,
      chainType: json['chain_type'] as String,
      isVerified: json['is_verified'] as bool? ?? false,
      cooldownUntil: json['cooldown_until'] != null
          ? DateTime.parse(json['cooldown_until'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'address': address,
        'chain_type': chainType,
        'is_verified': isVerified,
        'cooldown_until': cooldownUntil?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
