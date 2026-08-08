/// The backend returns HTTP 200 even for failed requests, with
/// `{ "success": false, "message": {...} }` in the body — status codes alone
/// can't be trusted, so every API call site must check this instead.
bool isApiSuccess(Map<String, dynamic> response) => response['success'] == true;

/// `message` is sometimes a plain string, sometimes a Laravel-style
/// validation map of field -> [errors]. Flattens either into one string.
String? extractApiMessage(Map<String, dynamic> response) {
  final message = response['message'];
  if (message == null) return null;
  if (message is String) return message;
  if (message is Map) {
    return message.values
        .map((v) => v is List ? v.join(', ') : v.toString())
        .join(', ');
  }
  return message.toString();
}
