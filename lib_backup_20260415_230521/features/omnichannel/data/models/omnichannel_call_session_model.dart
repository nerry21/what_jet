class OmnichannelCallSessionModel {
  const OmnichannelCallSessionModel({
    required this.id,
    required this.conversationId,
    required this.customerId,
    required this.channel,
    required this.direction,
    required this.callType,
    required this.status,
    required this.waCallId,
    required this.permissionStatus,
    required this.startedAt,
    required this.answeredAt,
    required this.connectedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.durationHuman,
    required this.finalStatus,
    required this.finalStatusLabel,
    required this.endReason,
    required this.endedBy,
    required this.disconnectSource,
    required this.disconnectReasonCode,
    required this.disconnectReasonLabel,
    required this.lastStatusAt,
    required this.isActive,
    required this.isRinging,
    required this.isConnected,
    required this.metaPayload,
    required this.timelineSnapshot,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int? conversationId;
  final int? customerId;
  final String? channel;
  final String? direction;
  final String? callType;
  final String? status;
  final String? waCallId;
  final String? permissionStatus;
  final String? startedAt;
  final String? answeredAt;
  final String? connectedAt;
  final String? endedAt;
  final int? durationSeconds;
  final String? durationHuman;
  final String? finalStatus;
  final String? finalStatusLabel;
  final String? endReason;
  final String? endedBy;
  final String? disconnectSource;
  final String? disconnectReasonCode;
  final String? disconnectReasonLabel;
  final String? lastStatusAt;
  final bool isActive;
  final bool isRinging;
  final bool isConnected;
  final Map<String, dynamic> metaPayload;
  final List<Map<String, dynamic>> timelineSnapshot;
  final String? createdAt;
  final String? updatedAt;

  factory OmnichannelCallSessionModel.fromJson(Map<String, dynamic> json) {
    final status = _stringValue(json['status']);
    final isActive = _boolValue(json['is_active']) ?? _deriveIsActive(status);
    final isRinging =
        _boolValue(json['is_ringing']) ?? _deriveIsRinging(status);
    final isConnected =
        _boolValue(json['is_connected']) ?? (status == 'connected');

    return OmnichannelCallSessionModel(
      id: _intValue(json['id']),
      conversationId: _intValue(json['conversation_id']),
      customerId: _intValue(json['customer_id']),
      channel: _stringValue(json['channel']),
      direction: _stringValue(json['direction']),
      callType: _stringValue(json['call_type']),
      status: status,
      waCallId: _stringValue(json['wa_call_id']),
      permissionStatus: _stringValue(json['permission_status']),
      startedAt: _stringValue(json['started_at']),
      answeredAt: _stringValue(json['answered_at']),
      connectedAt: _stringValue(json['connected_at']),
      endedAt: _stringValue(json['ended_at']),
      durationSeconds: _intValue(json['duration_seconds']),
      durationHuman: _stringValue(json['duration_human']),
      finalStatus: _stringValue(json['final_status']),
      finalStatusLabel: _stringValue(json['final_status_label']),
      endReason: _stringValue(json['end_reason']),
      endedBy: _stringValue(json['ended_by']),
      disconnectSource: _stringValue(json['disconnect_source']),
      disconnectReasonCode: _stringValue(json['disconnect_reason_code']),
      disconnectReasonLabel: _stringValue(json['disconnect_reason_label']),
      lastStatusAt: _stringValue(json['last_status_at']),
      isActive: isActive,
      isRinging: isRinging,
      isConnected: isConnected,
      metaPayload: _mapValue(json['meta_payload']),
      timelineSnapshot: _mapListValue(json['timeline_snapshot']),
      createdAt: _stringValue(json['created_at']),
      updatedAt: _stringValue(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'conversation_id': conversationId,
      'customer_id': customerId,
      'channel': channel,
      'direction': direction,
      'call_type': callType,
      'status': status,
      'wa_call_id': waCallId,
      'permission_status': permissionStatus,
      'started_at': startedAt,
      'answered_at': answeredAt,
      'connected_at': connectedAt,
      'ended_at': endedAt,
      'duration_seconds': durationSeconds,
      'duration_human': durationHuman,
      'final_status': finalStatus,
      'final_status_label': finalStatusLabel,
      'end_reason': endReason,
      'ended_by': endedBy,
      'disconnect_source': disconnectSource,
      'disconnect_reason_code': disconnectReasonCode,
      'disconnect_reason_label': disconnectReasonLabel,
      'last_status_at': lastStatusAt,
      'is_active': isActive,
      'is_ringing': isRinging,
      'is_connected': isConnected,
      'meta_payload': metaPayload,
      'timeline_snapshot': timelineSnapshot,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  bool get isFinished => isRejected || isEnded || isMissed || isFailed;

  bool get requiresPermission =>
      permissionStatus == 'required' ||
      permissionStatus == 'unknown' ||
      permissionStatus == 'denied' ||
      permissionStatus == 'expired' ||
      permissionStatus == 'failed' ||
      permissionStatus == 'rate_limited';

  bool get isPermissionRequested => permissionStatus == 'requested';

  bool get isPermissionDenied => permissionStatus == 'denied';

  bool get isPermissionExpired => permissionStatus == 'expired';

  bool get isPermissionRateLimited => permissionStatus == 'rate_limited';

  bool get isPermissionFailed => permissionStatus == 'failed';

  bool get isFailed => status == 'failed';

  bool get isRejected => status == 'rejected';

  bool get isEnded => status == 'ended';

  bool get isMissed => status == 'missed';

  bool get isCompleted => finalStatus == 'completed';

  bool get isInitiatedLike =>
      status == 'initiated' ||
      status == 'permission_requested' ||
      status == 'ringing' ||
      status == 'connecting';

  DateTime? get createdAtDateTime => _parseDateTime(createdAt);

  DateTime? get updatedAtDateTime => _parseDateTime(updatedAt);

  DateTime? get endedAtDateTime => _parseDateTime(endedAt);

  DateTime? get startedAtDateTime => _parseDateTime(startedAt);

  DateTime? get answeredAtDateTime => _parseDateTime(answeredAt);

  DateTime? get connectedAtDateTime =>
      _parseDateTime(connectedAt) ?? answeredAtDateTime;

  DateTime? get lastStatusAtDateTime => _parseDateTime(lastStatusAt);

  bool isNewerThan(OmnichannelCallSessionModel other) {
    final thisUpdated = lastStatusAtDateTime ?? updatedAtDateTime;
    final otherUpdated = other.lastStatusAtDateTime ?? other.updatedAtDateTime;

    if (thisUpdated != null && otherUpdated != null) {
      return !thisUpdated.isBefore(otherUpdated);
    }

    if (thisUpdated != null) {
      return true;
    }

    if (otherUpdated != null) {
      return false;
    }

    final thisCreated = createdAtDateTime;
    final otherCreated = other.createdAtDateTime;

    if (thisCreated != null && otherCreated != null) {
      return !thisCreated.isBefore(otherCreated);
    }

    if (thisCreated != null) {
      return true;
    }

    if (otherCreated != null) {
      return false;
    }

    final thisId = id ?? -1;
    final otherId = other.id ?? -1;
    return thisId >= otherId;
  }

  static bool _deriveIsActive(String? status) {
    return switch (status) {
      'initiated' ||
      'permission_requested' ||
      'ringing' ||
      'connecting' ||
      'connected' => true,
      _ => false,
    };
  }

  static bool _deriveIsRinging(String? status) {
    return switch (status) {
      'initiated' ||
      'permission_requested' ||
      'ringing' ||
      'connecting' => true,
      _ => false,
    };
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

bool? _boolValue(Object? value) {
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

Map<String, dynamic> _mapValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, entryValue) => MapEntry(key.toString(), entryValue));
  }

  return <String, dynamic>{};
}

List<Map<String, dynamic>> _mapListValue(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }

  return value
      .whereType<Map>()
      .map(
        (item) =>
            item.map((key, entryValue) => MapEntry(key.toString(), entryValue)),
      )
      .toList();
}

DateTime? _parseDateTime(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value)?.toLocal();
}
