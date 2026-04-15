import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../data/models/omnichannel_call_action_result.dart';
import '../../data/models/omnichannel_call_session_model.dart';
import '../../data/models/omnichannel_call_timeline_item_model.dart';
import '../../data/repositories/omnichannel_repository.dart';
import '../../data/services/omnichannel_call_media_service.dart';
import '../utils/omnichannel_call_status_ui.dart';

class OmnichannelCallController extends ChangeNotifier {
  OmnichannelCallController({
    required OmnichannelRepository repository,
    required OmnichannelCallMediaService mediaService,
  }) : _repository = repository,
       _mediaService = mediaService;

  final OmnichannelRepository _repository;
  final OmnichannelCallMediaService _mediaService;

  OmnichannelCallSessionModel? _currentCall;
  OmnichannelCallActionResult? _lastActionResult;
  List<OmnichannelCallTimelineItemModel> _timeline =
      const <OmnichannelCallTimelineItemModel>[];
  bool _isLoading = false;
  bool _isPolling = false;
  String? _lastMessage;
  String _fallbackMessage = omnichannelCallFallbackDescription();
  String? _boundConversationId;
  Timer? _pollTimer;
  bool _isFetchingStatus = false;
  int _pollFailureCount = 0;
  int _bindingVersion = 0;
  bool _showEndedSummary = false;

  OmnichannelCallSessionModel? get currentCall => _currentCall;
  OmnichannelCallActionResult? get lastActionResult => _lastActionResult;
  List<OmnichannelCallTimelineItemModel> get timeline => _timeline;
  bool get isLoading => _isLoading;
  bool get isPolling => _isPolling;
  String? get lastMessage => _lastMessage;
  bool get isFallbackMode => !callCapabilities.supportsWhatsAppVoiceMedia;
  String get fallbackMessage => _fallbackMessage;
  bool get showEndedSummary => _showEndedSummary;
  String? get boundConversationId => _boundConversationId;
  OmnichannelCallMediaSnapshot get mediaSnapshot => _mediaService.snapshot;
  AppCallCapabilities get callCapabilities => _mediaService.capabilities;
  bool get isMediaReady =>
      mediaSnapshot.isInitialized && !mediaSnapshot.isPreparing;
  bool get isMediaConnecting =>
      mediaSnapshot.mode == OmnichannelCallMediaMode.preparing;
  bool get isMediaConnected => mediaSnapshot.isMediaConnected;
  bool get isMuted => mediaSnapshot.isMuted;
  bool get isSpeakerEnabled => mediaSnapshot.isSpeakerEnabled;
  String? get mediaError => mediaSnapshot.lastError;
  String get mediaStatusText => mediaSnapshot.statusText;
  String get mediaDetailText => mediaSnapshot.detailText;
  OmnichannelCallMediaMode get mediaMode => mediaSnapshot.mode;

  bool get hasOngoingCall {
    final call = _currentCall;
    if (call == null) {
      return false;
    }

    return !call.isFinished ||
        call.isPermissionRequested ||
        call.requiresPermission;
  }

