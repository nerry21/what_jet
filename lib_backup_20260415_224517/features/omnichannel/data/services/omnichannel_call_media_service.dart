import '../models/omnichannel_call_action_result.dart';
import '../models/omnichannel_call_session_model.dart';

enum OmnichannelCallMediaMode {
  idle,
  preparing,
  unavailable,
  deferred,
  connected,
  failed,
}

class AppCallCapabilities {
  const AppCallCapabilities({
    required this.supportsWhatsAppVoiceMedia,
    required this.supportsMute,
    required this.supportsSpeakerToggle,
    required this.supportsCallRecording,
    required this.supportsCallTransfer,
    required this.supportsAgentPickup,
    required this.supportsWebrtcSignaling,
    required this.reason,
  });

  final bool supportsWhatsAppVoiceMedia;
  final bool supportsMute;
  final bool supportsSpeakerToggle;
  final bool supportsCallRecording;
  final bool supportsCallTransfer;
  final bool supportsAgentPickup;
  final bool supportsWebrtcSignaling;
  final String reason;

  static const AppCallCapabilities fallbackWhatsAppVoice = AppCallCapabilities(
    supportsWhatsAppVoiceMedia: false,
    supportsMute: false,
    supportsSpeakerToggle: false,
    supportsCallRecording: false,
    supportsCallTransfer: false,
    supportsAgentPickup: false,
    supportsWebrtcSignaling: false,
    reason:
        'Build admin ini baru menampilkan status, permission, dan timeline panggilan dari backend. Audio call real-time di dalam aplikasi belum diintegrasikan end-to-end.',
  );
}

class OmnichannelCallMediaSnapshot {
  const OmnichannelCallMediaSnapshot({
    required this.capabilities,
    required this.mode,
    required this.isInitialized,
    required this.isPreparing,
    required this.isMicGranted,
    required this.isMediaConnected,
    required this.isMuted,
    required this.isSpeakerEnabled,
    required this.statusText,
    required this.detailText,
    this.lastError,
    this.attachedSessionId,
  });

  final AppCallCapabilities capabilities;
  final OmnichannelCallMediaMode mode;
  final bool isInitialized;
  final bool isPreparing;
  final bool isMicGranted;
  final bool isMediaConnected;
  final bool isMuted;
  final bool isSpeakerEnabled;
  final String statusText;
  final String detailText;
  final String? lastError;
  final int? attachedSessionId;

  bool get supportsRealtimeVoice => capabilities.supportsWhatsAppVoiceMedia;

  bool get isUnavailable =>
      mode == OmnichannelCallMediaMode.unavailable ||
      mode == OmnichannelCallMediaMode.deferred;

  OmnichannelCallMediaSnapshot copyWith({
    AppCallCapabilities? capabilities,
    OmnichannelCallMediaMode? mode,
    bool? isInitialized,
    bool? isPreparing,
    bool? isMicGranted,
    bool? isMediaConnected,
    bool? isMuted,
    bool? isSpeakerEnabled,
    String? statusText,
    String? detailText,
    Object? lastError = _sentinel,
    Object? attachedSessionId = _sentinel,
  }) {
    return OmnichannelCallMediaSnapshot(
      capabilities: capabilities ?? this.capabilities,
      mode: mode ?? this.mode,
      isInitialized: isInitialized ?? this.isInitialized,
      isPreparing: isPreparing ?? this.isPreparing,
      isMicGranted: isMicGranted ?? this.isMicGranted,
      isMediaConnected: isMediaConnected ?? this.isMediaConnected,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerEnabled: isSpeakerEnabled ?? this.isSpeakerEnabled,
      statusText: statusText ?? this.statusText,
      detailText: detailText ?? this.detailText,
      lastError: lastError == _sentinel ? this.lastError : lastError as String?,
      attachedSessionId: attachedSessionId == _sentinel
          ? this.attachedSessionId
          : attachedSessionId as int?,
    );
  }

  static const _sentinel = Object();

  factory OmnichannelCallMediaSnapshot.initial(
    AppCallCapabilities capabilities,
  ) {
    return OmnichannelCallMediaSnapshot(
      capabilities: capabilities,
      mode: OmnichannelCallMediaMode.idle,
      isInitialized: false,
      isPreparing: false,
      isMicGranted: false,
      isMediaConnected: false,
      isMuted: false,
      isSpeakerEnabled: false,
      statusText: 'Media audio belum diinisialisasi.',
      detailText:
          'Status panggilan tetap akan disinkronkan dari backend WhatsApp.',
      lastError: null,
      attachedSessionId: null,
    );
  }
}

class OmnichannelCallMediaService {
  OmnichannelCallMediaService({
    AppCallCapabilities capabilities =
        AppCallCapabilities.fallbackWhatsAppVoice,
  }) : _capabilities = capabilities,
       _snapshot = OmnichannelCallMediaSnapshot.initial(capabilities);

  final AppCallCapabilities _capabilities;
  OmnichannelCallMediaSnapshot _snapshot;

  AppCallCapabilities get capabilities => _capabilities;

  OmnichannelCallMediaSnapshot get snapshot => _snapshot;

