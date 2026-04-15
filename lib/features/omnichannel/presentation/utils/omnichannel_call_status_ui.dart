import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/omnichannel_call_session_model.dart';
import '../../data/models/omnichannel_call_timeline_item_model.dart';

String omnichannelCallPrimaryStatusText(OmnichannelCallSessionModel? session) {
  if (session == null) {
    return 'Status panggilan belum tersedia';
  }

  if (session.isPermissionRequested) {
    return 'Meminta izin panggilan...';
  }

  if (session.isPermissionRateLimited) {
    return 'Layanan panggilan dibatasi sementara';
  }

  if (session.isPermissionDenied) {
    return 'Izin panggilan ditolak';
  }

  return switch (session.status) {
    'initiated' => 'Memanggil...',
    'ringing' => 'Berdering...',
    'connecting' => 'Menyambungkan...',
    'connected' => 'Tersambung',
    'rejected' => 'Panggilan ditolak',
    'missed' => 'Tidak dijawab',
    'ended' => 'Panggilan berakhir',
    'failed' => 'Panggilan gagal',
    _ when session.requiresPermission => 'Izin panggilan dibutuhkan',
    _ => 'Menunggu status panggilan',
  };
}

String omnichannelCallSecondaryStatusText(
  OmnichannelCallSessionModel? session,
) {
  if (session == null) {
    return 'Server belum mengirim call_session untuk percakapan ini.';
  }

  if (session.isPermissionRequested) {
    return 'Permintaan izin sudah dikirim. Status panggilan akan terus dipantau dari server.';
  }

  if (session.isPermissionRateLimited) {
    return 'Server menahan permintaan izin baru untuk sementara agar tidak terkena throttling tambahan dari Meta.';
  }

  if (session.isPermissionDenied) {
    return 'Pengguna belum memberikan izin panggilan. Backend tidak akan memulai panggilan sampai izin tersedia.';
  }

  if (session.isPermissionExpired) {
    return 'Izin panggilan sebelumnya sudah kedaluwarsa dan perlu diminta ulang.';
  }

  if (session.isPermissionFailed) {
    return 'Backend menandai konfigurasi atau proses permission call belum siap untuk request ini.';
  }

  if (session.requiresPermission) {
    return 'Panggilan bisnis belum bisa dimulai sampai izin pengguna tersedia.';
  }

  if (session.isRinging || session.isInitiatedLike) {
    return 'Signaling panggilan sedang diproses. Tunggu pembaruan status dari backend.';
  }

  if (session.isConnected) {
    return 'Backend menerima status terhubung. Ketersediaan audio live tetap mengikuti layer media pada build ini.';
  }

  if (session.endReason?.trim().isNotEmpty ?? false) {
    return 'Alasan akhir: ${omnichannelCallEndReasonLabel(session.endReason)}';
  }

  final status = _normalizeText(session.status);
  if (status != null) {
    return 'Status backend: ${humanizeStatusLabel(status)}';
  }

  return 'Menunggu sinkronisasi status dari backend.';
}

String omnichannelCallPermissionLabel(String? permissionStatus) {
  final normalized = _normalizeToken(permissionStatus);
  if (normalized == null) {
    return '-';
  }

  return switch (normalized) {
    'unknown' => 'Belum diketahui',
    'requested' => 'Diminta',
    'granted' => 'Diizinkan',
    'required' => 'Perlu izin',
    'denied' => 'Ditolak',
    'expired' => 'Kedaluwarsa',
    'rate_limited' => 'Dibatasi',
    'failed' => 'Gagal',
    _ => humanizeStatusLabel(normalized),
  };
}

String omnichannelCallFallbackHeadline() {
  return 'Audio langsung belum tersedia di aplikasi admin ini.';
}

String omnichannelCallFallbackDescription({bool isPolling = false}) {
  return isPolling
      ? 'Status panggilan tetap dipantau secara real-time dari server selama sesi ini aktif.'
      : 'Status panggilan tetap dipantau dari server dan akan diperbarui begitu backend menerima event terbaru.';
}

String omnichannelCallFallbackBannerNote() {
  return 'Audio live belum tersedia';
}

