import '../../../../core/config/app_config.dart';
import 'omnichannel_payload_parser.dart';

class OmnichannelThreadGroupModel {
  const OmnichannelThreadGroupModel({
    required this.label,
    required this.messages,
  });

  final String label;
  final List<OmnichannelThreadMessageModel> messages;

  factory OmnichannelThreadGroupModel.fromJson(Map<String, dynamic> json) {
    final label =
        omnichannelFirstMapped<String>(json, const <String>[
          'label',
          'date_label',
          'date',
          'group_label',
        ], omnichannelString) ??
        'Hari Ini';

    final messages = omnichannelFirstMapList(json, const <String>[
      'messages',
      'items',
      'data',
    ]).map(OmnichannelThreadMessageModel.fromJson).toList();

    return OmnichannelThreadGroupModel(label: label, messages: messages);
  }

  static List<OmnichannelThreadGroupModel> mergeGroups(
    List<OmnichannelThreadGroupModel> current,
    List<OmnichannelThreadGroupModel> incoming,
  ) {
    if (incoming.isEmpty) {
      return current;
    }

    final mergedMessages = <int, OmnichannelThreadMessageModel>{};
    for (final group in current) {
      for (final message in group.messages) {
        mergedMessages[message.id] = message;
      }
    }
    for (final group in incoming) {
      for (final message in group.messages) {
        mergedMessages[message.id] = message;
      }
    }

    return _buildGroupsFromMessages(mergedMessages.values.toList());
  }

  static List<OmnichannelThreadGroupModel> fromSources({
    required Map<String, dynamic> messagesPayload,
    Map<String, dynamic> pollPayload = const <String, dynamic>{},
  }) {
    final directGroups = omnichannelFirstMapList(
      messagesPayload,
      const <String>['thread_groups', 'thread.groups', 'groups'],
    );
    final polledGroups = omnichannelFirstMapList(pollPayload, const <String>[
      'thread_groups',
      'thread.groups',
      'groups',
    ]);
    final mergedGroups = directGroups.isNotEmpty ? directGroups : polledGroups;

    if (mergedGroups.isNotEmpty) {
      return mergedGroups.map(OmnichannelThreadGroupModel.fromJson).toList();
    }

    final messageItems = <Map<String, dynamic>>[
      ...omnichannelFirstMapList(messagesPayload, const <String>[
        'messages',
        'thread.messages',
        'conversation_messages',
        'items',
        'data',
      ]),
      ...omnichannelFirstMapList(pollPayload, const <String>[
        'messages',
        'thread.messages',
        'conversation_messages',
        'items',
        'data',
      ]),
    ];

    if (messageItems.isEmpty) {
      return const <OmnichannelThreadGroupModel>[];
    }

    final mergedMessages = <int, OmnichannelThreadMessageModel>{};
    for (final item in messageItems.map(
      OmnichannelThreadMessageModel.fromJson,
    )) {
      mergedMessages[item.id] = item;
    }

    return _buildGroupsFromMessages(mergedMessages.values.toList());
  }
}

class OmnichannelThreadMessageModel {
  const OmnichannelThreadMessageModel({
    required this.id,
    required this.messageType,
    required this.senderLabel,
    required this.text,
    required this.sentAt,
    required this.isMine,
    this.statusLabel,
    this.deliveryStatus,
    this.deliveryError,
    this.imageUrl,
    this.audioUrl,
    this.audioId,
    this.mediaCaption,
    this.mimeType,
    this.originalName,
    this.sizeBytes,
    this.isVoiceNote = false,
    this.isReadByCustomer = false,
  });

  final int id;
  final String messageType;
  final String senderLabel;
  final String text;
  final DateTime sentAt;
  final bool isMine;
  final String? statusLabel;
  final String? deliveryStatus;
  final String? deliveryError;
  final String? imageUrl;
  final String? audioUrl;
  final String? audioId;
  final String? mediaCaption;
  final String? mimeType;
  final String? originalName;
  final int? sizeBytes;
  final bool isVoiceNote;
  final bool isReadByCustomer;

  bool get hasImage => messageType == 'image' && imageUrl != null;
  bool get hasAudio =>
      messageType == 'audio' &&
      ((audioUrl?.trim().isNotEmpty ?? false) ||
          (audioId?.trim().isNotEmpty ?? false));

