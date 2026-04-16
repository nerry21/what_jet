import 'conversation_model.dart';

enum ChatMessageLocalState { stable, sending, failed }

/// Location payload attached to a chat message (message_type == 'location').
/// All fields are nullable because older or incomplete messages may not
/// carry every coordinate/label.
class ChatMessageLocation {
  const ChatMessageLocation({
    this.latitude,
    this.longitude,
    this.name,
    this.address,
  });

  final double? latitude;
  final double? longitude;
  final String? name;
  final String? address;

  /// True when we have enough data to actually pin a point on a map.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// True when there's at least something worth rendering (coords or text).
  bool get hasAnyData =>
      hasCoordinates ||
      (name != null && name!.isNotEmpty) ||
      (address != null && address!.isNotEmpty);

  static ChatMessageLocation? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(value);

    final location = ChatMessageLocation(
      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
      name: _nullableString(map['name']),
      address: _nullableString(map['address']),
    );

    return location.hasAnyData ? location : null;
  }
}

/// Interactive payload attached to a chat message (message_type == 'interactive').
/// Mirrors the shape emitted by `ConversationMessageResource` on the Laravel
/// backend.
class ChatMessageInteractive {
  const ChatMessageInteractive({
    this.type,
    this.header,
    this.body,
    this.footer,
    this.listButtonTitle,
    this.buttonOptions = const <String>[],
    this.listOptions = const <String>[],
    this.selection,
    this.isBookingReview = false,
  });

  /// Typically 'button' or 'list' (as sent to the WhatsApp Cloud API).
  final String? type;
  final String? header;
  final String? body;
  final String? footer;

  /// For list-type interactives, the label shown on the "open list" button
  /// (e.g. "Pilih Layanan").
  final String? listButtonTitle;

  /// Titles of reply buttons (for type == 'button').
  final List<String> buttonOptions;

  /// Row titles collected across all sections (for type == 'list').
  final List<String> listOptions;

  /// Which option the customer eventually tapped, if any. Shape is opaque;
  /// we only use this to show a selected-indicator in the UI.
  final Map<String, dynamic>? selection;

  final bool isBookingReview;

  bool get hasAnyOptions => buttonOptions.isNotEmpty || listOptions.isNotEmpty;

  bool get hasAnyData =>
      hasAnyOptions ||
      (header != null && header!.isNotEmpty) ||
      (body != null && body!.isNotEmpty) ||
      (footer != null && footer!.isNotEmpty);

  /// Preferred label to use in chat list previews or empty-bubble fallbacks.
  String get previewLabel {
    if (body != null && body!.isNotEmpty) return body!;
    if (header != null && header!.isNotEmpty) return header!;
    if (buttonOptions.isNotEmpty) return buttonOptions.first;
    if (listOptions.isNotEmpty) return listOptions.first;
    return 'Menu interaktif';
  }

  static ChatMessageInteractive? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(value);

    final buttonOptions = _stringList(map['button_options']);
    final listOptions = _stringList(map['list_options']);
    Map<String, dynamic>? selection;
    final rawSelection = map['selection'];
    if (rawSelection is Map) {
      selection = Map<String, dynamic>.from(rawSelection);
    }

    final interactive = ChatMessageInteractive(
      type: _nullableString(map['type']),
      header: _nullableString(map['header']),
      body: _nullableString(map['body']),
      footer: _nullableString(map['footer']),
      listButtonTitle: _nullableString(map['list_button_title']),
      buttonOptions: buttonOptions,
      listOptions: listOptions,
      selection: selection,
      isBookingReview: map['is_booking_review'] == true,
    );

