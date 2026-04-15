import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/models/conversation_model.dart';
import '../../data/repositories/live_chat_repository.dart';
import '../controllers/chat_detail_controller.dart';
import '../widgets/channel_badge.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.repository,
    required this.conversationId,
    this.initialConversation,
    this.pollIntervalMs,
    this.onConversationChanged,
    this.showBackButton = false,
    this.standalone = true,
  });

  final LiveChatRepository repository;
  final int conversationId;
  final ConversationModel? initialConversation;
  final int? pollIntervalMs;
  final ValueChanged<ConversationModel>? onConversationChanged;
  final bool showBackButton;
  final bool standalone;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  late final ChatDetailController _controller;
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String? _lastMessageSignature;

  @override
  void initState() {
    super.initState();
    _controller = ChatDetailController(
      repository: widget.repository,
      conversationId: widget.conversationId,
      initialConversation: widget.initialConversation,
      initialPollIntervalMs: widget.pollIntervalMs,
      onConversationChanged: widget.onConversationChanged,
    )..addListener(_handleControllerChanged);

    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final signature = _messageListSignature(_controller.messages);
    if (signature != _lastMessageSignature) {
      final shouldStickToBottom =
          _isNearBottom ||
          (_controller.messages.isNotEmpty && _controller.messages.last.isMine);
      _lastMessageSignature = signature;

      if (shouldStickToBottom) {
        _scheduleScrollToBottom();
      }
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) {
      return true;
    }

    final remaining =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    return remaining < 140;
  }

  void _scheduleScrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    _messageController.clear();
    _messageFocusNode.requestFocus();
    await _controller.sendMessage(text);
  }

  Future<void> _handleRetry(ChatMessageModel message) async {
    await _controller.retryMessage(message);
  }

  Future<void> _openDummyCall(String modeLabel) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _DummyCallScreen(
          contactLabel: AppConfig.businessDisplayName,
          modeLabel: modeLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Material(
        color: Colors.white,
        child: Column(
          children: <Widget>[
            _ConversationHeader(
              conversation: _controller.conversation,
              showBackButton: widget.showBackButton,
              onBack: () => Navigator.of(context).maybePop(),
              onStartVoiceCall: () => _openDummyCall('Panggilan suara'),
              onStartVideoCall: () => _openDummyCall('Panggilan video'),
              onRefresh: _controller.refresh,
              isRefreshing: _controller.isRefreshing || _controller.isPolling,
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFFF9F9F9), Colors.white],
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    if (_controller.isUnauthorized)
                      _ConversationBanner(
                        label:
                            _controller.errorMessage ??
                            'Sesi mobile berakhir. Kembali dan login ulang.',
                        actionLabel: 'Kembali',
                        color: const Color(0xFFFFECEE),
                        foregroundColor: AppColors.error,
                        onTap: () {
                          Navigator.of(context).maybePop();
                        },
                      ),
                    if (_controller.connectionMessage != null)
                      _ConversationBanner(
                        label: _controller.connectionMessage!,
                        actionLabel: 'Coba lagi',
                        color: const Color(0xFFFFF4E5),
                        foregroundColor: const Color(0xFF9A6700),
                        onTap: _controller.refresh,
                      ),
                    if (_controller.errorMessage != null &&
                        _controller.hasMessages &&
                        !_controller.isUnauthorized)
                      _ConversationBanner(
                        label: _controller.errorMessage!,
                        actionLabel: 'Refresh',
                        color: const Color(0xFFFFECEE),
                        foregroundColor: AppColors.error,
                        onTap: _controller.refresh,
                      ),
                    Expanded(child: _buildMessageArea(context)),
                  ],
                ),
              ),
            ),
            ChatInputBar(
              controller: _messageController,
              focusNode: _messageFocusNode,
              enabled:
                  !_controller.isLoading &&
                  _controller.conversation != null &&
                  !_controller.isUnauthorized,
              isSending: _controller.isComposerBusy,
              onSend: _handleSend,
            ),
          ],
        ),
      ),
    );

    if (!widget.standalone) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(child: content),
    );
  }

  Widget _buildMessageArea(BuildContext context) {
    if (_controller.isLoading && !_controller.hasMessages) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_controller.errorMessage != null && !_controller.hasMessages) {
      return _ConversationErrorState(
        title: _controller.isUnauthorized
            ? 'Sesi mobile berakhir'
            : 'Detail chat gagal dimuat',
        message: _controller.errorMessage!,
        actionLabel: _controller.isUnauthorized ? 'Kembali' : 'Coba lagi',
        onRetry: _controller.isUnauthorized
            ? () async {
                if (mounted) {
                  await Navigator.of(context).maybePop();
                }
              }
            : _controller.load,
      );
    }

    if (!_controller.hasMessages) {
      return _ConversationEmptyState(onRefresh: _controller.refresh);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 768;
        final bubbleMaxWidth = constraints.maxWidth * (compact ? 0.78 : 0.56);

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _controller.refresh,
          child: ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            itemCount: _controller.messages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final message = _controller.messages[index];
              return MessageBubble(
                message: message,
                timeLabel: _formatTime(message.sentAt),
                maxWidth: bubbleMaxWidth,
                onRetry: message.isMine && message.isFailed
                    ? () => unawaited(_handleRetry(message))
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  String _messageListSignature(List<ChatMessageModel> messages) {
    if (messages.isEmpty) {
      return 'empty';
    }

    final latest = messages.last;
    return '${messages.length}-${latest.stableKey}-${latest.deliveryStatus ?? ''}';
  }

  String _formatTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    final hours = local.hour.toString().padLeft(2, '0');
    final minutes = local.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.conversation,
    required this.showBackButton,
    required this.onBack,
    required this.onStartVoiceCall,
    required this.onStartVideoCall,
    required this.onRefresh,
    required this.isRefreshing,
  });

  final ConversationModel? conversation;
  final bool showBackButton;
  final VoidCallback onBack;
  final VoidCallback onStartVoiceCall;
  final VoidCallback onStartVideoCall;
  final Future<void> Function() onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final modeLabel =
        conversation?.operationalModeLabel ?? AppConfig.businessSubtitle;
    final channel = conversation?.channel ?? 'mobile_live_chat';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.primary, AppColors.primary],
        ),
      ),
      child: Row(
        children: <Widget>[
          if (showBackButton) ...<Widget>[
            _HeaderIconButton(icon: Icons.chevron_left, onTap: onBack),
            const SizedBox(width: 8),
          ],
          const _ContactAvatar(label: 'J'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Flexible(
                      child: Text(
                        AppConfig.businessDisplayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChannelBadge(channel: channel, compact: true),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  modeLabel,
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
            icon: isRefreshing ? Icons.sync_rounded : Icons.refresh_rounded,
            onTap: () => unawaited(onRefresh()),
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: Icons.phone_outlined,
            onTap: onStartVoiceCall,
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: Icons.videocam_outlined,
            onTap: onStartVideoCall,
          ),
        ],
      ),
    );
  }
}

