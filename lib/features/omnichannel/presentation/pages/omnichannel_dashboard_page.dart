import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import 'package:what_jet/core/config/app_config.dart';
import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../admin_auth/data/models/admin_user_model.dart';
import '../../../admin_auth/data/repositories/admin_auth_repository.dart';
import '../../domain/models/omnichannel_call_readiness_model.dart';
import '../../data/models/omnichannel_call_action_result.dart';
import '../../data/models/omnichannel_call_session_model.dart';
import '../../data/models/omnichannel_call_timeline_item_model.dart';
import '../../data/models/omnichannel_conversation_detail_model.dart';
import '../../data/models/omnichannel_conversation_list_model.dart';
import '../../data/models/omnichannel_thread_model.dart';
import '../../data/models/omnichannel_workspace_model.dart';
import '../../data/repositories/omnichannel_repository.dart';
import '../../data/services/omnichannel_call_media_service.dart';
import '../controllers/omnichannel_call_analytics_controller.dart';
import '../controllers/omnichannel_call_controller.dart';
import '../controllers/omnichannel_shell_controller.dart';
import '../notifications/in_app_notification_overlay.dart';
import '../../../../core/services/push_notification_service.dart';
import '../pages/omnichannel_call_page.dart';
import '../pages/omnichannel_call_history_page.dart';
import '../pages/omnichannel_starred_messages_page.dart';
import '../pages/omnichannel_updates_page.dart';
import '../utils/omnichannel_call_status_ui.dart';
import '../widgets/omnichannel_action_sheet.dart';
import '../widgets/omnichannel_center_pane.dart';
import '../widgets/manual_payment_compose_dialog.dart';
import '../widgets/omnichannel_call_settings_checklist_sheet.dart';
import '../widgets/omnichannel_left_pane.dart';
import '../widgets/omnichannel_new_chat_page.dart';
import '../widgets/omnichannel_right_pane.dart';
import '../widgets/omnichannel_shell_header.dart';
import '../widgets/omnichannel_surface.dart';
import '../widgets/omnichannel_call_analytics_panel.dart';
import '../widgets/sticker_picker_sheet.dart';
import '../widgets/forward_target_picker_sheet.dart';

enum _OmnichannelMobilePane {
  inbox,
  updates,
  conversation,
  insight,
  callHistory,
}

class OmnichannelDashboardPage extends StatefulWidget {
  const OmnichannelDashboardPage({
    super.key,
    required this.repository,
    required this.adminAuthRepository,
    this.initialUser,
  });

  final OmnichannelRepository repository;
  final AdminAuthRepository adminAuthRepository;
  final AdminUserModel? initialUser;

  @override
  State<OmnichannelDashboardPage> createState() =>
      _OmnichannelDashboardPageState();
}

