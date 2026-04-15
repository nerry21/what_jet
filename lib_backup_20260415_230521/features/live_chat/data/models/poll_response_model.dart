import 'chat_message_model.dart';
import 'conversation_model.dart';

class PollResponseModel {
  const PollResponseModel({
    required this.conversation,
    required this.messages,
    required this.channel,
    required this.channelLabel,
    required this.pollIntervalMs,
    this.sourceApp,
    this.sourceLabel,
    this.latestMessageId,
    this.unreadCount = 0,
    this.deltaCount = 0,
    this.created = false,
    this.duplicate = false,
    this.submittedMessage,
  });

  final ConversationModel conversation;
  final List<ChatMessageModel> messages;
  final String channel;
  final String channelLabel;
  final int pollIntervalMs;
  final String? sourceApp;
  final String? sourceLabel;
  final int? latestMessageId;
  final int unreadCount;
  final int deltaCount;
  final bool created;
  final bool duplicate;
  final ChatMessageModel? submittedMessage;

  factory PollResponseModel.fromJson(Map<String, dynamic> json) {
    final meta =
        (json['meta'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return PollResponseModel(
      conversation: ConversationModel.fromJson(
        (json['conversation'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      messages: ((json['messages'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChatMessageModel.fromJson)
          .toList(),
      channel: _nullableString(meta['channel']) ?? 'mobile_live_chat',
      channelLabel:
          _nullableString(meta['channel_label']) ?? 'Mobile Live Chat',
      pollIntervalMs: (meta['poll_interval_ms'] as num?)?.toInt() ?? 3000,
      sourceApp: _nullableString(meta['source_app']),
      sourceLabel: _nullableString(meta['source_label']),
      latestMessageId: (meta['latest_message_id'] as num?)?.toInt(),
      unreadCount: (meta['unread_count'] as num?)?.toInt() ?? 0,
      deltaCount: (meta['delta_count'] as num?)?.toInt() ?? 0,
      created: json['created'] == true || meta['created'] == true,
      duplicate: json['duplicate'] == true || meta['duplicate'] == true,
      submittedMessage: json['submitted_message'] is Map<String, dynamic>
          ? ChatMessageModel.fromJson(
              json['submitted_message'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