String omnichannelCallEndReasonLabel(String? endReason) {
  final normalized = _normalizeToken(endReason);
  if (normalized == null) {
    return '-';
  }

  return switch (normalized) {
    'completed' || 'ended' || 'hangup' || 'disconnected' => 'Selesai',
    'rejected' || 'declined' || 'busy' || 'denied' => 'Ditolak pengguna',
    'no_answer' ||
    'not_answered' ||
    'timeout' ||
    'unanswered' => 'Tidak dijawab',
    'failed' || 'error' => 'Gagal',
    _ => humanizeStatusLabel(normalized),
  };
}

String omnichannelCallOutcomeLabel(
  String? finalStatus, {
  String fallback = 'Sedang berlangsung',
}) {
  final normalized = _normalizeToken(finalStatus);
  if (normalized == null) {
    return fallback;
  }

  return switch (normalized) {
    'completed' => 'Berhasil',
    'missed' => 'Tidak dijawab',
    'rejected' => 'Ditolak',
    'failed' => 'Gagal',
    'cancelled' => 'Dibatalkan',
    'permission_pending' => 'Menunggu izin',
    'in_progress' => 'Sedang berlangsung',
    _ => humanizeStatusLabel(normalized),
  };
}

Color omnichannelCallOutcomeColor(String? finalStatus) {
  final normalized = _normalizeToken(finalStatus);

  return switch (normalized) {
    'completed' => AppColors.success,
    'missed' || 'cancelled' => AppColors.neutral500,
    'rejected' || 'failed' => AppColors.error,
    'permission_pending' => const Color(0xFFAF7E00),
    _ => AppColors.primary,
  };
}

IconData omnichannelCallOutcomeIcon(String? finalStatus) {
  final normalized = _normalizeToken(finalStatus);

  return switch (normalized) {
    'completed' => Icons.call_rounded,
    'missed' => Icons.phone_missed_rounded,
    'rejected' => Icons.phone_disabled_rounded,
    'failed' => Icons.error_outline_rounded,
    'cancelled' => Icons.call_end_rounded,
    'permission_pending' => Icons.lock_clock_outlined,
    _ => Icons.call_outlined,
  };
}

Color omnichannelCallStatusColor(OmnichannelCallSessionModel? session) {
  if (session == null) {
    return AppColors.neutral500;
  }

  if (session.isConnected) {
    return AppColors.success;
  }

  if (session.isFailed || session.isRejected) {
    return AppColors.error;
  }

  if (session.isPermissionRequested || session.requiresPermission) {
    return const Color(0xFFAF7E00);
  }

  if (session.isRinging || session.isInitiatedLike) {
    return AppColors.primary;
  }

  if (session.isEnded || session.isMissed) {
    return AppColors.neutral500;
  }

  return AppColors.primary;
}

IconData omnichannelCallStatusIcon(OmnichannelCallSessionModel? session) {
  if (session == null) {
    return Icons.call_outlined;
  }

  if (session.isConnected) {
    return Icons.call_rounded;
  }

  if (session.isFailed) {
    return Icons.error_outline_rounded;
  }

  if (session.isRejected) {
    return Icons.phone_disabled_rounded;
  }

  if (session.isPermissionRequested || session.requiresPermission) {
    return Icons.lock_clock_outlined;
  }

  if (session.isMissed) {
    return Icons.phone_missed_rounded;
  }

  return Icons.call_outlined;
}

bool omnichannelShouldShowCallBanner(OmnichannelCallSessionModel? session) {
  if (session == null) {
    return false;
  }

  if (!session.isFinished) {
    return true;
  }

  final updatedAt = session.updatedAtDateTime;
  if (updatedAt == null) {
    return true;
  }

  return DateTime.now().difference(updatedAt) <= const Duration(minutes: 3);
}

String omnichannelCallTimelineLabel(OmnichannelCallTimelineItemModel item) {
  final backendLabel = item.label?.trim();
  if (backendLabel != null && backendLabel.isNotEmpty) {
    return backendLabel;
  }

  final event = _normalizeToken(item.event);
  final status = _normalizeToken(item.status);
  final candidate = event ?? status;

  return switch (candidate) {
    'permission_requested' => 'Permintaan izin panggilan dikirim',
    'permission_granted' => 'Izin panggilan tersedia',
    'call_started' || 'initiated' => 'Panggilan WhatsApp dimulai',
    'ringing' => 'Panggilan berdering',
    'connecting' => 'Panggilan sedang menyambung',
    'connected' => 'Panggilan terhubung',
    'rejected' => 'Panggilan ditolak pengguna',
    'missed' => 'Panggilan tidak dijawab',
    'failed' => 'Panggilan gagal',
    'ended' => _endedLabelForReason(item.endReason),
    _ => 'Pembaruan panggilan diterima',
  };
}

