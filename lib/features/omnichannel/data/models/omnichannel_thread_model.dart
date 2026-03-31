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
    required this.senderLabel,
    required this.text,
    required this.sentAt,
    required this.isMine,
    this.statusLabel,
    this.deliveryStatus,
    this.deliveryError,
    this.isReadByCustomer = false,
  });

  final int id;
  final String senderLabel;
  final String text;
  final DateTime sentAt;
  final bool isMine;
  final String? statusLabel;
  final String? deliveryStatus;
  final String? deliveryError;
  final bool isReadByCustomer;

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

    return OmnichannelThreadMessageModel(
      id:
          omnichannelFirstMapped<int>(json, const <String>[
            'id',
            'message_id',
          ], omnichannelInt) ??
          sentAt.microsecondsSinceEpoch,
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
      deliveryError:
          omnichannelFirstMapped<String>(json, const <String>[
            'delivery_error',
          ], omnichannelString),
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
