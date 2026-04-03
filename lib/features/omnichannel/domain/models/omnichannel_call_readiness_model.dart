class OmnichannelCallReadinessCheck {
  final String key;
  final String label;
  final bool ok;
  final String message;

  const OmnichannelCallReadinessCheck({
    required this.key,
    required this.label,
    required this.ok,
    required this.message,
  });

  factory OmnichannelCallReadinessCheck.fromJson(Map<String, dynamic> json) {
    return OmnichannelCallReadinessCheck(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      ok: json['ok'] == true,
      message: (json['message'] ?? '').toString(),
    );
  }
}

class OmnichannelCallReadinessModel {
  final bool ok;
  final String statusLabel;
  final String statusColor;
  final bool callingEnabled;
  final bool configComplete;
  final bool remoteSettingsOk;
  final bool? remoteCallingEnabled;
  final String? remoteSettingsError;
  final List<String> missing;
  final List<OmnichannelCallReadinessCheck> checks;

  const OmnichannelCallReadinessModel({
    required this.ok,
    required this.statusLabel,
    required this.statusColor,
    required this.callingEnabled,
    required this.configComplete,
    required this.remoteSettingsOk,
    required this.remoteCallingEnabled,
    required this.remoteSettingsError,
    required this.missing,
    required this.checks,
  });

  factory OmnichannelCallReadinessModel.fromJson(Map<String, dynamic> json) {
    final checksRaw = (json['checks'] as List?) ?? const [];
    final missingRaw = (json['missing'] as List?) ?? const [];

    return OmnichannelCallReadinessModel(
      ok: json['ok'] == true,
      statusLabel: ((json['status'] as Map?)?['label'] ?? 'Unknown').toString(),
      statusColor: ((json['status'] as Map?)?['color'] ?? 'red').toString(),
      callingEnabled: json['calling_enabled'] == true,
      configComplete: json['config_complete'] == true,
      remoteSettingsOk: json['remote_settings_ok'] == true,
      remoteCallingEnabled: json['remote_calling_enabled'] is bool
          ? json['remote_calling_enabled'] as bool
          : null,
      remoteSettingsError: json['remote_settings_error']?.toString(),
      missing: missingRaw.map((e) => e.toString()).toList(),
      checks: checksRaw
          .whereType<Map>()
          .map(
            (e) => OmnichannelCallReadinessCheck.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }
}
