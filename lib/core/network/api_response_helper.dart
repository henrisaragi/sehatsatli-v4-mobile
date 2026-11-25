/// Backend v4 error bodies are `{message}` or Laravel's
/// `{message, errors: {field: [..]}}`; older endpoints sometimes sent
/// `message` itself as a field map. Flattens any of these into one line.
String? extractApiMessage(Map<String, dynamic> response) {
  final errors = response['errors'];
  if (errors is Map && errors.isNotEmpty) {
    return errors.values.map((v) => v is List ? v.join(', ') : v.toString()).join(', ');
  }
  final message = response['message'];
  if (message == null) return null;
  if (message is String) return message;
  if (message is Map) {
    return message.values.map((v) => v is List ? v.join(', ') : v.toString()).join(', ');
  }
  return message.toString();
}
