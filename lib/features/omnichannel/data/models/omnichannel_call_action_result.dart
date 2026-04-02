import 'omnichannel_call_session_model.dart';

class OmnichannelCallActionResult {
  const OmnichannelCallActionResult({
    required this.success,
    required this.message,
    required this.callAction,
    required this.permissionRequired,
    required this.callSession,
    required this.metaError,
    required this.raw,
  });

  final bool success;
  final String message;
  final String? callAction;
  final bool permissionRequired;
  final OmnichannelCallSessionModel? callSession;
  final Map<String, dynamic>? metaError;
  final Map<String, dynamic>? raw;

  factory OmnichannelCallActionResult.fromPayload(
    Map<String, dynamic> payload, {
    bool defaultSuccess = true,
    String fallbackMessage = 'Aksi panggilan selesai diproses.',
  }) {
    final callSessionJson = payload['call_session'];
    final metaErrorJson = payload['meta_error'];

    return OmnichannelCallActionResult(
      success: _resultBool(payload['success']) ?? defaultSuccess,
      message: _resultString(payload['message']) ?? fallbackMessage,
      callAction: _resultString(payload['call_action']),
      permissionRequired: _resultBool(payload['permission_required']) ?? false,
      callSession: callSessionJson is Map<String, dynamic>
          ? OmnichannelCallSessionModel.fromJson(callSessionJson)
          : (callSessionJson is Map
                ? OmnichannelCallSessionModel.fromJson(
                    callSessionJson.map(
                      (key, value) => MapEntry(key.toString(), value),
                    ),
                  )
                : null),
      metaError: metaErrorJson is Map<String, dynamic>
          ? metaErrorJson
          : (metaErrorJson is Map
                ? metaErrorJson.map(
                    (key, value) => MapEntry(key.toString(), value),
                  )
                : null),
      raw: payload,
    );
  }
}

String? _resultString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool? _resultBool(Object? value) {
  if (value is bool) {
    return value;
  }

  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }

  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }

  return null;
}