class _OmnichannelDashboardPageState extends State<OmnichannelDashboardPage>
    with WidgetsBindingObserver {
  late final OmnichannelShellController _controller;
  late final OmnichannelCallController _callController;
  late final OmnichannelCallAnalyticsController _callAnalyticsController;
  late final OmnichannelCallMediaService _callMediaService;
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _conversationListScrollController = ScrollController();

  bool _hasRedirected = false;
  bool _isSendingReply = false;
  bool _isSendingContact = false;
  bool _isTogglingBot = false;
  bool _isRecordingVoiceNote = false;
  OmnichannelThreadMessageModel? _replyingTo;
  int? _replyingToConversationId;
  _OmnichannelMobilePane _mobilePane = _OmnichannelMobilePane.inbox;
  OmnichannelCallSessionModel? _lastObservedCallSession;
  OmnichannelCallReadinessModel? _callReadiness;
  bool _isLoadingCallReadiness = false;
  bool _isClearingCallEligibilityCache = false;
  // Call Readiness UI is disabled by user request — keep the flag as `false`
  // so both the pinned panel and the restore floating bubble never render.
  // Underlying state and network helpers are left intact to avoid touching
  // unrelated logic.
  final bool _showCallReadinessCard = false;
  bool _showActiveCallCard = true;
  Offset _callReadinessBubbleOffset = const Offset(0, 0);
  Offset _activeCallBubbleOffset = const Offset(0, 56);
  bool _isCallReadinessExpanded = false;
  final bool _pinCallReadinessAboveCallCard = true;

  static const double _floatingBubbleWidth = 190.0;
  static const double _floatingBubbleHeight = 46.0;
  static const double _floatingBubbleBaseRight = 14.0;
  static const double _floatingBubbleBaseBottom = 74.0;

  OmnichannelThreadMessageModel? get _activeReplyTo {
    if (_replyingTo == null) {
      return null;
    }
    if (_replyingToConversationId != _controller.selectedConversation?.id) {
      return null;
    }
    return _replyingTo;
  }

  bool get _shouldAutoExpandCallReadiness {
    final readiness = _callReadiness;
    if (readiness == null) {
      return false;
    }

    return readiness.ok != true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = OmnichannelShellController(
      repository: widget.repository,
      adminAuthRepository: widget.adminAuthRepository,
    )..addListener(_handleControllerChanged);
    // Daftarkan listener untuk notifikasi pesan masuk → tampilkan banner.
    _controller.addChatNotificationListener(_handleChatNotification);
    // Register callback untuk push notification tap → navigate ke conversation
    PushNotificationService.instance.onNotificationTapped = (conversationId) {
      if (!mounted) return;
      _handleConversationTap(conversationId, showConversationOnMobile: true);
    };
    _callMediaService = OmnichannelCallMediaService();
    _callController = OmnichannelCallController(
      repository: widget.repository,
      mediaService: _callMediaService,
    )..addListener(_handleCallControllerChanged);
    _callAnalyticsController = OmnichannelCallAnalyticsController(
      repository: widget.repository,
    );

    _searchController.addListener(_handleSearchChanged);
    _conversationListScrollController.addListener(_handleListScroll);

    unawaited(_controller.initialize(initialUser: widget.initialUser));
    unawaited(_callAnalyticsController.initialize());
    // Call Readiness is hidden — skip the initial readiness request
    // so we don't spend battery/network on a feature users don't see.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    PushNotificationService.instance.onNotificationTapped = null;
    _controller
      ..removeChatNotificationListener(_handleChatNotification)
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _callController.removeListener(_handleCallControllerChanged);
    _callController.dispose();
    _callAnalyticsController.dispose();

    _searchController.removeListener(_handleSearchChanged);
    _conversationListScrollController.removeListener(_handleListScroll);

    _searchController.dispose();
    _conversationListScrollController.dispose();
    _audioRecorder.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    _controller.setPageActive(isActive);
    if (isActive && _callController.boundConversationId != null) {
      unawaited(
        _callController.refreshStatus(
          conversationId: _callController.boundConversationId!,
          silent: true,
        ),
      );
    }
    if (isActive) {
      unawaited(_callAnalyticsController.refresh(silent: true));
    }
  }

  void _handleSearchChanged() {
    _controller.setSearchQuery(_searchController.text);
  }

  void _handleListScroll() {
    if (!_conversationListScrollController.hasClients) {
      return;
    }

    final position = _conversationListScrollController.position;
    if (position.maxScrollExtent - position.pixels <= 240) {
      unawaited(_controller.loadMoreConversations());
    }
  }

  void _handleControllerChanged() {
    _syncCallBinding();

    if (!_controller.requiresLogin || _hasRedirected || !mounted) {
      return;
    }

    _hasRedirected = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacementNamed(AppRoutes.adminLogin);
    });
  }

  void _syncCallBinding({bool forceStartPolling = false}) {
    final conversation = _controller.selectedConversation;
    final conversationId = conversation?.id;

    _callController.bindConversation(
      conversationId: conversationId?.toString(),
      initialSession: _effectiveCallSession(conversation),
      initialTimeline: conversation?.callTimeline ?? const [],
      forceStartPolling: forceStartPolling,
    );
  }

  List<OmnichannelCallTimelineItemModel> _effectiveCallTimeline(
    OmnichannelConversationDetailModel? conversation,
  ) {
    final controllerTimeline = _callController.timeline;
    if (controllerTimeline.isNotEmpty) {
      return controllerTimeline;
    }

    return conversation?.callTimeline ?? const [];
  }

  OmnichannelCallSessionModel? _effectiveCallSession(
    OmnichannelConversationDetailModel? conversation,
  ) {
    if (conversation == null) {
      return _callController.currentCall;
    }

    final conversationSession = conversation.callSession;
    final controllerSession = _callController.currentCall;
    final conversationId = conversation.id.toString();

    if (controllerSession == null ||
        _callController.boundConversationId != conversationId) {
      return conversationSession;
    }

    if (conversationSession == null) {
      return controllerSession;
    }

    return controllerSession.isNewerThan(conversationSession)
        ? controllerSession
        : conversationSession;
  }

  Future<void> _startConversationCall() async {
    final conversation = _controller.selectedConversation;
    final conversationId = conversation?.id;

    if (conversationId == null || conversationId <= 0) {
      _showSnackBar('Conversation belum dipilih.');
      return;
    }

    if (conversation?.channel != 'whatsapp') {
      _showSnackBar(
        'Panggilan WhatsApp hanya tersedia untuk conversation channel WhatsApp.',
      );
      return;
    }

    if (_callController.isLoading) {
      return;
    }

    final ready = await _ensureCallingReady();
    if (!ready || !mounted) {
      return;
    }

    await _callController.startCall(conversationId: conversationId.toString());
    await _loadCallReadiness(silent: true);
    await _controller.softRefreshAfterExternalAction();
    await _callAnalyticsController.refresh(silent: true);
    _syncCallBinding(forceStartPolling: true);

    if (!mounted) {
      return;
    }

    final result = _callController.lastActionResult;
    if (result == null) {
      _showSnackBar('Respons panggilan dari backend belum tersedia.');
      return;
    }

    if (result.success) {
      _showSnackBar(_callSuccessMessage(result));
      await _openCurrentCallPage();
      return;
    }

    if (_shouldOpenCallPageForFailure(result)) {
      await _openCurrentCallPage();
      if (mounted) {
        _showSnackBar(_callErrorMessage(result));
      }
      return;
    }

    _showSnackBar(_callErrorMessage(result));
  }

  Future<void> _openCurrentCallPage() async {
    final conversation = _controller.selectedConversation;
    final conversationId = conversation?.id;

    if (conversation == null || conversationId == null || conversationId <= 0) {
      _showSnackBar('Conversation belum dipilih.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OmnichannelCallPage(
          controller: _callController,
          conversationId: conversationId.toString(),
          customerName: conversation.customerName,
          customerContact: conversation.customerContact,
          initialSession: _effectiveCallSession(conversation),
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _controller.softRefreshAfterExternalAction();
    _syncCallBinding(forceStartPolling: true);
  }

  Future<void> _endConversationCall() async {
    final conversationId = _controller.selectedConversation?.id;
    if (conversationId == null || conversationId <= 0) {
      _showSnackBar('Conversation belum dipilih.');
      return;
    }

    await _callController.endCall(conversationId: conversationId.toString());
    await _controller.softRefreshAfterExternalAction();
    await _callAnalyticsController.refresh(silent: true);
    _syncCallBinding(forceStartPolling: true);

    if (!mounted) {
      return;
    }

    final result = _callController.lastActionResult;
    if (result == null) {
      _showSnackBar('Status akhir panggilan belum tersedia.');
      return;
    }

    _showSnackBar(result.success ? result.message : _callErrorMessage(result));
  }

  Future<void> _showVideoCallUnavailable() async {
    _showSnackBar('Video call belum diimplementasikan pada tahap ini.');
  }

  Future<bool> _ensureCallingReady() async {
    try {
      final readiness = await widget.repository.loadCallReadiness();
      if (mounted) {
        setState(() {
          _callReadiness = readiness;
          if (_shouldAutoExpandCallReadiness) {
            _isCallReadinessExpanded = true;
          }
        });
      }

      if (!readiness.callingEnabled) {
        _showSnackBar(
          'Calling dimatikan di backend. Aktifkan WHATSAPP_CALLING_ENABLED=true.',
        );
        return false;
      }

      if (!readiness.configComplete) {
        _showSnackBar(
          'Konfigurasi calling backend belum lengkap: ${readiness.missing.join(', ')}',
        );
        return false;
      }

      if (readiness.tierEligibleForCalling == false) {
        _showSnackBar(
          readiness.eligibilityReason ??
              'Calling belum bisa diaktifkan karena messaging limit tier nomor belum memenuhi syarat Meta.',
        );
        return false;
      }

      if (readiness.remoteCallingEnabled == false) {
        _showSnackBar(
          readiness.eligibilityReason ??
              'Calling API belum aktif pada nomor WhatsApp ini. Aktifkan Call Settings nomor di Meta terlebih dahulu.',
        );
        return false;
      }

      if ((readiness.remoteSettingsError?.trim().isNotEmpty ?? false) &&
          readiness.remoteCallingEnabled != true) {
        _showSnackBar(
          'Readiness calling gagal dicek: ${readiness.remoteSettingsError}',
        );
        return false;
      }

      return true;
    } on ApiException catch (error) {
      _showSnackBar('Gagal mengecek readiness calling: ${error.message}');
      return false;
    } catch (error) {
      _showSnackBar('Gagal mengecek readiness calling: $error');
      return false;
    }
  }

  Future<void> _loadCallReadiness({
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    if (!silent) {
      setState(() {
        _isLoadingCallReadiness = true;
      });
    }

    try {
      final readiness = await widget.repository.loadCallReadiness(
        forceRefresh: forceRefresh,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _callReadiness = readiness;
        if (_shouldAutoExpandCallReadiness) {
          _isCallReadinessExpanded = true;
        } else if (!silent) {
          _isCallReadinessExpanded = false;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingCallReadiness = false;
    });
  }

  Future<void> _clearCallEligibilityCacheNow() async {
    if (_isClearingCallEligibilityCache) {
      return;
    }

    setState(() {
      _isClearingCallEligibilityCache = true;
    });

    try {
      final result = await widget.repository.clearCallReadinessCache();

      if (!mounted) {
        return;
      }

      _showSnackBar(
        (result['message']?.toString().trim().isNotEmpty ?? false)
            ? result['message'].toString().trim()
            : 'Eligibility cache berhasil dihapus.',
      );

      await _loadCallReadiness(silent: true, forceRefresh: true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Gagal menghapus eligibility cache: ${error.message}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Gagal menghapus eligibility cache: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isClearingCallEligibilityCache = false;
        });
      }
    }
  }

  Offset _clampBubbleOffset(
    Offset candidate, {
    required Size viewportSize,
    required double bubbleWidth,
    required double bubbleHeight,
    double rightPadding = 14,
    double bottomPadding = 18,
    double topPadding = 12,
    double leftPadding = 12,
    double baseRight = _floatingBubbleBaseRight,
    double baseBottom = _floatingBubbleBaseBottom,
  }) {
    final maxRight = max(
      rightPadding,
      viewportSize.width - bubbleWidth - leftPadding,
    );
    final minDx = baseRight - maxRight;
    final maxDx = baseRight - rightPadding;

    final maxBottom = max(
      bottomPadding,
      viewportSize.height - bubbleHeight - topPadding,
    );
    final minDy = baseBottom - maxBottom;
    final maxDy = baseBottom - bottomPadding;

    return Offset(
      candidate.dx.clamp(minDx, maxDx).toDouble(),
      candidate.dy.clamp(minDy, maxDy).toDouble(),
    );
  }

  // ignore: unused_element
  void _updateCallReadinessBubbleOffset(Offset delta, Size viewportSize) {
    if (!mounted) {
      return;
    }

    setState(() {
      _callReadinessBubbleOffset = _clampBubbleOffset(
        _callReadinessBubbleOffset + delta,
        viewportSize: viewportSize,
        bubbleWidth: _floatingBubbleWidth,
        bubbleHeight: _floatingBubbleHeight,
      );
    });
  }

  void _updateActiveCallBubbleOffset(Offset delta, Size viewportSize) {
    if (!mounted) {
      return;
    }

    setState(() {
      _activeCallBubbleOffset = _clampBubbleOffset(
        _activeCallBubbleOffset + delta,
        viewportSize: viewportSize,
        bubbleWidth: _floatingBubbleWidth,
        bubbleHeight: _floatingBubbleHeight,
      );
    });
  }

  void _hideCallReadinessCard() {
    // No-op: Call Readiness UI is disabled entirely.
    // Method is kept so existing callers (e.g. button callbacks still wired
    // in the widget tree) remain valid without breaking compilation.
  }

  // ignore: unused_element
  void _showCallReadinessCardAgain() {
    // No-op: the restore chip is never rendered, so this is unreachable,
    // but left in place as a safety net for any lingering callers.
  }

  void _hideActiveCallCard() {
    if (!mounted) {
      return;
    }
    setState(() {
      _showActiveCallCard = false;
    });
  }

  void _showActiveCallCardAgain() {
    if (!mounted) {
      return;
    }
    setState(() {
      _showActiveCallCard = true;
      _activeCallBubbleOffset = const Offset(0, 56);
    });
  }

  void _toggleCallReadinessExpanded() {
    if (!mounted) {
      return;
    }

    setState(() {
      _isCallReadinessExpanded = !_isCallReadinessExpanded;
    });
  }

  Future<void> _openMetaCallSettingsChecklist() async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.84,
          child: OmnichannelCallSettingsChecklistSheet(onClose: () {}),
        );
      },
    );

    if (!mounted) {
      return;
    }
    await _loadCallReadiness(silent: true, forceRefresh: true);
  }

  // ignore: unused_element
  Widget _buildLegacyStickyReadinessHeader() {
    final readiness = _callReadiness;
    final isReady = readiness?.ok == true;
    final statusText = readiness?.statusLabel ?? 'Checking...';
    final chipBg = isReady ? AppColors.success50 : AppColors.error50;
    final chipFg = isReady ? AppColors.success : AppColors.error;
    final borderColor = isReady
        ? AppColors.success.withValues(alpha: 0.28)
        : AppColors.error.withValues(alpha: 0.28);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: chipFg,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Call Readiness • $statusText',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: chipFg,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _toggleCallReadinessExpanded,
            borderRadius: AppRadii.borderRadiusPill,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: AppRadii.borderRadiusPill,
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isCallReadinessExpanded ? 'Ringkas' : 'Detail',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: chipFg,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _isCallReadinessExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: chipFg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyReadinessHeader() {
    final readiness = _callReadiness;
    final isReady = readiness?.ok == true;
    final statusText = readiness?.tierEligibleForCalling == false
        ? 'Not Ready • Tier Too Low'
        : (readiness?.statusLabel ?? 'Checking...');
    final chipBg = isReady ? AppColors.success50 : AppColors.error50;
    final chipFg = isReady ? AppColors.success : AppColors.error;
    final borderColor = isReady
        ? AppColors.success.withValues(alpha: 0.28)
        : AppColors.error.withValues(alpha: 0.28);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: chipFg,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Call Readiness • $statusText',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: chipFg,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _toggleCallReadinessExpanded,
            borderRadius: AppRadii.borderRadiusPill,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: AppRadii.borderRadiusPill,
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isCallReadinessExpanded ? 'Ringkas' : 'Detail',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: chipFg,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _isCallReadinessExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: chipFg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallReadinessPanelContent() {
    final readiness = _callReadiness;
    final statusText = readiness?.statusLabel ?? 'Checking...';
    final isReady = readiness?.ok == true;
    final statusBg = isReady ? AppColors.success50 : AppColors.error50;
    final statusFg = isReady ? AppColors.success : AppColors.error;
    final statusBorder = isReady
        ? AppColors.success.withValues(alpha: 0.28)
        : AppColors.error.withValues(alpha: 0.28);
    final cardTopColor = isReady
        ? AppColors.surfaceSecondary
        : AppColors.surfaceSecondary;
    final checksCount = readiness?.checks.length ?? 0;
    final hasMissingConfig = readiness?.missing.isNotEmpty == true;

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.borderRadiusXxl,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardTopColor, AppColors.surfaceSecondary],
        ),
        border: Border.all(color: statusBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: AppRadii.borderRadiusLg,
                  ),
                  child: Icon(
                    isReady
                        ? Icons.verified_rounded
                        : Icons.error_outline_rounded,
                    color: statusFg,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Call Readiness',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.neutral800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isReady
                            ? 'Sistem calling siap dipakai.'
                            : 'Masih ada hal yang perlu dibereskan sebelum mulai call.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: AppColors.neutral600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _isLoadingCallReadiness
                      ? null
                      : () => unawaited(_loadCallReadiness(forceRefresh: true)),
                  borderRadius: AppRadii.borderRadiusPill,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTertiary,
                      borderRadius: AppRadii.borderRadiusPill,
                    ),
                    child: Text(
                      _isLoadingCallReadiness ? 'Checking...' : 'Refresh',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neutral600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _hideCallReadinessCard,
                  borderRadius: AppRadii.borderRadiusPill,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTertiary,
                      borderRadius: AppRadii.borderRadiusPill,
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.neutral600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: AppRadii.borderRadiusPill,
                border: Border.all(color: statusBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusFg,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusFg,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (readiness != null &&
                ((readiness.eligibilityReason?.trim().isNotEmpty ?? false) ||
                    (readiness.messagingLimitTier?.trim().isNotEmpty ??
                        false) ||
                    (readiness.qualityRating?.trim().isNotEmpty ?? false)))
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: isReady
                      ? AppColors.surfaceSecondary
                      : AppColors.warning50,
                  borderRadius: AppRadii.borderRadiusLg,
                  border: Border.all(
                    color: isReady
                        ? AppColors.success.withValues(alpha: 0.28)
                        : AppColors.warning.withValues(alpha: 0.28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (readiness.eligibilityFromCache)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSecondary,
                              borderRadius: AppRadii.borderRadiusPill,
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Text(
                              readiness.eligibilityCacheTtlSeconds != null
                                  ? 'Cached • ${readiness.eligibilityCacheTtlSeconds}s TTL'
                                  : 'Cached',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.neutral600,
                              ),
                            ),
                          ),
                        if ((readiness.messagingLimitTier?.trim().isNotEmpty ??
                            false))
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSecondary,
                              borderRadius: AppRadii.borderRadiusPill,
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Text(
                              'Tier: ${readiness.messagingLimitTier}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.neutral600,
                              ),
                            ),
                          ),
                        if ((readiness.qualityRating?.trim().isNotEmpty ??
                            false))
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSecondary,
                              borderRadius: AppRadii.borderRadiusPill,
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Text(
                              'Quality: ${readiness.qualityRating}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.neutral600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if ((readiness.eligibilityReason?.trim().isNotEmpty ??
                        false)) ...[
                      const SizedBox(height: 10),
                      Text(
                        readiness.eligibilityReason!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                          color: const Color(0xFFFFCF73),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (readiness != null && readiness.eligibilityFromCache) ...[
              const SizedBox(height: 8),
              const Text(
                'Data eligibility saat ini berasal dari cache. Gunakan tombol Clear Eligibility Cache untuk memaksa pemeriksaan ulang dari Meta.',
                style: TextStyle(
                  fontSize: 11.8,
                  height: 1.4,
                  color: AppColors.neutral600,
                ),
              ),
            ],
            if (readiness == null && _isLoadingCallReadiness)
              const Text(
                'Sedang memeriksa backend dan pengaturan Meta...',
                style: TextStyle(fontSize: 13, color: AppColors.neutral600),
              ),
            if (readiness != null && !_isCallReadinessExpanded)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.surfaceTertiary,
                  borderRadius: AppRadii.borderRadiusLg,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  (readiness.eligibilityReason?.trim().isNotEmpty ?? false)
                      ? readiness.eligibilityReason!
                      : hasMissingConfig
                      ? 'Terdapat ${readiness.missing.length} konfigurasi yang belum lengkap dan $checksCount pemeriksaan readiness.'
                      : 'Tersedia $checksCount pemeriksaan readiness. Buka detail untuk melihat status lengkap.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.neutral600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (readiness != null && readiness.missing.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.warning50,
                        borderRadius: AppRadii.borderRadiusLg,
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        'Konfigurasi yang masih kurang: ${readiness.missing.join(', ')}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color: const Color(0xFFFFCF73),
                        ),
                      ),
                    ),
                  ],
                  if (readiness != null)
                    ...readiness.checks.map((check) {
                      final itemBg = check.ok
                          ? AppColors.surfaceSecondary
                          : AppColors.surfaceSecondary;
                      final itemBorder = check.ok
                          ? AppColors.success.withValues(alpha: 0.28)
                          : AppColors.error.withValues(alpha: 0.28);
                      final dotColor = check.ok
                          ? AppColors.success
                          : AppColors.error;

                      return Container(
                        margin: EdgeInsets.only(bottom: 10),
                        padding: EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: itemBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: itemBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              margin: EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    check.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.neutral800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    check.message,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: AppColors.neutral600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
              crossFadeState: _isCallReadinessExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
              sizeCurve: Curves.easeInOut,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoadingCallReadiness
                        ? null
                        : () => unawaited(_openMetaCallSettingsChecklist()),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: statusBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.borderRadiusLg,
                      ),
                      foregroundColor: AppColors.neutral800,
                    ),
                    icon: const Icon(Icons.checklist_rounded),
                    label: const Text(
                      'Open Meta Call Settings Checklist',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        (_isLoadingCallReadiness ||
                            _isClearingCallEligibilityCache)
                        ? null
                        : () => unawaited(_clearCallEligibilityCacheNow()),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.18),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.borderRadiusLg,
                      ),
                      foregroundColor: AppColors.error,
                    ),
                    icon: Icon(
                      _isClearingCallEligibilityCache
                          ? Icons.hourglass_top_rounded
                          : Icons.cleaning_services_rounded,
                    ),
                    label: Text(
                      _isClearingCallEligibilityCache
                          ? 'Clearing...'
                          : 'Clear Eligibility Cache',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedCallReadinessSection() {
    if (!_pinCallReadinessAboveCallCard) {
      return Container(
        margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: _buildCallReadinessPanelContent(),
      );
    }

    return Container(
      margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStickyReadinessHeader(),
          const SizedBox(height: 10),
          _buildCallReadinessPanelContent(),
        ],
      ),
    );
  }

  Widget _buildCallReadinessPanel() {
    return _buildPinnedCallReadinessSection();
  }

  Widget _buildFloatingHiddenCallChips() {
    // Call Readiness UI is disabled — do not render its restore chip.
    const canRestoreReadiness = false;
    final activeSession = _effectiveCallSession(
      _controller.selectedConversation,
    );
    final canRestoreActiveCallCard =
        !_showActiveCallCard && omnichannelShouldShowCallBanner(activeSession);

    if (!canRestoreReadiness && !canRestoreActiveCallCard) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final activeCallOffset = _clampBubbleOffset(
              _activeCallBubbleOffset,
              viewportSize: viewportSize,
              bubbleWidth: _floatingBubbleWidth,
              bubbleHeight: _floatingBubbleHeight,
            );

            return Stack(
              children: [
                // Call Readiness restore chip intentionally omitted.
                if (canRestoreActiveCallCard)
                  _buildDraggableFloatingRestoreBubble(
                    label: 'Kartu Panggilan',
                    icon: Icons.call_outlined,
                    offset: activeCallOffset,
                    baseRight: _floatingBubbleBaseRight,
                    baseBottom: _floatingBubbleBaseBottom,
                    onTap: _showActiveCallCardAgain,
                    onPanUpdate: (delta) =>
                        _updateActiveCallBubbleOffset(delta, viewportSize),
                    accentColor: const Color(0xFFFFCF73),
                    borderColor: AppColors.warning.withValues(alpha: 0.28),
                    iconBg: const Color(0xFFFFF8E8),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDraggableFloatingRestoreBubble({
    required String label,
    required IconData icon,
    required Offset offset,
    required double baseRight,
    required double baseBottom,
    required VoidCallback onTap,
    required ValueChanged<Offset> onPanUpdate,
    required Color accentColor,
    required Color borderColor,
    required Color iconBg,
  }) {
    return Positioned(
      right: baseRight - offset.dx,
      bottom: baseBottom - offset.dy,
      child: SafeArea(
        child: GestureDetector(
          onPanUpdate: (details) => onPanUpdate(details.delta),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadii.borderRadiusPill,
              child: Ink(
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadii.borderRadiusPill,
                  border: Border.all(color: borderColor),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: AppRadii.borderRadiusPill,
                        ),
                        child: Icon(icon, size: 15, color: accentColor),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.neutral600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.open_in_full_rounded,
                        size: 16,
                        color: accentColor.withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _callSuccessMessage(OmnichannelCallActionResult result) {
    return switch (result.callAction) {
      'permission_requested' => 'Permintaan izin panggilan berhasil dikirim.',
      'permission_still_pending' => 'Permission masih menunggu persetujuan.',
      'call_started' => 'Panggilan sedang diproses.',
      'call_already_processing' => 'Permintaan panggilan masih diproses.',
      _ =>
        result.message.trim().isNotEmpty
            ? result.message.trim()
            : 'Panggilan WhatsApp sedang diproses.',
    };
  }

  String _callErrorMessage(OmnichannelCallActionResult result) {
    return switch (result.callAction) {
      'permission_rate_limited' =>
        'Permintaan izin terlalu sering, coba lagi nanti.',
      'permission_denied' => 'Izin panggilan ditolak oleh pengguna.',
      'permission_expired' =>
        'Izin panggilan sudah kedaluwarsa dan perlu diminta ulang.',
      'call_blocked_configuration_error' =>
        'Konfigurasi panggilan belum lengkap. Aktifkan WhatsApp Calling API di Meta Business Manager (Phone Numbers → Calling) untuk nomor ini, lalu coba lagi.',
      'call_rate_limited' => 'Layanan panggilan sedang dibatasi sementara.',
      'duplicate_action' =>
        'Permintaan aksi panggilan yang sama masih diproses.',
      _ => _defaultCallErrorMessage(result),
    };
  }

  String _defaultCallErrorMessage(OmnichannelCallActionResult result) {
    final metaError = result.metaError ?? const <String, dynamic>{};
    final metaMessage = metaError['message']?.toString().trim();

    if (metaMessage != null && metaMessage.isNotEmpty) {
      final normalized = metaMessage.toLowerCase();

      if (normalized.contains('calling api not enabled') ||
          normalized.contains('calling is not enabled') ||
          normalized.contains('not enabled for this phone number')) {
        return 'Calling API belum aktif pada nomor ini. Aktifkan Call Settings nomor WhatsApp di Meta terlebih dahulu.';
      }

      return metaMessage;
    }

    final message = result.message.trim();
    if (message.isNotEmpty) {
      return message;
    }

    return 'Gagal memproses panggilan WhatsApp.';
  }

  bool _shouldOpenCallPageForFailure(OmnichannelCallActionResult result) {
    final callSession = result.callSession;
    if (callSession == null) {
      return false;
    }

    final metaCode = result.metaError?['code']?.toString().trim();
    if (metaCode == 'signaling_session_required') {
      return true;
    }

    if (<String?>{
      'permission_rate_limited',
      'permission_still_pending',
      'duplicate_action',
      'call_already_processing',
    }.contains(result.callAction)) {
      return true;
    }

    return callSession.isPermissionRequested ||
        (callSession.permissionStatus == 'granted' && !callSession.isFinished);
  }

  void _handleCallControllerChanged() {
    final previous = _lastObservedCallSession;
    final current = _callController.currentCall;
    _lastObservedCallSession = current;

    if (!mounted || previous == null || current == null) {
      return;
    }

    if ((previous.id ?? -1) != (current.id ?? -1)) {
      return;
    }

    if ((previous.status ?? '').trim() == (current.status ?? '').trim()) {
      return;
    }

    unawaited(_callAnalyticsController.refresh(silent: true));

    if (current.isRejected) {
      _showSnackBar('Panggilan ditolak pengguna.');
      return;
    }

    if (current.isMissed) {
      _showSnackBar('Panggilan tidak dijawab.');
      return;
    }

    if (current.isEnded) {
      _showSnackBar('Panggilan berakhir.');
      return;
    }

    if (current.isFailed) {
      _showSnackBar(
        current.endReason?.trim().isNotEmpty == true
            ? 'Panggilan gagal: ${omnichannelCallEndReasonLabel(current.endReason)}'
            : 'Panggilan gagal.',
      );
    }
  }

  Future<void> _retryBootstrap() {
    _hasRedirected = false;
    return _controller.initialize(initialUser: widget.initialUser);
  }

  Future<void> _openStarredMessages() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            OmnichannelStarredMessagesPage(repository: widget.repository),
      ),
    );
  }

  Future<void> _openConversationCallHistory() async {
    final conversation = _controller.selectedConversation;
    final conversationId = conversation?.id;

    if (conversation == null || conversationId == null || conversationId <= 0) {
      _showSnackBar('Conversation belum dipilih.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OmnichannelCallHistoryPage(
          repository: widget.repository,
          conversationId: conversationId,
          conversationTitle: conversation.title,
          initialSummary: conversation.callHistorySummary,
          initialItems: conversation.callHistory,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _controller.softRefreshAfterExternalAction();
    _syncCallBinding(forceStartPolling: true);
  }

  Future<bool> _sendAdminReply(String message) async {
    final conversationId = _controller.selectedConversation?.id;
    if (conversationId == null || conversationId <= 0) {
      _showSnackBar('Conversation belum dipilih.');
      return false;
    }

    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      _showSnackBar('Pesan tidak boleh kosong.');
      return false;
    }

    if (_isSendingReply) {
      return false;
    }

    setState(() => _isSendingReply = true);

    try {
      final notice = await widget.repository.sendAdminReply(
        conversationId: conversationId,
        message: trimmed,
        replyToMessageId: _activeReplyTo?.id,
      );

      await _controller.softRefreshAfterExternalAction();

      if (mounted) {
        _showSnackBar(notice);
      }

      if (mounted) {
        setState(() {
          _replyingTo = null;
          _replyingToConversationId = null;
        });
      }

      return true;
    } on ApiException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
      return false;
    } catch (error) {
      if (mounted) {
        _showSnackBar('Gagal mengirim balasan admin: $error');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSendingReply = false);
      }
    }
  }

  Future<bool> _sendAdminGalleryImage(String? caption) async {
    return _sendAdminImage(caption, ImageSource.gallery);
  }

  Future<bool> _sendAdminCameraImage(String? caption) async {
    return _sendAdminImage(caption, ImageSource.camera);
  }

  Future<bool> _sendAdminImage(String? caption, ImageSource source) async {
    final conversation = _controller.selectedConversation;
    final conversationId = conversation?.id;

    if (conversationId == null || conversationId <= 0) {
      _showSnackBar('Conversation belum dipilih.');
      return false;
    }

    if (conversation?.channel != 'whatsapp') {
      _showSnackBar('Galeri saat ini hanya aktif untuk conversation WhatsApp.');
      return false;
    }

    if (_isSendingReply || _isSendingContact) {
      return false;
    }

    final pickedImage = await _imagePicker.pickImage(
      source: source,
      imageQuality: 92,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (pickedImage == null) {
      return false;
    }

    final normalizedMimeType = _normalizeSendableImageMimeType(
      pickedImage.mimeType,
      pickedImage.name,
    );

    if (normalizedMimeType == null) {
      _showSnackBar(
        'Format gambar ini belum didukung untuk kirim WhatsApp. Gunakan JPG atau PNG.',
      );
      return false;
    }

    final fileBytes = await pickedImage.readAsBytes();
    if (fileBytes.isEmpty) {
      _showSnackBar('File gambar kosong atau gagal dibaca.');
      return false;
    }

    final normalizedFileName = _normalizedImageFileName(
      pickedImage.name,
      normalizedMimeType,
    );

    setState(() => _isSendingReply = true);

    try {
      final notice = await widget.repository.sendAdminImageReply(
        conversationId: conversationId,
        fileBytes: fileBytes,
        fileName: normalizedFileName,
        caption: caption,
        mimeType: normalizedMimeType,
        replyToMessageId: _activeReplyTo?.id,
      );

      await _controller.softRefreshAfterExternalAction();

      if (mounted) {
        _showSnackBar(notice);
      }

      if (mounted) {
        setState(() {
          _replyingTo = null;
          _replyingToConversationId = null;
        });
      }

      return true;
    } on ApiException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
      return false;
    } catch (error) {
      if (mounted) {
        final sourceLabel = source == ImageSource.camera ? 'kamera' : 'galeri';
        _showSnackBar('Gagal mengirim gambar dari $sourceLabel: $error');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSendingReply = false);
      }
    }
  }

  String? _normalizeSendableImageMimeType(String? mimeType, String fileName) {
    final normalized = (mimeType ?? _mimeTypeFromFileName(fileName) ?? '')
        .trim()
        .toLowerCase();

    return switch (normalized) {
      'image/jpeg' || 'image/jpg' || 'image/pjpeg' => 'image/jpeg',
      'image/png' => 'image/png',
      _ => null,
    };
  }

  String _normalizedImageFileName(String fileName, String mimeType) {
    final trimmed = fileName.trim();
    final fallbackExtension = mimeType == 'image/png' ? 'png' : 'jpg';

    if (trimmed.isEmpty) {
      return 'whatsapp-image.$fallbackExtension';
    }

    final lastDot = trimmed.lastIndexOf('.');
    if (lastDot <= 0 || lastDot == trimmed.length - 1) {
      return '$trimmed.$fallbackExtension';
    }

    final ext = trimmed.substring(lastDot + 1).toLowerCase();
    if (mimeType == 'image/jpeg' && (ext == 'jpg' || ext == 'jpeg')) {
      return trimmed;
    }
    if (mimeType == 'image/png' && ext == 'png') {
      return trimmed;
    }

    final baseName = trimmed.substring(0, lastDot);
    return '$baseName.$fallbackExtension';
  }

  String? _mimeTypeFromFileName(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) {
      return null;
    }

    final ext = parts.last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      _ => null,
    };
  }

  Future<bool> _sendAdminGalleryVideo(String? caption) async {
    return _sendAdminVideo(caption, ImageSource.gallery);
  }

  Future<bool> _sendAdminCameraVideo(String? caption) async {
    return _sendAdminVideo(caption, ImageSource.camera);
  }

  Future<bool> _sendAdminVideo(String? caption, ImageSource source) async {
    final conversation = _controller.selectedConversation;
    final conversationId = conversation?.id;

    if (conversationId == null || conversationId <= 0) {
      _showSnackBar('Conversation belum dipilih.');
      return false;
    }

    if (conversation?.channel != 'whatsapp') {
      _showSnackBar('Video saat ini hanya aktif untuk conversation WhatsApp.');
      return false;
    }

    if (_isSendingReply || _isSendingContact) {
      return false;
    }

    final pickedVideo = await _imagePicker.pickVideo(
      source: source,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (pickedVideo == null) {
      return false;
    }

    final normalizedMimeType = _normalizeSendableVideoMimeType(
      pickedVideo.mimeType,
      pickedVideo.name,
    );

    if (normalizedMimeType == null) {
      _showSnackBar(
        'Format video ini belum didukung untuk kirim WhatsApp. Gunakan MP4.',
      );
      return false;
    }

    // WhatsApp video size limit: 16 MB (mirror precedent dokumen :2156-2161).
    const int maxBytes = 16 * 1024 * 1024;

    // R1 (DEC-APP-1) — pre-check ukuran SEBELUM readAsBytes (cegah OOM saat
    // admin pilih video besar). BE tetap otoritas final.
    final fileLength = await pickedVideo.length();
    if (fileLength > maxBytes) {
      _showSnackBar('Video maksimal 16MB. Kompres atau kirim sebagai dokumen.');
      return false;
    }

    final fileBytes = await pickedVideo.readAsBytes();
    if (fileBytes.isEmpty) {
      _showSnackBar('File video kosong atau gagal dibaca.');
      return false;
    }

    // Safety net pasca-read (platform yang length()-nya tak akurat).
    if (fileBytes.length > maxBytes) {
      _showSnackBar('Video maksimal 16MB. Kompres atau kirim sebagai dokumen.');
      return false;
    }

    final normalizedFileName = _normalizedVideoFileName(
      pickedVideo.name,
      normalizedMimeType,
    );

    setState(() => _isSendingReply = true);

    try {
      final notice = await widget.repository.sendAdminVideoReply(
        conversationId: conversationId,
        fileBytes: fileBytes,
        fileName: normalizedFileName,
        caption: caption,
        mimeType: normalizedMimeType,
        replyToMessageId: _activeReplyTo?.id,
      );

      await _controller.softRefreshAfterExternalAction();

      if (mounted) {
        _showSnackBar(notice);
      }

      if (mounted) {
        setState(() {
          _replyingTo = null;
          _replyingToConversationId = null;
        });
      }

      return true;
    } on ApiException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
      return false;
    } catch (error) {
      if (mounted) {
        final sourceLabel = source == ImageSource.camera ? 'kamera' : 'galeri';
        _showSnackBar('Gagal mengirim video dari $sourceLabel: $error');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSendingReply = false);
      }
    }
  }

  String? _normalizeSendableVideoMimeType(String? mimeType, String fileName) {
    final normalized = (mimeType ?? '').trim().toLowerCase();
    final byMime = switch (normalized) {
      'video/mp4' => 'video/mp4',
      'video/3gpp' || 'video/3gp' => 'video/3gpp',
      'video/quicktime' || 'video/mov' => 'video/quicktime',
      _ => null,
    };
    if (byMime != null) {
      return byMime;
    }

    // Fallback ekstensi (Android galeri sering mimeType null).
    final parts = fileName.split('.');
    if (parts.length < 2) {
      return null;
    }
    return switch (parts.last.toLowerCase()) {
      'mp4' || 'm4v' => 'video/mp4',
      '3gp' || '3gpp' => 'video/3gpp',
      'mov' || 'qt' => 'video/quicktime',
      _ => null,
    };
  }

  String _normalizedVideoFileName(String fileName, String mimeType) {
    final trimmed = fileName.trim();
    final fallbackExtension = switch (mimeType) {
      'video/3gpp' => '3gp',
      'video/quicktime' => 'mov',
      _ => 'mp4',
    };

    if (trimmed.isEmpty) {
      return 'whatsapp-video.$fallbackExtension';
    }

    final lastDot = trimmed.lastIndexOf('.');
    if (lastDot <= 0 || lastDot == trimmed.length - 1) {
      return '$trimmed.$fallbackExtension';
    }

    final ext = trimmed.substring(lastDot + 1).toLowerCase();
    if (mimeType == 'video/mp4' && (ext == 'mp4' || ext == 'm4v')) {
      return trimmed;
    }
    if (mimeType == 'video/3gpp' && (ext == '3gp' || ext == '3gpp')) {
      return trimmed;
    }
    if (mimeType == 'video/quicktime' && (ext == 'mov' || ext == 'qt')) {
      return trimmed;
    }

    final baseName = trimmed.substring(0, lastDot);
    return '$baseName.$fallbackExtension';
  }

  Future<bool> _toggleBot(bool turnOn) async {
    final conversationId = _controller.selectedConversation?.id;
    if (conversationId == null || conversationId <= 0 || _isTogglingBot) {
      return false;
    }

    setState(() => _isTogglingBot = true);

    try {
      final notice = turnOn
          ? await widget.repository.turnBotOn(conversationId: conversationId)
          : await widget.repository.turnBotOff(
              conversationId: conversationId,
              autoResumeMinutes: 15,
            );

      await _controller.softRefreshAfterExternalAction();

      if (mounted) {
        _showSnackBar(notice);
      }
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
      return false;
    } catch (error) {
      if (mounted) {
        _showSnackBar('Gagal mengubah status bot: $error');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isTogglingBot = false);
      }
    }
  }

  Future<bool> _cancelVoiceNoteRecording() async {
    if (!_isRecordingVoiceNote) {
      return false;
    }

    try {
      await _audioRecorder.stop();
    } catch (_) {
      // abaikan error stop saat batal
    }

    if (mounted) {
      setState(() => _isRecordingVoiceNote = false);
      _showSnackBar('Rekaman voice note dibatalkan.');
    }

    return true;
  }

  Future<bool> _toggleVoiceNoteRecording() async {
    final conversation = _controller.selectedConversation;
    final conversationId = conversation?.id;

    if (conversationId == null || conversationId <= 0) {
      _showSnackBar('Conversation belum dipilih.');
      return false;
    }

    if (conversation?.channel != 'whatsapp') {
      _showSnackBar(
        'Voice note saat ini hanya aktif untuk conversation WhatsApp.',
      );
      return false;
    }

    if (_isSendingReply || _isSendingContact) {
      return false;
    }

    try {
      if (_isRecordingVoiceNote) {
        final path = await _audioRecorder.stop();

        if (mounted) {
          setState(() => _isRecordingVoiceNote = false);
        }

        if (path == null || path.trim().isEmpty) {
          _showSnackBar('Rekaman voice note kosong atau gagal disimpan.');
          return false;
        }

        final file = XFile(path);
        final fileBytes = await file.readAsBytes();

        if (fileBytes.isEmpty) {
          _showSnackBar('File voice note kosong atau gagal dibaca.');
          return false;
        }

        final guessedMimeType = _normalizeVoiceMimeType(
          file.mimeType,
          file.name,
        );

        final normalizedName = _normalizedVoiceFileName(
          file.name,
          guessedMimeType,
        );

        debugPrint('VOICE NOTE SEND START');
        debugPrint('VOICE NOTE PATH => $path');
        debugPrint('VOICE NOTE FILE NAME => ${file.name}');
        debugPrint('VOICE NOTE MIME => $guessedMimeType');
        debugPrint('VOICE NOTE BYTES => ${fileBytes.length}');
        debugPrint('VOICE NOTE CONVERSATION ID => $conversationId');

        if (mounted) {
          setState(() => _isSendingReply = true);
        }

        try {
          final notice = await widget.repository.sendAdminAudioReply(
            conversationId: conversationId,
            fileBytes: fileBytes,
            fileName: normalizedName,
            mimeType: guessedMimeType,
            replyToMessageId: _activeReplyTo?.id,
          );

          debugPrint('VOICE NOTE SEND SUCCESS => $notice');

          await _controller.softRefreshAfterExternalAction();

          if (mounted) {
            _showSnackBar(notice);
          }

          if (mounted) {
            setState(() {
              _replyingTo = null;
              _replyingToConversationId = null;
            });
          }

          return true;
        } on ApiException catch (error) {
          final details = _buildApiErrorDetails(
            error,
            title: 'VOICE NOTE API ERROR',
          );

          debugPrint(details);

          if (mounted) {
            _showSnackBar(
              error.statusCode != null
                  ? 'VOICE NOTE ${error.statusCode}: ${error.message}'
                  : 'VOICE NOTE: ${error.message}',
            );
          }

          return false;
        } catch (error, stackTrace) {
          debugPrint('VOICE NOTE UNEXPECTED ERROR => $error');
          debugPrintStack(stackTrace: stackTrace);

          if (mounted) {
            _showSnackBar('Gagal mengirim voice note: $error');
          }
          return false;
        } finally {
          if (mounted) {
            setState(() => _isSendingReply = false);
          }
        }
      }

      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _showSnackBar('Izin mikrofon belum diberikan.');
        return false;
      }

      final tempPath =
          '${Directory.systemTemp.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: tempPath,
      );

      debugPrint('VOICE NOTE RECORDING START => $tempPath');

      if (mounted) {
        setState(() => _isRecordingVoiceNote = true);
      }

      return false;
    } catch (error, stackTrace) {
      debugPrint('VOICE NOTE PROCESS ERROR => $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() => _isRecordingVoiceNote = false);
        _showSnackBar('Gagal memproses voice note: $error');
      }
      return false;
    }
  }

  String _normalizeVoiceMimeType(String? mimeType, String fileName) {
    final normalized =
        (mimeType ?? _mimeTypeFromFileName(fileName) ?? 'audio/ogg')
            .trim()
            .toLowerCase();

    return switch (normalized) {
      'audio/ogg' || 'audio/opus' || 'application/ogg' => 'audio/ogg',
      'audio/mpeg' || 'audio/mp3' => 'audio/mpeg',
      'audio/mp4' || 'audio/aac' || 'audio/x-m4a' => 'audio/mp4',
      _ => 'audio/ogg',
    };
  }

  String _normalizedVoiceFileName(String fileName, String mimeType) {
    final trimmed = fileName.trim();
    final fallbackExtension = mimeType == 'audio/mpeg'
        ? 'mp3'
        : (mimeType == 'audio/mp4' ? 'm4a' : 'ogg');

    if (trimmed.isEmpty) {
      return 'voice-note.$fallbackExtension';
    }

    final lastDot = trimmed.lastIndexOf('.');
    if (lastDot <= 0 || lastDot == trimmed.length - 1) {
      return '$trimmed.$fallbackExtension';
    }

    final baseName = trimmed.substring(0, lastDot);
    return '$baseName.$fallbackExtension';
  }

  Future<bool> _sendAdminDocument(String? caption) async {
    final conversation = _controller.selectedConversation;
    final conversationId = conversation?.id;

    if (conversationId == null || conversationId <= 0) {
      _showSnackBar('Conversation belum dipilih.');
      return false;
    }

    if (conversation?.channel != 'whatsapp') {
      _showSnackBar(
        'Dokumen saat ini hanya aktif untuk conversation WhatsApp.',
      );
      return false;
    }

    if (_isSendingReply || _isSendingContact) {
      return false;
    }

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
    } catch (error) {
      _showSnackBar('Gagal membuka pemilih file: $error');
      return false;
    }

    if (picked == null || picked.files.isEmpty) {
      return false;
    }

    final pickedFile = picked.files.first;
    final fileName = pickedFile.name;
    List<int> fileBytes;
    final initialBytes = pickedFile.bytes;

    if (initialBytes != null && initialBytes.isNotEmpty) {
      fileBytes = initialBytes;
    } else if (pickedFile.path != null) {
      try {
        fileBytes = await File(pickedFile.path!).readAsBytes();
      } catch (error) {
        _showSnackBar('Gagal membaca file dokumen: $error');
        return false;
      }
    } else {
      _showSnackBar('File dokumen kosong atau gagal dibaca.');
      return false;
    }

    if (fileBytes.isEmpty) {
      _showSnackBar('File dokumen kosong atau gagal dibaca.');
      return false;
    }

    // WhatsApp document size limit: 100 MB
    const int maxBytes = 100 * 1024 * 1024;
    if (fileBytes.length > maxBytes) {
      _showSnackBar('Ukuran dokumen melebihi 100 MB. Pilih file lebih kecil.');
      return false;
    }

    final mimeType = _mimeTypeFromFileName(fileName);

    setState(() => _isSendingReply = true);

    try {
      final notice = await widget.repository.sendAdminDocumentReply(
        conversationId: conversationId,
        fileBytes: fileBytes,
        fileName: fileName,
        caption: caption,
        mimeType: mimeType,
        replyToMessageId: _activeReplyTo?.id,
      );

      await _controller.softRefreshAfterExternalAction();

      if (mounted) {
        _showSnackBar(notice);
      }

      if (mounted) {
        setState(() {
          _replyingTo = null;
          _replyingToConversationId = null;
        });
      }

      return true;
    } on ApiException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
      return false;
    } catch (error) {
      if (mounted) {
        _showSnackBar('Gagal mengirim dokumen: $error');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSendingReply = false);
      }
    }
  }

  Future<bool> _sendAdminLocation({
    required double latitude,
    required double longitude,
    String? locationName,
    String? locationAddress,
  }) async {
    if (_activeReplyTo != null) {
      _showSnackBar('Batalkan balasan dulu untuk kirim lokasi/kontak.');
      return false;
    }

    final conversation = _controller.selectedConversation;
    final conversationId = conversation?.id;

    if (conversationId == null || conversationId <= 0) {
      _showSnackBar('Conversation belum dipilih.');
      return false;
    }

    if (conversation?.channel != 'whatsapp') {
      _showSnackBar('Lokasi saat ini hanya aktif untuk conversation WhatsApp.');
      return false;
    }

    if (_isSendingReply || _isSendingContact) {
      return false;
    }

    setState(() => _isSendingReply = true);

    try {
      final notice = await widget.repository.sendAdminLocationReply(
        conversationId: conversationId,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
        locationAddress: locationAddress,
      );

      await _controller.softRefreshAfterExternalAction();

      if (mounted) {
        _showSnackBar(notice);
      }

      return true;
    } on ApiException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
      return false;
    } catch (error) {
      if (mounted) {
        _showSnackBar('Gagal mengirim lokasi: $error');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSendingReply = false);
      }
    }
  }

  Future<void> _saveDeviceContact() async {
    final conversation = _controller.selectedConversation;
    if (conversation == null) {
      return;
    }

    final contact = conversation.customerContact.trim();
    final conversationId = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => OmnichannelCreateContactPage(
          repository: widget.repository,
          initialFirstName: conversation.customerName,
          initialPhone: contact == '-' ? '' : contact,
        ),
      ),
    );

    if (conversationId != null && mounted) {
      unawaited(_controller.refresh());
    }
  }

  Future<bool> _sendAdminContact({
    required String fullName,
    required String phone,
    String? email,
    String? company,
  }) async {
    if (_activeReplyTo != null) {
      _showSnackBar('Batalkan balasan dulu untuk kirim lokasi/kontak.');
      return false;
    }

    final conversationId = _controller.selectedConversation?.id;
    if (conversationId == null || conversationId <= 0) {
      _showSnackBar('Conversation belum dipilih.');
      return false;
    }

    if (_isSendingContact) {
      return false;
    }

    setState(() => _isSendingContact = true);

    try {
      final notice = await widget.repository.sendAdminContact(
        conversationId: conversationId,
        fullName: fullName.trim(),
        phone: phone.trim(),
        email: email?.trim().isEmpty == true ? null : email?.trim(),
        company: company?.trim().isEmpty == true ? null : company?.trim(),
      );

      await _controller.softRefreshAfterExternalAction();

      if (mounted) {
        _showSnackBar(notice);
      }

      return true;
    } on ApiException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
      return false;
    } catch (error) {
      if (mounted) {
        _showSnackBar('Gagal mengirim kontak: $error');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSendingContact = false);
      }
    }
  }

  Future<void> _handleReactToMessage(int messageId, String emoji) async {
    final status = await _controller.reactToMessage(
      messageId: messageId,
      emoji: emoji,
    );
    if (!mounted) {
      return;
    }
    if (status != 'sent') {
      _showSnackBar(_reactionFeedbackMessage(status));
    }
  }

  String _reactionFeedbackMessage(String status) {
    if (status == 'skipped') {
      return 'Reaksi tidak didukung untuk pesan ini.';
    }
    return 'Gagal mengirim reaksi.';
  }

  Future<void> _handleToggleStar(int messageId, bool currentlyStarred) async {
    final ok = await _controller.toggleStar(
      messageId: messageId,
      currentlyStarred: currentlyStarred,
    );
    if (!mounted) {
      return;
    }
    if (!ok) {
      _showSnackBar('Gagal memperbarui bintang pesan.');
      return;
    }
    await _controller.softRefreshAfterExternalAction();
  }

  Future<void> _handleResendSticker(int sourceMessageId) async {
    try {
      final result = await _controller.resendSticker(
        sourceMessageId: sourceMessageId,
      );
      if (!mounted) {
        return;
      }
      if (result == 'failed' || result == 'skipped') {
        _showSnackBar(_resendStickerFeedbackMessage(result));
        return;
      }
      await _controller.softRefreshAfterExternalAction();
      if (mounted) {
        _showSnackBar(result);
      }
    } on ApiException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('Gagal mengirim ulang stiker: $error');
      }
    }
  }

  Future<void> _handleSaveSticker(int sourceMessageId) async {
    try {
      final result = await _controller.saveStickerFavorite(
        sourceMessageId: sourceMessageId,
      );
      if (mounted) {
        _showSnackBar(result);
      }
    } on ApiException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('Gagal menyimpan stiker: $error');
      }
    }
  }

  String _resendStickerFeedbackMessage(String status) {
    if (status == 'skipped') {
      return 'Kirim ulang stiker hanya untuk percakapan WhatsApp.';
    }
    return 'Gagal mengirim ulang stiker.';
  }

  Future<void> _handleOpenStickerPicker() async {
    await showStickerPickerSheet(
      context: context,
      onLoad: _controller.loadStickerFavorites,
      onPick: (favoriteId) => unawaited(_handleSendStickerFavorite(favoriteId)),
    );
  }

  Future<void> _handleSendStickerFavorite(int favoriteId) async {
    try {
      final result = await _controller.sendStickerFavorite(
        favoriteId: favoriteId,
      );
      if (!mounted) {
        return;
      }
      if (result == 'failed' || result == 'skipped') {
        _showSnackBar(_sendStickerFavoriteFeedbackMessage(result));
        return;
      }
      await _controller.softRefreshAfterExternalAction();
      if (mounted) {
        _showSnackBar(result);
      }
    } on ApiException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('Gagal mengirim stiker favorit: $error');
      }
    }
  }

  String _sendStickerFavoriteFeedbackMessage(String status) {
    if (status == 'skipped') {
      return 'Kirim stiker favorit hanya untuk percakapan WhatsApp.';
    }
    return 'Gagal mengirim stiker favorit.';
  }

  Future<void> _handleSendRouteCarousel() async {
    try {
      final result = await _controller.sendRouteCarousel();
      if (!mounted) {
        return;
      }
      if (result == 'failed' || result == 'skipped') {
        _showSnackBar(_sendRouteCarouselFeedbackMessage(result));
        return;
      }
      await _controller.softRefreshAfterExternalAction();
      if (mounted) {
        _showSnackBar(result);
      }
    } on ApiException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('Gagal mengirim daftar rute: $error');
      }
    }
  }

  Future<void> _handleSendPayment(String paymentType) async {
    try {
      final result = await _controller.sendPayment(paymentType);
      if (!mounted) {
        return;
      }
      if (result == 'failed' || result == 'skipped') {
        _showSnackBar(_paymentFeedbackMessage(result));
        return;
      }
      await _controller.softRefreshAfterExternalAction();
      if (mounted) {
        _showSnackBar(result);
      }
    } on ApiException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('Gagal mengirim instruksi pembayaran: $error');
      }
    }
  }

  Future<void> _handleSendPaymentQris() async {
    if (AppConfig.manualPaymentComposeEnabled) {
      await _openComposeDialog('qris');
    } else {
      await _handleSendPayment('qris');
    }
  }

  Future<void> _handleSendPaymentNorek() async {
    if (AppConfig.manualPaymentComposeEnabled) {
      await _openComposeDialog('norek');
    } else {
      await _handleSendPayment('norek');
    }
  }

  Future<void> _openComposeDialog(String paymentType) async {
    final result = await showDialog<ManualPaymentComposeResult>(
      context: context,
      builder: (dialogContext) {
        return ManualPaymentComposeDialog(
          paymentType: paymentType,
          onFetchBookings: _controller.fetchComposeBookings,
        );
      },
    );
    if (result == null) {
      return;
    }
    try {
      final message = await _controller.sendComposedPayment(
        paymentType: paymentType,
        bookingCode: result.bookingCode,
        total: result.total,
        loket: result.loket,
      );
      if (!mounted) {
        return;
      }
      if (message == 'failed' || message == 'skipped') {
        _showSnackBar(_paymentFeedbackMessage(message));
        return;
      }
      await _controller.softRefreshAfterExternalAction();
      if (mounted) {
        _showSnackBar(message);
      }
    } on ApiException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('Gagal mengirim instruksi pembayaran: $error');
      }
    }
  }

  String _paymentFeedbackMessage(String status) {
    if (status == 'skipped') {
      return 'Kirim pembayaran hanya untuk percakapan WhatsApp.';
    }
    return 'Gagal mengirim instruksi pembayaran.';
  }

  String _sendRouteCarouselFeedbackMessage(String status) {
    if (status == 'skipped') {
      return 'Kirim daftar rute hanya untuk percakapan WhatsApp.';
    }
    return 'Gagal mengirim daftar rute.';
  }

  Future<void> _handleForward(int messageId) async {
    await showForwardTargetPickerSheet(
      context: context,
      items: _controller.conversationsForForwardPicker,
      onPick: (targetConversationId) =>
          unawaited(_handleForwardToTarget(messageId, targetConversationId)),
    );
  }

  Future<void> _handleForwardToTarget(
    int messageId,
    int targetConversationId,
  ) async {
    final ok = await _controller.forwardMessage(
      messageId: messageId,
      targetConversationId: targetConversationId,
    );
    if (!mounted) {
      return;
    }
    _showSnackBar(ok ? 'Pesan diteruskan.' : 'Gagal meneruskan pesan.');
  }

  void _showSnackBar(String message) {
    final text = message.trim();
    if (text.isEmpty || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 6)),
      );
  }

  String _buildApiErrorDetails(
    ApiException error, {
    String title = 'API ERROR',
  }) {
    final lines = <String>[
      title,
      if (error.statusCode != null) 'Status: ${error.statusCode}',
      'Message: ${error.message}',
      if (error.payload != null) 'Payload: ${error.payload}',
      if (error.rawBody != null && error.rawBody!.trim().isNotEmpty)
        'Raw: ${error.rawBody}',
    ];

    return lines.join('\n');
  }

  void _setMobilePane(_OmnichannelMobilePane pane) {
    if (_mobilePane == pane || !mounted) {
      return;
    }

    setState(() => _mobilePane = pane);
  }

  /// Callback dari [OmnichannelShellController] saat ada pesan masuk baru
  /// terdeteksi dari poll cycle. Menampilkan in-app notification banner
  /// gaya WhatsApp di bagian atas layar.
  void _handleChatNotification(ChatNotificationEvent event) {
    if (!mounted) return;

    InAppNotificationOverlay.instance.showSummary(
      context: context,
      newMessageCount: event.totalNewCount,
      firstSenderName: event.senderName,
      firstSenderPreview: event.preview,
      onTap: () {
        if (!mounted) return;
        _handleConversationTap(
          event.conversationId,
          showConversationOnMobile: true,
        );
      },
    );
  }

  void _handleConversationTap(
    int conversationId, {
    required bool showConversationOnMobile,
  }) {
    final currentConversationId = _controller.selectedConversation?.id;
    if (_replyingTo != null && currentConversationId != conversationId) {
      setState(() {
        _replyingTo = null;
        _replyingToConversationId = null;
      });
    }

    if (showConversationOnMobile) {
      _setMobilePane(_OmnichannelMobilePane.conversation);
    }

    unawaited(_controller.selectConversation(conversationId));
  }

  void _handleConversationLongPress(int conversationId) {
    final item = _findConversationItem(conversationId);
    final isPinned = item?.isPinned ?? false;
    final isMuted = item?.isMuted ?? false;
    // coupling: BE ConversationStatus::Archived->label() == 'Archived'.
    // Scope 'all'/'closed' memuat archived → derive juga dari statusLabel,
    // bukan scope saja (lihat PCAC 3D v2 OQ-A4').
    final isArchived =
        _controller.scopeFilter == 'archived' ||
        (item?.statusLabel.trim().toLowerCase() == 'archived');
    showConversationActionSheet(
      context: context,
      onMarkUnread: () => unawaited(_controller.markUnread(conversationId)),
      onManageLabel: () => unawaited(_handleManageLabel(conversationId)),
      isPinned: isPinned,
      onTogglePin: () => unawaited(
        isPinned
            ? _controller.unpin(conversationId)
            : _controller.pin(conversationId),
      ),
      isArchived: isArchived,
      onToggleArchive: () => unawaited(
        isArchived
            ? _controller.unarchive(conversationId)
            : _controller.archive(conversationId),
      ),
      isMuted: isMuted,
      onToggleMute: () => unawaited(
        isMuted
            ? _controller.unmute(conversationId)
            : _controller.mute(conversationId),
      ),
    );
  }

  OmnichannelConversationListItemModel? _findConversationItem(
    int conversationId,
  ) {
    final items =
        _controller.conversationList?.items ??
        const <OmnichannelConversationListItemModel>[];
    for (final item in items) {
      if (item.id == conversationId) {
        return item;
      }
    }
    return null;
  }

  Future<void> _handleManageLabel(int conversationId) async {
    final result = await showDialog<_LabelDialogResult>(
      context: context,
      builder: (dialogContext) {
        return _ManageLabelDialog(
          findItem: () => _findConversationItem(conversationId),
        );
      },
    );

    if (result == null) {
      return;
    }

    if (result.type == _LabelActionType.add) {
      await _controller.addLabel(conversationId, result.tag);
    } else {
      await _controller.removeLabel(conversationId, result.tag);
    }

    if (mounted) {
      _showSnackBar(
        'Permintaan label diproses. Daftar diperbarui setelah sinkronisasi.',
      );
    }
  }

  Widget _buildAdaptiveShell({
    required BoxConstraints constraints,
    required OmnichannelWorkspaceModel workspace,
    required OmnichannelConversationListModel? conversationList,
    required bool shellLoading,
  }) {
    final items =
        conversationList?.items ??
        const <OmnichannelConversationListItemModel>[];
    final selectedConversationId = conversationList?.selectedConversationId;
    final useWhatsAppReferenceShell = kIsWeb || constraints.maxWidth < 960;

    if (useWhatsAppReferenceShell) {
      final mobileShell = _buildMobileShell(
        workspace: workspace,
        items: items,
        selectedConversationId: selectedConversationId,
        shellLoading: shellLoading,
      );

      if (kIsWeb && constraints.maxWidth > 420) {
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 392,
            height: constraints.maxHeight,
            child: mobileShell,
          ),
        );
      }

      return mobileShell;
    }

    return _buildDesktopShell(
      constraints: constraints,
      workspace: workspace,
      items: items,
      selectedConversationId: selectedConversationId,
      shellLoading: shellLoading,
    );
  }

  Widget _buildCenterPaneWithPinnedReadiness({required Widget child}) {
    if (!_pinCallReadinessAboveCallCard) {
      return child;
    }

    final topSpacing = _showCallReadinessCard ? 12.0 : 0.0;

    return Column(
      children: [
        if (_showCallReadinessCard) _buildCallReadinessPanel(),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: topSpacing),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopShell({
    required BoxConstraints constraints,
    required OmnichannelWorkspaceModel workspace,
    required List<OmnichannelConversationListItemModel> items,
    required int? selectedConversationId,
    required bool shellLoading,
  }) {
    final gap = constraints.maxWidth >= 1440 ? 20.0 : 16.0;
    final leftWidth = constraints.maxWidth >= 1440 ? 360.0 : 336.0;
    final rightWidth = constraints.maxWidth >= 1440 ? 340.0 : 320.0;
    final minShellWidth = leftWidth + rightWidth + 540 + (gap * 2);
    final shellWidth = max(constraints.maxWidth, minShellWidth);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: shellWidth,
        height: constraints.maxHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: leftWidth,
              child: OmnichannelLeftPane(
                workspace: workspace,
                items: items,
                selectedConversationId: selectedConversationId,
                scrollController: _conversationListScrollController,
                searchController: _searchController,
                selectedScope: _controller.scopeFilter,
                selectedChannel: _controller.channelFilter,
                onScopeChanged: _controller.setScopeFilter,
                onChannelChanged: _controller.setChannelFilter,
                selectedTag: _controller.tagFilter,
                onTagChanged: _controller.setTagFilter,
                onConversationTap: (conversationId) => _handleConversationTap(
                  conversationId,
                  showConversationOnMobile: false,
                ),
                onConversationLongPress: AppConfig.chatManagementEnabled
                    ? _handleConversationLongPress
                    : null,
                isLoading: shellLoading,
                isLoadingMore: _controller.isLoadingMore,
                hasMore: _controller.hasMoreConversations,
                repository: widget.repository,
                onContactSaved: () => unawaited(_controller.refresh()),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _buildCenterPaneWithPinnedReadiness(
                child: OmnichannelCenterPane(
                  onReactToMessage: (messageId, emoji) =>
                      unawaited(_handleReactToMessage(messageId, emoji)),
                  onToggleStar: (messageId, currentlyStarred) =>
                      unawaited(_handleToggleStar(messageId, currentlyStarred)),
                  onForward: (messageId) =>
                      unawaited(_handleForward(messageId)),
                  onResendSticker: (sourceMessageId) =>
                      unawaited(_handleResendSticker(sourceMessageId)),
                  onSaveSticker: (sourceMessageId) =>
                      unawaited(_handleSaveSticker(sourceMessageId)),
                  onStickerPickerRequested: _handleOpenStickerPicker,
                  onSendRouteCarousel: _handleSendRouteCarousel,
                  onSendPaymentQris: _handleSendPaymentQris,
                  onSendPaymentNorek: _handleSendPaymentNorek,
                  onComposerChanged: (text) =>
                      _controller.notifyAdminTyping(text),
                  conversation: _controller.selectedConversation,
                  callSession: _effectiveCallSession(
                    _controller.selectedConversation,
                  ),
                  callTimeline: _effectiveCallTimeline(
                    _controller.selectedConversation,
                  ),
                  callHistorySummary:
                      _controller.selectedConversation?.callHistorySummary,
                  callHistory:
                      _controller.selectedConversation?.callHistory ?? const [],
                  isCallFallbackMode: _callController.isFallbackMode,
                  callFallbackMessage: _callController.fallbackMessage,
                  showCallBanner: _showActiveCallCard,
                  onHideCallBanner: _hideActiveCallCard,
                  threadGroups: _controller.threadGroups,
                  isShellLoading: shellLoading,
                  isConversationLoading: _controller.isConversationLoading,
                  isSendingReply: _isSendingReply,
                  isSendingContact: _isSendingContact,
                  onSendReply: _sendAdminReply,
                  onSendGalleryImage: _sendAdminGalleryImage,
                  onSendCameraImage: _sendAdminCameraImage,
                  onSendGalleryVideo: _sendAdminGalleryVideo,
                  onSendCameraVideo: _sendAdminCameraVideo,
                  onSendDocument: _sendAdminDocument,
                  onSendLocation: _sendAdminLocation,
                  onSendVoiceNote: _toggleVoiceNoteRecording,
                  onCancelVoiceNote: _cancelVoiceNoteRecording,
                  isRecordingVoiceNote: _isRecordingVoiceNote,
                  onSendContact: _sendAdminContact,
                  onSaveContact: () => unawaited(_saveDeviceContact()),
                  isTogglingBot: _isTogglingBot,
                  onToggleBot: _toggleBot,
                  isCallLoading: _callController.isLoading,
                  onCallTap: _startConversationCall,
                  onVideoTap: _showVideoCallUnavailable,
                  onOpenCallPage: () => unawaited(_openCurrentCallPage()),
                  onOpenCallHistory: () =>
                      unawaited(_openConversationCallHistory()),
                  onEndCall: _endConversationCall,
                  onSwipeToReply: (message) => setState(() {
                    _replyingTo = message;
                    _replyingToConversationId =
                        _controller.selectedConversation?.id;
                  }),
                  replyingTo: _activeReplyTo,
                  onCancelReply: () => setState(() {
                    _replyingTo = null;
                    _replyingToConversationId = null;
                  }),
                  onOpenInbox: null,
                  selectionVersion: _controller.selectionVersion,
                ),
              ),
            ),
            SizedBox(width: gap),
            SizedBox(
              width: rightWidth,
              child: OmnichannelRightPane(
                conversation: _controller.selectedConversation,
                insight: _controller.insight,
                isLoading: shellLoading,
                callAnalyticsSnapshot: _callAnalyticsController.snapshot,
                isCallAnalyticsLoading:
                    _callAnalyticsController.isLoading ||
                    _callAnalyticsController.isRefreshing,
                callAnalyticsErrorMessage:
                    _callAnalyticsController.errorMessage,
                onRetryCallAnalytics: () => _callAnalyticsController.refresh(),
                onOpenConversationFromCall: (conversationId) =>
                    _handleConversationTap(
                      conversationId,
                      showConversationOnMobile:
                          kIsWeb || MediaQuery.sizeOf(context).width < 960,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileShell({
    required OmnichannelWorkspaceModel workspace,
    required List<OmnichannelConversationListItemModel> items,
    required int? selectedConversationId,
    required bool shellLoading,
  }) {
    return Column(
      children: <Widget>[
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<_OmnichannelMobilePane>(_mobilePane),
              child: switch (_mobilePane) {
                _OmnichannelMobilePane.inbox => OmnichannelLeftPane(
                  workspace: workspace,
                  items: items,
                  selectedConversationId: selectedConversationId,
                  scrollController: _conversationListScrollController,
                  searchController: _searchController,
                  selectedScope: _controller.scopeFilter,
                  selectedChannel: _controller.channelFilter,
                  onScopeChanged: _controller.setScopeFilter,
                  onChannelChanged: _controller.setChannelFilter,
                  selectedTag: _controller.tagFilter,
                  onTagChanged: _controller.setTagFilter,
                  onConversationTap: (conversationId) => _handleConversationTap(
                    conversationId,
                    showConversationOnMobile: true,
                  ),
                  onConversationLongPress: AppConfig.chatManagementEnabled
                      ? _handleConversationLongPress
                      : null,
                  isLoading: shellLoading,
                  isLoadingMore: _controller.isLoadingMore,
                  hasMore: _controller.hasMoreConversations,
                  useMobileInboxLayout: true,
                  repository: widget.repository,
                  onContactSaved: () => unawaited(_controller.refresh()),
                ),
                _OmnichannelMobilePane.updates => OmnichannelUpdatesPage(
                  repository: widget.repository,
                ),
                _OmnichannelMobilePane.conversation =>
                  _buildCenterPaneWithPinnedReadiness(
                    child: OmnichannelCenterPane(
                      onReactToMessage: (messageId, emoji) =>
                          unawaited(_handleReactToMessage(messageId, emoji)),
                      onToggleStar: (messageId, currentlyStarred) => unawaited(
                        _handleToggleStar(messageId, currentlyStarred),
                      ),
                      onForward: (messageId) =>
                          unawaited(_handleForward(messageId)),
                      onResendSticker: (sourceMessageId) =>
                          unawaited(_handleResendSticker(sourceMessageId)),
                      onSaveSticker: (sourceMessageId) =>
                          unawaited(_handleSaveSticker(sourceMessageId)),
                      onStickerPickerRequested: _handleOpenStickerPicker,
                      onSendRouteCarousel: _handleSendRouteCarousel,
                      onSendPaymentQris: _handleSendPaymentQris,
                      onSendPaymentNorek: _handleSendPaymentNorek,
                      onComposerChanged: (text) =>
                          _controller.notifyAdminTyping(text),
                      conversation: _controller.selectedConversation,
                      callSession: _effectiveCallSession(
                        _controller.selectedConversation,
                      ),
                      callTimeline: _effectiveCallTimeline(
                        _controller.selectedConversation,
                      ),
                      callHistorySummary:
                          _controller.selectedConversation?.callHistorySummary,
                      callHistory:
                          _controller.selectedConversation?.callHistory ??
                          const [],
                      isCallFallbackMode: _callController.isFallbackMode,
                      callFallbackMessage: _callController.fallbackMessage,
                      showCallBanner: _showActiveCallCard,
                      onHideCallBanner: _hideActiveCallCard,
                      threadGroups: _controller.threadGroups,
                      isShellLoading: shellLoading,
                      isConversationLoading: _controller.isConversationLoading,
                      isSendingReply: _isSendingReply,
                      isSendingContact: _isSendingContact,
                      onSendReply: _sendAdminReply,
                      onSendGalleryImage: _sendAdminGalleryImage,
                      onSendCameraImage: _sendAdminCameraImage,
                      onSendGalleryVideo: _sendAdminGalleryVideo,
                      onSendCameraVideo: _sendAdminCameraVideo,
                      onSendDocument: _sendAdminDocument,
                      onSendLocation: _sendAdminLocation,
                      onSendVoiceNote: _toggleVoiceNoteRecording,
                      onCancelVoiceNote: _cancelVoiceNoteRecording,
                      isRecordingVoiceNote: _isRecordingVoiceNote,
                      onSendContact: _sendAdminContact,
                      onSaveContact: () => unawaited(_saveDeviceContact()),
                      isTogglingBot: _isTogglingBot,
                      onToggleBot: _toggleBot,
                      isCallLoading: _callController.isLoading,
                      onCallTap: _startConversationCall,
                      onVideoTap: _showVideoCallUnavailable,
                      onOpenCallPage: () => unawaited(_openCurrentCallPage()),
                      onOpenCallHistory: () =>
                          unawaited(_openConversationCallHistory()),
                      onEndCall: _endConversationCall,
                      onSwipeToReply: (message) => setState(() {
                        _replyingTo = message;
                        _replyingToConversationId =
                            _controller.selectedConversation?.id;
                      }),
                      replyingTo: _activeReplyTo,
                      onCancelReply: () => setState(() {
                        _replyingTo = null;
                        _replyingToConversationId = null;
                      }),
                      onOpenInbox: () =>
                          _setMobilePane(_OmnichannelMobilePane.inbox),
                      selectionVersion: _controller.selectionVersion,
                    ),
                  ),
                _OmnichannelMobilePane.insight => OmnichannelRightPane(
                  conversation: _controller.selectedConversation,
                  insight: _controller.insight,
                  isLoading: shellLoading,
                  callAnalyticsSnapshot: _callAnalyticsController.snapshot,
                  isCallAnalyticsLoading:
                      _callAnalyticsController.isLoading ||
                      _callAnalyticsController.isRefreshing,
                  callAnalyticsErrorMessage:
                      _callAnalyticsController.errorMessage,
                  onRetryCallAnalytics: () =>
                      _callAnalyticsController.refresh(),
                  onOpenConversationFromCall: (conversationId) =>
                      _handleConversationTap(
                        conversationId,
                        showConversationOnMobile: true,
                      ),
                ),
                _OmnichannelMobilePane.callHistory => Scaffold(
                  backgroundColor: AppColors.scaffoldBackground,
                  body: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Panggilan',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.neutral800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Riwayat dan analitik panggilan',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.neutral400,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OmnichannelCallAnalyticsPanel(
                          snapshot: _callAnalyticsController.snapshot,
                          isLoading:
                              _callAnalyticsController.isLoading ||
                              _callAnalyticsController.isRefreshing,
                          errorMessage: _callAnalyticsController.errorMessage,
                          onRetry: () => _callAnalyticsController.refresh(),
                          onOpenConversation: (conversationId) =>
                              _handleConversationTap(
                                conversationId,
                                showConversationOnMobile: true,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              },
            ),
          ),
        ),
        // ═══ BOTTOM NAVIGATION BAR ═══
        _MobilePaneSelector(
          selectedPane: _mobilePane,
          onPaneSelected: _setMobilePane,
          onStarredMessagesTap: _openStarredMessages,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            _controller,
            _callController,
            _callAnalyticsController,
          ]),
          builder: (context, _) {
            final screenWidth = MediaQuery.sizeOf(context).width;
            final isMobileShell = kIsWeb || screenWidth < 960;
            final horizontalPadding = isMobileShell ? 12.0 : 24.0;
            final contentPadding = isMobileShell ? 0.0 : 24.0;
            final shellLoading =
                _controller.isLoading && !_controller.hasShellData;

            final showFatalError =
                _controller.errorMessage != null &&
                !_controller.hasShellData &&
                !shellLoading &&
                !_controller.requiresLogin;

            final workspace =
                _controller.workspace ??
                OmnichannelWorkspaceModel.placeholder();

            final conversationList = _controller.conversationList;

            if (showFatalError) {
              final errorBody = SizedBox.expand(
                child: OmnichannelErrorState(
                  title: 'Dashboard admin belum siap',
                  message: _controller.errorMessage!,
                  onRetry: _retryBootstrap,
                ),
              );

              if (isMobileShell) {
                return ColoredBox(
                  color: AppColors.surfaceSecondary,
                  child: errorBody,
                );
              }

              return Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppColors.scaffoldBackground,
                      AppColors.borderLight,
                    ],
                  ),
                ),
                child: errorBody,
              );
            }

            final shellBody = Column(
              children: <Widget>[
                if (!isMobileShell)
                  OmnichannelShellHeader(
                    currentUser: _controller.currentUser,
                    isLoggingOut: _controller.isLoggingOut,
                    onLogout: () => unawaited(_controller.logout()),
                  ),
                if (_controller.errorMessage != null &&
                    _controller.hasShellData)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      isMobileShell ? 8 : 12,
                      horizontalPadding,
                      0,
                    ),
                    child: OmnichannelInlineBanner(
                      message: _controller.errorMessage!,
                      onRetry: _controller.isRefreshing
                          ? () async {}
                          : _controller.refresh,
                    ),
                  ),
                if (_controller.isRefreshing ||
                    _controller.isConversationLoading ||
                    _isSendingReply ||
                    _isSendingContact ||
                    _isTogglingBot ||
                    _callController.isLoading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.primary,
                    backgroundColor: Colors.transparent,
                  ),
                Expanded(
                  child: contentPadding == 0
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              _buildAdaptiveShell(
                                constraints: constraints,
                                workspace: workspace,
                                conversationList: conversationList,
                                shellLoading: shellLoading,
                              ),
                        )
                      : Padding(
                          padding: EdgeInsets.all(contentPadding),
                          child: LayoutBuilder(
                            builder: (context, constraints) =>
                                _buildAdaptiveShell(
                                  constraints: constraints,
                                  workspace: workspace,
                                  conversationList: conversationList,
                                  shellLoading: shellLoading,
                                ),
                          ),
                        ),
                ),
              ],
            );
            final layeredShellBody = Stack(
              fit: StackFit.expand,
              children: [shellBody, _buildFloatingHiddenCallChips()],
            );

            if (isMobileShell) {
              return ColoredBox(
                color: AppColors.surfaceSecondary,
                child: layeredShellBody,
              );
            }

            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.scaffoldBackground,
                    AppColors.borderLight,
                  ],
                ),
              ),
              child: layeredShellBody,
            );
          },
        ),
      ),
    );
  }
}

