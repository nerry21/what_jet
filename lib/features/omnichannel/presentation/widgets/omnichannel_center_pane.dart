import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../live_chat/presentation/widgets/channel_badge.dart';
import '../../data/models/omnichannel_conversation_detail_model.dart';
import '../../data/models/omnichannel_thread_model.dart';
import 'omnichannel_surface.dart';
import 'whatsapp_attachment_sheet.dart';
import 'whatsapp_emoji_picker.dart';

enum _MobileConversationMenuAction { sendContact, toggleBot }

class OmnichannelCenterPane extends StatefulWidget {
  const OmnichannelCenterPane({
    super.key,
    required this.conversation,
    required this.threadGroups,
    required this.isShellLoading,
    required this.isConversationLoading,
    required this.isSendingReply,
    required this.isSendingContact,
    required this.onSendReply,
    required this.onSendGalleryImage,
    required this.onSendContact,
    required this.isTogglingBot,
    required this.onToggleBot,
    this.onOpenInbox,
  });

  final OmnichannelConversationDetailModel? conversation;
  final List<OmnichannelThreadGroupModel> threadGroups;
  final bool isShellLoading;
  final bool isConversationLoading;
  final bool isSendingReply;
  final bool isSendingContact;
  final Future<bool> Function(String message) onSendReply;
  final Future<bool> Function(String? caption) onSendGalleryImage;
  final Future<bool> Function({
    required String fullName,
    required String phone,
    String? email,
    String? company,
  })
  onSendContact;
  final bool isTogglingBot;
  final Future<bool> Function(bool turnOn) onToggleBot;
  final VoidCallback? onOpenInbox;

  @override
  State<OmnichannelCenterPane> createState() => _OmnichannelCenterPaneState();
}

class _OmnichannelCenterPaneState extends State<OmnichannelCenterPane> {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _threadScrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();

  bool get _isMobileConversationLayout => widget.onOpenInbox != null;

  @override
  void dispose() {
    _composerController.dispose();
    _threadScrollController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openEmojiPicker() async {
    if (widget.conversation == null || widget.isSendingReply) {
      return;
    }

    FocusScope.of(context).unfocus();

    await showWhatsAppEmojiPicker(
      context: context,
      onEmojiSelected: _insertEmoji,
      onBackspacePressed: _deleteSelectedTextOrLastCharacter,
    );

    if (mounted && !widget.isSendingReply) {
      _composerFocusNode.requestFocus();
    }
  }

  void _insertEmoji(String emoji) {
    final value = _composerController.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid && selection.start >= 0
        ? selection.start
        : text.length;
    final end = selection.isValid && selection.end >= 0
        ? selection.end
        : text.length;
    final newText = text.replaceRange(start, end, emoji);
    final newOffset = start + emoji.length;

    _composerController.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
      composing: TextRange.empty,
    );
  }