    return interactive.hasAnyData ? interactive : null;
  }
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.localId,
    required this.direction,
    required this.senderType,
    required this.messageType,
    required this.text,
    required this.sentAt,
    this.id,
    this.conversationId,
    this.senderUserId,
    this.deliveryStatus,
    this.deliveryError,
    this.isFallback = false,
    this.clientMessageId,
    this.channelMessageId,
    this.readAt,
    this.deliveredToAppAt,
    this.createdAt,
    this.updatedAt,
    this.isMineFlag,
    this.localState = ChatMessageLocalState.stable,
    this.location,
    this.interactive,
  });

  final int? id;
  final String localId;
  final int? conversationId;
  final String direction;
  final String senderType;
  final String messageType;
  final String text;
  final int? senderUserId;
  final String? deliveryStatus;
  final String? deliveryError;
  final bool isFallback;
  final String? clientMessageId;
  final String? channelMessageId;
  final DateTime sentAt;
  final DateTime? readAt;
  final DateTime? deliveredToAppAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? isMineFlag;
  final ChatMessageLocalState localState;

  /// Populated when `message_type == 'location'`.
  final ChatMessageLocation? location;

  /// Populated when `message_type == 'interactive'`.
  final ChatMessageInteractive? interactive;

  bool get isMine =>
      isMineFlag == true ||
      (senderType == 'customer' && direction == 'inbound');

  bool get isSending => localState == ChatMessageLocalState.sending;

  bool get isFailed =>
      localState == ChatMessageLocalState.failed || deliveryStatus == 'failed';

  bool get isSent => !isSending && !isFailed;

  bool get isDelivered =>
      deliveredToAppAt != null ||
      deliveryStatus == 'delivered' ||
      deliveryStatus == 'read';

  bool get isReadByCustomer => readAt != null || deliveryStatus == 'read';

  bool get isLocation => messageType == 'location' && location != null;

  bool get isInteractive => messageType == 'interactive' && interactive != null;

  String get stableKey => id != null
      ? 'server_$id'
      : clientMessageId != null
      ? 'client_$clientMessageId'
      : 'local_$localId';

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt();
    final createdAt = _parseDateTime(json['created_at']);
    final sentAt =
        _parseDateTime(json['sent_at']) ?? createdAt ?? DateTime.now();
    final deliveryStatus = _nullableString(json['delivery_status']);

    return ChatMessageModel(
      id: id,
      localId: 'server-${id ?? sentAt.microsecondsSinceEpoch}',
      conversationId: (json['conversation_id'] as num?)?.toInt(),
      direction: _nullableString(json['direction']) ?? 'inbound',
      senderType: _nullableString(json['sender_type']) ?? 'customer',
      messageType: _nullableString(json['message_type']) ?? 'text',
      sentAt: sentAt,
      text:
          _nullableString(json['message_text']) ??
          _nullableString(json['text']) ??
          '',
      senderUserId: (json['sender_user_id'] as num?)?.toInt(),
      deliveryStatus: deliveryStatus,
      deliveryError: _nullableString(json['delivery_error']),
      isFallback: json['is_fallback'] == true,
      clientMessageId: _nullableString(json['client_message_id']),
      channelMessageId: _nullableString(json['channel_message_id']),
      readAt: _parseDateTime(json['read_at']),
      deliveredToAppAt: _parseDateTime(json['delivered_to_app_at']),
      createdAt: createdAt,
      updatedAt: _parseDateTime(json['updated_at']),
      isMineFlag: json['is_mine'] == true,
      localState: deliveryStatus == 'failed'
          ? ChatMessageLocalState.failed
          : ChatMessageLocalState.stable,
      location: ChatMessageLocation.fromJson(json['location']),
      interactive: ChatMessageInteractive.fromJson(json['interactive']),
    );
  }

  factory ChatMessageModel.optimistic({
    required String localId,
    required int conversationId,
    required String text,
    required String clientMessageId,
  }) {
    final now = DateTime.now();

    return ChatMessageModel(
      localId: localId,
      conversationId: conversationId,
      direction: 'inbound',
      senderType: 'customer',
      messageType: 'text',
      text: text,
      deliveryStatus: 'pending',
      clientMessageId: clientMessageId,
      sentAt: now,
      createdAt: now,
      isMineFlag: true,
      localState: ChatMessageLocalState.sending,
    );
  }

  ChatMessageModel copyWith({
    int? id,
    String? localId,
    int? conversationId,
    String? direction,
    String? senderType,
    String? messageType,
    String? text,
    int? senderUserId,
    String? deliveryStatus,
    String? deliveryError,
    bool? isFallback,
    String? clientMessageId,
    String? channelMessageId,
    DateTime? sentAt,
    DateTime? readAt,
    DateTime? deliveredToAppAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isMineFlag,
    ChatMessageLocalState? localState,
    ChatMessageLocation? location,
    ChatMessageInteractive? interactive,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      conversationId: conversationId ?? this.conversationId,
      direction: direction ?? this.direction,
      senderType: senderType ?? this.senderType,
      messageType: messageType ?? this.messageType,
      text: text ?? this.text,
      senderUserId: senderUserId ?? this.senderUserId,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      deliveryError: deliveryError ?? this.deliveryError,
      isFallback: isFallback ?? this.isFallback,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      channelMessageId: channelMessageId ?? this.channelMessageId,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      deliveredToAppAt: deliveredToAppAt ?? this.deliveredToAppAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isMineFlag: isMineFlag ?? this.isMineFlag,
      localState: localState ?? this.localState,
      location: location ?? this.location,
      interactive: interactive ?? this.interactive,
    );
  }

  bool matches(ChatMessageModel other) {
    if (id != null && other.id != null) {
      return id == other.id;
    }

    if (clientMessageId != null &&
        other.clientMessageId != null &&
        clientMessageId == other.clientMessageId) {
      return true;
    }

    if (channelMessageId != null &&
        other.channelMessageId != null &&
        channelMessageId == other.channelMessageId) {
      return true;
    }

    return localId == other.localId;
  }
}

class SendMessageResponseModel {
  const SendMessageResponseModel({
    required this.ok,
    required this.duplicate,
    required this.conversation,
    required this.message,
    this.pollIntervalMs = 3000,
  });

  final bool ok;
  final bool duplicate;
  final ConversationModel conversation;
  final ChatMessageModel message;
  final int pollIntervalMs;

  factory SendMessageResponseModel.fromJson(Map<String, dynamic> json) {
    final meta =
        (json['meta'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return SendMessageResponseModel(
      ok: json['ok'] != false,
      duplicate: json['duplicate'] == true,
      conversation: ConversationModel.fromJson(
        (json['conversation'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      message: ChatMessageModel.fromJson(
        (json['message'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      pollIntervalMs: (meta['poll_interval_ms'] as num?)?.toInt() ?? 3000,
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

double? _parseDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }
  return null;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((e) => e?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}
