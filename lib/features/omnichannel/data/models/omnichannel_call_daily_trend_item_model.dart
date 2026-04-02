import 'omnichannel_payload_parser.dart';

class OmnichannelCallDailyTrendItemModel {
  const OmnichannelCallDailyTrendItemModel({
    required this.date,
    required this.totalCalls,
    required this.completedCalls,
    required this.missedCalls,
    required this.failedCalls,
    required this.totalDurationSeconds,
  });

  final String date;
  final int totalCalls;
  final int completedCalls;
  final int missedCalls;
  final int failedCalls;
  final int totalDurationSeconds;

  factory OmnichannelCallDailyTrendItemModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return OmnichannelCallDailyTrendItemModel(
      date:
          omnichannelFirstMapped<String>(
            json,
            const <String>['date'],
            omnichannelString,
          ) ??
          '',
      totalCalls:
          omnichannelFirstMapped<int>(
            json,
            const <String>['total_calls'],
            omnichannelInt,
          ) ??
          0,
      completedCalls:
          omnichannelFirstMapped<int>(
            json,
            const <String>['completed_calls'],
            omnichannelInt,
          ) ??
          0,
      missedCalls:
          omnichannelFirstMapped<int>(
            json,
            const <String>['missed_calls'],
            omnichannelInt,
          ) ??
          0,
      failedCalls:
          omnichannelFirstMapped<int>(
            json,
            const <String>['failed_calls'],
            omnichannelInt,
          ) ??
          0,
      totalDurationSeconds:
          omnichannelFirstMapped<int>(
            json,
            const <String>['total_duration_seconds'],
            omnichannelInt,
          ) ??
          0,
    );
  }
}
