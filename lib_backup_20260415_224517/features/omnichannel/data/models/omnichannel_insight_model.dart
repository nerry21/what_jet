import 'omnichannel_conversation_detail_model.dart';
import 'omnichannel_payload_parser.dart';

class OmnichannelInsightModel {
  const OmnichannelInsightModel({
    required this.customerName,
    required this.customerContact,
    required this.customerTags,
    required this.conversationTags,
    required this.quickDetails,
    required this.noteLines,
  });

  final String customerName;
  final String customerContact;
  final List<String> customerTags;
  final List<String> conversationTags;
  final Map<String, String> quickDetails;
  final List<String> noteLines;

  factory OmnichannelInsightModel.fromSources({
    required Map<String, dynamic> detailPayload,
    required Map<String, dynamic> messagesPayload,
    Map<String, dynamic> pollPayload = const <String, dynamic>{},
    OmnichannelConversationDetailModel? conversation,
  }) {
    final candidates = <Map<String, dynamic>>[
      omnichannelFirstMap(detailPayload, const <String>[
        'insight_pane',
        'insight',
        'profile',
      ]),
      omnichannelFirstMap(pollPayload, const <String>[
        'insight_pane',
        'insight',
        'profile',
      ]),
      detailPayload,
      pollPayload,
      messagesPayload,
    ].where((map) => map.isNotEmpty).toList();
    final customer = omnichannelFirstMapFromSources(candidates, const <String>[
      'customer',
      'customer_profile',
      'profile',
    ]);

    return OmnichannelInsightModel(
      customerName:
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
          conversation?.customerName ??
          'Belum ada percakapan',
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
          conversation?.customerContact ??
          '-',
      customerTags: _parseTags(candidates, const <String>[
        'customer_tags',
        'profile.customer_tags',
        'tags.customer',
      ]),
      conversationTags: _parseTags(candidates, const <String>[
        'conversation_tags',
        'profile.conversation_tags',
        'tags.conversation',
      ]),
      quickDetails: _parseQuickDetails(candidates, conversation),
      noteLines: _parseNotes(candidates),
    );
  }

  factory OmnichannelInsightModel.empty() {
    return const OmnichannelInsightModel(
      customerName: 'Belum ada percakapan',
      customerContact: '-',
      customerTags: <String>[],
      conversationTags: <String>[],
      quickDetails: <String, String>{},
      noteLines: <String>[],
    );
  }

  OmnichannelInsightModel mergeWith(OmnichannelInsightModel other) {
    return OmnichannelInsightModel(
      customerName: other.customerName != 'Belum ada percakapan'
          ? other.customerName
          : customerName,
      customerContact: other.customerContact != '-'
          ? other.customerContact
          : customerContact,
      customerTags: other.customerTags.isNotEmpty
          ? other.customerTags
          : customerTags,
      conversationTags: other.conversationTags.isNotEmpty
          ? other.conversationTags
          : conversationTags,
      quickDetails: other.quickDetails.isNotEmpty
          ? other.quickDetails
          : quickDetails,
      noteLines: other.noteLines.isNotEmpty ? other.noteLines : noteLines,
    );
  }
}

List<String> _parseTags(
  List<Map<String, dynamic>> candidates,
  List<String> paths,
) {
  final tagObjects = omnichannelFirstMapListFromSources(candidates, paths);
  if (tagObjects.isNotEmpty) {
    return tagObjects
        .map(
          (tag) =>
              omnichannelFirstMapped<String>(tag, const <String>[
                'label',
                'name',
                'title',
                'value',
              ], omnichannelString) ??
              '',
        )
        .where((tag) => tag.trim().isNotEmpty)
        .toList();
  }

  return omnichannelFirstMappedFromSources<List<String>>(candidates, paths, (
        value,
      ) {
        final tags = omnichannelStringList(value);
        return tags.isEmpty ? null : tags;
      }) ??
      const <String>[];
}

Map<String, String> _parseQuickDetails(
  List<Map<String, dynamic>> candidates,
  OmnichannelConversationDetailModel? conversation,
) {
  final detailMap = omnichannelFirstMapFromSources(candidates, const <String>[
    'quick_details',
    'details',
    'summary',
  ]);

  if (detailMap.isNotEmpty) {
    final mapped = <String, String>{};
    for (final entry in detailMap.entries) {
      final value = omnichannelString(entry.value);
      if (value == null) {
        continue;
      }
      mapped[humanizeOmnichannelKey(entry.key)] = value;
    }

    if (mapped.isNotEmpty) {
      return mapped;
    }
  }

  if (conversation == null) {
    return const <String, String>{};
  }

  return <String, String>{
    'Channel': channelLabelForOmnichannel(conversation.channel),
    'Status': conversation.statusLabel,
    'Mode': conversation.operationalModeLabel,
    'Customer': conversation.customerName,
  };
}

List<String> _parseNotes(List<Map<String, dynamic>> candidates) {
  final noteObjects = omnichannelFirstMapListFromSources(
    candidates,
    const <String>['note_lines', 'notes', 'insight_notes'],
  );

  if (noteObjects.isNotEmpty) {
    return noteObjects
        .map(
          (note) =>
              omnichannelFirstMapped<String>(note, const <String>[
                'text',
                'label',
                'message',
                'title',
              ], omnichannelString) ??
              '',
        )
        .where((note) => note.trim().isNotEmpty)
        .toList();
  }

  return omnichannelFirstMappedFromSources<List<String>>(
        candidates,
        const <String>['note_lines', 'notes', 'insight_notes'],
        (value) {
          final notes = omnichannelStringList(value);
          return notes.isEmpty ? null : notes;
        },
      ) ??
      const <String>[];
}
