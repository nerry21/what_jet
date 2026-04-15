import 'omnichannel_call_daily_trend_item_model.dart';
import 'omnichannel_call_history_item_model.dart';
import 'omnichannel_call_outcome_item_model.dart';
import 'omnichannel_payload_parser.dart';

class OmnichannelCallCapabilityModel {
  const OmnichannelCallCapabilityModel({
    required this.supportsLiveAudio,
    required this.supportsCallRecording,
    required this.supportsCallTransfer,
    required this.supportsAgentPickup,
    required this.supportsWebrtcSignaling,
  });

  final bool supportsLiveAudio;
  final bool supportsCallRecording;
  final bool supportsCallTransfer;
  final bool supportsAgentPickup;
  final bool supportsWebrtcSignaling;

  factory OmnichannelCallCapabilityModel.fromJson(Map<String, dynamic> json) {
    return OmnichannelCallCapabilityModel(
      supportsLiveAudio:
          omnichannelFirstMapped<bool>(json, const <String>[
            'supports_live_audio',
          ], omnichannelBool) ??
          false,
      supportsCallRecording:
          omnichannelFirstMapped<bool>(json, const <String>[
            'supports_call_recording',
          ], omnichannelBool) ??
          false,
      supportsCallTransfer:
          omnichannelFirstMapped<bool>(json, const <String>[
            'supports_call_transfer',
          ], omnichannelBool) ??
          false,
      supportsAgentPickup:
          omnichannelFirstMapped<bool>(json, const <String>[
            'supports_agent_pickup',
          ], omnichannelBool) ??
          false,
      supportsWebrtcSignaling:
          omnichannelFirstMapped<bool>(json, const <String>[
            'supports_webrtc_signaling',
          ], omnichannelBool) ??
          false,
    );
  }
}

class OmnichannelCallAnalyticsSummaryModel {
  const OmnichannelCallAnalyticsSummaryModel({
    required this.totalCalls,
    required this.completedCalls,
    required this.missedCalls,
    required this.rejectedCalls,
    required this.failedCalls,
    required this.cancelledCalls,
    required this.permissionPendingCalls,
    required this.inProgressCalls,
    required this.totalDurationSeconds,
    required this.totalDurationHuman,
    required this.averageDurationSeconds,
    required this.averageDurationHuman,
    required this.completionRate,
    required this.missedRate,
  });

  final int totalCalls;
  final int completedCalls;
  final int missedCalls;
  final int rejectedCalls;
  final int failedCalls;
  final int cancelledCalls;
  final int permissionPendingCalls;
  final int inProgressCalls;
  final int totalDurationSeconds;
  final String totalDurationHuman;
  final int averageDurationSeconds;
  final String averageDurationHuman;
  final double completionRate;
  final double missedRate;

  factory OmnichannelCallAnalyticsSummaryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return OmnichannelCallAnalyticsSummaryModel(
      totalCalls:
          omnichannelFirstMapped<int>(json, const <String>[
            'total_calls',
          ], omnichannelInt) ??
          0,
      completedCalls:
          omnichannelFirstMapped<int>(json, const <String>[
            'completed_calls',
          ], omnichannelInt) ??
          0,
      missedCalls:
          omnichannelFirstMapped<int>(json, const <String>[
            'missed_calls',
          ], omnichannelInt) ??
          0,
      rejectedCalls:
          omnichannelFirstMapped<int>(json, const <String>[
            'rejected_calls',
          ], omnichannelInt) ??
          0,
      failedCalls:
          omnichannelFirstMapped<int>(json, const <String>[
            'failed_calls',
          ], omnichannelInt) ??
          0,
      cancelledCalls:
          omnichannelFirstMapped<int>(json, const <String>[
            'cancelled_calls',
          ], omnichannelInt) ??
          0,
      permissionPendingCalls:
          omnichannelFirstMapped<int>(json, const <String>[
            'permission_pending_calls',
          ], omnichannelInt) ??
          0,
      inProgressCalls:
          omnichannelFirstMapped<int>(json, const <String>[
            'in_progress_calls',
          ], omnichannelInt) ??
          0,
      totalDurationSeconds:
          omnichannelFirstMapped<int>(json, const <String>[
            'total_duration_seconds',
          ], omnichannelInt) ??
          0,
      totalDurationHuman:
          omnichannelFirstMapped<String>(json, const <String>[
            'total_duration_human',
          ], omnichannelString) ??
          '0 dtk',
      averageDurationSeconds:
          omnichannelFirstMapped<int>(json, const <String>[
            'average_duration_seconds',
          ], omnichannelInt) ??
          0,
      averageDurationHuman:
          omnichannelFirstMapped<String>(json, const <String>[
            'average_duration_human',
          ], omnichannelString) ??
          '0 dtk',
      completionRate: _doubleValue(json['completion_rate']) ?? 0,
      missedRate: _doubleValue(json['missed_rate']) ?? 0,
    );
  }
}

class OmnichannelCallAnalyticsSnapshotModel {
  const OmnichannelCallAnalyticsSnapshotModel({
    required this.summary,
    required this.outcomeBreakdown,
    required this.dailyTrend,
    required this.recentCalls,
    required this.capabilities,
    required this.futureMetrics,
  });

  final OmnichannelCallAnalyticsSummaryModel summary;
  final List<OmnichannelCallOutcomeItemModel> outcomeBreakdown;
  final List<OmnichannelCallDailyTrendItemModel> dailyTrend;
  final List<OmnichannelCallHistoryItemModel> recentCalls;
  final OmnichannelCallCapabilityModel capabilities;
  final Map<String, dynamic> futureMetrics;

  factory OmnichannelCallAnalyticsSnapshotModel.fromPayload({
    Map<String, dynamic> summaryPayload = const <String, dynamic>{},
    Map<String, dynamic> recentPayload = const <String, dynamic>{},
  }) {
    final summaryJson = omnichannelFirstMap(summaryPayload, const <String>[
      'summary',
    ]);
    final breakdownJson = omnichannelFirstMapList(
      summaryPayload,
      const <String>['outcome_breakdown'],
    );
    final trendJson = omnichannelFirstMapList(summaryPayload, const <String>[
      'daily_trend',
    ]);
    final capabilitiesJson = omnichannelFirstMap(summaryPayload, const <String>[
      'capabilities',
    ]);
    final recentJson = omnichannelFirstMapList(recentPayload, const <String>[
      'recent_calls',
    ]);

    return OmnichannelCallAnalyticsSnapshotModel(
      summary: OmnichannelCallAnalyticsSummaryModel.fromJson(summaryJson),
      outcomeBreakdown: breakdownJson
          .map(OmnichannelCallOutcomeItemModel.fromJson)
          .toList(),
      dailyTrend: trendJson
          .map(OmnichannelCallDailyTrendItemModel.fromJson)
          .toList(),
      recentCalls: recentJson
          .map(OmnichannelCallHistoryItemModel.fromJson)
          .toList(),
      capabilities: OmnichannelCallCapabilityModel.fromJson(capabilitiesJson),
      futureMetrics: omnichannelFirstMap(summaryPayload, const <String>[
        'future_metrics',
      ]),
    );
  }
}

double? _doubleValue(Object? value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '');
}
