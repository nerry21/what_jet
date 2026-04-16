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
    this.imageDownloadUrl,
    this.audioUrl,
    this.audioDownloadUrl,
    this.audioId,
    this.videoUrl,
    this.videoDownloadUrl,
    this.videoId,
    this.documentUrl,
    this.documentDownloadUrl,
    this.documentId,
    this.mediaCaption,
    this.mimeType,
    this.originalName,
    this.sizeBytes,
    this.isVoiceNote = false,
    this.isReadByCustomer = false,
    this.latitude,
    this.longitude,
    this.locationName,
    this.locationAddress,
    this.interactiveType,
    this.interactiveButtonOptions = const <String>[],
    this.interactiveListOptions = const <String>[],
    this.interactiveHeader,
    this.interactiveBody,
    this.interactiveFooter,
    this.interactiveListButtonTitle,
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
  final String? imageDownloadUrl;
  final String? audioUrl;
  final String? audioDownloadUrl;
  final String? audioId;
  final String? videoUrl;
  final String? videoDownloadUrl;
  final String? videoId;
  final String? documentUrl;
  final String? documentDownloadUrl;
  final String? documentId;
  final String? mediaCaption;
  final String? mimeType;
  final String? originalName;
  final int? sizeBytes;
  final bool isVoiceNote;
  final bool isReadByCustomer;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? locationAddress;
  final String? interactiveType;
  final List<String> interactiveButtonOptions;
  final List<String> interactiveListOptions;
  final String? interactiveHeader;
  final String? interactiveBody;
  final String? interactiveFooter;
  final String? interactiveListButtonTitle;

  bool get hasImage =>
      messageType == 'image' && (imageUrl?.trim().isNotEmpty ?? false);

  bool get hasAudio =>
      messageType == 'audio' &&
      ((audioUrl?.trim().isNotEmpty ?? false) ||
          (audioId?.trim().isNotEmpty ?? false));

  bool get hasVideo =>
      messageType == 'video' &&
      ((videoUrl?.trim().isNotEmpty ?? false) ||
          (videoId?.trim().isNotEmpty ?? false));

  bool get hasDocument =>
      messageType == 'document' &&
      ((documentUrl?.trim().isNotEmpty ?? false) ||
          (documentId?.trim().isNotEmpty ?? false));

  bool get hasLocation =>
      (messageType == 'location' || latitude != null || longitude != null) &&
      latitude != null &&
      longitude != null;

  bool get hasInteractive =>
      (messageType == 'interactive' ||
          (interactiveType?.trim().isNotEmpty ?? false)) &&
      (interactiveButtonOptions.isNotEmpty ||
          interactiveListOptions.isNotEmpty);

  String? get preferredImageDownloadUrl => imageDownloadUrl ?? imageUrl;
  String? get preferredAudioDownloadUrl => audioDownloadUrl ?? audioUrl;
  String? get preferredVideoDownloadUrl => videoDownloadUrl ?? videoUrl;
  String? get preferredDocumentDownloadUrl =>
      documentDownloadUrl ?? documentUrl;

  String get displayText {
    final caption = mediaCaption?.trim() ?? '';
    if (caption.isNotEmpty) {
      return caption;
    }

    if (hasImage || hasAudio || hasVideo || hasDocument || hasLocation) {
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
    final location = omnichannelFirstMap(json, const <String>['location']);
    final interactive = omnichannelFirstMap(json, const <String>[
      'interactive',
    ]);

    final interactiveButtonOptions = _stringList(interactive['button_options']);
    final interactiveListOptions = _stringList(interactive['list_options']);

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
        'sent';

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
      imageUrl: _normalizeMediaUrl(
        omnichannelFirstMappedFromSources<String>(
          <Map<String, dynamic>>[media, json],
          const <String>['image_url', 'media.image_url'],
          omnichannelString,
        ),
      ),
      imageDownloadUrl: _normalizeMediaUrl(
        omnichannelFirstMappedFromSources<String>(
          <Map<String, dynamic>>[media, json],
          const <String>['image_download_url', 'media.image_download_url'],
          omnichannelString,
        ),
      ),
      audioUrl: _normalizeMediaUrl(
        omnichannelFirstMappedFromSources<String>(
          <Map<String, dynamic>>[media, json],
          const <String>['audio_url', 'media.audio_url'],
          omnichannelString,
        ),
      ),
      audioDownloadUrl: _normalizeMediaUrl(
        omnichannelFirstMappedFromSources<String>(
          <Map<String, dynamic>>[media, json],
          const <String>['audio_download_url', 'media.audio_download_url'],
          omnichannelString,
        ),
      ),
      audioId: omnichannelFirstMappedFromSources<String>(
        <Map<String, dynamic>>[media, json],
        const <String>['audio_id', 'media.audio_id'],
        omnichannelString,
      ),
      videoUrl: _normalizeMediaUrl(
        omnichannelFirstMappedFromSources<String>(
          <Map<String, dynamic>>[media, json],
          const <String>['video_url', 'media.video_url'],
          omnichannelString,
        ),
      ),
      videoDownloadUrl: _normalizeMediaUrl(
        omnichannelFirstMappedFromSources<String>(
          <Map<String, dynamic>>[media, json],
          const <String>['video_download_url', 'media.video_download_url'],
          omnichannelString,
        ),
      ),
      videoId: omnichannelFirstMappedFromSources<String>(
        <Map<String, dynamic>>[media, json],
        const <String>['video_id', 'media.video_id'],
        omnichannelString,
      ),
      documentUrl: _normalizeMediaUrl(
        omnichannelFirstMappedFromSources<String>(
          <Map<String, dynamic>>[media, json],
          const <String>['document_url', 'media.document_url'],
          omnichannelString,
        ),
      ),
      documentDownloadUrl: _normalizeMediaUrl(
        omnichannelFirstMappedFromSources<String>(
          <Map<String, dynamic>>[media, json],
          const <String>[
            'document_download_url',
            'media.document_download_url',
          ],
          omnichannelString,
        ),
      ),
      documentId: omnichannelFirstMappedFromSources<String>(
        <Map<String, dynamic>>[media, json],
        const <String>['document_id', 'media.document_id'],
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
      latitude: omnichannelFirstMappedFromSources<double>(
        <Map<String, dynamic>>[location, media, json],
        const <String>['latitude', 'media.latitude', 'location.latitude'],
        _toDouble,
      ),
      longitude: omnichannelFirstMappedFromSources<double>(
        <Map<String, dynamic>>[location, media, json],
        const <String>['longitude', 'media.longitude', 'location.longitude'],
        _toDouble,
      ),
      locationName: omnichannelFirstMappedFromSources<String>(
        <Map<String, dynamic>>[location, media, json],
        const <String>['name', 'location.name', 'location_name'],
        omnichannelString,
      ),
      locationAddress: omnichannelFirstMappedFromSources<String>(
        <Map<String, dynamic>>[location, media, json],
        const <String>['address', 'location.address', 'location_address'],
        omnichannelString,
      ),
      interactiveType: omnichannelFirstMapped<String>(
        interactive,
        const <String>['type'],
        omnichannelString,
      ),
      interactiveButtonOptions: interactiveButtonOptions,
      interactiveListOptions: interactiveListOptions,
      interactiveHeader: omnichannelFirstMapped<String>(
        interactive,
        const <String>['header', 'header_text'],
        omnichannelString,
      ),
      interactiveBody: omnichannelFirstMapped<String>(
        interactive,
        const <String>['body', 'body_text'],
        omnichannelString,
      ),
      interactiveFooter: omnichannelFirstMapped<String>(
        interactive,
        const <String>['footer', 'footer_text'],
        omnichannelString,
      ),
      interactiveListButtonTitle: omnichannelFirstMapped<String>(
        interactive,
        const <String>['list_button_title', 'button_title'],
        omnichannelString,
      ),
    );
  }
}

/// Helper: accept int, double, or string and return a double.
double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }
  return null;
}

/// Helper: safely convert any iterable into a `List<String>` of trimmed,
/// non-empty entries.
List<String> _stringList(Object? value) {
  if (value is! Iterable) return const <String>[];
  final result = <String>[];
  for (final item in value) {
    if (item == null) continue;
    final text = item.toString().trim();
    if (text.isNotEmpty) {
      result.add(text);
    }
  }
  return result;
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

String? _normalizeMediaUrl(String? rawValue) {
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
