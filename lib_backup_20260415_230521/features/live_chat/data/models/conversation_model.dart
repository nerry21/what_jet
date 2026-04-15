import 'customer_model.dart';

class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.channel,
    required this.channelLabel,
    required this.status,
    required this.operationalMode,
    required this.operationalModeLabel,
    required this.needsHuman,
    required this.unreadCount,
    required this.customer,
    this.channelConversationId,
    this.sourceApp,
    this.sourceLabel,
    this.isFromMobileApp = false,
    this.isWhatsApp = false,
    this.isMobileLiveChat = false,
    this.handoffMode,
    this.startedAt,
    this.lastMessageAt,
    this.lastReadAtCustomer,
    this.lastReadAtAdmin,
    this.latestMessagePreview,
    this.latestMessageId,
  });

  final int id;
  final String channel;
  final String channelLabel;
  final String status;
  final String operationalMode;
  final String operationalModeLabel;
  final bool needsHuman;
  final int unreadCount;
  final CustomerModel customer;
  final String? channelConversationId;
  final String? sourceApp;
  final String? sourceLabel;
  final bool isFromMobileApp;
  final bool isWhatsApp;
  final bool isMobileLiveChat;
  final String? handoffMode;
  final DateTime? startedAt;
  final DateTime? lastMessageAt;
  final DateTime? lastReadAtCustomer;
  final DateTime? lastReadAtAdmin;
  final String? latestMessagePreview;
  final int? latestMessageId;

  bool get hasUnread => unreadCount > 0;

  bool get isActive => status == 'active';

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final latestMessage = json['latest_message'] as Map<String, dynamic>?;
    final sourceApp = _nullableString(json['source_app']);

    return ConversationModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      channel: _nullableString(json['channel']) ?? 'mobile_live_chat',
      channelLabel:
          _nullableString(json['channel_label']) ?? 'Mobile Live Chat',
      status: _nullableString(json['status']) ?? 'active',
      operationalMode:
          _nullableString(json['operational_mode']) ?? 'bot_active',
      operationalModeLabel:
          _nullableString(json['operational_mode_label']) ?? 'Bot Active',
      needsHuman: json['needs_human'] == true,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      customer: json['customer'] is Map<String, dynamic>
          ? CustomerModel.fromJson(json['customer'] as Map<String, dynamic>)
          : const CustomerModel.empty(),
      channelConversationId: _nullableString(json['channel_conversation_id']),
      sourceApp: sourceApp,
      sourceLabel:
          _nullableString(json['source_label']) ??
          _formatSourceLabel(sourceApp),
      isFromMobileApp: json['is_from_mobile_app'] == true,
      isWhatsApp: json['is_whatsapp'] == true,
      isMobileLiveChat:
          json['is_mobile_live_chat'] == true ||
          (_nullableString(json['channel']) ?? '') == 'mobile_live_chat',
      handoffMode: _nullableString(json['handoff_mode']),
      startedAt: _parseDateTime(json['started_at']),
      lastMessageAt:
          _parseDateTime(json['last_message_at']) ??
          _parseDateTime(latestMessage?['sent_at']) ??
          _parseDateTime(latestMessage?['created_at']),
      lastReadAtCustomer: _parseDateTime(json['last_read_at_customer']),
      lastReadAtAdmin: _parseDateTime(json['last_read_at_admin']),
      latestMessagePreview:
          _nullableString(json['latest_message_preview']) ??
          _nullableString(latestMessage?['message_text']) ??
          _nullableString(latestMessage?['text']),
      latestMessageId:
          (json['latest_message_id'] as num?)?.toInt() ??
          (latestMessage?['id'] as num?)?.toInt(),
    );
  }

  ConversationModel copyWith({
    int? id,
    String? channel,
    String? channelLabel,
    String? status,
    String? operationalMode,
    String? operationalModeLabel,
    bool? needsHuman,
    int? unreadCount,
    CustomerModel? customer,
    String? channelConversationId,
    String? sourceApp,
    String? sourceLabel,
    bool? isFromMobileApp,
    bool? isWhatsApp,
    bool? isMobileLiveChat,
    String? handoffMode,
    DateTime? startedAt,
    DateTime? lastMessageAt,
    DateTime? lastReadAtCustomer,
    DateTime? lastReadAtAdmin,
    String? latestMessagePreview,
    int? latestMessageId,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      channel: channel ?? this.channel,
      channelLabel: channelLabel ?? this.channelLabel,
      status: status ?? this.status,
      operationalMode: operationalMode ?? this.operationalMode,
      operationalModeLabel: operationalModeLabel ?? this.operationalModeLabel,
      needsHuman: needsHuman ?? this.needsHuman,
      unreadCount: unreadCount ?? this.unreadCount,
      customer: customer ?? this.customer,
      channelConversationId:
          channelConversationId ?? this.channelConversationId,
      sourceApp: sourceApp ?? this.sourceApp,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      isFromMobileApp: isFromMobileApp ?? this.isFromMobileApp,
      isWhatsApp: isWhatsApp ?? this.isWhatsApp,
      isMobileLiveChat: isMobileLiveChat ?? this.isMobileLiveChat,
      handoffMode: handoffMode ?? this.handoffMode,
      startedAt: startedAt ?? this.startedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastReadAtCustomer: lastReadAtCustomer ?? this.lastReadAtCustomer,
      lastReadAtAdmin: lastReadAtAdmin ?? this.lastReadAtAdmin,
      latestMessagePreview: latestMessagePreview ?? this.latestMessagePreview,
      latestMessageId: latestMessageId ?? this.latestMessageId,
    );
  }
}

class ConversationListResponseModel {
  const ConversationListResponseModel({
    required this.customer,
    required this.conversations,
    required this.pollIntervalMs,
  });

  final CustomerModel customer;
  final List<ConversationModel> conversations;
  final int pollIntervalMs;

  factory ConversationListResponseModel.fromJson(Map<String, dynamic> json) {
    final meta =
        (json['meta'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return ConversationListResponseModel(
      customer: json['customer'] is Map<String, dynamic>
          ? CustomerModel.fromJson(json['customer'] as Map<String, dynamic>)
          : const CustomerModel.empty(),
      conversations: ((json['conversations'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ConversationModel.fromJson)
          .toList(),
      pollIntervalMs: (meta['poll_interval_ms'] as num?)?.toInt() ?? 3000,
    );
  }
}

class ReadReceiptModel {
  const ReadReceiptModel({
    required this.updatedCount,
    required this.conversation,
  });

  final int updatedCount;
  final ConversationModel conversation;

  int get conversationId => conversation.id;

  int get unreadCount => conversation.unreadCount;

  factory ReadReceiptModel.fromJson(Map<String, dynamic> json) {
    return ReadReceiptModel(
      updatedCount: (json['updated_count'] as num?)?.toInt() ?? 0,
      conversation: ConversationModel.fromJson(
        (json['conversation'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  final text = _nullableString(value);
  if (text == null) {
    return null;
  }

  return DateTime.tryParse(text)?.toLocal();
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String? _formatSourceLabel(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  final normalized = value.replaceAll('-', '_');
  final words = normalized
      .split('_')
      .where((segment) => segment.isNotEmpty)
      .map((segment) {
        final lower = segment.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .toList();

  return words.isEmpty ? null : words.join(' ');
}
