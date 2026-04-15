import 'omnichannel_payload_parser.dart';

class OmnichannelConversationListModel {
  const OmnichannelConversationListModel({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    this.selectedConversationId,
  });

  final List<OmnichannelConversationListItemModel> items;
  final int page;
  final int perPage;
  final int total;
  final int? selectedConversationId;

  bool get isEmpty => items.isEmpty;
  bool get hasMore => items.length < total;

  factory OmnichannelConversationListModel.fromSources({
    required Map<String, dynamic> conversationsPayload,
    Map<String, dynamic> pollListPayload = const <String, dynamic>{},
    int? preferredConversationId,
  }) {
    final primaryItems = _parseItems(conversationsPayload);
    final pollItems = _parseItems(pollListPayload);
    final items = primaryItems.isNotEmpty
        ? _mergeConversationItems(primaryItems, pollItems)
        : pollItems;

    final sources = <Map<String, dynamic>>[
      conversationsPayload,
      pollListPayload,
    ];
    final selectedConversationId =
        omnichannelFirstMappedFromSources<int>(sources, const <String>[
          'conversation_list.selected_conversation_id',
          'selected_conversation_id',
          'meta.selected_conversation_id',
        ], omnichannelInt) ??
        _resolveSelectedConversationId(preferredConversationId, items);

    return OmnichannelConversationListModel(
      items: items,
      page:
          omnichannelFirstMappedFromSources<int>(sources, const <String>[
            'conversation_list.page',
            'conversation_list.current_page',
            'pagination.current_page',
            'meta.current_page',
            'page',
          ], omnichannelInt) ??
          1,
      perPage:
          omnichannelFirstMappedFromSources<int>(sources, const <String>[
            'conversation_list.per_page',
            'pagination.per_page',
            'meta.per_page',
            'per_page',
          ], omnichannelInt) ??
          items.length,
      total:
          omnichannelFirstMappedFromSources<int>(sources, const <String>[
            'conversation_list.total',
            'pagination.total',
            'meta.total',
            'total',
          ], omnichannelInt) ??
          items.length,
      selectedConversationId: selectedConversationId,
    );
  }

  OmnichannelConversationListModel copyWith({
    List<OmnichannelConversationListItemModel>? items,
    int? page,
    int? perPage,
    int? total,
    int? selectedConversationId,
  }) {
    return OmnichannelConversationListModel(
      items: items ?? this.items,
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      total: total ?? this.total,
      selectedConversationId:
          selectedConversationId ?? this.selectedConversationId,
    );
  }

  OmnichannelConversationListModel mergePoll(
    OmnichannelConversationListModel incoming,
  ) {
    if (incoming.items.isEmpty) {
      return copyWith(
        selectedConversationId:
            incoming.selectedConversationId ?? selectedConversationId,
      );
    }

    return OmnichannelConversationListModel(
      items: _mergeConversationItems(items, incoming.items),
      page: incoming.page > 0 ? incoming.page : page,
      perPage: incoming.perPage > 0 ? incoming.perPage : perPage,
      total: incoming.total > 0 ? incoming.total : total,
      selectedConversationId:
          incoming.selectedConversationId ?? selectedConversationId,
    );
  }

  OmnichannelConversationListModel appendPage(
    OmnichannelConversationListModel incoming,
  ) {
    return OmnichannelConversationListModel(
      items: _appendConversationItems(items, incoming.items),
      page: incoming.page > 0 ? incoming.page : page,
      perPage: incoming.perPage > 0 ? incoming.perPage : perPage,
      total: incoming.total > 0 ? incoming.total : total,
      selectedConversationId: selectedConversationId,
    );
  }
}

class OmnichannelConversationListItemModel {
  const OmnichannelConversationListItemModel({
    required this.id,
    required this.title,
    required this.preview,
    required this.channel,
    required this.statusLabel,
    required this.unreadCount,
    required this.lastActivityAt,
    required this.mergeKey,
    this.customerLabel,
    this.customerPhone,
    this.mergedConversationCount = 1,
  });

  final int id;
  final String title;
  final String preview;
  final String channel;
  final String statusLabel;
  final int unreadCount;
  final DateTime lastActivityAt;
  final String mergeKey;
  final String? customerLabel;
  final String? customerPhone;
  final int mergedConversationCount;

  bool get hasUnread => unreadCount > 0;

  factory OmnichannelConversationListItemModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final customer = omnichannelFirstMap(json, const <String>[
      'customer',
      'customer_profile',
      'profile',
    ]);
    final latestMessage = omnichannelFirstMap(json, const <String>[
      'latest_message',
      'last_message',
    ]);
    final channel =
        omnichannelFirstMapped<String>(json, const <String>[
          'channel',
          'channel_key',
        ], omnichannelString) ??
        'mobile_live_chat';
    final customerLabel = omnichannelFirstMappedFromSources<String>(
      <Map<String, dynamic>>[json, customer],
      const <String>[
        'customer_label',
        'customer_name',
        'name',
        'display_name',
        'display_contact',
        'contact_name',
      ],
      omnichannelString,
    );
    final customerPhone = omnichannelFirstMappedFromSources<String>(
      <Map<String, dynamic>>[json, customer],
      const <String>[
        'customer_phone_e164',
        'phone_e164',
        'display_contact',
      ],
      omnichannelString,
    );
    final statusLabel =
        omnichannelFirstMapped<String>(json, const <String>[
          'status_label',
          'operational_mode_label',
          'status_badge.label',
          'status',
        ], omnichannelString) ??
        'Active';
    final title =
        omnichannelFirstMapped<String>(json, const <String>[
          'title',
          'subject',
        ], omnichannelString) ??
        joinOmnichannelText(<String?>[
          customerLabel,
          channelLabelForOmnichannel(channel),
        ], fallback: channelLabelForOmnichannel(channel));

