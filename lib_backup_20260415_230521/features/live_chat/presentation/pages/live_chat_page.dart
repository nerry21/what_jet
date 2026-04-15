import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/models/conversation_model.dart';
import '../../data/repositories/live_chat_repository.dart';
import '../../../status/data/repositories/customer_status_repository.dart';
import '../../../status/data/services/customer_status_api_service.dart';
import '../../../status/presentation/widgets/customer_status_strip.dart';
import '../controllers/live_chat_controller.dart';
import '../widgets/chat_list_tile.dart';
import 'chat_detail_page.dart';

class LiveChatPage extends StatefulWidget {
  const LiveChatPage({super.key, required this.repository});

  final LiveChatRepository repository;

  @override
  State<LiveChatPage> createState() => _LiveChatPageState();
}

class _LiveChatPageState extends State<LiveChatPage> {
  late final LiveChatController _controller;
  late final ApiClient _statusApiClient;
  late final TokenStorage _tokenStorage;
  late final CustomerStatusRepository _statusRepository;
  final TextEditingController _searchController = TextEditingController();
  _ConversationFilter _filter = _ConversationFilter.all;

  @override
  void initState() {
    super.initState();
    _statusApiClient = ApiClient();
    _tokenStorage = TokenStorage();
    _statusRepository = CustomerStatusRepository(
      apiService: CustomerStatusApiService(_statusApiClient),
      readAccessToken: _readStatusAccessToken,
    );
    _controller = LiveChatController(repository: widget.repository);
    _searchController.addListener(_handleSearchChanged);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _statusApiClient.dispose();
    _controller.dispose();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<String> _readStatusAccessToken() async {
    final token = await _tokenStorage.readAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('Token live chat belum tersedia.');
    }

    return token.trim();
  }

  void _handleSearchChanged() {
    _controller.setSearchQuery(_searchController.text);
  }

  Future<void> _startConversationFlow({required bool compact}) async {
    final openingMessage = await _showStartConversationSheet();
    if (!mounted || openingMessage == null) {
      return;
    }

    final conversation = await _controller.startConversation(
      openingMessage: openingMessage.isEmpty ? null : openingMessage,
      clientMessageId: _buildClientMessageId(),
    );

    if (!mounted) {
      return;
    }

    if (conversation == null) {
      _showSnackBar(
        _controller.errorMessage ?? 'Gagal memulai percakapan.',
        isError: true,
      );
      return;
    }

    _controller.selectConversation(conversation.id);

    if (compact) {
      await _openConversation(conversation);
    }
  }

