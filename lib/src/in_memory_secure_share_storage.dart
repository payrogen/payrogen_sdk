import 'secure_storage.dart';

/// In-memory implementation of [SecureShareStorage] for testing.
///
/// Stores shares in a simple map. This implementation does NOT provide
/// any security guarantees and should only be used in tests.
class InMemorySecureShareStorage implements SecureShareStorage {
  final Map<String, String> _store = {};

  /// Returns a read-only view of the internal store (for test assertions).
  Map<String, String> get store => Map.unmodifiable(_store);

  @override
  Future<void> storeShareA({
    required String userId,
    required String shareA,
  }) async {
    _store[userId] = shareA;
  }

  @override
  Future<String?> retrieveShareA({required String userId}) async {
    return _store[userId];
  }

  @override
  Future<void> deleteShareA({required String userId}) async {
    _store.remove(userId);
  }

  @override
  Future<bool> hasShareA({required String userId}) async {
    return _store.containsKey(userId);
  }

  /// Clears all stored shares (useful between tests).
  void clear() {
    _store.clear();
  }
}
