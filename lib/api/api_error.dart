/// Typed error surfaced from every repository to every controller.
/// Controllers map this to localised user-facing messages.
sealed class ApiError {
  const ApiError();
}

/// 402 Payment Required — not enough credits.
/// Carries the raw paise values so the UI can convert to coins for display.
final class InsufficientCreditsError extends ApiError {
  const InsufficientCreditsError({
    required this.availablePaise,
    required this.requiredPaise,
  });
  final int availablePaise;
  final int requiredPaise;

  /// "5 🪙" — pass symbol from currencyInfoProvider.
  String availableCoins(String symbol) => '${availablePaise ~/ 100} $symbol';

  /// "10 🪙" — pass symbol from currencyInfoProvider.
  String requiredCoins(String symbol) => '${requiredPaise ~/ 100} $symbol';

  @override
  String toString() => 'InsufficientCreditsError(have $availablePaise, need $requiredPaise)';
}

/// 4xx/5xx response with a body we could parse.
final class ServerError extends ApiError {
  const ServerError({required this.statusCode, required this.message});
  final int statusCode;
  final String message;

  bool get isUnauthorised => statusCode == 401;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => 'ServerError($statusCode): $message';
}

/// Network-level failure (timeout, no connectivity, DNS).
final class NetworkError extends ApiError {
  const NetworkError({this.message = 'Network unreachable'});
  final String message;

  @override
  String toString() => 'NetworkError: $message';
}

/// Unexpected exception (JSON parse failure, etc.)
final class UnknownError extends ApiError {
  const UnknownError(this.cause);
  final Object cause;

  @override
  String toString() => 'UnknownError: $cause';
}