    return OmnichannelConversationListItemModel(
      id:
          omnichannelFirstMapped<int>(json, const <String>[
            'id',
            'conversation_id',
          ], omnichannelInt) ??
          0,
      title: title,
      preview:
          omnichannelFirstMappedFromSources<String>(
            <Map<String, dynamic>>[json, latestMessage],
            const <String>[
              'preview',
              'last_message_preview',
              'latest_message_preview',
              'message_text',
              'text',
              'body',
            ],
            omnichannelString,
          ) ??
          '-',
      channel: channel,
      statusLabel: humanizeOmnichannelKey(statusLabel),
      unreadCount:
          omnichannelFirstMapped<int>(json, const <String>[
            'unread_count',
            'unread_total',
            'unread',
          ], omnichannelInt) ??
          0,
      lastActivityAt:
          omnichannelFirstMappedFromSources<DateTime>(
            <Map<String, dynamic>>[json, latestMessage],
            const <String>[
              'last_activity_at',
              'last_message_at',
              'updated_at',
              'sent_at',
              'created_at',
              'started_at',
            ],
            omnichannelDateTime,
          ) ??
          DateTime.now(),
      mergeKey:
          omnichannelFirstMapped<String>(json, const <String>[
            'merge_key',
          ], omnichannelString) ??
          _fallbackMergeKey(channel, customerPhone, customerLabel, title),
      customerLabel: customerLabel,
      customerPhone: customerPhone,
      mergedConversationCount:
          omnichannelFirstMapped<int>(json, const <String>[
            'merged_conversation_count',
          ], omnichannelInt) ??
          1,
    );
  }
}

List<OmnichannelConversationListItemModel> _parseItems(
  Map<String, dynamic> payload,
) {
  final container = omnichannelFirstMap(payload, const <String>[
    'conversation_list',
    'list',
  ]);
  final items = omnichannelFirstMapList(
    container.isEmpty ? payload : container,
    const <String>['items', 'data', 'conversations'],
  );
  final fallbackItems = items.isEmpty
      ? omnichannelFirstMapList(payload, const <String>[
          'conversations',
          'items',
          'data',
        ])
      : items;

  return _dedupeConversationItems(
    fallbackItems
        .map(OmnichannelConversationListItemModel.fromJson)
        .where((item) => item.id > 0)
        .toList(),
  );
}

List<OmnichannelConversationListItemModel> _mergeConversationItems(
  List<OmnichannelConversationListItemModel> primary,
  List<OmnichannelConversationListItemModel> fallback,
) {
  if (fallback.isEmpty) {
    return _dedupeConversationItems(primary);
  }

  final merged = <String, OmnichannelConversationListItemModel>{
    for (final item in primary) item.mergeKey: item,
  };

  for (final item in fallback) {
    final existing = merged[item.mergeKey];
    if (existing == null ||
        item.lastActivityAt.millisecondsSinceEpoch >=
            existing.lastActivityAt.millisecondsSinceEpoch) {
      merged[item.mergeKey] = item;
    }
  }

  return _dedupeConversationItems(merged.values.toList())
    ..sort(
      (left, right) => right.lastActivityAt.millisecondsSinceEpoch.compareTo(
        left.lastActivityAt.millisecondsSinceEpoch,
      ),
    );
}

List<OmnichannelConversationListItemModel> _appendConversationItems(
  List<OmnichannelConversationListItemModel> current,
  List<OmnichannelConversationListItemModel> incoming,
) {
  if (incoming.isEmpty) {
    return _dedupeConversationItems(current);
  }

  final merged = <String, OmnichannelConversationListItemModel>{
    for (final item in current) item.mergeKey: item,
  };

  for (final item in incoming) {
    final existing = merged[item.mergeKey];
    if (existing == null ||
        item.lastActivityAt.millisecondsSinceEpoch >=
            existing.lastActivityAt.millisecondsSinceEpoch) {
      merged[item.mergeKey] = item;
    }
  }

  return _dedupeConversationItems(merged.values.toList())
    ..sort(
      (left, right) => right.lastActivityAt.millisecondsSinceEpoch.compareTo(
        left.lastActivityAt.millisecondsSinceEpoch,
      ),
    );
}

List<OmnichannelConversationListItemModel> _dedupeConversationItems(
  List<OmnichannelConversationListItemModel> items,
) {
  final deduped = <String, OmnichannelConversationListItemModel>{};

  for (final item in items) {
    final existing = deduped[item.mergeKey];
    if (existing == null ||
        item.lastActivityAt.millisecondsSinceEpoch >=
            existing.lastActivityAt.millisecondsSinceEpoch) {
      deduped[item.mergeKey] = item;
    }
  }

  return deduped.values.toList()
    ..sort(
      (left, right) => right.lastActivityAt.millisecondsSinceEpoch.compareTo(
        left.lastActivityAt.millisecondsSinceEpoch,
      ),
    );
}

int? _resolveSelectedConversationId(
  int? preferredConversationId,
  List<OmnichannelConversationListItemModel> items,
) {
  if (preferredConversationId != null &&
      items.any((item) => item.id == preferredConversationId)) {
    return preferredConversationId;
  }

  return items.isEmpty ? null : items.first.id;
}

String _fallbackMergeKey(
  String channel,
  String? customerPhone,
  String? customerLabel,
  String title,
) {
  final phone = (customerPhone ?? '').trim();
  if (channel == 'whatsapp' && phone.isNotEmpty) {
    return 'whatsapp:phone:${phone.toLowerCase()}';
  }

  final label = (customerLabel ?? title).trim();
  return '$channel:${label.toLowerCase()}';
}
