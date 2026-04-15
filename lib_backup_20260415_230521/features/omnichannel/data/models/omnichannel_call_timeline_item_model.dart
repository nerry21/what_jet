class OmnichannelCallTimelineItemModel {
  const OmnichannelCallTimelineItemModel({
    required this.type,
    required this.event,
    required this.label,
    required this.callSessionId,
    required this.callType,
    required this.status,
    required this.endReason,
    required this.timestamp,
  });

  final String type;
  final String? event;
  final String? label;
  final int? callSessionId;
  final String? callType;
  final String? status;
  final String? endReason;
  final String? timestamp;

  factory OmnichannelCallTimelineItemModel.fromJson(Map<String, dynamic> json) {
    return OmnichannelCallTimelineItemModel(
      type: _stringValue(json['type']) ?? 'call_event',
      event: _stringValue(json['event']),
      label: _stringValue(json['label']),
      callSessionId: _intValue(json['call_session_id']),
      callType: _stringValue(json['call_type']),
      status: _stringValue(json['status']),
      endReason: _stringValue(json['end_reason']),
      timestamp: _stringValue(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'event': event,
      'label': label,
      'call_session_id': callSessionId,
      'call_type': callType,
      'status': status,
      'end_reason': endReason,
      'timestamp': timestamp,
    };
  }

  DateTime? get timestampDateTime => _parseDateTime(timestamp);

  bool get isTerminal {
    final normalized = _normalizedEventOrStatus;
    return normalized == 'ended' ||
        normalized == 'failed' ||
        normalized == 'rejected' ||
        normalized == 'missed';
  }

  String get stableKey {
    return <String>[
      type.trim(),
      event?.trim() ?? '',
      status?.trim() ?? '',
      callSessionId?.toString() ?? '',
      endReason?.trim() ?? '',
      timestamp?.trim() ?? '',
    ].join('|');
  }

  bool isNewerThan(OmnichannelCallTimelineItemModel other) {
    final thisTimestamp = timestampDateTime;
    final otherTimestamp = other.timestampDateTime;

    if (thisTimestamp != null && otherTimestamp != null) {
      return !thisTimestamp.isBefore(otherTimestamp);
    }

    if (thisTimestamp != null) {
      return true;
    }

    if (otherTimestamp != null) {
      return false;
    }

    final thisSessionId = callSessionId ?? -1;
    final otherSessionId = other.callSessionId ?? -1;
    if (thisSessionId != otherSessionId) {
      return thisSessionId >= otherSessionId;
    }

    return stableKey.compareTo(other.stableKey) >= 0;
  }

  String? get _normalizedEventOrStatus {
    final candidate = event?.trim().isNotEmpty == true ? event : status;
    final normalized = candidate?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized.replaceAll('-', '_').replaceAll(' ', '_');
  }
}

String? _stringValue(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '');
}

DateTime? _parseDateTime(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value)?.toLocal();
}