class _ConversationBanner extends StatelessWidget {
  const _ConversationBanner({
    required this.label,
    required this.actionLabel,
    required this.color,
    required this.foregroundColor,
    required this.onTap,
  });

  final String label;
  final String actionLabel;
  final Color color;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: foregroundColor,
              ),
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: foregroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _ConversationEmptyState extends StatelessWidget {
  const _ConversationEmptyState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.message_outlined,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada pesan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Percakapan akan muncul di sini begitu live chat dimulai.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.neutral500,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => unawaited(onRefresh()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationErrorState extends StatelessWidget {
  const _ConversationErrorState({
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 32,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
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
                color: AppColors.neutral500,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => unawaited(onRetry()),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
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

class _ContactAvatar extends StatelessWidget {
  const _ContactAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Colors.white24, Colors.white38],
          ),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _DummyCallScreen extends StatefulWidget {
  const _DummyCallScreen({required this.contactLabel, required this.modeLabel});

  final String contactLabel;
  final String modeLabel;

  @override
  State<_DummyCallScreen> createState() => _DummyCallScreenState();
}

class _DummyCallScreenState extends State<_DummyCallScreen> {
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _seconds++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.primary, AppColors.primary200],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Positioned(
                top: 16,
                left: 12,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.contactLabel.characters.first.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.contactLabel,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.modeLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xE6FFFFFF),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _formatCallTime(_seconds),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xE6FFFFFF),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _CallControlButton(
                          icon: Icons.mic_none_rounded,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(width: 20),
                        _CallControlButton(
                          icon: Icons.volume_up_outlined,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(width: 20),
                        _CallControlButton(
                          icon: Icons.call_end_rounded,
                          color: const Color(0xFFFF6B6B),
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCallTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainderSeconds = seconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainderSeconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${remainderSeconds.toString().padLeft(2, '0')}';
  }
}

class _CallControlButton extends StatelessWidget {
  const _CallControlButton({
    required this.icon,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