String omnichannelCallTimelineMetaText(OmnichannelCallTimelineItemModel item) {
  final parts = <String>[];
  final formattedTime = omnichannelFormatCallTimestamp(item.timestamp);
  if (formattedTime != null) {
    parts.add(formattedTime);
  }

  final status = _normalizeToken(item.status);
  if (status != null && status != _normalizeToken(item.event)) {
    parts.add(humanizeStatusLabel(status));
  }

  final reason = _normalizeToken(item.endReason);
  if (reason != null) {
    parts.add(omnichannelCallEndReasonLabel(reason));
  }

  if (parts.isEmpty) {
    return 'Status dipantau dari backend';
  }

  return parts.join(' | ');
}

Color omnichannelCallTimelineColor(OmnichannelCallTimelineItemModel item) {
  final event = _normalizeToken(item.event) ?? _normalizeToken(item.status);

  return switch (event) {
    'connected' || 'permission_granted' => AppColors.success,
    'failed' || 'rejected' => AppColors.error,
    'missed' || 'ended' => AppColors.neutral500,
    'permission_requested' => const Color(0xFFAF7E00),
    _ => AppColors.primary,
  };
}

IconData omnichannelCallTimelineIcon(OmnichannelCallTimelineItemModel item) {
  final event = _normalizeToken(item.event) ?? _normalizeToken(item.status);

  return switch (event) {
    'permission_requested' => Icons.lock_clock_outlined,
    'permission_granted' => Icons.verified_rounded,
    'call_started' || 'initiated' => Icons.call_outlined,
    'ringing' => Icons.ring_volume_rounded,
    'connecting' => Icons.sync_rounded,
    'connected' => Icons.call_rounded,
    'rejected' => Icons.phone_disabled_rounded,
    'missed' => Icons.phone_missed_rounded,
    'failed' => Icons.error_outline_rounded,
    'ended' => Icons.call_end_rounded,
    _ => Icons.call_outlined,
  };
}

String omnichannelCallFinishedSummaryTitle(
  OmnichannelCallSessionModel? session,
  List<OmnichannelCallTimelineItemModel> items,
) {
  if (session == null && items.isEmpty) {
    return 'Ringkasan panggilan belum tersedia';
  }

  return switch (session?.status) {
    'rejected' => 'Panggilan suara WhatsApp ditolak',
    'missed' => 'Panggilan suara WhatsApp tidak dijawab',
    'failed' => 'Panggilan suara WhatsApp gagal',
    'ended' => 'Panggilan suara WhatsApp berakhir',
    _ => 'Ringkasan panggilan WhatsApp',
  };
}

String omnichannelCallFinishedSummaryDetail(
  OmnichannelCallSessionModel? session,
  List<OmnichannelCallTimelineItemModel> items,
) {
  final parts = <String>[];
  if (session != null) {
    parts.add('Status akhir: ${omnichannelCallPrimaryStatusText(session)}');
    parts.add('Durasi: ${omnichannelCallDurationLabel(session)}');

    final endedAt = omnichannelFormatCallTimestamp(session.endedAt);
    if (endedAt != null) {
      parts.add('Waktu: $endedAt');
    }
  } else {
    final latest = items.isEmpty ? null : items.last;
    if (latest != null) {
      parts.add('Status akhir: ${omnichannelCallTimelineLabel(latest)}');
      final timestamp = omnichannelFormatCallTimestamp(latest.timestamp);
      if (timestamp != null) {
        parts.add('Waktu: $timestamp');
      }
    }
  }

  return parts.join(' | ');
}

String omnichannelCallDurationLabel(OmnichannelCallSessionModel? session) {
  if (session == null) {
    return '-';
  }

  return omnichannelCallDurationText(
    durationSeconds: session.durationSeconds,
    durationHuman: session.durationHuman,
    fallback: _derivedCallDurationLabel(session),
  );
}

