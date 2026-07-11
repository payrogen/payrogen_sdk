/// Abstraction for secure device storage of cryptographic key shares.
///
/// Implementations use platform-specific secure storage mechanisms:
/// - iOS: Keychain Services
/// - Android: Android Keystore (via EncryptedSharedPreferences)
///
/// This interface enables dependency injection and testing without
/// requiring native platform code.
abstract class SecureShareStorage {
  /// Stores Share_A securely for the given [userId].
  ///
  /// Overwrites any previously stored share for the same user.
  /// Throws [SecureStorageException] if the storage operation fails.
  Future<void> storeShareA({
    required String userId,
    required String shareA,
  });

  /// Retrieves Share_A for the given [userId].
  ///
  /// Returns `null` if no share is stored for the user.
  /// Throws [SecureStorageException] if the retrieval operation fails.
  Future<String?> retrieveShareA({required String userId});

  /// Deletes the stored Share_A for the given [userId].
  ///
  /// No-op if no share is stored for the user.
  /// Throws [SecureStorageException] if the deletion operation fails.
  Future<void> deleteShareA({required String userId});

  /// Checks whether a Share_A is stored for the given [userId].
  Future<bool> hasShareA({required String userId});
}

/// Exception thrown when secure storage operations fail.
class SecureStorageException implements Exception {
  /// Human-readable description of the failure.
  final String message;

  /// The underlying error, if available.
  final Object? cause;

  const SecureStorageException({
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'SecureStorageException: $message';
}
