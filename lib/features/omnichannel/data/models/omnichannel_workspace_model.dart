import 'omnichannel_payload_parser.dart';

class OmnichannelWorkspaceModel {
  const OmnichannelWorkspaceModel({
    required this.unreadTotal,
    required this.activeConversations,
    required this.filters,
    required this.channels,
  });

  final int unreadTotal;
  final int activeConversations;
  final List<OmnichannelFilterOptionModel> filters;
  final List<OmnichannelFilterOptionModel> channels;

  factory OmnichannelWorkspaceModel.fromSources({
    Map<String, dynamic> workspacePayload = const <String, dynamic>{},
    Map<String, dynamic> summaryPayload = const <String, dynamic>{},
    Map<String, dynamic> filtersPayload = const <String, dynamic>{},
    Map<String, dynamic> pollListPayload = const <String, dynamic>{},
  }) {
    final sources = <Map<String, dynamic>>[
      workspacePayload,
      summaryPayload,
      filtersPayload,
      pollListPayload,
    ];

    final filters = _parseFilterOptions(
      sources,
      const <String>[
        'filters.scopes',
        'meta.filters.scopes',
        'workspace.filters.scopes',
        'workspace.scopes',
        'scope_filters',
        'scopes',
        'filters',
      ],
      fallback: const <OmnichannelFilterOptionModel>[
        OmnichannelFilterOptionModel(key: 'all', label: 'Semua'),
        OmnichannelFilterOptionModel(key: 'unread', label: 'Belum Dibaca'),
        OmnichannelFilterOptionModel(key: 'bot_active', label: 'Bot Active'),
        OmnichannelFilterOptionModel(key: 'human_takeover', label: 'Takeover'),
      ],
    );
    final channels = _parseFilterOptions(
      sources,
      const <String>[
        'filters.channels',
        'meta.filters.channels',
        'workspace.filters.channels',
        'workspace.channels',
        'channel_filters',
        'channels',
      ],
      fallback: const <OmnichannelFilterOptionModel>[
        OmnichannelFilterOptionModel(key: 'all', label: 'Semua Channel'),
        OmnichannelFilterOptionModel(key: 'whatsapp', label: 'WhatsApp'),
        OmnichannelFilterOptionModel(
          key: 'mobile_live_chat',
          label: 'Live Chat',
        ),
      ],
    );

    return OmnichannelWorkspaceModel(
      unreadTotal:
          omnichannelFirstMappedFromSources<int>(sources, const <String>[
            'summary.unread_total',
            'summary_counts.unread_total',
            'counts.unread_total',
            'workspace.unread_total',
            'unread_total',
            'totals.unread',
          ], omnichannelInt) ??
          _countFromFilters(filters, 'unread'),
      activeConversations:
          omnichannelFirstMappedFromSources<int>(sources, const <String>[
            'summary.active_conversations',
            'summary.active_total',
            'summary_counts.active_conversations',
            'summary_counts.active_total',
            'counts.active_conversations',
            'workspace.active_conversations',
            'active_conversations',
            'totals.active',
          ], omnichannelInt) ??
          _countFromFilters(filters, 'all'),
      filters: filters,
      channels: channels,
    );
  }

  factory OmnichannelWorkspaceModel.placeholder() {
    return const OmnichannelWorkspaceModel(
      unreadTotal: 9,
      activeConversations: 24,
      filters: <OmnichannelFilterOptionModel>[
        OmnichannelFilterOptionModel(key: 'all', label: 'Semua', count: 24),
        OmnichannelFilterOptionModel(
          key: 'unread',
          label: 'Belum Dibaca',
          count: 9,
        ),
        OmnichannelFilterOptionModel(
          key: 'bot_active',
          label: 'Bot Active',
          count: 7,
        ),
        OmnichannelFilterOptionModel(
          key: 'human_takeover',
          label: 'Takeover',
          count: 4,
        ),
      ],
      channels: <OmnichannelFilterOptionModel>[
        OmnichannelFilterOptionModel(
          key: 'all',
          label: 'Semua Channel',
          count: 24,
        ),
        OmnichannelFilterOptionModel(
          key: 'whatsapp',
          label: 'WhatsApp',
          count: 16,
        ),
        OmnichannelFilterOptionModel(
          key: 'mobile_live_chat',
          label: 'Live Chat',
          count: 8,
        ),
      ],
    );
  }

  OmnichannelWorkspaceModel copyWith({
    int? unreadTotal,
    int? activeConversations,
    List<OmnichannelFilterOptionModel>? filters,
    List<OmnichannelFilterOptionModel>? channels,
  }) {
    return OmnichannelWorkspaceModel(
      unreadTotal: unreadTotal ?? this.unreadTotal,
      activeConversations: activeConversations ?? this.activeConversations,
      filters: filters ?? this.filters,
      channels: channels ?? this.channels,
    );
  }

  OmnichannelWorkspaceModel mergeWith(OmnichannelWorkspaceModel other) {
    return OmnichannelWorkspaceModel(
      unreadTotal: other.unreadTotal > 0 ? other.unreadTotal : unreadTotal,
      activeConversations: other.activeConversations > 0
          ? other.activeConversations
          : activeConversations,
      filters: other.filters.isNotEmpty ? other.filters : filters,
      channels: other.channels.isNotEmpty ? other.channels : channels,
    );
  }
}

class OmnichannelFilterOptionModel {
  const OmnichannelFilterOptionModel({
    required this.key,
    required this.label,
    this.count = 0,
  });

  final String key;
  final String label;
  final int count;

  factory OmnichannelFilterOptionModel.fromJson(Map<String, dynamic> json) {
    final key =
        omnichannelFirstMapped<String>(json, const <String>[
          'key',
          'value',
          'id',
          'scope',
          'channel',
        ], omnichannelString) ??
        'all';

    return OmnichannelFilterOptionModel(
      key: key,
      label:
          omnichannelFirstMapped<String>(json, const <String>[
            'label',
            'name',
            'title',
          ], omnichannelString) ??
          humanizeOmnichannelKey(key),
      count:
          omnichannelFirstMapped<int>(json, const <String>[
            'count',
            'total',
            'value_count',
          ], omnichannelInt) ??
          0,
    );
  }
}

List<OmnichannelFilterOptionModel> _parseFilterOptions(
  List<Map<String, dynamic>> sources,
  List<String> paths, {
  required List<OmnichannelFilterOptionModel> fallback,
}) {
  final candidates = omnichannelFirstMapListFromSources(
    sources,
    paths,
  ).map(OmnichannelFilterOptionModel.fromJson).toList();

  return candidates.isEmpty ? fallback : candidates;
}

int _countFromFilters(List<OmnichannelFilterOptionModel> filters, String key) {
  for (final filter in filters) {
    if (filter.key == key) {
      return filter.count;
    }
  }

  return 0;
}