String omnichannelCallDurationText({
  int? durationSeconds,
  String? durationHuman,
  String fallback = '-',
}) {
  final providedHuman = durationHuman?.trim();
  if (providedHuman != null && providedHuman.isNotEmpty) {
    return providedHuman;
  }

  if (durationSeconds == null) {
    return fallback;
  }

  if (durationSeconds <= 0) {
    return '0 dtk';
  }

  final hours = durationSeconds ~/ 3600;
  final minutes = (durationSeconds % 3600) ~/ 60;
  final seconds = durationSeconds % 60;
  final parts = <String>[];

  if (hours > 0) {
    parts.add('$hours j');
  }

  if (minutes > 0) {
    parts.add('$minutes m');
  }

  if (seconds > 0 && hours == 0) {
    parts.add('$seconds dtk');
  }

  return parts.isEmpty ? '0 dtk' : parts.join(' ');
}

String? omnichannelFormatTrendDate(String? rawDate) {
  final timestamp = _parseDateTime(rawDate);
  if (timestamp == null) {
    return _normalizeText(rawDate);
  }

  final day = timestamp.day.toString().padLeft(2, '0');
  final month = switch (timestamp.month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'Mei',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Agu',
    9 => 'Sep',
    10 => 'Okt',
    11 => 'Nov',
    12 => 'Des',
    _ => '',
  };

  return '$day $month';
}

String humanizeStatusLabel(String value) {
  final normalized = _normalizeToken(value);
  if (normalized == null) {
    return '-';
  }

  return switch (normalized) {
    'permission_still_pending' => 'Permission Still Pending',
    'permission_rate_limited' => 'Permission Rate Limited',
    'permission_denied' => 'Permission Denied',
    'permission_expired' => 'Permission Expired',
    'call_blocked_configuration_error' => 'Configuration Error',
    'duplicate_action' => 'Duplicate Action',
    'call_already_processing' => 'Call Already Processing',
    'call_rate_limited' => 'Call Rate Limited',
    'permission_requested' => 'Permission Requested',
    'call_started' => 'Call Started',
    'no_answer' => 'No Answer',
    _ =>
      normalized
          .split('_')
          .map(
            (segment) => segment.isEmpty
                ? ''
                : '${segment[0].toUpperCase()}${segment.substring(1)}',
          )
          .join(' '),
  };
}

String? omnichannelFormatCallTimestamp(String? isoTimestamp) {
  final timestamp = _parseDateTime(isoTimestamp);
  if (timestamp == null) {
    return null;
  }

  final month = switch (timestamp.month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'Mei',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Agu',
    9 => 'Sep',
    10 => 'Okt',
    11 => 'Nov',
    12 => 'Des',
    _ => '',
  };

  final day = timestamp.day.toString().padLeft(2, '0');
  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');

  return '$day $month $hour:$minute';
}

String _derivedCallDurationLabel(OmnichannelCallSessionModel session) {
  final startedAt =
      _parseDateTime(session.connectedAt) ??
      _parseDateTime(session.answeredAt) ??
      _parseDateTime(session.startedAt);
  final endedAt = _parseDateTime(session.endedAt);

  if (startedAt == null || endedAt == null || endedAt.isBefore(startedAt)) {
    return '-';
  }

  return omnichannelCallDurationText(
    durationSeconds: endedAt.difference(startedAt).inSeconds,
  );
}