  String get displayText {
    final caption = mediaCaption?.trim() ?? '';
    if (caption.isNotEmpty) {
      return caption;
    }

    if (hasImage || hasAudio) {
      return '';
    }

    final trimmed = text.trim();
    if (messageType == 'audio' &&
        (trimmed == '[Voice note admin]' || trimmed == '[Voice note]')) {
      return '';
    }

    return trimmed;
  }

  bool get isFailed => deliveryStatus == 'failed';
  bool get isRead => isReadByCustomer || statusLabel == 'read';
  bool get isDelivered => deliveryStatus == 'delivered' || isRead;
  bool get isSent => deliveryStatus == 'sent' || isDelivered;
  bool get isSending => deliveryStatus == 'pending' || statusLabel == 'sending';

  factory OmnichannelThreadMessageModel.fromJson(Map<String, dynamic> json) {
    final sender = omnichannelFirstMap(json, const <String>[
      'sender',
      'author',
      'user',
    ]);
    final media = omnichannelFirstMap(json, const <String>['media']);

    final sentAt =
        omnichannelFirstMappedFromSources<DateTime>(
          <Map<String, dynamic>>[json, sender],
          const <String>['sent_at', 'created_at', 'timestamp'],
          omnichannelDateTime,
        ) ??
        DateTime.now();

    final senderType =
        omnichannelFirstMapped<String>(json, const <String>[
          'sender_type',
          'direction',
          'source',
        ], omnichannelString) ??
        '';

    final isMine =
        omnichannelFirstMapped<bool>(json, const <String>[
          'is_mine',
          'mine',
        ], omnichannelBool) ??
        senderType.toLowerCase().contains('outbound') ||
            senderType.toLowerCase().contains('admin') ||
            senderType.toLowerCase().contains('agent') ||
            senderType.toLowerCase().contains('bot');

    final deliveryStatus =
        omnichannelFirstMapped<String>(json, const <String>[
          'delivery_status',
          'delivery.status',
        ], omnichannelString) ??
        (isMine ? 'sent' : 'sent');

    final statusLabel =
        omnichannelFirstMapped<String>(json, const <String>[
          'status_label',
          'delivery_label',
          'delivery.label',
        ], omnichannelString) ??
        (isMine ? 'sent' : null);

    final messageType =
        omnichannelFirstMapped<String>(json, const <String>[
          'message_type',
          'type',
        ], omnichannelString) ??
        'text';

    final resolvedImageUrl = _normalizeImageUrl(
      omnichannelFirstMappedFromSources<String>(
        <Map<String, dynamic>>[media, json],
        const <String>['image_url', 'media.image_url'],
        omnichannelString,
      ),
    );

    final resolvedAudioUrl = _normalizeAudioUrl(
      omnichannelFirstMappedFromSources<String>(
        <Map<String, dynamic>>[media, json],
        const <String>['audio_url', 'media.audio_url'],
        omnichannelString,
      ),
    );

    return OmnichannelThreadMessageModel(
      id:
          omnichannelFirstMapped<int>(json, const <String>[
            'id',
            'message_id',
          ], omnichannelInt) ??
          sentAt.microsecondsSinceEpoch,
      messageType: messageType,
      senderLabel:
          omnichannelFirstMappedFromSources<String>(
            <Map<String, dynamic>>[json, sender],
            const <String>['sender_label', 'name', 'display_name', 'label'],
            omnichannelString,
          ) ??
          (isMine ? 'Admin' : 'Customer'),
      text:
          omnichannelFirstMapped<String>(json, const <String>[
            'text',
            'message_text',
            'body',
            'content',
            'preview',
          ], omnichannelString) ??
          '',
      sentAt: sentAt,
      isMine: isMine,
      statusLabel: statusLabel,
      deliveryStatus: deliveryStatus,
      deliveryError: omnichannelFirstMapped<String>(json, const <String>[
        'delivery_error',
      ], omnichannelString),
      imageUrl: resolvedImageUrl,
      audioUrl: resolvedAudioUrl,
      audioId: omnichannelFirstMappedFromSources<String>(
        <Map<String, dynamic>>[media, json],
        const <String>['audio_id', 'media.audio_id'],
        omnichannelString,
      ),
      mediaCaption: omnichannelFirstMappedFromSources<String>(
        <Map<String, dynamic>>[media, json],
        const <String>['caption', 'media.caption'],
        omnichannelString,
      ),
      mimeType: omnichannelFirstMappedFromSources<String>(
        <Map<String, dynamic>>[media, json],
        const <String>['mime_type', 'media.mime_type'],
        omnichannelString,
      ),
      originalName: omnichannelFirstMappedFromSources<String>(
        <Map<String, dynamic>>[media, json],
        const <String>['original_name', 'media.original_name'],
        omnichannelString,
      ),
      sizeBytes: omnichannelFirstMappedFromSources<int>(
        <Map<String, dynamic>>[media, json],
        const <String>['size_bytes', 'media.size_bytes'],
        omnichannelInt,
      ),
      isVoiceNote:
          omnichannelFirstMappedFromSources<bool>(
            <Map<String, dynamic>>[media, json],
            const <String>['is_voice_note', 'media.is_voice_note'],
            omnichannelBool,
          ) ??
          (messageType == 'audio'),
      isReadByCustomer:
          omnichannelFirstMapped<bool>(json, const <String>[
            'is_read_by_customer',
          ], omnichannelBool) ??
          false,
    );
  }
}

