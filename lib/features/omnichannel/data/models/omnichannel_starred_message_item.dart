/// Item daftar "Pesan Berbintang" (BRIEF 5C-2-APP).
///
/// Dikonsumsi layar daftar dari GET admin-mobile `starred-messages`. Shape item
/// (sudah FLATTEN ke top-level oleh `ApiClient`): `id`, `conversation_id`,
/// `conversation_customer_name`, `message_text`, `message_type`, dan `starred_at`
/// flat ISO8601. Model self-contained: nol normalisasi cross-file; teks dari
/// `message_text` apa adanya (fallback non-text di-handle di layer page).
class OmnichannelStarredMessageItem {
  const OmnichannelStarredMessageItem({
    required this.id,
    required this.conversationId,
    required this.customerName,
    required this.text,
    required this.messageType,
    required this.starredAt,
  });

  factory OmnichannelStarredMessageItem.fromJson(Map<String, dynamic> json) {
    return OmnichannelStarredMessageItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      conversationId: (json['conversation_id'] as num?)?.toInt() ?? 0,
      customerName: (json['conversation_customer_name'] as String? ?? '')
          .trim(),
      text: (json['message_text'] as String?)?.trim(),
      messageType: (json['message_type'] as String? ?? '').trim(),
      starredAt: _parseDateTime(json['starred_at']),
    );
  }

  final int id;
  final int conversationId;
  final String customerName;
  final String? text;
  final String messageType;
  final DateTime? starredAt;

  static DateTime? _parseDateTime(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.trim());
  }
}
