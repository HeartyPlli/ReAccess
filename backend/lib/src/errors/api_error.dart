class ApiError implements Exception {
  const ApiError({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  static const unauthorized = ApiError(
    statusCode: 401,
    message: 'Unauthorized.',
  );

  static const forbidden = ApiError(statusCode: 403, message: 'Forbidden.');
}