String _groupLabel(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day/$month/$year';
}

List<OmnichannelThreadGroupModel> _buildGroupsFromMessages(
  List<OmnichannelThreadMessageModel> messages,
) {
  final grouped = <String, List<OmnichannelThreadMessageModel>>{};
  for (final item in messages) {
    final key = _groupLabel(item.sentAt);
    grouped.putIfAbsent(key, () => <OmnichannelThreadMessageModel>[]).add(item);
  }

  return grouped.entries
      .map(
        (entry) => OmnichannelThreadGroupModel(
          label: entry.key,
          messages: entry.value
            ..sort((left, right) => left.sentAt.compareTo(right.sentAt)),
        ),
      )
      .toList()
    ..sort((left, right) {
      final leftTimestamp = left.messages.isEmpty
          ? 0
          : left.messages.first.sentAt.millisecondsSinceEpoch;
      final rightTimestamp = right.messages.isEmpty
          ? 0
          : right.messages.first.sentAt.millisecondsSinceEpoch;
      return leftTimestamp.compareTo(rightTimestamp);
    });
}

String? _normalizeImageUrl(String? rawValue) {
  final value = rawValue?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }

  final baseUri = Uri.tryParse(AppConfig.baseUrl);
  if (value.startsWith('//')) {
    final scheme = baseUri != null && baseUri.scheme.isNotEmpty
        ? baseUri.scheme
        : 'https';
    return '$scheme:$value';
  }

  var normalized = value;
  var parsed = Uri.tryParse(normalized);

  if (parsed == null) {
    return value;
  }

  if (!parsed.hasScheme && baseUri != null) {
    parsed = baseUri.resolve(normalized);
    normalized = parsed.toString();
  }

  if (parsed.scheme == 'http' &&
      baseUri != null &&
      baseUri.scheme == 'https' &&
      parsed.host.toLowerCase() == baseUri.host.toLowerCase()) {
    parsed = parsed.replace(scheme: 'https');
    normalized = parsed.toString();
  }

  return normalized;
}

String? _normalizeAudioUrl(String? rawValue) {
  final value = rawValue?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }

  final baseUri = Uri.tryParse(AppConfig.baseUrl);
  if (value.startsWith('//')) {
    final scheme = baseUri != null && baseUri.scheme.isNotEmpty
        ? baseUri.scheme
        : 'https';
    return '$scheme:$value';
  }

  var normalized = value;
  var parsed = Uri.tryParse(normalized);

  if (parsed == null) {
    return value;
  }

  if (!parsed.hasScheme && baseUri != null) {
    parsed = baseUri.resolve(normalized);
    normalized = parsed.toString();
  }

  if (parsed.scheme == 'http' &&
      baseUri != null &&
      baseUri.scheme == 'https' &&
      parsed.host.toLowerCase() == baseUri.host.toLowerCase()) {
    parsed = parsed.replace(scheme: 'https');
    normalized = parsed.toString();
  }

  return normalized;
}
