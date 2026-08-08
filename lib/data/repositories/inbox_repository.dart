import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response_helper.dart';

/// Parsed shape of one `user-inbox` row (API_ENDPOINTS.md §5). Keeps [raw]
/// around so [InboxRepository.markRead] can resend the full record — the
/// `save` endpoint has no per-field update, it takes the whole object.
class InboxMessage {
  InboxMessage({
    required this.id,
    required this.subject,
    required this.message,
    required this.receivedDate,
    required this.read,
    required this.raw,
  });

  factory InboxMessage.fromJson(Map<String, dynamic> json) {
    bool truthy(dynamic v) => v == true || v == 1 || v == '1';
    return InboxMessage(
      id: json['id'],
      subject: (json['subject'] ?? json['title'] ?? 'Notifikasi').toString(),
      message: (json['message'] ?? json['body'] ?? json['description'] ?? '').toString(),
      receivedDate:
          (json['received_date'] ?? json['created_at'] ?? json['date'] ?? '').toString(),
      read: truthy(json['read']) || json['read_date'] != null,
      raw: json,
    );
  }

  final dynamic id;
  final String subject;
  final String message;
  final String receivedDate;
  final bool read;
  final Map<String, dynamic> raw;

  InboxMessage copyWith({bool? read}) => InboxMessage(
        id: id,
        subject: subject,
        message: message,
        receivedDate: receivedDate,
        read: read ?? this.read,
        raw: raw,
      );
}

class InboxRepository {
  InboxRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<InboxMessage>> fetchAll({required String token}) async {
    final response = await _apiClient.post(ApiEndpoints.userInboxGetAll, token: token);
    if (!isApiSuccess(response)) return [];

    final data = response['data'];
    List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map && data['data'] is List) {
      items = data['data'] as List;
    } else {
      items = const [];
    }

    return items
        .whereType<Map>()
        .map((e) => InboxMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Resends the full message with `read: true` and a fresh `read_date`,
  /// per the `{ id?, user_id, received_date, read_date, subject, message,
  /// read }` body shape API_ENDPOINTS.md §5 documents for `save`.
  Future<bool> markRead(InboxMessage message, {required String token}) async {
    final body = {
      ...message.raw,
      'id': message.id,
      'received_date': message.receivedDate,
      'read_date': DateTime.now().toUtc().toIso8601String(),
      'subject': message.subject,
      'message': message.message,
      'read': true,
    };
    final response = await _apiClient.post(
      ApiEndpoints.userInboxSave,
      body: body,
      token: token,
    );
    return isApiSuccess(response);
  }
}
