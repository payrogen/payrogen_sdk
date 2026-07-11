/// Base exception for all PayRogen SDK errors.
class PayRogenException implements Exception {
  /// Error code from the Gateway API.
  final String code;

  /// Human-readable error message.
  final String message;

  /// Optional details about the error.
  final Map<String, dynamic>? details;

  /// The HTTP status code, if applicable.
  final int? statusCode;

  const PayRogenException({
    required this.code,
    required this.message,
    this.details,
    this.statusCode,
  });

  @override
  String toString() => 'PayRogenException($code): $message';
}

/// Thrown when the SDK has not been initialized.
class PayRogenNotInitializedException extends PayRogenException {
  const PayRogenNotInitializedException()
      : super(
          code: 'NOT_INITIALIZED',
          message:
              'PayRogen SDK has not been initialized. Call PayRogen.init() first.',
        );
}

/// Thrown when authentication fails.
class PayRogenAuthException extends PayRogenException {
  const PayRogenAuthException({String? message})
      : super(
          code: 'AUTH_FAILED',
          message: message ?? 'Authentication with the Gateway failed.',
          statusCode: 401,
        );
}

/// Thrown when a network request fails.
class PayRogenNetworkException extends PayRogenException {
  const PayRogenNetworkException({String? message})
      : super(
          code: 'NETWORK_ERROR',
          message: message ?? 'Unable to reach the PayRogen Gateway.',
        );
}

/// Thrown when the API returns a validation error.
class PayRogenValidationException extends PayRogenException {
  const PayRogenValidationException({
    required super.message,
    super.details,
  }) : super(
          code: 'VALIDATION_ERROR',
          statusCode: 400,
        );
}

/// Thrown when the API rate limit is exceeded.
class PayRogenRateLimitException extends PayRogenException {
  /// Duration to wait before retrying.
  final Duration retryAfter;

  PayRogenRateLimitException({required this.retryAfter})
      : super(
          code: 'RATE_LIMITED',
          message:
              'Rate limit exceeded. Retry after ${retryAfter.inSeconds} seconds.',
          statusCode: 429,
        );
}