List<OmnichannelCallTimelineItemModel> omnichannelDerivedCallTimelineForSession(
  OmnichannelCallSessionModel? session,
) {
  if (session == null) {
    return const <OmnichannelCallTimelineItemModel>[];
  }

  final items = <OmnichannelCallTimelineItemModel>[];

  void addItem({
    required String event,
    required String label,
    required String? timestamp,
    String? status,
    String? endReason,
  }) {
    final item = OmnichannelCallTimelineItemModel(
      type: 'call_event',
      event: event,
      label: label,
      callSessionId: session.id,
      callType: session.callType,
      status: status,
      endReason: endReason,
      timestamp: timestamp,
    );

    if (item.timestamp == null &&
        items.any((existing) => existing.stableKey == item.stableKey)) {
      return;
    }

    if (!items.any((existing) => existing.stableKey == item.stableKey)) {
      items.add(item);
    }
  }

  final permissionRequestedAt =
      _stringAtPath(session.metaPayload, 'permission.requested_at') ??
      _stringAtPath(session.metaPayload, 'permission.last_requested_at') ??
      session.createdAt;
  if (session.isPermissionRequested) {
    addItem(
      event: 'permission_requested',
      label: 'Permintaan izin panggilan dikirim',
      timestamp: permissionRequestedAt,
      status: session.status ?? 'permission_requested',
    );
  }

  final permissionGrantedAt = _stringAtPath(
    session.metaPayload,
    'permission.granted_at',
  );
  if ((session.permissionStatus ?? '').trim() == 'granted' &&
      permissionGrantedAt != null) {
    addItem(
      event: 'permission_granted',
      label: 'Izin panggilan tersedia',
      timestamp: permissionGrantedAt,
      status: session.status,
    );
  }

  final canMarkStarted =
      (session.waCallId?.trim().isNotEmpty ?? false) ||
      session.status == 'initiated' ||
      session.isRinging ||
      session.isConnected ||
      session.isFinished;
  if (canMarkStarted && !session.isPermissionRequested) {
    addItem(
      event: 'call_started',
      label: 'Panggilan WhatsApp dimulai',
      timestamp: session.startedAt ?? session.createdAt,
      status: session.status ?? 'initiated',
    );
  }

  if (session.isRinging || session.status == 'connecting') {
    final ringingEvent = session.status == 'connecting'
        ? 'connecting'
        : 'ringing';
    addItem(
      event: ringingEvent,
      label: ringingEvent == 'connecting'
          ? 'Panggilan sedang menyambung'
          : 'Panggilan berdering',
      timestamp: session.updatedAt ?? session.startedAt ?? session.createdAt,
      status: session.status,
    );
  }

  if (session.isConnected) {
    addItem(
      event: 'connected',
      label: 'Panggilan terhubung',
      timestamp: session.answeredAt ?? session.updatedAt ?? session.startedAt,
      status: session.status,
    );
  }

  if (session.isFinished) {
    final event = switch (session.status) {
      'rejected' => 'rejected',
      'missed' => 'missed',
      'failed' => 'failed',
      _ => 'ended',
    };

    addItem(
      event: event,
      label: event == 'ended'
          ? _endedLabelForReason(session.endReason)
          : omnichannelCallTimelineLabel(
              OmnichannelCallTimelineItemModel(
                type: 'call_event',
                event: event,
                label: null,
                callSessionId: session.id,
                callType: session.callType,
                status: session.status,
                endReason: session.endReason,
                timestamp: session.endedAt,
              ),
            ),
      timestamp: session.endedAt ?? session.updatedAt ?? session.createdAt,
      status: session.status,
      endReason: session.endReason,
    );
  }

  items.sort((left, right) {
    final leftTimestamp = left.timestampDateTime;
    final rightTimestamp = right.timestampDateTime;

    if (leftTimestamp != null && rightTimestamp != null) {
      final comparison = leftTimestamp.compareTo(rightTimestamp);
      if (comparison != 0) {
        return comparison;
      }
    } else if (leftTimestamp != null) {
      return 1;
    } else if (rightTimestamp != null) {
      return -1;
    }

    final leftSessionId = left.callSessionId ?? -1;
    final rightSessionId = right.callSessionId ?? -1;
    if (leftSessionId != rightSessionId) {
      return leftSessionId.compareTo(rightSessionId);
    }

    return left.stableKey.compareTo(right.stableKey);
  });

  return items;
}

String? _normalizeText(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

String? _normalizeToken(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == null || text.isEmpty) {
    return null;
  }

  return text.replaceAll('-', '_').replaceAll(' ', '_');
}

DateTime? _parseDateTime(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value)?.toLocal();
}

String? _stringAtPath(Map<String, dynamic> json, String path) {
  final segments = path.split('.');
  Object? current = json;

  for (final segment in segments) {
    if (current is Map) {
      current = current[segment];
      continue;
    }

    return null;
  }

  return current?.toString().trim().isEmpty == false
      ? current.toString().trim()
      : null;
}

String _endedLabelForReason(String? endReason) {
  return switch (_normalizeToken(endReason)) {
    'no_answer' ||
    'not_answered' ||
    'timeout' ||
    'unanswered' => 'Panggilan tidak dijawab',
    'rejected' ||
    'declined' ||
    'busy' ||
    'denied' => 'Panggilan ditolak pengguna',
    'failed' || 'error' => 'Panggilan gagal',
    _ => 'Panggilan berakhir',
  };
}