  void bindConversation({
    required String? conversationId,
    OmnichannelCallSessionModel? initialSession,
    List<OmnichannelCallTimelineItemModel> initialTimeline =
        const <OmnichannelCallTimelineItemModel>[],
    bool forceStartPolling = false,
  }) {
    final hasConversationChanged = _boundConversationId != conversationId;
    final shouldNotify =
        hasConversationChanged ||
        _shouldAcceptIncomingSession(initialSession) ||
        _shouldAcceptIncomingTimeline(initialTimeline) ||
        (conversationId == null && _currentCall != null);

    if (hasConversationChanged) {
      _bindingVersion++;
      stopPolling();
      _boundConversationId = conversationId;
      _pollFailureCount = 0;
      _lastActionResult = null;

      if (conversationId == null) {
        _currentCall = null;
        _timeline = const <OmnichannelCallTimelineItemModel>[];
        _lastMessage = null;
        _refreshDerivedState();
        unawaited(_clearMediaState(notify: true));
      } else {
        _currentCall = initialSession;
        _timeline = _buildEffectiveTimeline(
          sourceTimeline: initialTimeline,
          session: _currentCall,
        );
        _refreshDerivedState();
        unawaited(_syncMediaState(notify: true));
      }
    } else {
      bindInitialSession(initialSession, notify: false);
      bindInitialTimeline(initialTimeline, notify: false);
    }

    if (conversationId == null) {
      if (shouldNotify) {
        notifyListeners();
      }
      return;
    }

    final session = initialSession ?? _currentCall;
    if (forceStartPolling || _shouldContinuePolling(session)) {
      startPolling(conversationId: conversationId);
    } else if (!_shouldContinuePolling(session)) {
      stopPolling();
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  void bindInitialSession(
    OmnichannelCallSessionModel? session, {
    bool notify = true,
  }) {
    if (!_shouldAcceptIncomingSession(session)) {
      if (session != null && session.isFinished) {
        stopPolling();
      }
      return;
    }

    _currentCall = session;
    _timeline = _buildEffectiveTimeline(sourceTimeline: _timeline, session: session);

    if (session != null) {
      _lastMessage = null;
      if (session.isFinished) {
        stopPolling();
      }
    }

    _refreshDerivedState();
    unawaited(_syncMediaState(notify: true));

    if (notify) {
      notifyListeners();
    }
  }

  void bindInitialTimeline(
    List<OmnichannelCallTimelineItemModel> timeline, {
    bool notify = true,
  }) {
    final nextTimeline = _buildEffectiveTimeline(
      sourceTimeline: timeline,
      session: _currentCall,
    );
    if (_isSameTimeline(_timeline, nextTimeline)) {
      return;
    }

    _timeline = nextTimeline;
    _refreshDerivedState();

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> startCall({
    required String conversationId,
    String callType = 'audio',
  }) async {
    await _runAction(
      conversationId: conversationId,
      action: () => _repository.startConversationCall(
        conversationId: conversationId,
        callType: callType,
      ),
    );
  }

  Future<void> requestPermission({
    required String conversationId,
    String callType = 'audio',
  }) async {
    await _runAction(
      conversationId: conversationId,
      action: () => _repository.requestConversationCallPermission(
        conversationId: conversationId,
        callType: callType,
      ),
    );
  }

  Future<void> acceptCall({required String conversationId}) async {
    await _runAction(
      conversationId: conversationId,
      action: () =>
          _repository.acceptConversationCall(conversationId: conversationId),
    );
  }

  Future<void> rejectCall({required String conversationId}) async {
    await _runAction(
      conversationId: conversationId,
      action: () =>
          _repository.rejectConversationCall(conversationId: conversationId),
    );
  }

  Future<void> endCall({required String conversationId}) async {
    await _runAction(
      conversationId: conversationId,
      action: () =>
          _repository.endConversationCall(conversationId: conversationId),
    );
  }

  Future<void> initializeMediaLayer() async {
    await _mediaService.initialize();
    await _mediaService.prepareAudioSession();
    await _syncMediaState();
    notifyListeners();
  }

  Future<void> setMuted(bool value) async {
    await _mediaService.setMuted(value);
    notifyListeners();
  }

  Future<void> setSpeakerEnabled(bool value) async {
    await _mediaService.setSpeakerEnabled(value);
    notifyListeners();
  }

  Future<void> refreshStatus({
    required String conversationId,
    bool silent = false,
  }) async {
    if (_isFetchingStatus) {
      return;
    }

    if (_boundConversationId != null &&
        _boundConversationId != conversationId) {
      return;
    }

    _boundConversationId ??= conversationId;
    final bindingVersion = _bindingVersion;
    _isFetchingStatus = true;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final result = await _repository.fetchConversationCallStatus(
        conversationId: conversationId,
      );

      if (_bindingVersion != bindingVersion ||
          _boundConversationId != conversationId) {
        return;
      }

      _lastActionResult = result;
      if (result.success) {
        _pollFailureCount = 0;
        if (result.callSession != null) {
          bindInitialSession(result.callSession, notify: false);
        } else {
          _timeline = _buildEffectiveTimeline(
            sourceTimeline: _timeline,
            session: _currentCall,
          );
          _refreshDerivedState();
        }
        _lastMessage = null;
      } else {
        _pollFailureCount += 1;
        _lastMessage = _pollFailureCount >= 3
            ? 'Status panggilan sedang bermasalah. Menunggu sinkronisasi ulang.'
            : (silent
                  ? _lastMessage
                  : (result.message.trim().isEmpty
                        ? 'Gagal memperbarui status panggilan.'
                        : result.message.trim()));
      }

      if (_currentCall?.isFinished == true) {
        await _clearMediaState();
        stopPolling();
      } else if (_shouldContinuePolling(_currentCall) ||
          _lastActionResult?.success == true ||
          _isPolling) {
        await _syncMediaState();
        _ensurePollingTimer(conversationId);
      } else {
        stopPolling();
      }
    } catch (error) {
      _pollFailureCount += 1;
      if (_pollFailureCount >= 3) {
        _lastMessage =
            'Status panggilan sedang bermasalah. Menunggu sinkronisasi ulang.';
      }
      debugPrint('CALL STATUS POLLING ERROR => $error');
    } finally {
      _isFetchingStatus = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  void startPolling({required String conversationId}) {
    if (_boundConversationId != null &&
        _boundConversationId != conversationId) {
      stopPolling();
    }

    _boundConversationId = conversationId;

    if (!_shouldContinuePolling(_currentCall) &&
        _lastActionResult?.success != true) {
      _isPolling = false;
      _refreshDerivedState();
      notifyListeners();
      return;
    }

    _ensurePollingTimer(conversationId);
    _refreshDerivedState();
    notifyListeners();
    unawaited(refreshStatus(conversationId: conversationId, silent: true));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_isPolling) {
      _isPolling = false;
      _refreshDerivedState();
      notifyListeners();
    }
  }

  void clearEndedState() {
    if (_currentCall == null || !_currentCall!.isFinished) {
      return;
    }

    _currentCall = null;
    _lastActionResult = null;
    _lastMessage = null;
    _showEndedSummary = false;
    _refreshDerivedState();
    unawaited(_clearMediaState());
    stopPolling();
    notifyListeners();
  }

  Future<void> _runAction({
    required String conversationId,
    required Future<OmnichannelCallActionResult> Function() action,
  }) async {
    if (_isLoading) {
      return;
    }

    _boundConversationId = conversationId;
    final bindingVersion = _bindingVersion;
    _isLoading = true;
    _lastMessage = null;
    notifyListeners();

    try {
      final result = await action();

      if (_bindingVersion != bindingVersion ||
          _boundConversationId != conversationId) {
        return;
      }

      _lastActionResult = result;
      _lastMessage = result.message.trim().isEmpty
          ? null
          : result.message.trim();

      if (result.callSession != null) {
        bindInitialSession(result.callSession, notify: false);
      } else {
        _timeline = _buildEffectiveTimeline(
          sourceTimeline: _timeline,
          session: _currentCall,
        );
        _refreshDerivedState();
      }

      if (_shouldContinuePolling(_currentCall)) {
        await _syncMediaState();
        _ensurePollingTimer(conversationId);
      } else {
        if (_currentCall?.isFinished == true) {
          await _clearMediaState();
        }
        stopPolling();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _ensurePollingTimer(String conversationId) {
    final timer = _pollTimer;
    if (timer != null && timer.isActive && _isPolling) {
      return;
    }

    _pollTimer?.cancel();
    _isPolling = true;
    _refreshDerivedState();
    _pollTimer = Timer.periodic(
      AppConfig.defaultPollingInterval,
      (_) => unawaited(
        refreshStatus(conversationId: conversationId, silent: true),
      ),
    );
  }

  bool _shouldContinuePolling(OmnichannelCallSessionModel? session) {
    if (session == null) {
      return false;
    }

    if (session.isFinished) {
      return false;
    }

    if (session.isConnected ||
        session.isActive ||
        session.isPermissionRequested ||
        session.requiresPermission ||
        session.isInitiatedLike) {
      return true;
    }

    return false;
  }

  bool _shouldAcceptIncomingSession(OmnichannelCallSessionModel? session) {
    if (session == null) {
      return false;
    }

    final current = _currentCall;
    if (current == null) {
      return true;
    }

    return session.isNewerThan(current);
  }

  bool _shouldAcceptIncomingTimeline(
    List<OmnichannelCallTimelineItemModel> timeline,
  ) {
    if (timeline.isEmpty) {
      return false;
    }

    if (_timeline.isEmpty) {
      return true;
    }

    final incomingLatest = timeline.last;
    final currentLatest = _timeline.last;
    return incomingLatest.isNewerThan(currentLatest);
  }

  List<OmnichannelCallTimelineItemModel> _buildEffectiveTimeline({
    List<OmnichannelCallTimelineItemModel> sourceTimeline =
        const <OmnichannelCallTimelineItemModel>[],
    OmnichannelCallSessionModel? session,
  }) {
    final merged = <String, OmnichannelCallTimelineItemModel>{};

    for (final item in <OmnichannelCallTimelineItemModel>[
      ...sourceTimeline,
      ...omnichannelDerivedCallTimelineForSession(session),
    ]) {
      final existing = merged[item.stableKey];
      if (existing == null || item.isNewerThan(existing)) {
        merged[item.stableKey] = item;
      }
    }

    final values = merged.values.toList()
      ..sort((left, right) {
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

    return values;
  }

  bool _isSameTimeline(
    List<OmnichannelCallTimelineItemModel> current,
    List<OmnichannelCallTimelineItemModel> incoming,
  ) {
    if (identical(current, incoming)) {
      return true;
    }

    if (current.length != incoming.length) {
      return false;
    }

    for (var index = 0; index < current.length; index++) {
      if (current[index].stableKey != incoming[index].stableKey) {
        return false;
      }
    }

    return true;
  }

  void _refreshDerivedState() {
    _showEndedSummary =
        _currentCall?.isFinished == true ||
        (_timeline.isNotEmpty && _timeline.last.isTerminal);
    _fallbackMessage = omnichannelCallFallbackDescription(
      isPolling: _isPolling || hasOngoingCall,
    );
  }

  Future<void> _syncMediaState({bool notify = false}) async {
    await _mediaService.initialize();
    final call = _currentCall;

    if (call == null || call.isFinished) {
      await _mediaService.endMediaSession();
      if (notify) {
        notifyListeners();
      }
      return;
    }

    await _mediaService.attachToCallSession(call);
    await _mediaService.connectMedia(
      session: call,
      lastActionResult: _lastActionResult,
    );

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _clearMediaState({bool notify = false}) async {
    await _mediaService.initialize();
    await _mediaService.endMediaSession();

    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(_mediaService.dispose());
    super.dispose();
  }
}
