import 'dart:developer' as developer;

class StatusAnalyticsService {
  const StatusAnalyticsService();

  Future<void> track({
    required String event,
    required Map<String, Object?> params,
  }) async {
    developer.log(
      'STATUS_ANALYTICS',
      name: 'status.analytics',
      error: <String, Object?>{'event': event, 'params': params},
    );
  }
}