  Future<void> initialize() async {
    if (_snapshot.isInitialized) {
      return;
    }

    _snapshot = _snapshot.copyWith(
      isInitialized: true,
      mode: OmnichannelCallMediaMode.unavailable,
      statusText: 'Audio live belum tersedia.',
      detailText: _capabilities.reason,
      lastError: null,
    );
  }

  Future<bool> ensureMicrophonePermission() async {
    await initialize();

    _snapshot = _snapshot.copyWith(
      isMicGranted: false,
      mode: OmnichannelCallMediaMode.unavailable,
      statusText: 'Akses mikrofon tidak diminta.',
      detailText:
          'Build ini belum membuka sesi media WhatsApp real-time, jadi permission mikrofon belum digunakan.',
      lastError: null,
    );

    return false;
  }

  Future<void> prepareAudioSession() async {
    await initialize();

    _snapshot = _snapshot.copyWith(
      isPreparing: true,
      mode: OmnichannelCallMediaMode.preparing,
      statusText: 'Menyiapkan lapisan media...',
      detailText:
          'Build admin mengecek kesiapan abstraksi media tanpa membuka suara real-time.',
      lastError: null,
    );

    _snapshot = _snapshot.copyWith(
      isPreparing: false,
      mode: OmnichannelCallMediaMode.unavailable,
      statusText: 'Audio live belum tersedia.',
      detailText: _capabilities.reason,
      lastError: null,
    );
  }

  Future<void> attachToCallSession(OmnichannelCallSessionModel session) async {
    await initialize();

    _snapshot = _snapshot.copyWith(
      attachedSessionId: session.id,
      mode: session.isFinished
          ? OmnichannelCallMediaMode.idle
          : OmnichannelCallMediaMode.deferred,
      isPreparing: false,
      isMediaConnected: false,
      isMuted: false,
      isSpeakerEnabled: false,
      statusText: session.isFinished
          ? 'Sesi media sudah ditutup.'
          : 'Media suara langsung belum tersedia.',
      detailText: _detailForSession(session),
      lastError: null,
    );
  }

  Future<void> connectMedia({
    OmnichannelCallSessionModel? session,
    OmnichannelCallActionResult? lastActionResult,
  }) async {
    await initialize();

    final detailText = _detailForConnectionAttempt(session, lastActionResult);

    _snapshot = _snapshot.copyWith(
      attachedSessionId: session?.id ?? _snapshot.attachedSessionId,
      mode: OmnichannelCallMediaMode.deferred,
      isPreparing: false,
      isMediaConnected: false,
      statusText: 'Audio real-time belum tersedia.',
      detailText: detailText,
      lastError: null,
    );
  }

  Future<void> setMuted(bool value) async {
    await initialize();

    _snapshot = _snapshot.copyWith(
      mode: OmnichannelCallMediaMode.deferred,
      isMuted: false,
      statusText: 'Mute belum tersedia.',
      detailText:
          'Kontrol mute baru dapat diaktifkan setelah layer media real-time tersedia.',
      lastError: 'Fitur mute belum didukung pada build ini.',
    );
  }

  Future<void> setSpeakerEnabled(bool value) async {
    await initialize();

    _snapshot = _snapshot.copyWith(
      mode: OmnichannelCallMediaMode.deferred,
      isSpeakerEnabled: false,
      statusText: 'Speaker belum tersedia.',
      detailText:
          'Kontrol speaker baru dapat diaktifkan setelah layer media real-time tersedia.',
      lastError: 'Fitur speaker toggle belum didukung pada build ini.',
    );
  }

  Future<void> endMediaSession() async {
    await initialize();

    _snapshot = _snapshot.copyWith(
      attachedSessionId: null,
      mode: OmnichannelCallMediaMode.idle,
      isPreparing: false,
      isMediaConnected: false,
      isMuted: false,
      isSpeakerEnabled: false,
      statusText: 'Sesi media tidak aktif.',
      detailText:
          'Resource media tidak dibuka pada build ini. Status panggilan tetap mengikuti backend.',
      lastError: null,
    );
  }

  Future<void> dispose() async {
    await endMediaSession();
  }

  String _detailForSession(OmnichannelCallSessionModel session) {
    if (session.isPermissionRequested) {
      return 'Admin masih menunggu izin panggilan dari pengguna. Audio live tidak akan aktif sebelum integrasi media tersedia.';
    }

    if (session.isConnected) {
      return 'Backend menandai panggilan terhubung, tetapi channel suara admin belum tersedia pada build ini.';
    }

    if (session.isRinging || session.isInitiatedLike) {
      return 'Signaling panggilan tetap dipantau dari backend, tetapi build admin belum dapat membuka jalur audio WhatsApp secara langsung.';
    }

    if (session.isFinished) {
      return 'Panggilan sudah selesai dan tidak ada resource media yang perlu dipertahankan.';
    }

    return _capabilities.reason;
  }

  String _detailForConnectionAttempt(
    OmnichannelCallSessionModel? session,
    OmnichannelCallActionResult? lastActionResult,
  ) {
    final metaCode = lastActionResult?.metaError?['code']?.toString().trim();
    if (metaCode == 'signaling_session_required') {
      return 'Backend Meta Calling masih membutuhkan payload session/SDP. Build admin ini belum memiliki layer WebRTC untuk mengirim offer/answer tersebut.';
    }

    if (session != null) {
      return _detailForSession(session);
    }

    return _capabilities.reason;
  }
}
