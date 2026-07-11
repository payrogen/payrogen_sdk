import 'dart:async';

/// Represents a queued operation that failed due to network issues.
class QueuedOperation<T> {
  /// The async function to retry.
  final Future<T> Function() operation;

  /// Number of attempts made so far.
  int attempts;

  /// Maximum number of retry attempts.
  final int maxAttempts;

  /// Completer to resolve when the operation succeeds or exhausts retries.
  final Completer<T> completer;

  QueuedOperation({
    required this.operation,
    required this.completer,
    this.attempts = 0,
    this.maxAttempts = 3,
  });
}

/// Handles queueing and retrying operations that fail due to network issues.
///
/// When the Gateway is unreachable, operations are queued and retried with
/// exponential backoff (1s, 2s, 4s) up to a maximum of 3 attempts.
/// (Requirement 9.6)
class OfflineRetryQueue {
  final List<QueuedOperation<dynamic>> _queue = [];

  /// Whether the queue is currently processing retries.
  bool _isProcessing = false;

  /// Base delay for exponential backoff in milliseconds.
  final int baseDelayMs;

  /// Maximum number of retry attempts per operation.
  final int maxAttempts;

  /// Optional delay function for testing (allows mocking time).
  final Future<void> Function(Duration duration)? delayFunction;

  /// Number of items currently in the queue.
  int get length => _queue.length;

  /// Whether the queue is currently processing.
  bool get isProcessing => _isProcessing;

  OfflineRetryQueue({
    this.baseDelayMs = 1000,
    this.maxAttempts = 3,
    this.delayFunction,
  });

  /// Enqueue an operation for retry with exponential backoff.
  ///
  /// Returns a Future that resolves when the operation succeeds or
  /// throws the last error after exhausting all retry attempts.
  Future<T> enqueue<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    final queuedOp = QueuedOperation<T>(
      operation: operation,
      completer: completer,
      maxAttempts: maxAttempts,
    );
    _queue.add(queuedOp);
    _processQueue();
    return completer.future;
  }

  /// Process all queued operations with exponential backoff.
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final op = _queue.first;
      final success = await _retryOperation(op);
      if (success || op.attempts >= op.maxAttempts) {
        _queue.removeAt(0);
      }
    }

    _isProcessing = false;
  }

  /// Retry a single operation with exponential backoff.
  ///
  /// Returns true if the operation succeeded, false if it failed.
  Future<bool> _retryOperation(QueuedOperation<dynamic> op) async {
    while (op.attempts < op.maxAttempts) {
      op.attempts++;

      // Wait with exponential backoff before retrying (1s, 2s, 4s)
      if (op.attempts > 1) {
        final delayMs = baseDelayMs * (1 << (op.attempts - 2));
        final delay = Duration(milliseconds: delayMs);
        if (delayFunction != null) {
          await delayFunction!(delay);
        } else {
          await Future.delayed(delay);
        }
      }

      try {
        final result = await op.operation();
        op.completer.complete(result);
        return true;
      } on Exception catch (e) {
        if (op.attempts >= op.maxAttempts) {
          op.completer.completeError(e);
          return false;
        }
      }
    }
    return false;
  }

  /// Clear all pending operations from the queue.
  void clear() {
    for (final op in _queue) {
      op.completer.completeError(
        Exception('Operation cancelled: queue cleared'),
      );
    }
    _queue.clear();
  }
}
