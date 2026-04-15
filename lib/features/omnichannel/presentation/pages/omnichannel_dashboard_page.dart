import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

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
import '../../data/models/omnichannel_workspace_model.dart';
import '../../data/repositories/omnichannel_repository.dart';
import '../../data/services/omnichannel_call_media_service.dart';
import '../controllers/omnichannel_call_analytics_controller.dart';
import '../controllers/omnichannel_call_controller.dart';
import '../controllers/omnichannel_shell_controller.dart';
import '../pages/omnichannel_call_page.dart';
import '../pages/omnichannel_call_history_page.dart';
import '../pages/omnichannel_updates_page.dart';
import '../utils/omnichannel_call_status_ui.dart';
import '../widgets/omnichannel_center_pane.dart';
import '../widgets/omnichannel_call_settings_checklist_sheet.dart';
import '../widgets/omnichannel_left_pane.dart';
import '../widgets/omnichannel_right_pane.dart';
import '../widgets/omnichannel_shell_header.dart';
import '../widgets/omnichannel_surface.dart';

enum _OmnichannelMobilePane { inbox, updates, conversation, insight }

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
  _OmnichannelMobilePane _mobilePane = _OmnichannelMobilePane.inbox;
  OmnichannelCallSessionModel? _lastObservedCallSession;
  OmnichannelCallReadinessModel? _callReadiness;
  bool _isLoadingCallReadiness = false;
  bool _isClearingCallEligibilityCache = false;
  bool _showCallReadinessCard = true;
  bool _showActiveCallCard = true;
  Offset _callReadinessBubbleOffset = const Offset(0, 0);
  Offset _activeCallBubbleOffset = const Offset(0, 56);
  bool _isCallReadinessExpanded = false;
  final bool _pinCallReadinessAboveCallCard = true;

  static const double _floatingBubbleWidth = 190.0;
  static const double _floatingBubbleHeight = 46.0;
  static const double _floatingBubbleBaseRight = 14.0;
  static const double _floatingBubbleBaseBottom = 74.0;

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
    unawaited(_loadCallReadiness());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _controller
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
    if (!mounted) {
      return;
    }
    setState(() {
      _showCallReadinessCard = false;
    });
  }

  void _showCallReadinessCardAgain() {
    if (!mounted) {
      return;
    }
    setState(() {
      _showCallReadinessCard = true;
      _callReadinessBubbleOffset = const Offset(0, 0);
    });
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
    final chipBg = isReady ? const Color(0xFFEAFBF1) : const Color(0xFFFFEEEE);
    final chipFg = isReady ? const Color(0xFF157F3D) : const Color(0xFFD92D20);
    final borderColor = isReady
        ? const Color(0xFFC7EFD6)
        : const Color(0xFFF4C7C3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    final chipBg = isReady ? const Color(0xFFEAFBF1) : const Color(0xFFFFEEEE);
    final chipFg = isReady ? const Color(0xFF157F3D) : const Color(0xFFD92D20);
    final borderColor = isReady
        ? const Color(0xFFC7EFD6)
        : const Color(0xFFF4C7C3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    final statusBg = isReady
        ? const Color(0xFFEAFBF1)
        : const Color(0xFFFFEEEE);
    final statusFg = isReady
        ? const Color(0xFF157F3D)
        : const Color(0xFFD92D20);
    final statusBorder = isReady
        ? const Color(0xFFC7EFD6)
        : const Color(0xFFF4C7C3);
    final cardTopColor = isReady
        ? const Color(0xFFF3FCF6)
        : const Color(0xFFFFF7F7);
    final checksCount = readiness?.checks.length ?? 0;
    final hasMissingConfig = readiness?.missing.isNotEmpty == true;

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.borderRadiusXxl,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardTopColor, Colors.white],
        ),
        border: Border.all(color: statusBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                          color: Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isReady
                            ? 'Sistem calling siap dipakai.'
                            : 'Masih ada hal yang perlu dibereskan sebelum mulai call.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: Color(0xFF667085),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F7),
                      borderRadius: AppRadii.borderRadiusPill,
                    ),
                    child: Text(
                      _isLoadingCallReadiness ? 'Checking...' : 'Refresh',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF344054),
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
                      color: const Color(0xFFF9FAFB),
                      borderRadius: AppRadii.borderRadiusPill,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Color(0xFF667085),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: isReady
                      ? const Color(0xFFF5FBF7)
                      : const Color(0xFFFFF8F2),
                  borderRadius: AppRadii.borderRadiusLg,
                  border: Border.all(
                    color: isReady
                        ? const Color(0xFFD6F0DE)
                        : const Color(0xFFF5D9B8),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: AppRadii.borderRadiusPill,
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Text(
                              readiness.eligibilityCacheTtlSeconds != null
                                  ? 'Cached • ${readiness.eligibilityCacheTtlSeconds}s TTL'
                                  : 'Cached',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF344054),
                              ),
                            ),
                          ),
                        if ((readiness.messagingLimitTier?.trim().isNotEmpty ??
                            false))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: AppRadii.borderRadiusPill,
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Text(
                              'Tier: ${readiness.messagingLimitTier}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF344054),
                              ),
                            ),
                          ),
                        if ((readiness.qualityRating?.trim().isNotEmpty ??
                            false))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: AppRadii.borderRadiusPill,
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Text(
                              'Quality: ${readiness.qualityRating}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF344054),
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
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                          color: Color(0xFF9A3412),
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
                  color: Color(0xFF667085),
                ),
              ),
            ],
            if (readiness == null && _isLoadingCallReadiness)
              const Text(
                'Sedang memeriksa backend dan pengaturan Meta...',
                style: TextStyle(fontSize: 13, color: Color(0xFF667085)),
              ),
            if (readiness != null && !_isCallReadinessExpanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: AppRadii.borderRadiusLg,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  (readiness.eligibilityReason?.trim().isNotEmpty ?? false)
                      ? readiness.eligibilityReason!
                      : hasMissingConfig
                      ? 'Terdapat ${readiness.missing.length} konfigurasi yang belum lengkap dan $checksCount pemeriksaan readiness.'
                      : 'Tersedia $checksCount pemeriksaan readiness. Buka detail untuk melihat status lengkap.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Color(0xFF667085),
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
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFAEB),
                        borderRadius: AppRadii.borderRadiusLg,
                        border: Border.all(color: const Color(0xFFF7D79B)),
                      ),
                      child: Text(
                        'Konfigurasi yang masih kurang: ${readiness.missing.join(', ')}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color: Color(0xFFB54708),
                        ),
                      ),
                    ),
                  ],
                  if (readiness != null)
                    ...readiness.checks.map((check) {
                      final itemBg = check.ok
                          ? const Color(0xFFF6FBF7)
                          : const Color(0xFFFFF7F7);
                      final itemBorder = check.ok
                          ? const Color(0xFFD6F0DE)
                          : const Color(0xFFF4CCCC);
                      final dotColor = check.ok
                          ? const Color(0xFF157F3D)
                          : const Color(0xFFD92D20);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(13),
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
                              margin: const EdgeInsets.only(top: 4),
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
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF101828),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    check.message,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: Color(0xFF667085),
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
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: statusBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.borderRadiusLg,
                      ),
                      foregroundColor: const Color(0xFF101828),
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
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Color(0xFFF5D0D5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.borderRadiusLg,
                      ),
                      foregroundColor: const Color(0xFFB42318),
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
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: _buildCallReadinessPanelContent(),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
    final canRestoreReadiness = !_showCallReadinessCard;
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
            final callReadinessOffset = _clampBubbleOffset(
              _callReadinessBubbleOffset,
              viewportSize: viewportSize,
              bubbleWidth: _floatingBubbleWidth,
              bubbleHeight: _floatingBubbleHeight,
            );
            final activeCallOffset = _clampBubbleOffset(
              _activeCallBubbleOffset,
              viewportSize: viewportSize,
              bubbleWidth: _floatingBubbleWidth,
              bubbleHeight: _floatingBubbleHeight,
            );

            return Stack(
              children: [
                if (canRestoreReadiness)
                  _buildDraggableFloatingRestoreBubble(
                    label: 'Call Readiness',
                    icon: Icons.verified_outlined,
                    offset: callReadinessOffset,
                    baseRight: _floatingBubbleBaseRight,
                    baseBottom: _floatingBubbleBaseBottom,
                    onTap: _showCallReadinessCardAgain,
                    onPanUpdate: (delta) =>
                        _updateCallReadinessBubbleOffset(delta, viewportSize),
                    accentColor: const Color(0xFFE53935),
                    borderColor: const Color(0xFFF2B8B5),
                    iconBg: const Color(0xFFFFF1F0),
                  ),
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
                    accentColor: const Color(0xFF9A6700),
                    borderColor: const Color(0xFFE7D7A5),
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
                  color: Colors.white.withValues(alpha: 0.97),
                  borderRadius: AppRadii.borderRadiusPill,
                  border: Border.all(color: borderColor),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
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
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF344054),
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
        'Konfigurasi panggilan belum lengkap.',
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
          );

          debugPrint('VOICE NOTE SEND SUCCESS => $notice');

          await _controller.softRefreshAfterExternalAction();

          if (mounted) {
            _showSnackBar(notice);
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

  Future<bool> _sendAdminContact({
    required String fullName,
    required String phone,
    String? email,
    String? company,
  }) async {
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

  void _handleConversationTap(
    int conversationId, {
    required bool showConversationOnMobile,
  }) {
    if (showConversationOnMobile) {
      _setMobilePane(_OmnichannelMobilePane.conversation);
    }

    unawaited(_controller.selectConversation(conversationId));
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
                onConversationTap: (conversationId) => _handleConversationTap(
                  conversationId,
                  showConversationOnMobile: false,
                ),
                isLoading: shellLoading,
                isLoadingMore: _controller.isLoadingMore,
                hasMore: _controller.hasMoreConversations,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _buildCenterPaneWithPinnedReadiness(
                child: OmnichannelCenterPane(
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
                  onSendVoiceNote: _toggleVoiceNoteRecording,
                  onCancelVoiceNote: _cancelVoiceNoteRecording,
                  isRecordingVoiceNote: _isRecordingVoiceNote,
                  onSendContact: _sendAdminContact,
                  isTogglingBot: _isTogglingBot,
                  onToggleBot: _toggleBot,
                  isCallLoading: _callController.isLoading,
                  onCallTap: _startConversationCall,
                  onVideoTap: _showVideoCallUnavailable,
                  onOpenCallPage: () => unawaited(_openCurrentCallPage()),
                  onOpenCallHistory: () =>
                      unawaited(_openConversationCallHistory()),
                  onEndCall: _endConversationCall,
                  onOpenInbox: null,
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
    const showPaneSelector = true;

    return Column(
      children: <Widget>[
        if (showPaneSelector) ...<Widget>[
          _MobilePaneSelector(
            selectedPane: _mobilePane,
            onPaneSelected: _setMobilePane,
          ),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
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
                  onConversationTap: (conversationId) => _handleConversationTap(
                    conversationId,
                    showConversationOnMobile: true,
                  ),
                  isLoading: shellLoading,
                  isLoadingMore: _controller.isLoadingMore,
                  hasMore: _controller.hasMoreConversations,
                  useMobileInboxLayout: true,
                ),
                _OmnichannelMobilePane.updates => OmnichannelUpdatesPage(
                  repository: widget.repository,
                ),
                _OmnichannelMobilePane.conversation =>
                  _buildCenterPaneWithPinnedReadiness(
                    child: OmnichannelCenterPane(
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
                      onSendVoiceNote: _toggleVoiceNoteRecording,
                      onCancelVoiceNote: _cancelVoiceNoteRecording,
                      isRecordingVoiceNote: _isRecordingVoiceNote,
                      onSendContact: _sendAdminContact,
                      isTogglingBot: _isTogglingBot,
                      onToggleBot: _toggleBot,
                      isCallLoading: _callController.isLoading,
                      onCallTap: _startConversationCall,
                      onVideoTap: _showVideoCallUnavailable,
                      onOpenCallPage: () => unawaited(_openCurrentCallPage()),
                      onOpenCallHistory: () =>
                          unawaited(_openConversationCallHistory()),
                      onEndCall: _endConversationCall,
                      onOpenInbox: () =>
                          _setMobilePane(_OmnichannelMobilePane.inbox),
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
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                return ColoredBox(color: Colors.white, child: errorBody);
              }

              return Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
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
              return ColoredBox(color: Colors.white, child: layeredShellBody);
            }

            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
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
  });

  final _OmnichannelMobilePane selectedPane;
  final ValueChanged<_OmnichannelMobilePane> onPaneSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _MobilePaneButton(
              label: 'Inbox',
              icon: Icons.inbox_outlined,
              selected: selectedPane == _OmnichannelMobilePane.inbox,
              onTap: () => onPaneSelected(_OmnichannelMobilePane.inbox),
            ),
          ),
          Expanded(
            child: _MobilePaneButton(
              label: 'Pembaharuan',
              icon: Icons.autorenew_rounded,
              selected: selectedPane == _OmnichannelMobilePane.updates,
              onTap: () => onPaneSelected(_OmnichannelMobilePane.updates),
            ),
          ),
          Expanded(
            child: _MobilePaneButton(
              label: 'Chat',
              icon: Icons.forum_outlined,
              selected: selectedPane == _OmnichannelMobilePane.conversation,
              onTap: () => onPaneSelected(_OmnichannelMobilePane.conversation),
            ),
          ),
          Expanded(
            child: _MobilePaneButton(
              label: 'Insight',
              icon: Icons.insights_outlined,
              selected: selectedPane == _OmnichannelMobilePane.insight,
              onTap: () => onPaneSelected(_OmnichannelMobilePane.insight),
            ),
          ),
        ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.borderRadiusMd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: AppRadii.borderRadiusMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.neutral500,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.neutral500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