  Future<void> _finalizeSuccessfulComposerSend() async {
    _composerController.clear();

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (_threadScrollController.hasClients) {
      _threadScrollController.animateTo(
        _threadScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _deleteSelectedTextOrLastCharacter() {
    final value = _composerController.value;
    final text = value.text;
    if (text.isEmpty) {
      return;
    }

    final selection = value.selection;
    final start = selection.isValid && selection.start >= 0
        ? selection.start
        : text.length;
    final end = selection.isValid && selection.end >= 0
        ? selection.end
        : text.length;

    if (start != end) {
      final newText = text.replaceRange(start, end, '');
      _composerController.value = value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.empty,
      );
      return;
    }

    if (start <= 0) {
      return;
    }

    final prefix = text.substring(0, start);
    final prefixLength = prefix.characters.length;
    final truncatedPrefix = prefixLength > 0
        ? prefix.characters.take(prefixLength - 1).toString()
        : '';
    final newText = truncatedPrefix + text.substring(end);

    _composerController.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: truncatedPrefix.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _submitReply() async {
    final text = _composerController.text.trim();
    if (text.isEmpty || widget.isSendingReply || widget.conversation == null) {
      return;
    }

    final success = await widget.onSendReply(text);
    if (success && mounted) {
      await _finalizeSuccessfulComposerSend();
    }
  }

  Future<void> _handleGalleryAttachment() async {
    final caption = _composerController.text.trim();
    final success = await widget.onSendGalleryImage(
      caption.isEmpty ? null : caption,
    );

    if (success && mounted) {
      await _finalizeSuccessfulComposerSend();
    }
  }

  Future<void> _openSendContactDialog() async {
    if (widget.conversation == null || widget.isSendingContact) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return _SendContactDialog(
          isSubmitting: widget.isSendingContact,
          onSubmit: widget.onSendContact,
        );
      },
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$feature belum diaktifkan di backend.')),
      );
  }

  Future<void> _openAttachmentSheet() async {
    if (widget.conversation == null ||
        widget.isSendingReply ||
        widget.isSendingContact) {
      return;
    }

    await showWhatsAppAttachmentSheet(
      context: context,
      onGalleryTap: _handleGalleryAttachment,
      onCameraTap: () async => _showComingSoon('Kamera'),
      onLocationTap: () async => _showComingSoon('Lokasi'),
      onContactTap: _openSendContactDialog,
      onDocumentTap: () async => _showComingSoon('Dokumen'),
      onAudioTap: () async => _showComingSoon('Audio'),
      onPollTap: () async => _showComingSoon('Polling'),
      onEventTap: () async => _showComingSoon('Acara'),
    );
  }

  Future<void> _handleMobileMenuAction(
    _MobileConversationMenuAction action,
  ) async {
    switch (action) {
      case _MobileConversationMenuAction.sendContact:
        await _openSendContactDialog();
        return;
      case _MobileConversationMenuAction.toggleBot:
        final conversation = widget.conversation;
        if (conversation == null || widget.isTogglingBot) {
          return;
        }
        await widget.onToggleBot(!conversation.isBotEnabled);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final threadGroups = widget.threadGroups;
    final isShellLoading = widget.isShellLoading;
    final isConversationLoading = widget.isConversationLoading;

    if (_isMobileConversationLayout) {
      return _MobileConversationScaffold(
        conversation: conversation,
        threadGroups: threadGroups,
        isShellLoading: isShellLoading,
        isConversationLoading: isConversationLoading,
        isSendingReply: widget.isSendingReply,
        isSendingContact: widget.isSendingContact,
        isTogglingBot: widget.isTogglingBot,
        threadScrollController: _threadScrollController,
        composerController: _composerController,
        composerFocusNode: _composerFocusNode,
        onOpenInbox: widget.onOpenInbox!,
        onSubmit: _submitReply,
        onOpenAttachmentSheet: _openAttachmentSheet,
        onEmojiTap: _openEmojiPicker,
        onVideoTap: () => _showComingSoon('Video call'),
        onCallTap: () => _showComingSoon('Panggilan telepon'),
        onCameraTap: () => _showComingSoon('Kamera'),
        onVoiceNoteTap: () => _showComingSoon('Voice note'),
        onMenuSelected: _handleMobileMenuAction,
      );
    }

    return OmnichannelPaneCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isShellLoading)
            const Expanded(child: _CenterPaneSkeleton())
          else if (conversation == null)
            const Expanded(
              child: OmnichannelEmptyState(
                icon: Icons.forum_outlined,
                title: 'Pilih conversation',
                message:
                    'Pane tengah akan menampilkan thread admin setelah item conversation dipilih.',
              ),
            )
          else ...<Widget>[
            _CenterHeader(
              conversation: conversation,
              isConversationLoading: isConversationLoading,
              isTogglingBot: widget.isTogglingBot,
              onToggleBot: widget.onToggleBot,
              onOpenInbox: widget.onOpenInbox,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: threadGroups.isEmpty
                  ? const OmnichannelEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Belum ada thread',
                      message:
                          'Belum ada pesan untuk conversation ini, atau backend belum mengirim thread yang bisa ditampilkan.',
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final bubbleMaxWidth = constraints.maxWidth * 0.78;

                        return ListView.builder(
                          controller: _threadScrollController,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                          itemCount: threadGroups.length,
                          itemBuilder: (context, index) {
                            final group = threadGroups[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index == threadGroups.length - 1
                                    ? 0
                                    : 16,
                              ),
                              child: Column(
                                children: <Widget>[
                                  _DateSeparator(label: group.label),
                                  const SizedBox(height: 12),
                                  ...group.messages.map(
                                    (message) => _ThreadBubble(
                                      message: message,
                                      maxWidth: bubbleMaxWidth,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            SafeArea(
              top: false,
              child: _ActiveComposer(
                controller: _composerController,
                focusNode: _composerFocusNode,
                channel: conversation.channel,
                isSending: widget.isSendingReply,
                isSendingContact: widget.isSendingContact,
                onSubmit: _submitReply,
                onSendContact: _openSendContactDialog,
                onEmojiTap: _openEmojiPicker,
                onVoiceNoteTap: () => _showComingSoon('Voice note'),
                onCallTap: () => _showComingSoon('Panggilan telepon'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileConversationScaffold extends StatelessWidget {
  const _MobileConversationScaffold({
    required this.conversation,
    required this.threadGroups,
    required this.isShellLoading,
    required this.isConversationLoading,
    required this.isSendingReply,
    required this.isSendingContact,
    required this.isTogglingBot,
    required this.threadScrollController,
    required this.composerController,
    required this.composerFocusNode,
    required this.onOpenInbox,
    required this.onSubmit,
    required this.onOpenAttachmentSheet,
    required this.onEmojiTap,
    required this.onVideoTap,
    required this.onCallTap,
    required this.onCameraTap,
    required this.onVoiceNoteTap,
    required this.onMenuSelected,
  });

  final OmnichannelConversationDetailModel? conversation;
  final List<OmnichannelThreadGroupModel> threadGroups;
  final bool isShellLoading;
  final bool isConversationLoading;
  final bool isSendingReply;
  final bool isSendingContact;
  final bool isTogglingBot;
  final ScrollController threadScrollController;
  final TextEditingController composerController;
  final FocusNode composerFocusNode;
  final VoidCallback onOpenInbox;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onOpenAttachmentSheet;
  final Future<void> Function() onEmojiTap;
  final VoidCallback onVideoTap;
  final VoidCallback onCallTap;
  final VoidCallback onCameraTap;
  final VoidCallback onVoiceNoteTap;
  final Future<void> Function(_MobileConversationMenuAction action)
  onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF0E7DD),
      child: Column(
        children: <Widget>[
          _MobileConversationAppBar(
            conversation: conversation,
            isConversationLoading: isConversationLoading,
            isTogglingBot: isTogglingBot,
            onOpenInbox: onOpenInbox,
            onVideoTap: onVideoTap,
            onCallTap: onCallTap,
            onMenuSelected: onMenuSelected,
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                const Positioned.fill(child: _WhatsAppWallpaper()),
                Positioned.fill(
                  child: isShellLoading
                      ? const _MobileConversationLoadingBody()
                      : conversation == null
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: OmnichannelEmptyState(
                            icon: Icons.forum_outlined,
                            title: 'Pilih conversation',
                            message:
                                'Klik salah satu chat untuk membuka percakapan seperti tampilan WhatsApp.',
                          ),
                        )
                      : threadGroups.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: OmnichannelEmptyState(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'Belum ada chat',
                            message:
                                'Thread conversation ini masih kosong atau backend belum mengirim pesan.',
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final bubbleMaxWidth = constraints.maxWidth * 0.78;

                            return ListView.builder(
                              controller: threadScrollController,
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                18,
                              ),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: threadGroups.length,
                              itemBuilder: (context, index) {
                                final group = threadGroups[index];
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == threadGroups.length - 1
                                        ? 0
                                        : 14,
                                  ),
                                  child: Column(
                                    children: <Widget>[
                                      _MobileDateSeparator(label: group.label),
                                      const SizedBox(height: 10),
                                      ...group.messages.map(
                                        (message) => _MobileConversationBubble(
                                          message: message,
                                          maxWidth: bubbleMaxWidth,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          if (conversation != null)
            _MobileConversationComposer(
              controller: composerController,
              focusNode: composerFocusNode,
              isSending: isSendingReply,
              isSendingContact: isSendingContact,
              onSubmit: onSubmit,
              onAttachTap: onOpenAttachmentSheet,
              onEmojiTap: onEmojiTap,
              onCameraTap: onCameraTap,
              onVoiceNoteTap: onVoiceNoteTap,
            ),
        ],
      ),
    );
  }
}

class _MobileConversationAppBar extends StatelessWidget {
  const _MobileConversationAppBar({
    required this.conversation,
    required this.isConversationLoading,
    required this.isTogglingBot,
    required this.onOpenInbox,
    required this.onVideoTap,
    required this.onCallTap,
    required this.onMenuSelected,
  });

  final OmnichannelConversationDetailModel? conversation;
  final bool isConversationLoading;
  final bool isTogglingBot;
  final VoidCallback onOpenInbox;
  final VoidCallback onVideoTap;
  final VoidCallback onCallTap;
  final Future<void> Function(_MobileConversationMenuAction action)
  onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final title = _safeText(conversation?.customerName, fallback: 'Chat');
    final subtitle = _safeText(
      conversation?.customerContact,
      fallback: _safeText(conversation?.subtitle, fallback: 'Omnichannel'),
    );
    final initial = _safeInitial(conversation?.customerName, fallback: 'C');

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppConfig.softBackgroundAlt)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _MobileAppBarIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: onOpenInbox,
              ),
              const SizedBox(width: 4),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      conversation?.channel == 'mobile_live_chat'
                          ? AppConfig.green
                          : AppConfig.purple,
                      conversation?.channel == 'mobile_live_chat'
                          ? AppConfig.greenLight
                          : AppConfig.purpleLight,
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppConfig.mutedText,
                            ),
                          ),
                        ),
                        if (isConversationLoading || isTogglingBot)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppConfig.green,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (conversation != null) ...<Widget>[
                _MobileAppBarIconButton(
                  icon: Icons.videocam_outlined,
                  onTap: onVideoTap,
                ),
                _MobileAppBarIconButton(
                  icon: Icons.call_outlined,
                  onTap: onCallTap,
                ),
                PopupMenuButton<_MobileConversationMenuAction>(
                  onSelected: (value) => onMenuSelected(value),
                  itemBuilder: (context) =>
                      <PopupMenuEntry<_MobileConversationMenuAction>>[
                        const PopupMenuItem<_MobileConversationMenuAction>(
                          value: _MobileConversationMenuAction.sendContact,
                          child: Text('Kirim kontak'),
                        ),
                        PopupMenuItem<_MobileConversationMenuAction>(
                          value: _MobileConversationMenuAction.toggleBot,
                          child: Text(
                            conversation!.isBotEnabled
                                ? 'Matikan bot'
                                : 'Aktifkan bot',
                          ),
                        ),
                      ],
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.black87,
                  ),
                ),
              ],
            ],
          ),
          if (conversation != null) ...<Widget>[
            const SizedBox(height: 10),
            _BotControlBanner(
              conversation: conversation!,
              isTogglingBot: isTogglingBot,
              onPressed: () async {
                await onMenuSelected(_MobileConversationMenuAction.toggleBot);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileAppBarIconButton extends StatelessWidget {
  const _MobileAppBarIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.black87, size: 24),
        ),
      ),
    );
  }
}

class _BotControlBanner extends StatelessWidget {
  const _BotControlBanner({
    required this.conversation,
    required this.isTogglingBot,
    required this.onPressed,
  });

  final OmnichannelConversationDetailModel conversation;
  final bool isTogglingBot;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = conversation.isBotEnabled;
    final title = isEnabled ? 'Bot sedang aktif' : 'Bot sedang nonaktif';
    final description = isEnabled
        ? 'Jika admin membalas langsung, bot otomatis OFF.'
        : (conversation.botAutoResumeEnabled
              ? _buildBotResumeLabel(conversation)
              : 'Bot OFF. Aktifkan lagi secara manual bila diperlukan.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isEnabled
            ? AppConfig.green.withValues(alpha: 0.08)
            : const Color(0xFFFFF4EA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled
              ? AppConfig.green.withValues(alpha: 0.20)
              : const Color(0xFFF1C69A),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: AppConfig.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _BotToggleAction(
            isEnabled: isEnabled,
            isBusy: isTogglingBot,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class _BotToggleAction extends StatelessWidget {
  const _BotToggleAction({
    required this.isEnabled,
    required this.isBusy,
    required this.onPressed,
  });

  final bool isEnabled;
  final bool isBusy;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isBusy ? null : () async => onPressed(),
      style: FilledButton.styleFrom(
        backgroundColor: isEnabled ? const Color(0xFFF38A22) : AppConfig.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: isBusy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              isEnabled ? Icons.toggle_off_rounded : Icons.smart_toy_rounded,
              size: 18,
            ),
      label: Text(
        isEnabled ? 'OFF' : 'ON',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MobileDateSeparator extends StatelessWidget {
  const _MobileDateSeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppConfig.mutedText,
          ),
        ),
      ),
    );
  }
}

class _MobileConversationBubble extends StatelessWidget {
  const _MobileConversationBubble({
    required this.message,
    required this.maxWidth,
  });

  final OmnichannelThreadMessageModel message;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final timeColor = Colors.black.withValues(alpha: 0.58);
    final statusIcon = _buildStatusIcon();

    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
          decoration: BoxDecoration(
            color: message.isMine ? const Color(0xFFD9FDD3) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(message.isMine ? 18 : 4),
              bottomRight: Radius.circular(message.isMine ? 4 : 18),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (message.hasImage) ...<Widget>[
                _ConversationImagePreview(
                  imageUrl: message.imageUrl!,
                  maxWidth: maxWidth - 24,
                ),
                if (message.displayText.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.displayText.isNotEmpty)
                Text(
                  message.displayText,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: Colors.black,
                  ),
                ),
              if (message.displayText.isEmpty && !message.hasImage)
                const Text(
                  '-',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: Colors.black,
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    formatOmnichannelThreadTime(message.sentAt),
                    style: TextStyle(fontSize: 12, color: timeColor),
                  ),
                  if (statusIcon != null) ...<Widget>[
                    const SizedBox(width: 4),
                    statusIcon,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildStatusIcon() {
    if (!message.isMine) {
      return null;
    }

    if (message.isFailed) {
      return const Icon(
        Icons.error_outline_rounded,
        size: 15,
        color: AppConfig.danger,
      );
    }

    if (message.isSending) {
      return const Icon(
        Icons.schedule_rounded,
        size: 15,
        color: AppConfig.subtleText,
      );
    }

    return Icon(
      Icons.done_all_rounded,
      size: 16,
      color: message.isRead ? const Color(0xFF53BDEB) : AppConfig.subtleText,
    );
  }
}

class _MobileConversationComposer extends StatelessWidget {
  const _MobileConversationComposer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.isSendingContact,
    required this.onSubmit,
    required this.onAttachTap,
    required this.onEmojiTap,
    required this.onCameraTap,
    required this.onVoiceNoteTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final bool isSendingContact;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onAttachTap;
  final Future<void> Function() onEmojiTap;
  final VoidCallback onCameraTap;
  final VoidCallback onVoiceNoteTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      color: const Color(0xFFF0E7DD),
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final hasText = value.text.trim().isNotEmpty;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        IconButton(
                          onPressed: isSending ? null : () => onEmojiTap(),
                          icon: const Icon(
                            Icons.emoji_emotions_outlined,
                            color: AppConfig.subtleText,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            enabled: !isSending,
                            minLines: 1,
                            maxLines: 5,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              hintText: 'Ketik pesan',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: isSending || isSendingContact
                              ? null
                              : () => onAttachTap(),
                          icon: isSendingContact
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppConfig.green,
                                  ),
                                )
                              : const Icon(
                                  Icons.attach_file_rounded,
                                  color: AppConfig.subtleText,
                                ),
                        ),
                        IconButton(
                          onPressed: onCameraTap,
                          icon: const Icon(
                            Icons.camera_alt_outlined,
                            color: AppConfig.subtleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppConfig.green,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: isSending
                        ? null
                        : hasText
                        ? () => onSubmit()
                        : onVoiceNoteTap,
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: Center(
                        child: isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                hasText
                                    ? Icons.send_rounded
                                    : Icons.mic_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MobileConversationLoadingBody extends StatelessWidget {
  const _MobileConversationLoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
      children: const <Widget>[
        _MobileDateSeparator(label: 'Memuat chat'),
        SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OmnichannelSkeletonBlock(width: 220, height: 74, radius: 18),
        ),
        SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: OmnichannelSkeletonBlock(width: 180, height: 64, radius: 18),
        ),
        SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: OmnichannelSkeletonBlock(width: 260, height: 92, radius: 18),
        ),
      ],
    );
  }
}

class _WhatsAppWallpaper extends StatelessWidget {
  const _WhatsAppWallpaper();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WhatsAppWallpaperPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _WhatsAppWallpaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFF0E7DD);
    canvas.drawRect(Offset.zero & size, background);

    final circlePaint = Paint()
      ..color = const Color(0xFFD9CEC0).withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final dotPaint = Paint()
      ..color = const Color(0xFFD5C6B6).withValues(alpha: 0.22);

    const spacing = 56.0;
    for (double y = 18; y < size.height + spacing; y += spacing) {
      for (double x = 18; x < size.width + spacing; x += spacing) {
        canvas.drawCircle(Offset(x, y), 10, circlePaint);
        canvas.drawCircle(Offset(x + 16, y + 16), 2.2, dotPaint);
        canvas.drawCircle(Offset(x - 14, y + 12), 1.6, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CenterHeader extends StatelessWidget {
  const _CenterHeader({
    required this.conversation,
    required this.isConversationLoading,
    required this.isTogglingBot,
    required this.onToggleBot,
    this.onOpenInbox,
  });

  final OmnichannelConversationDetailModel conversation;
  final bool isConversationLoading;
  final bool isTogglingBot;
  final Future<bool> Function(bool turnOn) onToggleBot;
  final VoidCallback? onOpenInbox;

  @override
  Widget build(BuildContext context) {
    final initial = _safeInitial(conversation.customerName, fallback: 'C');

    final badges = <String>{
      _safeText(conversation.statusLabel, fallback: ''),
      _safeText(conversation.operationalModeLabel, fallback: ''),
      ...conversation.badges
          .map((badge) => badge.trim())
          .where((badge) => badge.isNotEmpty),
    }.where((badge) => badge.isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConfig.softBackground.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppConfig.softBackgroundAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (onOpenInbox != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: onOpenInbox,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppConfig.softBackgroundAlt,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.black87,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      conversation.channel == 'mobile_live_chat'
                          ? AppConfig.green
                          : AppConfig.purple,
                      conversation.channel == 'mobile_live_chat'
                          ? AppConfig.greenLight
                          : AppConfig.purpleLight,
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _safeText(
                              conversation.title,
                              fallback: 'Conversation',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ChannelBadge(channel: conversation.channel),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _safeText(conversation.subtitle, fallback: '-'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppConfig.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              if (isConversationLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppConfig.green,
                    ),
                  ),
                ),
            ],
          ),
          if (onOpenInbox != null) ...<Widget>[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: onOpenInbox,
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('Daftar Chat'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderBadge(
                  label: conversation.isBotEnabled ? 'Bot: ON' : 'Bot: OFF',
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: isTogglingBot
                    ? null
                    : () => onToggleBot(!conversation.isBotEnabled),
                icon: isTogglingBot
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        conversation.isBotEnabled
                            ? Icons.toggle_off_rounded
                            : Icons.smart_toy_rounded,
                        size: 18,
                      ),
                label: Text(
                  conversation.isBotEnabled ? 'Matikan Bot' : 'Aktifkan Bot',
                ),
              ),
            ],
          ),
          if (conversation.botAutoResumeEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _buildBotResumeLabel(conversation),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppConfig.mutedText,
                ),
              ),
            ),
          if (badges.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: badges
                  .map((badge) => _HeaderBadge(label: badge))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppConfig.softBackgroundAlt),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppConfig.mutedText,
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider(color: AppConfig.softBackgroundAlt)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppConfig.softBackground.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppConfig.mutedText,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppConfig.softBackgroundAlt)),
      ],
    );
  }
}

class _ThreadBubble extends StatelessWidget {
  const _ThreadBubble({required this.message, required this.maxWidth});

  final OmnichannelThreadMessageModel message;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            gradient: message.isMine
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppConfig.bubbleOutgoing,
                      AppConfig.bubbleOutgoingAlt,
                    ],
                  )
                : null,
            color: message.isMine ? null : AppConfig.bubbleIncoming,
            borderRadius: BorderRadius.circular(20),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                message.senderLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: message.isMine ? AppConfig.green : AppConfig.mutedText,
                ),
              ),
              const SizedBox(height: 5),
              if (message.hasImage) ...<Widget>[
                _ConversationImagePreview(
                  imageUrl: message.imageUrl!,
                  maxWidth: maxWidth - 28,
                ),
                if (message.displayText.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.displayText.isNotEmpty)
                Text(
                  message.displayText,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black,
                  ),
                ),
              if (message.displayText.isEmpty && !message.hasImage)
                const Text(
                  '-',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    formatOmnichannelThreadTime(message.sentAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppConfig.subtleText,
                    ),
                  ),
                  if (message.statusLabel != null) ...<Widget>[
                    const SizedBox(width: 8),
                    Text(
                      message.statusLabel!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppConfig.green,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationImagePreview extends StatelessWidget {
  const _ConversationImagePreview({
    required this.imageUrl,
    required this.maxWidth,
  });

  final String imageUrl;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final previewWidth = maxWidth.clamp(160.0, 240.0).toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: previewWidth,
        height: previewWidth,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }

            return const DecoratedBox(
              decoration: BoxDecoration(color: Color(0xFFEDEDED)),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppConfig.green,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) {
            return const DecoratedBox(
              decoration: BoxDecoration(color: Color(0xFFEDEDED)),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.broken_image_outlined,
                      color: AppConfig.subtleText,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Gambar tidak tersedia',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppConfig.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActiveComposer extends StatelessWidget {
  const _ActiveComposer({
    required this.controller,
    required this.focusNode,
    required this.channel,
    required this.isSending,
    required this.isSendingContact,
    required this.onSubmit,
    required this.onSendContact,
    required this.onEmojiTap,
    required this.onVoiceNoteTap,
    required this.onCallTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String channel;
  final bool isSending;
  final bool isSendingContact;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onSendContact;
  final Future<void> Function() onEmojiTap;
  final VoidCallback onVoiceNoteTap;
  final VoidCallback onCallTap;

  @override
  Widget build(BuildContext context) {
    final isWhatsApp = channel == 'whatsapp';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConfig.softBackground.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppConfig.softBackgroundAlt),
      ),
      child: Row(
        children: <Widget>[
          _ComposerActionButton(
            icon: Icons.person_add_alt_1_rounded,
            label: 'Kontak',
            busy: isSendingContact,
            activeColor: AppConfig.green,
            onTap: isSendingContact ? null : onSendContact,
          ),
          const SizedBox(width: 8),
          if (isWhatsApp) ...<Widget>[
            _ComposerIconButton(
              icon: Icons.emoji_emotions_outlined,
              tooltip: 'Emoji',
              onTap: isSending ? null : () => onEmojiTap(),
            ),
            const SizedBox(width: 8),
          ],
          _ComposerIconButton(
            icon: Icons.mic_none_rounded,
            tooltip: 'Voice Note',
            onTap: onVoiceNoteTap,
          ),
          const SizedBox(width: 8),
          _ComposerIconButton(
            icon: Icons.call_outlined,
            tooltip: 'Telepon',
            onTap: onCallTap,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !isSending,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: isWhatsApp
                    ? 'Tulis balasan admin untuk WhatsApp...'
                    : 'Tulis balasan admin untuk live chat...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppConfig.subtleText,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: AppConfig.softBackgroundAlt,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: AppConfig.softBackgroundAlt,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: AppConfig.softBackgroundAlt,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: isSending ? AppConfig.subtleText : AppConfig.green,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: isSending ? null : onSubmit,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerActionButton extends StatelessWidget {
  const _ComposerActionButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final Color activeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppConfig.softBackgroundAlt),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppConfig.green,
                  ),
                )
              else
                Icon(icon, size: 18, color: activeColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppConfig.softBackgroundAlt),
            ),
            child: Icon(
              icon,
              color: onTap == null ? AppConfig.subtleText : AppConfig.mutedText,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _SendContactDialog extends StatefulWidget {
  const _SendContactDialog({
    required this.isSubmitting,
    required this.onSubmit,
  });

  final bool isSubmitting;
  final Future<bool> Function({
    required String fullName,
    required String phone,
    String? email,
    String? company,
  })
  onSubmit;

  @override
  State<_SendContactDialog> createState() => _SendContactDialogState();
}

class _SendContactDialogState extends State<_SendContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  bool _isSubmittingLocal = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmittingLocal) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmittingLocal = true);

    final success = await widget.onSubmit(
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      company: _companyController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmittingLocal = false);

    if (success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.isSubmitting || _isSubmittingLocal;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Kirim Kontak',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kontak ini akan dikirim ke customer melalui WhatsApp.',
                    style: TextStyle(fontSize: 13, color: AppConfig.mutedText),
                  ),
                  const SizedBox(height: 18),
                  _DialogField(
                    controller: _fullNameController,
                    label: 'Nama Lengkap',
                    hintText: 'Contoh: Nerry Popindo',
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Nama kontak wajib diisi.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _DialogField(
                    controller: _phoneController,
                    label: 'Nomor Telepon',
                    hintText: 'Contoh: +628117598804',
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Nomor telepon wajib diisi.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _DialogField(
                    controller: _emailController,
                    label: 'Email',
                    hintText: 'Opsional',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _DialogField(
                    controller: _companyController,
                    label: 'Perusahaan / Organisasi',
                    hintText: 'Opsional',
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: busy ? null : _handleSubmit,
                        icon: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Kirim Kontak'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppConfig.mutedText,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: AppConfig.softBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppConfig.softBackgroundAlt),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppConfig.softBackgroundAlt),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppConfig.green),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _CenterPaneSkeleton extends StatelessWidget {
  const _CenterPaneSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppConfig.softBackground.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppConfig.softBackgroundAlt),
          ),
          child: const Row(
            children: <Widget>[
              OmnichannelSkeletonBlock(width: 48, height: 48, radius: 24),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    OmnichannelSkeletonBlock(width: 180, height: 18),
                    SizedBox(height: 8),
                    OmnichannelSkeletonBlock(width: 220, height: 12),
                    SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        OmnichannelSkeletonBlock(
                          width: 88,
                          height: 26,
                          radius: 999,
                        ),
                        SizedBox(width: 8),
                        OmnichannelSkeletonBlock(
                          width: 120,
                          height: 26,
                          radius: 999,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: OmnichannelSkeletonBlock(
              width: double.infinity,
              height: 280,
              radius: 20,
            ),
          ),
        ),
        const SizedBox(height: 12),
        OmnichannelPaneCard(
          child: Row(
            children: const <Widget>[
              OmnichannelSkeletonBlock(width: 88, height: 40, radius: 999),
              SizedBox(width: 8),
              OmnichannelSkeletonBlock(width: 42, height: 42, radius: 999),
              SizedBox(width: 8),
              OmnichannelSkeletonBlock(width: 42, height: 42, radius: 999),
              SizedBox(width: 10),
              Expanded(child: OmnichannelSkeletonBlock(height: 48, radius: 18)),
              SizedBox(width: 10),
              OmnichannelSkeletonBlock(width: 40, height: 40, radius: 20),
            ],
          ),
        ),
      ],
    );
  }
}

String _safeText(String? value, {required String fallback}) {
  final text = value?.trim();
  return (text == null || text.isEmpty) ? fallback : text;
}

String _safeInitial(String? value, {required String fallback}) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return fallback;
  }
  return text.characters.first.toUpperCase();
}

String _buildBotResumeLabel(OmnichannelConversationDetailModel conversation) {
  final raw = conversation.botAutoResumeAt?.trim();
  final minutes = conversation.botAutoResumeAfterMinutes;

  if (raw == null || raw.isEmpty) {
    return 'Bot aktif otomatis lagi dalam $minutes menit.';
  }

  final parsed = DateTime.tryParse(raw)?.toLocal();
  if (parsed == null) {
    return 'Bot aktif otomatis lagi: $raw';
  }

  final hours = parsed.hour.toString().padLeft(2, '0');
  final mins = parsed.minute.toString().padLeft(2, '0');
  final now = DateTime.now();
  final isToday =
      now.year == parsed.year &&
      now.month == parsed.month &&
      now.day == parsed.day;

  if (isToday) {
    return 'Bot aktif otomatis lagi jam $hours:$mins.';
  }

  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');

  return 'Bot aktif otomatis lagi $day/$month $hours:$mins.';
}
