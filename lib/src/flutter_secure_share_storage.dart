import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage.dart';

/// Implementation of [SecureShareStorage] using `flutter_secure_storage`.
///
/// On iOS, this stores data in the Keychain.
/// On Android, this stores data in the Android Keystore
/// (EncryptedSharedPreferences).
///
/// Key format: `payrogen_share_a_{userId}`
class FlutterSecureShareStorage implements SecureShareStorage {
  final FlutterSecureStorage _storage;

  /// Prefix for all Share_A keys in secure storage.
  static const _keyPrefix = 'payrogen_share_a_';

  /// Creates a [FlutterSecureShareStorage] with default platform options.
  ///
  /// On iOS, uses kSecAttrAccessibleWhenUnlockedThisDeviceOnly for security.
  /// On Android, uses EncryptedSharedPreferences.
  FlutterSecureShareStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.unlocked_this_device,
              ),
            );

  String _keyForUser(String userId) => '$_keyPrefix$userId';

  @override
  Future<void> storeShareA({
    required String userId,
    required String shareA,
  }) async {
    try {
      await _storage.write(key: _keyForUser(userId), value: shareA);
    } on Exception catch (e) {
      throw SecureStorageException(
        message: 'Failed to store Share_A for user $userId',
        cause: e,
      );
    }
  }

  @override
  Future<String?> retrieveShareA({required String userId}) async {
    try {
      return await _storage.read(key: _keyForUser(userId));
    } on Exception catch (e) {
      throw SecureStorageException(
        message: 'Failed to retrieve Share_A for user $userId',
        cause: e,
      );
    }
  }

  @override
  Future<void> deleteShareA({required String userId}) async {
    try {
      await _storage.delete(key: _keyForUser(userId));
    } on Exception catch (e) {
      throw SecureStorageException(
        message: 'Failed to delete Share_A for user $userId',
        cause: e,
      );
    }
  }

  @override
  Future<bool> hasShareA({required String userId}) async {
    try {
      return await _storage.containsKey(key: _keyForUser(userId));
    } on Exception catch (e) {
      throw SecureStorageException(
        message: 'Failed to check Share_A existence for user $userId',
        cause: e,
      );
    }
  }
}
