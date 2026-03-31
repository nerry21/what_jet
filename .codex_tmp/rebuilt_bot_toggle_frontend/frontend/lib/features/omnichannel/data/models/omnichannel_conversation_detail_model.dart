import 'omnichannel_payload_parser.dart';

class OmnichannelConversationDetailModel {
  const OmnichannelConversationDetailModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.channel,
    required this.customerName,
    required this.customerContact,
    required this.statusLabel,
    required this.operationalModeLabel,
    required this.badges,
    required this.isBotEnabled,
    required this.isHumanTakeover,
    required this.botAutoResumeAt,
    required this.botAutoResumeEnabled,
  });

  final int id;
  final String title;
  final String subtitle;
  final String channel;
  final String customerName;
  final String customerContact;
  final String statusLabel;
  final String operationalModeLabel;
  final List<String> badges;
  final bool isBotEnabled;
  final bool isHumanTakeover;
  final String? botAutoResumeAt;
  final bool botAutoResumeEnabled;

  factory OmnichannelConversationDetailModel.fromSources({
    required Map<String, dynamic> detailPayload,
    Map<String, dynamic> pollPayload = const <String, dynamic>{},
  }) {
    final candidates = <Map<String, dynamic>>[
      omnichannelFirstMap(detailPayload, const <String>[
        'selected_conversation',
        'conversation',
        'detail',
      ]),
      omnichannelFirstMap(pollPayload, const <String>[
        'selected_conversation',
        'conversation',
        'detail',
      ]),
      detailPayload,
      pollPayload,
    ].where((map) => map.isNotEmpty).toList();

    if (candidates.isEmpty) {
      return const OmnichannelConversationDetailModel(
        id: 0,
        title: 'Belum ada conversation',
        subtitle: '',
        channel: 'mobile_live_chat',
        customerName: 'Customer',
        customerContact: '-',
        statusLabel: 'Active',
        operationalModeLabel: 'Inbox',
        badges: <String>[],
        isBotEnabled: true,
        isHumanTakeover: false,
        botAutoResumeAt: null,
        botAutoResumeEnabled: false,
      );
    }

    final customer = omnichannelFirstMapFromSources(candidates, const <String>[
      'customer',
      'customer_profile',
      'profile',
    ]);
    final latestMessage = omnichannelFirstMapFromSources(
      candidates,
      const <String>['latest_message', 'last_message'],
    );
    final channel =
        omnichannelFirstMappedFromSources<String>(candidates, const <String>[
          'channel',
          'channel_key',
        ], omnichannelString) ??
        'mobile_live_chat';
    final customerName =
        omnichannelFirstMappedFromSources<String>(
          <Map<String, dynamic>>[...candidates, customer],
          const <String>[
            'customer_name',
            'name',
            'display_name',
            'display_contact',
            'contact_name',
          ],
          omnichannelString,
        ) ??
        'Customer';
    final statusLabel =
        omnichannelFirstMappedFromSources<String>(candidates, const <String>[
          'status_label',
          'status_badge.label',
          'status',
        ], omnichannelString) ??
        'Active';
    final operationalModeLabel =
        omnichannelFirstMappedFromSources<String>(candidates, const <String>[
          'operational_mode_label',
          'mode_label',
          'mode',
          'source_label',
        ], omnichannelString) ??
        'Inbox';

    return OmnichannelConversationDetailModel(
      id:
          omnichannelFirstMappedFromSources<int>(candidates, const <String>[
            'id',
            'conversation_id',
          ], omnichannelInt) ??
          0,
      title:
          omnichannelFirstMappedFromSources<String>(candidates, const <String>[
            'title',
            'subject',
          ], omnichannelString) ??
          joinOmnichannelText(<String?>[
            customerName,
            channelLabelForOmnichannel(channel),
          ], fallback: customerName),
      subtitle:
          omnichannelFirstMappedFromSources<String>(
            <Map<String, dynamic>>[...candidates, latestMessage],
            const <String>[
              'subtitle',
              'latest_message_preview',
              'last_message_preview',
              'message_text',
              'text',
              'body',
              'source_label',
            ],
            omnichannelString,
          ) ??
          operationalModeLabel,
      channel: channel,
      customerName: customerName,
      customerContact:
          omnichannelFirstMappedFromSources<String>(
            <Map<String, dynamic>>[...candidates, customer],
            const <String>[
              'customer_contact',
              'email',
              'phone',
              'display_contact',
            ],
            omnichannelString,
          ) ??
          '-',
      statusLabel: humanizeOmnichannelKey(statusLabel),
      operationalModeLabel: humanizeOmnichannelKey(operationalModeLabel),
      badges: _parseBadges(
        candidates,
        channel,
        statusLabel,
        operationalModeLabel,
      ),
      isBotEnabled: omnichannelFirstMappedFromSources<bool>(candidates, const <String>[
            'bot_control.enabled',
            'bot_enabled',
          ], omnichannelBool) ??
          (!(omnichannelFirstMappedFromSources<bool>(candidates, const <String>[
                'is_admin_takeover',
                'bot_control.human_takeover',
              ], omnichannelBool) ?? false)),
      isHumanTakeover: omnichannelFirstMappedFromSources<bool>(candidates, const <String>[
            'bot_control.human_takeover',
            'is_admin_takeover',
          ], omnichannelBool) ?? false,
      botAutoResumeAt: omnichannelFirstMappedFromSources<String>(candidates, const <String>[
        'bot_control.auto_resume_at',
        'bot_auto_resume_at',
      ], omnichannelString),
      botAutoResumeEnabled: omnichannelFirstMappedFromSources<bool>(candidates, const <String>[
            'bot_control.auto_resume_enabled',
            'bot_auto_resume_enabled',
          ], omnichannelBool) ?? false,
    );
  }

  OmnichannelConversationDetailModel mergeWith(
    OmnichannelConversationDetailModel other,
  ) {
    if (other.id <= 0) {
      return this;
    }

    return OmnichannelConversationDetailModel(
      id: other.id,
      title: other.title.trim().isNotEmpty ? other.title : title,
      subtitle: other.subtitle.trim().isNotEmpty ? other.subtitle : subtitle,
      channel: other.channel.trim().isNotEmpty ? other.channel : channel,
      customerName: other.customerName.trim().isNotEmpty
          ? other.customerName
          : customerName,
      customerContact: other.customerContact.trim().isNotEmpty &&
              other.customerContact != '-'
          ? other.customerContact
          : customerContact,
      statusLabel: other.statusLabel.trim().isNotEmpty
          ? other.statusLabel
          : statusLabel,
      operationalModeLabel: other.operationalModeLabel.trim().isNotEmpty
          ? other.operationalModeLabel
          : operationalModeLabel,
      badges: other.badges.isNotEmpty ? other.badges : badges,
      isBotEnabled: other.id > 0 ? other.isBotEnabled : isBotEnabled,
      isHumanTakeover: other.id > 0 ? other.isHumanTakeover : isHumanTakeover,
      botAutoResumeAt: other.botAutoResumeAt ?? botAutoResumeAt,
      botAutoResumeEnabled: other.id > 0 ? other.botAutoResumeEnabled : botAutoResumeEnabled,
    );
  }
}

List<String> _parseBadges(
  List<Map<String, dynamic>> candidates,
  String channel,
  String statusLabel,
  String operationalModeLabel,
) {
  final badgeObjects = omnichannelFirstMapListFromSources(
    candidates,
    const <String>['badges', 'chips', 'labels'],
  );
  final badges = badgeObjects
      .map(
        (badge) =>
            omnichannelFirstMapped<String>(badge, const <String>[
              'label',
              'name',
              'title',
              'value',
            ], omnichannelString) ??
            '',
      )
      .where((badge) => badge.trim().isNotEmpty)
      .map(humanizeOmnichannelKey)
      .toList();

  if (badges.isNotEmpty) {
    return badges;
  }

  return <String>[
    channelLabelForOmnichannel(channel),
    humanizeOmnichannelKey(statusLabel),
    humanizeOmnichannelKey(operationalModeLabel),
  ].where((item) => item.trim().isNotEmpty).toList();
}