  Future<void> _openConversation(ConversationModel conversation) async {
    _controller.selectConversation(conversation.id);

    final compact = MediaQuery.sizeOf(context).width < 768;
    if (!compact) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ChatDetailPage(
          repository: widget.repository,
          conversationId: conversation.id,
          initialConversation: conversation,
          pollIntervalMs: _controller.pollIntervalMs,
          onConversationChanged: _controller.updateConversation,
          showBackButton: true,
        ),
      ),
    );

    if (mounted) {
      await _controller.refresh();
    }
  }

  Future<void> _handleSidebarMenu(_SidebarMenuAction action) async {
    if (action == _SidebarMenuAction.refresh) {
      await _controller.refresh();
      return;
    }

    await _controller.resetProfile();
    if (!mounted) {
      return;
    }

    _showSnackBar('Sesi live chat baru sudah disiapkan.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.softBackground,
      body: Container(
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
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final compact = MediaQuery.sizeOf(context).width < 768;
              final hasShellData =
                  _controller.customer != null ||
                  _controller.conversations.isNotEmpty;

              if (_controller.isInitializing && !hasShellData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppConfig.green),
                );
              }

              if (_controller.errorMessage != null && !hasShellData) {
                return _ShellErrorState(
                  title: _controller.isOffline
                      ? 'Koneksi belum tersedia'
                      : 'Live chat belum siap',
                  message: _controller.errorMessage!,
                  actionLabel: 'Coba lagi',
                  onRetry: _controller.reconnectSession,
                );
              }

              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 32,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: compact
                    ? _buildSidebar(compact: true)
                    : Row(
                        children: <Widget>[
                          SizedBox(
                            width: 360,
                            child: _buildSidebar(compact: false),
                          ),
                          Expanded(child: _buildDesktopDetailPanel()),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar({required bool compact}) {
    final conversations = _visibleConversations;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFF0F0F0))),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          _SidebarHeader(
            customerName:
                _controller.customer?.displayName ?? AppConfig.guestDisplayName,
            onStartConversation: () =>
                unawaited(_startConversationFlow(compact: compact)),
            onRefresh: _controller.isRefreshing
                ? null
                : () => unawaited(_controller.refresh()),
            menuBuilder: (context) => PopupMenuButton<_SidebarMenuAction>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) => unawaited(_handleSidebarMenu(value)),
              itemBuilder: (context) =>
                  const <PopupMenuEntry<_SidebarMenuAction>>[
                    PopupMenuItem<_SidebarMenuAction>(
                      value: _SidebarMenuAction.refresh,
                      child: Text('Refresh'),
                    ),
                    PopupMenuItem<_SidebarMenuAction>(
                      value: _SidebarMenuAction.newSession,
                      child: Text('Sesi baru'),
                    ),
                  ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _SearchInput(controller: _searchController),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _FilterChipButton(
                    label: 'Semua',
                    active: _filter == _ConversationFilter.all,
                    onTap: () =>
                        setState(() => _filter = _ConversationFilter.all),
                  ),
                  const SizedBox(width: 12),
                  _FilterChipButton(
                    label: 'Belum Dibaca',
                    active: _filter == _ConversationFilter.unread,
                    onTap: () =>
                        setState(() => _filter = _ConversationFilter.unread),
                  ),
                  const SizedBox(width: 12),
                  _FilterChipButton(
                    label: 'Aktif',
                    active: _filter == _ConversationFilter.active,
                    onTap: () =>
                        setState(() => _filter = _ConversationFilter.active),
                  ),
                ],
              ),
            ),
          ),
          if (_controller.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SidebarInlineBanner(
                label: _controller.errorMessage!,
                actionLabel: _controller.isUnauthorized
                    ? 'Sambungkan lagi'
                    : 'Retry',
                foregroundColor: _controller.isOffline
                    ? const Color(0xFF9A6700)
                    : AppConfig.danger,
                backgroundColor: _controller.isOffline
                    ? const Color(0xFFFFF4E5)
                    : AppConfig.danger.withValues(alpha: 0.08),
                onTap: () => _controller.reconnectSession(
                  clearSession: _controller.isUnauthorized,
                ),
              ),
            ),
          const SizedBox(height: 8),
          _StatusSection(repository: _statusRepository),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              color: AppConfig.green,
              onRefresh: _controller.refresh,
              child: conversations.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: <Widget>[
                        SizedBox(
                          height: max(
                            360,
                            MediaQuery.sizeOf(context).height * 0.55,
                          ),
                          child: _SidebarEmptyState(
                            isLoading:
                                _controller.isRefreshing ||
                                _controller.isInitializing,
                            onStartConversation: () => unawaited(
                              _startConversationFlow(compact: compact),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        final selected =
                            _controller.selectedConversationId ==
                            conversation.id;

                        return ChatListTile(
                          conversation: conversation,
                          title: _conversationTitle(conversation),
                          subtitle: _conversationSubtitle(conversation),
                          timeLabel: _formatListTime(
                            conversation.lastMessageAt ??
                                conversation.startedAt,
                          ),
                          selected: selected,
                          onTap: () =>
                              unawaited(_openConversation(conversation)),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDetailPanel() {
    final selectedConversation = _controller.conversationById(
      _controller.selectedConversationId,
    );

    if (selectedConversation == null) {
      return const _DesktopPlaceholder();
    }

    return ChatDetailPage(
      key: ValueKey<int>(selectedConversation.id),
      repository: widget.repository,
      conversationId: selectedConversation.id,
      initialConversation: selectedConversation,
      pollIntervalMs: _controller.pollIntervalMs,
      onConversationChanged: _controller.updateConversation,
      standalone: false,
    );
  }

  Future<String?> _showStartConversationSheet() {
    final openingMessageController = TextEditingController();

    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 32,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text(
                        'Mulai Percakapan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        icon: const Icon(
                          Icons.close,
                          color: AppConfig.mutedText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Anda bisa mengirim pesan pertama sekarang, atau langsung buka chat kosong.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppConfig.mutedText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GreyInput(
                    controller: openingMessageController,
                    hintText: 'Tulis pesan pembuka',
                    keyboardType: TextInputType.multiline,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            AppConfig.green,
                            AppConfig.greenLight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pop(openingMessageController.text.trim());
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Lanjutkan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(openingMessageController.dispose);
  }

  List<ConversationModel> get _visibleConversations {
    final base = _controller.filteredConversations;

    switch (_filter) {
      case _ConversationFilter.all:
        return base;
      case _ConversationFilter.unread:
        return base.where((conversation) => conversation.hasUnread).toList();
      case _ConversationFilter.active:
        return base.where((conversation) => conversation.isActive).toList();
    }
  }

  String _conversationTitle(ConversationModel conversation) {
    if (conversation.channel == 'whatsapp') {
      return '${AppConfig.businessDisplayName} WA';
    }

    return AppConfig.businessDisplayName;
  }

  String _conversationSubtitle(ConversationModel conversation) {
    final preview = conversation.latestMessagePreview?.trim();
    if (preview != null && preview.isNotEmpty) {
      return preview;
    }

    final sourceLabel = conversation.sourceLabel?.trim();
    if (sourceLabel != null && sourceLabel.isNotEmpty) {
      return '${conversation.operationalModeLabel} - $sourceLabel';
    }

    return conversation.operationalModeLabel;
  }

  String _formatListTime(DateTime? timestamp) {
    if (timestamp == null) {
      return '';
    }

    final local = timestamp.toLocal();
    final now = DateTime.now();
    final isToday =
        now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;

    if (isToday) {
      final hours = local.hour.toString().padLeft(2, '0');
      final minutes = local.minute.toString().padLeft(2, '0');
      return '$hours:$minutes';
    }

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _buildClientMessageId() {
    final random = Random.secure();
    final nonce = List<int>.generate(
      4,
      (_) => random.nextInt(255),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return 'bootstrap-${DateTime.now().microsecondsSinceEpoch}-$nonce';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        backgroundColor: isError ? AppConfig.danger : AppConfig.success,
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.customerName,
    required this.onStartConversation,
    required this.onRefresh,
    required this.menuBuilder,
  });

  final String customerName;
  final VoidCallback onStartConversation;
  final VoidCallback? onRefresh;
  final WidgetBuilder menuBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppConfig.green, AppConfig.green],
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  AppConfig.appTitle,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Live chat siap untuk $customerName',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xCCFFFFFF),
                  ),
                ),
              ],
            ),
          ),
          _HeaderIconButton(
            icon: Icons.add_circle_outline,
            onTap: onStartConversation,
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(icon: Icons.refresh_rounded, onTap: onRefresh),
          const SizedBox(width: 8),
          menuBuilder(context),
        ],
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, color: AppConfig.subtleText),
          hintText: 'Cari chat atau status',
          hintStyle: TextStyle(color: AppConfig.subtleText),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.repository});

  final CustomerStatusRepository repository;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Status',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        CustomerStatusStrip(repository: repository),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AppConfig.green.withValues(alpha: 0.12)
                : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? AppConfig.green : AppConfig.mutedText,
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarInlineBanner extends StatelessWidget {
  const _SidebarInlineBanner({
    required this.label,
    required this.actionLabel,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onTap,
  });

  final String label;
  final String actionLabel;
  final Color foregroundColor;
  final Color backgroundColor;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: foregroundColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: foregroundColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () => unawaited(onTap()),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _SidebarEmptyState extends StatelessWidget {
  const _SidebarEmptyState({
    required this.isLoading,
    required this.onStartConversation,
  });

  final bool isLoading;
  final VoidCallback onStartConversation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: AppConfig.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: AppConfig.green),
                  )
                : const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 34,
                    color: AppConfig.green,
                  ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Belum ada percakapan aktif',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mulai live chat baru untuk menghubungi tim support dari aplikasi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppConfig.mutedText,
            ),
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[AppConfig.green, AppConfig.greenLight],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              onPressed: onStartConversation,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Mulai Percakapan'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopPlaceholder extends StatelessWidget {
  const _DesktopPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppConfig.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.message_outlined,
                  size: 36,
                  color: AppConfig.green,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Pilih chat untuk mulai',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Daftar conversation di kiri sudah terhubung ke backend Laravel dan siap dipakai untuk polling live chat.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppConfig.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellErrorState extends StatelessWidget {
  const _ShellErrorState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onRetry,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 32,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[AppConfig.green, AppConfig.greenLight],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppConfig.appTitle,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Aplikasi akan menyambungkan sesi live chat secara otomatis.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xE6FFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppConfig.danger.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          size: 32,
                          color: AppConfig.danger,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppConfig.mutedText,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                AppConfig.green,
                                AppConfig.greenLight,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x3300A884),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextButton(
                            onPressed: () => unawaited(onRetry()),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              actionLabel,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GreyInput extends StatelessWidget {
  const _GreyInput({
    required this.controller,
    required this.hintText,
    required this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppConfig.subtleText),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: maxLines > 1 ? 14 : 16,
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

enum _ConversationFilter { all, unread, active }

enum _SidebarMenuAction { refresh, newSession }