class _MobilePaneSelector extends StatelessWidget {
  const _MobilePaneSelector({
    required this.selectedPane,
    required this.onPaneSelected,
    required this.onStarredMessagesTap,
  });

  final _OmnichannelMobilePane selectedPane;
  final ValueChanged<_OmnichannelMobilePane> onPaneSelected;
  final VoidCallback onStarredMessagesTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: AppColors.surfacePrimary,
          border: Border(
            top: BorderSide(color: AppColors.primary.withValues(alpha: 0.08)),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x30000000),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _MobilePaneButton(
                label: 'Inbox',
                icon: Icons.chat_bubble_rounded,
                selected: selectedPane == _OmnichannelMobilePane.inbox,
                onTap: () => onPaneSelected(_OmnichannelMobilePane.inbox),
              ),
            ),
            Expanded(
              child: _MobilePaneButton(
                label: 'Pembaruan',
                icon: Icons.autorenew_rounded,
                selected: selectedPane == _OmnichannelMobilePane.updates,
                onTap: () => onPaneSelected(_OmnichannelMobilePane.updates),
              ),
            ),
            Expanded(
              child: _MobilePaneButton(
                label: 'Insight',
                icon: Icons.insights_rounded,
                selected: selectedPane == _OmnichannelMobilePane.insight,
                onTap: () => onPaneSelected(_OmnichannelMobilePane.insight),
              ),
            ),
            Expanded(
              child: _MobilePaneButton(
                label: 'Panggilan',
                icon: Icons.call_rounded,
                selected: selectedPane == _OmnichannelMobilePane.callHistory,
                onTap: () => onPaneSelected(_OmnichannelMobilePane.callHistory),
              ),
            ),
            if (AppConfig.starredListEnabled)
              Expanded(
                child: _MobilePaneButton(
                  label: 'Berbintang',
                  icon: Icons.star_rounded,
                  selected: false,
                  onTap: onStarredMessagesTap,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MobilePaneButton extends StatelessWidget {
  const _MobilePaneButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: 52,
            height: 32,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: AppRadii.borderRadiusLg,
            ),
            alignment: Alignment.center,
            child: AnimatedScale(
              scale: selected ? 1.0 : 0.9,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: Icon(
                icon,
                size: 22,
                color: selected ? AppColors.primary : AppColors.neutral400,
              ),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.neutral400,
            ),
            child: Text(label),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: selected ? 20 : 0,
            height: 2.5,
            margin: EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: AppRadii.borderRadiusPill,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

enum _LabelActionType { add, remove }

class _LabelDialogResult {
  const _LabelDialogResult(this.type, this.tag);

  final _LabelActionType type;
  final String tag;
}

class _ManageLabelDialog extends StatefulWidget {
  const _ManageLabelDialog({required this.findItem});

  final OmnichannelConversationListItemModel? Function() findItem;

  @override
  State<_ManageLabelDialog> createState() => _ManageLabelDialogState();
}

class _ManageLabelDialogState extends State<_ManageLabelDialog> {
  final TextEditingController _textController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String? _validate(String raw) {
    final value = raw.trim();
    if (value.length < 2 || value.length > 40) {
      return 'Label harus 2–40 karakter.';
    }
    if (!RegExp(r'[A-Za-z0-9]').hasMatch(value)) {
      return 'Label harus memuat minimal satu huruf atau angka.';
    }
    return null;
  }

  void _submit() {
    final value = _textController.text.trim();
    final error = _validate(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_LabelDialogResult(_LabelActionType.add, value));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.findItem();

    if (item == null) {
      return AlertDialog(
        title: const Text('Kelola label'),
        content: const Text('Percakapan belum tersedia di daftar saat ini.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Kelola label'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (item.tags.isEmpty)
            const Text('Belum ada label.')
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final tag in item.tags)
                  InputChip(
                    label: Text(tag.value),
                    onDeleted: () => Navigator.of(context).pop(
                      _LabelDialogResult(_LabelActionType.remove, tag.value),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Tambah label',
              hintText: 'mis. follow-up-vip',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}
