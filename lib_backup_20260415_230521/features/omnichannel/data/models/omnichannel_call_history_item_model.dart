import 'omnichannel_payload_parser.dart';

class OmnichannelCallHistoryItemModel {
  const OmnichannelCallHistoryItemModel({
    required this.id,
    required this.conversationId,
    required this.customerLabel,
    required this.customerContact,
    required this.callType,
    required this.status,
    required this.statusLabel,
    required this.finalStatus,
    required this.finalStatusLabel,
    required this.durationSeconds,
    required this.durationHuman,
    required this.startedAt,
    required this.connectedAt,
    required this.endedAt,
    required this.permissionStatus,
    required this.endReason,
    required this.waCallId,
  });

  final int id;
  final int? conversationId;
  final String customerLabel;
  final String customerContact;
  final String callType;
  final String? status;
  final String? statusLabel;
  final String? finalStatus;
  final String? finalStatusLabel;
  final int? durationSeconds;
  final String? durationHuman;
  final String? startedAt;
  final String? connectedAt;
  final String? endedAt;
  final String? permissionStatus;
  final String? endReason;
  final String? waCallId;

  factory OmnichannelCallHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return OmnichannelCallHistoryItemModel(
      id:
          omnichannelFirstMapped<int>(json, const <String>[
            'id',
          ], omnichannelInt) ??
          0,
      conversationId: omnichannelFirstMapped<int>(json, const <String>[
        'conversation_id',
      ], omnichannelInt),
      customerLabel:
          omnichannelFirstMapped<String>(json, const <String>[
            'customer_label',
            'conversation_label',
          ], omnichannelString) ??
          'Customer',
      customerContact:
          omnichannelFirstMapped<String>(json, const <String>[
            'customer_contact',
          ], omnichannelString) ??
          '-',
      callType:
          omnichannelFirstMapped<String>(json, const <String>[
            'call_type',
          ], omnichannelString) ??
          'audio',
      status: omnichannelFirstMapped<String>(json, const <String>[
        'status',
      ], omnichannelString),
      statusLabel: omnichannelFirstMapped<String>(json, const <String>[
        'status_label',
      ], omnichannelString),
      finalStatus: omnichannelFirstMapped<String>(json, const <String>[
        'final_status',
      ], omnichannelString),
      finalStatusLabel: omnichannelFirstMapped<String>(json, const <String>[
        'final_status_label',
        'outcome_label',
      ], omnichannelString),
      durationSeconds: omnichannelFirstMapped<int>(json, const <String>[
        'duration_seconds',
      ], omnichannelInt),
      durationHuman: omnichannelFirstMapped<String>(json, const <String>[
        'duration_human',
      ], omnichannelString),
      startedAt: omnichannelFirstMapped<String>(json, const <String>[
        'started_at',
      ], omnichannelString),
      connectedAt: omnichannelFirstMapped<String>(json, const <String>[
        'connected_at',
        'answered_at',
      ], omnichannelString),
      endedAt: omnichannelFirstMapped<String>(json, const <String>[
        'ended_at',
      ], omnichannelString),
      permissionStatus: omnichannelFirstMapped<String>(json, const <String>[
        'permission_status',
      ], omnichannelString),
      endReason: omnichannelFirstMapped<String>(json, const <String>[
        'end_reason',
        'disconnect_reason_label',
      ], omnichannelString),
      waCallId: omnichannelFirstMapped<String>(json, const <String>[
        'wa_call_id',
      ], omnichannelString),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'conversation_id': conversationId,
      'customer_label': customerLabel,
      'customer_contact': customerContact,
      'call_type': callType,
      'status': status,
      'status_label': statusLabel,
      'final_status': finalStatus,
      'final_status_label': finalStatusLabel,
      'duration_seconds': durationSeconds,
      'duration_human': durationHuman,
      'started_at': startedAt,
      'connected_at': connectedAt,
      'ended_at': endedAt,
      'permission_status': permissionStatus,
      'end_reason': endReason,
      'wa_call_id': waCallId,
    };
  }

  DateTime? get startedAtDateTime => omnichannelDateTime(startedAt);

  DateTime? get endedAtDateTime => omnichannelDateTime(endedAt);
}

class OmnichannelConversationCallHistorySummaryModel {
  const OmnichannelConversationCallHistorySummaryModel({
    required this.totalCalls,
    required this.lastCallStatus,
    required this.lastCallLabel,
    required this.lastCallAt,
    required this.lastCallDurationSeconds,
    required this.lastCallDurationHuman,
  });

  final int totalCalls;
  final String? lastCallStatus;
  final String? lastCallLabel;
  final String? lastCallAt;
  final int? lastCallDurationSeconds;
  final String? lastCallDurationHuman;

  factory OmnichannelConversationCallHistorySummaryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return OmnichannelConversationCallHistorySummaryModel(
      totalCalls:
          omnichannelFirstMapped<int>(json, const <String>[
            'total_calls',
          ], omnichannelInt) ??
          0,
      lastCallStatus: omnichannelFirstMapped<String>(json, const <String>[
        'last_call_status',
      ], omnichannelString),
      lastCallLabel: omnichannelFirstMapped<String>(json, const <String>[
        'last_call_label',
      ], omnichannelString),
      lastCallAt: omnichannelFirstMapped<String>(json, const <String>[
        'last_call_at',
      ], omnichannelString),
      lastCallDurationSeconds: omnichannelFirstMapped<int>(json, const <String>[
        'last_call_duration_seconds',
      ], omnichannelInt),
      lastCallDurationHuman: omnichannelFirstMapped<String>(
        json,
        const <String>['last_call_duration_human'],
        omnichannelString,
      ),
    );
  }
}

class OmnichannelConversationCallHistoryModel {
  const OmnichannelConversationCallHistoryModel({
    required this.summary,
    required this.items,
  });

  final OmnichannelConversationCallHistorySummaryModel summary;
  final List<OmnichannelCallHistoryItemModel> items;

  factory OmnichannelConversationCallHistoryModel.fromPayload(
    Map<String, dynamic> payload,
  ) {
    final summaryJson = omnichannelFirstMap(payload, const <String>[
      'call_history_summary',
    ]);
    final itemsJson = omnichannelFirstMapList(payload, const <String>[
      'call_history',
    ]);

    return OmnichannelConversationCallHistoryModel(
      summary: OmnichannelConversationCallHistorySummaryModel.fromJson(
        summaryJson,
      ),
      items: itemsJson.map(OmnichannelCallHistoryItemModel.fromJson).toList(),
    );
  }
}
