import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../admin_auth/data/models/admin_user_model.dart';
import '../../../admin_auth/data/repositories/admin_auth_repository.dart';
import '../../data/models/omnichannel_conversation_list_model.dart';
import '../../data/models/omnichannel_workspace_model.dart';
import '../../data/repositories/omnichannel_repository.dart';
import '../controllers/omnichannel_shell_controller.dart';
import '../widgets/omnichannel_center_pane.dart';
import '../widgets/omnichannel_left_pane.dart';
import '../widgets/omnichannel_right_pane.dart';
import '../widgets/omnichannel_shell_header.dart';
import '../widgets/omnichannel_surface.dart';

enum _OmnichannelMobilePane { inbox, conversation, insight }

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = OmnichannelShellController(
      repository: widget.repository,
      adminAuthRepository: widget.adminAuthRepository,
    )..addListener(_handleControllerChanged);

    _searchController.addListener(_handleSearchChanged);
    _conversationListScrollController.addListener(_handleListScroll);

    unawaited(_controller.initialize(initialUser: widget.initialUser));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();

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

  Future<void> _retryBootstrap() {
    _hasRedirected = false;
    return _controller.initialize(initialUser: widget.initialUser);
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

          await _controller.softRefreshAfterExternalAction();
          if (mounted) {
            _showSnackBar(notice);
          }
          return true;
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
          '${Directory.systemTemp.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.ogg';
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.opus,
          bitRate: 64000,
          sampleRate: 16000,
        ),
        path: tempPath,
      );

      if (mounted) {
        setState(() => _isRecordingVoiceNote = true);
      }
      _showSnackBar(
        'Rekaman voice note dimulai. Tekan ikon mic sekali lagi untuk mengirim.',
      );
      return false;
    } on ApiException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
      return false;
    } catch (error) {
      if (mounted) {
        _showSnackBar('Gagal memproses voice note: $error');
        setState(() => _isRecordingVoiceNote = false);
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
      ..showSnackBar(SnackBar(content: Text(text)));
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
              child: OmnichannelCenterPane(
                conversation: _controller.selectedConversation,
                threadGroups: _controller.threadGroups,
                isShellLoading: shellLoading,
                isConversationLoading: _controller.isConversationLoading,
                isSendingReply: _isSendingReply,
                isSendingContact: _isSendingContact,
                onSendReply: _sendAdminReply,
                onSendGalleryImage: _sendAdminGalleryImage,
                onSendCameraImage: _sendAdminCameraImage,
                onSendVoiceNote: _toggleVoiceNoteRecording,
                isRecordingVoiceNote: _isRecordingVoiceNote,
                onSendContact: _sendAdminContact,
                isTogglingBot: _isTogglingBot,
                onToggleBot: _toggleBot,
                onOpenInbox: null,
              ),
            ),
            SizedBox(width: gap),
            SizedBox(
              width: rightWidth,
              child: OmnichannelRightPane(
                conversation: _controller.selectedConversation,
                insight: _controller.insight,
                isLoading: shellLoading,
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
    final showPaneSelector = _mobilePane == _OmnichannelMobilePane.insight;

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
                _OmnichannelMobilePane.conversation => OmnichannelCenterPane(
                  conversation: _controller.selectedConversation,
                  threadGroups: _controller.threadGroups,
                  isShellLoading: shellLoading,
                  isConversationLoading: _controller.isConversationLoading,
                  isSendingReply: _isSendingReply,
                  isSendingContact: _isSendingContact,
                  onSendReply: _sendAdminReply,
                  onSendGalleryImage: _sendAdminGalleryImage,
                  onSendCameraImage: _sendAdminCameraImage,
                  onSendVoiceNote: _toggleVoiceNoteRecording,
                  isRecordingVoiceNote: _isRecordingVoiceNote,
                  onSendContact: _sendAdminContact,
                  isTogglingBot: _isTogglingBot,
                  onToggleBot: _toggleBot,
                  onOpenInbox: () =>
                      _setMobilePane(_OmnichannelMobilePane.inbox),
                ),
                _OmnichannelMobilePane.insight => OmnichannelRightPane(
                  conversation: _controller.selectedConversation,
                  insight: _controller.insight,
                  isLoading: shellLoading,
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
          animation: _controller,
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
                      AppConfig.softBackground,
                      AppConfig.softBackgroundAlt,
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
                    _isTogglingBot)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppConfig.green,
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

            if (isMobileShell) {
              return ColoredBox(color: Colors.white, child: shellBody);
            }

            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppConfig.softBackground,
                    AppConfig.softBackgroundAlt,
                  ],
                ),
              ),
              child: shellBody,
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
        border: Border.all(color: AppConfig.softBackgroundAlt),
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
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppConfig.green.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: selected ? AppConfig.green : AppConfig.mutedText,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppConfig.green : AppConfig.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
