import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import '../../data/models/omnichannel_call_history_item_model.dart';
import '../../../live_chat/presentation/widgets/channel_badge.dart';
import '../../data/models/omnichannel_call_session_model.dart';
import '../../data/models/omnichannel_call_timeline_item_model.dart';
import '../../data/models/omnichannel_conversation_detail_model.dart';
import '../../data/models/omnichannel_thread_model.dart';
import '../pages/location_picker_page.dart';
import '../utils/omnichannel_call_status_ui.dart';
import 'omnichannel_call_banner.dart';
import 'omnichannel_call_history_section.dart';
import 'omnichannel_call_timeline_section.dart';
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
    required this.onSendCameraImage,
    required this.onSendContact,
    required this.onSendDocument,
    required this.onSendLocation,
    required this.onSendVoiceNote,
    required this.onCancelVoiceNote,
    required this.isRecordingVoiceNote,
    required this.isTogglingBot,
    required this.onToggleBot,
    required this.callSession,
    required this.callTimeline,
    required this.callHistorySummary,
    required this.callHistory,
    required this.isCallFallbackMode,
    required this.callFallbackMessage,
    this.showCallBanner = true,
    this.onHideCallBanner,
    required this.isCallLoading,
    required this.onCallTap,
    required this.onVideoTap,
    required this.onOpenCallPage,
    this.onOpenCallHistory,
    this.onEndCall,
    this.onOpenInbox,
    this.selectionVersion = 0,
  });

  final OmnichannelConversationDetailModel? conversation;
  final List<OmnichannelThreadGroupModel> threadGroups;
  final bool isShellLoading;
  final bool isConversationLoading;
  final bool isSendingReply;
  final bool isSendingContact;
  final Future<bool> Function(String message) onSendReply;
  final Future<bool> Function(String? caption) onSendGalleryImage;
  final Future<bool> Function(String? caption) onSendCameraImage;
  final Future<bool> Function({
    required String fullName,
    required String phone,
    String? email,
    String? company,
  })
  onSendContact;
  final Future<bool> Function(String? caption) onSendDocument;
  final Future<bool> Function({
    required double latitude,
    required double longitude,
    String? locationName,
    String? locationAddress,
  })
  onSendLocation;
  final Future<bool> Function() onSendVoiceNote;
  final Future<bool> Function() onCancelVoiceNote;
  final bool isRecordingVoiceNote;
  final bool isTogglingBot;
  final Future<bool> Function(bool turnOn) onToggleBot;
  final OmnichannelCallSessionModel? callSession;
  final List<OmnichannelCallTimelineItemModel> callTimeline;
  final OmnichannelConversationCallHistorySummaryModel? callHistorySummary;
  final List<OmnichannelCallHistoryItemModel> callHistory;
  final bool isCallFallbackMode;
  final String? callFallbackMessage;
  final bool showCallBanner;
  final VoidCallback? onHideCallBanner;
  final bool isCallLoading;
  final Future<void> Function() onCallTap;
  final Future<void> Function() onVideoTap;
  final VoidCallback? onOpenCallPage;
  final VoidCallback? onOpenCallHistory;
  final Future<void> Function()? onEndCall;
  final VoidCallback? onOpenInbox;
  final int selectionVersion;

  @override
  State<OmnichannelCenterPane> createState() => _OmnichannelCenterPaneState();
}

class _OmnichannelCenterPaneState extends State<OmnichannelCenterPane> {
  static const double _threadBottomThreshold = 120;

  final TextEditingController _composerController = TextEditingController();
  final ScrollController _threadScrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();

  bool get _isMobileConversationLayout => widget.onOpenInbox != null;

  @override
  void initState() {
    super.initState();

    if (_threadMessageCount(widget.threadGroups) > 0) {
      _scheduleScrollToThreadBottom();
    }
  }

  @override
  void didUpdateWidget(covariant OmnichannelCenterPane oldWidget) {
    super.didUpdateWidget(oldWidget);

    final previousConversationId = oldWidget.conversation?.id;
    final currentConversationId = widget.conversation?.id;
    final conversationChanged = previousConversationId != currentConversationId;
    final previousMessageCount = _threadMessageCount(oldWidget.threadGroups);
    final currentMessageCount = _threadMessageCount(widget.threadGroups);
    final previousLatestMessageId = _latestThreadMessageId(
      oldWidget.threadGroups,
    );
    final currentLatestMessageId = _latestThreadMessageId(widget.threadGroups);
    final wasNearBottom = _isNearThreadBottom();
    final selectionVersionChanged =
        oldWidget.selectionVersion != widget.selectionVersion;

    if (conversationChanged && currentMessageCount > 0) {
      _scheduleScrollToThreadBottom();
      return;
    }

    // Re-selecting the same conversation (e.g. tapping it again in the
    // inbox list) should still jump to the latest message.
    if (selectionVersionChanged && currentMessageCount > 0) {
      _scheduleScrollToThreadBottom();
      return;
    }

    if (previousMessageCount == 0 && currentMessageCount > 0) {
      _scheduleScrollToThreadBottom();
      return;
    }

    final hasNewLatestMessage =
        previousLatestMessageId != null &&
        currentLatestMessageId != null &&
        currentLatestMessageId > previousLatestMessageId;

    if (hasNewLatestMessage && wasNearBottom) {
      _scheduleScrollToThreadBottom(animated: true);
    }
  }

  @override
  void dispose() {
    _composerController.dispose();
    _threadScrollController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  bool _isNearThreadBottom() {
    if (!_threadScrollController.hasClients) {
      return true;
    }

    final position = _threadScrollController.position;
    return position.maxScrollExtent - position.pixels <= _threadBottomThreshold;
  }

  void _scheduleScrollToThreadBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_threadScrollController.hasClients) {
        return;
      }

      final targetOffset = _threadScrollController.position.maxScrollExtent;
      if (animated) {
        _threadScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        return;
      }

      _threadScrollController.jumpTo(targetOffset);
    });
  }

  int _threadMessageCount(List<OmnichannelThreadGroupModel> groups) {
    var count = 0;

    for (final group in groups) {
      count += group.messages.length;
    }

    return count;
  }

  int? _latestThreadMessageId(List<OmnichannelThreadGroupModel> groups) {
    int? latestId;

    for (final group in groups) {
      for (final message in group.messages) {
        final id = message.id;
        if (latestId == null || id > latestId) {
          latestId = id;
        }
      }
    }

    return latestId;
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

  Future<void> _handleCameraAttachment() async {
    final caption = _composerController.text.trim();
    final success = await widget.onSendCameraImage(
      caption.isEmpty ? null : caption,
    );

    if (success && mounted) {
      await _finalizeSuccessfulComposerSend();
    }
  }

  Future<void> _handleDirectCameraTap() async {
    if (widget.conversation == null ||
        widget.isSendingReply ||
        widget.isSendingContact) {
      return;
    }

    await _handleCameraAttachment();
  }

  Future<void> _handleVoiceNoteTap() async {
    if (widget.conversation == null ||
        widget.isSendingReply ||
        widget.isSendingContact) {
      return;
    }

    final success = await widget.onSendVoiceNote();
    if (success && mounted && _threadScrollController.hasClients) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      _threadScrollController.animateTo(
        _threadScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _handleCancelVoiceNoteTap() async {
    if (widget.conversation == null || !widget.isRecordingVoiceNote) {
      return;
    }

    await widget.onCancelVoiceNote();
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

  Future<void> _handleDocumentAttachment() async {
    final caption = _composerController.text.trim();
    final success = await widget.onSendDocument(
      caption.isEmpty ? null : caption,
    );

    if (success && mounted) {
      await _finalizeSuccessfulComposerSend();
    }
  }

  Future<void> _handleAudioFileAttachment() async {
    // Audio from the attachment tray is sent as a document (it keeps the
    // original filename and MIME type, while the mic button beside the
    // composer is still used to record and send voice notes).
    final caption = _composerController.text.trim();
    final success = await widget.onSendDocument(
      caption.isEmpty ? null : caption,
    );

    if (success && mounted) {
      await _finalizeSuccessfulComposerSend();
    }
  }

  Future<void> _handlePollAttachment() async {
    if (widget.conversation == null || widget.isSendingReply) {
      return;
    }

    final poll = await showDialog<_PollDraftResult>(
      context: context,
      builder: (context) => const _SendPollDialog(),
    );

    if (poll == null || !mounted) {
      return;
    }

    final buffer = StringBuffer('📊 *${poll.question}*\n\n');
    for (var i = 0; i < poll.options.length; i++) {
      buffer.writeln('${i + 1}. ${poll.options[i]}');
    }
    buffer.writeln(
      '\nBalas dengan angka (1-${poll.options.length}) untuk memilih.',
    );

    final success = await widget.onSendReply(buffer.toString().trim());
    if (success && mounted) {
      await _finalizeSuccessfulComposerSend();
    }
  }

  Future<void> _handleEventAttachment() async {
    if (widget.conversation == null || widget.isSendingReply) {
      return;
    }

    final event = await showDialog<_EventDraftResult>(
      context: context,
      builder: (context) => const _SendEventDialog(),
    );

    if (event == null || !mounted) {
      return;
    }

    final buffer = StringBuffer('📅 *${event.title}*\n\n');
    if (event.location.isNotEmpty) {
      buffer.writeln('📍 ${event.location}');
    }
    buffer.writeln('🗓️ ${event.formattedDate()}');
    if (event.description.isNotEmpty) {
      buffer.writeln('\n${event.description}');
    }

    final success = await widget.onSendReply(buffer.toString().trim());
    if (success && mounted) {
      await _finalizeSuccessfulComposerSend();
    }
  }

  Future<void> _handleLocationAttachment() async {
    if (widget.conversation == null || widget.isSendingReply) {
      return;
    }

    final result = await Navigator.of(context).push<PickedLocationResult>(
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );

    if (result == null || !mounted) {
      return;
    }

    final success = await widget.onSendLocation(
      latitude: result.latitude,
      longitude: result.longitude,
      locationName: result.name,
      locationAddress: result.address,
    );

    if (success && mounted) {
      await _finalizeSuccessfulComposerSend();
    }
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
      onCameraTap: _handleCameraAttachment,
      onLocationTap: _handleLocationAttachment,
      onContactTap: _openSendContactDialog,
      onDocumentTap: _handleDocumentAttachment,
      onAudioTap: _handleAudioFileAttachment,
      onPollTap: _handlePollAttachment,
      onEventTap: _handleEventAttachment,
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

  Widget? _buildCallBanner() {
    final session = widget.callSession;
    if (!widget.showCallBanner || !omnichannelShouldShowCallBanner(session)) {
      return null;
    }

    return OmnichannelCallBanner(
      session: session,
      isBusy: widget.isCallLoading,
      isFallbackMode: widget.isCallFallbackMode,
      fallbackNote: widget.callFallbackMessage,
      onOpenCall: widget.onOpenCallPage ?? () => unawaited(widget.onCallTap()),
      onEndCall: widget.onEndCall,
      onClose: widget.onHideCallBanner,
    );
  }

  Widget? _buildCallTimelineSection({required bool compact}) {
    final session = widget.callSession;
    final items = widget.callTimeline;
    if (session == null && items.isEmpty) {
      return null;
    }

    return OmnichannelCallTimelineSection(
      items: items,
      session: session,
      dark: false,
      maxItems: compact ? 4 : 6,
      title: 'Riwayat panggilan',
      subtitle: widget.isCallFallbackMode
          ? 'Event panggilan tetap tersimpan di thread, sementara audio live belum tersedia pada build admin ini.'
          : 'Perubahan status panggilan ditampilkan sebagai event sistem di thread ini.',
      emptyMessage:
          'Histori panggilan belum tersedia. Status aktif akan muncul di sini saat backend mengirim pembaruan.',
    );
  }

  Widget? _buildCallHistorySection({required bool compact}) {
    if (widget.callHistorySummary == null && widget.callHistory.isEmpty) {
      return null;
    }

    return OmnichannelCallHistorySection(
      summary: widget.callHistorySummary,
      items: widget.callHistory,
      maxItems: compact ? 3 : 4,
      onOpenAll: widget.onOpenCallHistory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final threadGroups = widget.threadGroups;
    final isShellLoading = widget.isShellLoading;
    final isConversationLoading = widget.isConversationLoading;
    final callBanner = _buildCallBanner();
    final callHistorySection = _buildCallHistorySection(compact: false);
    final callTimelineSection = _buildCallTimelineSection(compact: false);

    if (_isMobileConversationLayout) {
      return _MobileConversationScaffold(
        conversation: conversation,
        threadGroups: threadGroups,
        isShellLoading: isShellLoading,
        isConversationLoading: isConversationLoading,
        isSendingReply: widget.isSendingReply,
        isSendingContact: widget.isSendingContact,
        isRecordingVoiceNote: widget.isRecordingVoiceNote,
        isTogglingBot: widget.isTogglingBot,
        threadScrollController: _threadScrollController,
        composerController: _composerController,
        composerFocusNode: _composerFocusNode,
        onOpenInbox: widget.onOpenInbox!,
        onSubmit: _submitReply,
        onOpenAttachmentSheet: _openAttachmentSheet,
        onEmojiTap: _openEmojiPicker,
        onVideoTap: () => unawaited(widget.onVideoTap()),
        onCallTap: () => unawaited(widget.onCallTap()),
        onCameraTap: _handleDirectCameraTap,
        onVoiceNoteTap: _handleVoiceNoteTap,
        onCancelVoiceNoteTap: _handleCancelVoiceNoteTap,
        onMenuSelected: _handleMobileMenuAction,
        callBanner: callBanner,
        callHistorySection: _buildCallHistorySection(compact: true),
        callTimelineSection: _buildCallTimelineSection(compact: true),
      );
    }

    return OmnichannelPaneCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isShellLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
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
            if (callBanner != null) ...<Widget>[
              callBanner,
              const SizedBox(height: 12),
            ],
            Expanded(
              child:
                  threadGroups.isEmpty &&
                      callHistorySection == null &&
                      callTimelineSection == null
                  ? const OmnichannelEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Belum ada thread',
                      message:
                          'Belum ada pesan untuk conversation ini, atau backend belum mengirim thread yang bisa ditampilkan.',
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final bubbleMaxWidth = constraints.maxWidth * 0.78;

                        return ListView(
                          controller: _threadScrollController,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(0, 0, 0, 12),
                          children: <Widget>[
                            if (callHistorySection != null) ...<Widget>[
                              callHistorySection,
                              const SizedBox(height: 16),
                            ],
                            if (callTimelineSection != null) ...<Widget>[
                              callTimelineSection,
                              const SizedBox(height: 16),
                            ],
                            if (threadGroups.isEmpty)
                              const OmnichannelEmptyState(
                                icon: Icons.chat_bubble_outline_rounded,
                                title: 'Belum ada pesan chat',
                                message:
                                    'Riwayat panggilan tetap ditampilkan di atas. Pesan chat akan muncul di sini saat percakapan berjalan.',
                              )
                            else
                              for (
                                var index = 0;
                                index < threadGroups.length;
                                index++
                              ) ...<Widget>[
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == threadGroups.length - 1
                                        ? 0
                                        : 16,
                                  ),
                                  child: Column(
                                    children: <Widget>[
                                      _DateSeparator(
                                        label: threadGroups[index].label,
                                      ),
                                      const SizedBox(height: 12),
                                      ...threadGroups[index].messages.map(
                                        (message) => _ThreadBubble(
                                          message: message,
                                          maxWidth: bubbleMaxWidth,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                          ],
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
                onVoiceNoteTap: _handleVoiceNoteTap,
                isRecordingVoiceNote: widget.isRecordingVoiceNote,
                onCallTap: () => unawaited(widget.onCallTap()),
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
    required this.isRecordingVoiceNote,
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
    required this.onCancelVoiceNoteTap,
    required this.onMenuSelected,
    this.callBanner,
    this.callHistorySection,
    this.callTimelineSection,
  });

  final OmnichannelConversationDetailModel? conversation;
  final List<OmnichannelThreadGroupModel> threadGroups;
  final bool isShellLoading;
  final bool isConversationLoading;
  final bool isSendingReply;
  final bool isSendingContact;
  final bool isRecordingVoiceNote;
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
  final Future<void> Function() onCancelVoiceNoteTap;
  final Future<void> Function(_MobileConversationMenuAction action)
  onMenuSelected;
  final Widget? callBanner;
  final Widget? callHistorySection;
  final Widget? callTimelineSection;

  @override
  Widget build(BuildContext context) {
    final threadBody = isShellLoading
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
        : threadGroups.isEmpty &&
              callHistorySection == null &&
              callTimelineSection == null
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

              return ListView(
                controller: threadScrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(12, 12, 12, 18),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: <Widget>[
                  if (callHistorySection != null) ...<Widget>[
                    callHistorySection!,
                    const SizedBox(height: 14),
                  ],
                  if (callTimelineSection != null) ...<Widget>[
                    callTimelineSection!,
                    const SizedBox(height: 14),
                  ],
                  if (threadGroups.isEmpty)
                    const OmnichannelEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Belum ada chat',
                      message:
                          'Riwayat panggilan tetap tampil di atas. Pesan chat akan muncul di sini saat conversation bergerak.',
                    )
                  else
                    for (var index = 0; index < threadGroups.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == threadGroups.length - 1 ? 0 : 14,
                        ),
                        child: Column(
                          children: <Widget>[
                            _MobileDateSeparator(
                              label: threadGroups[index].label,
                            ),
                            const SizedBox(height: 10),
                            ...threadGroups[index].messages.map(
                              (message) => _MobileConversationBubble(
                                message: message,
                                maxWidth: bubbleMaxWidth,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              );
            },
          );

    return ColoredBox(
      color: AppColors.surfaceTertiary,
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
                  child: Column(
                    children: <Widget>[
                      if (callBanner != null)
                        Padding(
                          padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
                          child: callBanner!,
                        ),
                      Expanded(child: threadBody),
                    ],
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
              isRecordingVoiceNote: isRecordingVoiceNote,
              onSubmit: onSubmit,
              onAttachTap: onOpenAttachmentSheet,
              onEmojiTap: onEmojiTap,
              onCameraTap: onCameraTap,
              onVoiceNoteTap: onVoiceNoteTap,
              onCancelVoiceNoteTap: onCancelVoiceNoteTap,
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
      padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
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
                          ? AppColors.primary
                          : AppColors.accent,
                      conversation?.channel == 'mobile_live_chat'
                          ? AppColors.primary200
                          : AppColors.accent200,
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.surfacePrimary,
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutral800,
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
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.neutral500,
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
                                color: AppColors.primary,
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
                    color: AppColors.neutral800,
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
        borderRadius: AppRadii.borderRadiusPill,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.neutral800, size: 24),
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
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isEnabled
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.warning50,
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(
          color: isEnabled
              ? AppColors.primary.withValues(alpha: 0.20)
              : AppColors.warning,
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutral800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: AppColors.neutral500,
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
        backgroundColor: isEnabled
            ? const Color(0xFFF38A22)
            : AppColors.primary,
        foregroundColor: AppColors.white,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderRadiusMd),
      ),
      icon: isBusy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.surfacePrimary,
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
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary.withValues(alpha: 0.75),
          borderRadius: AppRadii.borderRadiusPill,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.neutral500,
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
    final timeColor = AppColors.neutral800.withValues(alpha: 0.58);
    final statusIcon = _buildStatusIcon();

    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.fromLTRB(12, 9, 12, 8),
          decoration: BoxDecoration(
            color: message.isMine
                ? AppColors.bubbleOutgoing
                : AppColors.bubbleIncoming,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(message.isMine ? 18 : 4),
              bottomRight: Radius.circular(message.isMine ? 4 : 18),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0x18000000),
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
                  downloadUrl: message.preferredImageDownloadUrl,
                  maxWidth: maxWidth - 24,
                ),
                if (message.displayText.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.hasAudio) ...<Widget>[
                _ConversationAudioBubble(message: message, compact: true),
                if (message.displayText.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.hasVideo) ...<Widget>[
                _ConversationVideoCard(message: message, compact: true),
                if (message.displayText.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.hasDocument) ...<Widget>[
                _ConversationDocumentCard(message: message, compact: true),
                if (message.displayText.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.hasLocation) ...<Widget>[
                _ConversationLocationCard(
                  message: message,
                  maxWidth: maxWidth - 24,
                ),
                if (message.displayText.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.hasInteractive) ...<Widget>[
                _ConversationInteractiveCard(message: message),
                if (message.displayText.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.displayText.isNotEmpty)
                Text(
                  message.displayText,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: AppColors.neutral800,
                  ),
                ),
              if (message.displayText.isEmpty &&
                  !message.hasImage &&
                  !message.hasAudio &&
                  !message.hasVideo &&
                  !message.hasDocument &&
                  !message.hasLocation &&
                  !message.hasInteractive)
                const Text(
                  '-',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: AppColors.neutral800,
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
        color: AppColors.error,
      );
    }

    if (message.isSending) {
      return const Icon(
        Icons.schedule_rounded,
        size: 15,
        color: AppColors.neutral300,
      );
    }

    return Icon(
      Icons.done_all_rounded,
      size: 16,
      color: message.isRead ? AppColors.readReceipt : AppColors.neutral300,
    );
  }
}

class _MobileConversationComposer extends StatefulWidget {
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
    required this.onCancelVoiceNoteTap,
    required this.isRecordingVoiceNote,
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
  final Future<void> Function() onCancelVoiceNoteTap;
  final bool isRecordingVoiceNote;

  @override
  State<_MobileConversationComposer> createState() =>
      _MobileConversationComposerState();
}

class _MobileConversationComposerState
    extends State<_MobileConversationComposer> {
  Timer? _timer;
  int _recordingSeconds = 0;

  @override
  void didUpdateWidget(covariant _MobileConversationComposer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isRecordingVoiceNote && widget.isRecordingVoiceNote) {
      _startTimer();
    } else if (oldWidget.isRecordingVoiceNote && !widget.isRecordingVoiceNote) {
      _stopTimer(reset: true);
    }
  }

  @override
  void dispose() {
    _stopTimer(reset: false);
    super.dispose();
  }

  void _startTimer() {
    _stopTimer(reset: false);
    _recordingSeconds = 0;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _recordingSeconds += 1;
      });
    });
  }

  void _stopTimer({required bool reset}) {
    _timer?.cancel();
    _timer = null;

    if (reset && mounted) {
      setState(() {
        _recordingSeconds = 0;
      });
    } else if (reset) {
      _recordingSeconds = 0;
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm.$ss';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isRecordingVoiceNote) {
      return Container(
        padding: EdgeInsets.fromLTRB(10, 8, 10, 10),
        color: AppColors.surfaceTertiary,
        child: SafeArea(
          top: false,
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: widget.isSending
                    ? null
                    : () => widget.onCancelVoiceNoteTap(),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.neutral300,
                  size: 28,
                ),
              ),
              Expanded(
                child: Container(
                  height: 58,
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: AppRadii.borderRadiusXxxl,
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        _formatDuration(_recordingSeconds),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.neutral800,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(child: _VoiceNoteWaveform()),
                      const SizedBox(width: 10),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.error50,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.pause_rounded,
                          color: AppColors.error,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: AppColors.primary,
                borderRadius: AppRadii.borderRadiusPill,
                child: InkWell(
                  onTap: widget.isSending ? null : widget.onVoiceNoteTap,
                  borderRadius: AppRadii.borderRadiusPill,
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: Center(
                      child: widget.isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.surfacePrimary,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: AppColors.surfacePrimary,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 10),
      color: AppColors.surfaceTertiary,
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, value, _) {
            final hasText = value.text.trim().isNotEmpty;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        IconButton(
                          onPressed: widget.isSending
                              ? null
                              : () => widget.onEmojiTap(),
                          icon: const Icon(
                            Icons.emoji_emotions_outlined,
                            color: AppColors.neutral300,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            enabled: !widget.isSending,
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
                          onPressed: widget.isSending || widget.isSendingContact
                              ? null
                              : () => widget.onAttachTap(),
                          icon: widget.isSendingContact
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : const Icon(
                                  Icons.attach_file_rounded,
                                  color: AppColors.neutral300,
                                ),
                        ),
                        IconButton(
                          onPressed: widget.onCameraTap,
                          icon: const Icon(
                            Icons.camera_alt_outlined,
                            color: AppColors.neutral300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.primary,
                  borderRadius: AppRadii.borderRadiusPill,
                  child: InkWell(
                    onTap: widget.isSending
                        ? null
                        : hasText
                        ? () => widget.onSubmit()
                        : widget.onVoiceNoteTap,
                    borderRadius: AppRadii.borderRadiusPill,
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: Center(
                        child: widget.isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.surfacePrimary,
                                ),
                              )
                            : Icon(
                                hasText
                                    ? Icons.send_rounded
                                    : Icons.mic_rounded,
                                color: AppColors.surfacePrimary,
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

class _VoiceNoteWaveform extends StatelessWidget {
  const _VoiceNoteWaveform();

  @override
  Widget build(BuildContext context) {
    const bars = <double>[
      10,
      14,
      18,
      12,
      20,
      26,
      16,
      22,
      28,
      14,
      18,
      24,
      30,
      16,
      22,
      12,
      26,
      18,
      14,
      20,
      24,
      16,
      28,
      18,
      12,
      22,
      26,
      14,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: bars
          .map(
            (height) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 3,
                height: height,
                decoration: BoxDecoration(
                  color: AppColors.neutral300,
                  borderRadius: AppRadii.borderRadiusPill,
                ),
              ),
            ),
          )
          .toList(),
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
      padding: EdgeInsets.fromLTRB(12, 14, 12, 18),
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
    final background = Paint()..color = AppColors.surfaceTertiary;
    canvas.drawRect(Offset.zero & size, background);

    final circlePaint = Paint()
      ..color = AppColors.borderLight.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final dotPaint = Paint()
      ..color = AppColors.borderLight.withValues(alpha: 0.22);

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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground.withValues(alpha: 0.72),
        borderRadius: AppRadii.borderRadiusXl,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (onOpenInbox != null)
                Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Material(
                    color: AppColors.surfaceSecondary,
                    borderRadius: AppRadii.borderRadiusPill,
                    child: InkWell(
                      onTap: onOpenInbox,
                      borderRadius: AppRadii.borderRadiusPill,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: AppRadii.borderRadiusPill,
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.neutral800,
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
                          ? AppColors.primary
                          : AppColors.accent,
                      conversation.channel == 'mobile_live_chat'
                          ? AppColors.primary200
                          : AppColors.accent200,
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.surfacePrimary,
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.neutral800,
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
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.neutral500,
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
                      color: AppColors.primary,
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
              padding: EdgeInsets.only(top: 8),
              child: Text(
                _buildBotResumeLabel(conversation),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.neutral500),
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
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadii.borderRadiusPill,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.neutral500,
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
        const Expanded(child: Divider(color: AppColors.borderLight)),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 10),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.scaffoldBackground.withValues(alpha: 0.85),
            borderRadius: AppRadii.borderRadiusPill,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.neutral500,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.borderLight)),
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
          margin: EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            gradient: message.isMine
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppColors.bubbleOutgoing,
                      AppColors.bubbleOutgoingGradientEnd,
                    ],
                  )
                : null,
            color: message.isMine ? null : AppColors.bubbleIncoming,
            borderRadius: AppRadii.borderRadiusXl,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.neutral800.withValues(alpha: 0.05),
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
                  color: message.isMine
                      ? AppColors.primary
                      : AppColors.neutral500,
                ),
              ),
              const SizedBox(height: 5),
              if (message.hasImage) ...<Widget>[
                _ConversationImagePreview(
                  imageUrl: message.imageUrl!,
                  downloadUrl: message.preferredImageDownloadUrl,
                  maxWidth: maxWidth - 28,
                ),
                if (message.displayText.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.hasAudio) ...<Widget>[
                _ConversationAudioBubble(message: message, compact: false),
                if (message.displayText.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.hasVideo) ...<Widget>[
                _ConversationVideoCard(message: message),
                if (message.displayText.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.hasDocument) ...<Widget>[
                _ConversationDocumentCard(message: message, compact: false),
                if (message.displayText.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.hasLocation) ...<Widget>[
                _ConversationLocationCard(
                  message: message,
                  maxWidth: maxWidth - 28,
                ),
                if (message.displayText.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.hasInteractive) ...<Widget>[
                _ConversationInteractiveCard(message: message),
                if (message.displayText.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.displayText.isNotEmpty)
                Text(
                  message.displayText,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.neutral800,
                  ),
                ),
              if (message.displayText.isEmpty &&
                  !message.hasImage &&
                  !message.hasAudio &&
                  !message.hasVideo &&
                  !message.hasDocument &&
                  !message.hasLocation &&
                  !message.hasInteractive)
                const Text(
                  '-',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.neutral800,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    formatOmnichannelThreadTime(message.sentAt),
                    style: TextStyle(fontSize: 11, color: AppColors.neutral300),
                  ),
                  if (message.isMine) ...<Widget>[
                    const SizedBox(width: 6),
                    _DeliveryStatusIcon(message: message),
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

/// WhatsApp-style delivery status icon — renders:
///  - clock icon (grey)         → pending / sending
///  - single check (grey)       → sent (accepted by WA server)
///  - double check (grey)       → delivered to customer device
///  - double check (blue)       → read by customer
///  - warning icon (red)        → failed
///  Only rendered for outbound messages (`isMine == true`).
class _DeliveryStatusIcon extends StatelessWidget {
  const _DeliveryStatusIcon({required this.message});

  final OmnichannelThreadMessageModel message;

  @override
  Widget build(BuildContext context) {
    if (message.isFailed) {
      return Icon(
        Icons.error_outline_rounded,
        size: 14,
        color: AppColors.error,
      );
    }

    if (message.isSending) {
      return Icon(
        Icons.access_time_rounded,
        size: 13,
        color: AppColors.neutral300,
      );
    }

    if (message.isRead) {
      return Icon(
        Icons.done_all_rounded,
        size: 15,
        color: const Color(0xFF34B7F1), // WhatsApp blue tick
      );
    }

    if (message.isDelivered) {
      return Icon(
        Icons.done_all_rounded,
        size: 15,
        color: AppColors.neutral400,
      );
    }

    if (message.isSent) {
      return Icon(Icons.done_rounded, size: 15, color: AppColors.neutral400);
    }

    // Fallback — brand new message not yet reported by transport.
    return Icon(
      Icons.access_time_rounded,
      size: 13,
      color: AppColors.neutral300,
    );
  }
}

/// Renders an inline map preview for `location` messages. Uses OpenStreetMap
/// static-tile style: a centered pin drawn over a map tile fetched from
/// `staticmap.openstreetmap.de`. Free, no API key.
class _ConversationLocationCard extends StatelessWidget {
  const _ConversationLocationCard({
    required this.message,
    required this.maxWidth,
  });

  final OmnichannelThreadMessageModel message;
  final double maxWidth;

  Future<void> _openInExternalMaps() async {
    final lat = message.latitude;
    final lng = message.longitude;
    if (lat == null || lng == null) return;

    final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    final fallback = Uri.parse(
      'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng',
    );
    if (await canLaunchUrl(fallback)) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = message.latitude;
    final lng = message.longitude;
    if (lat == null || lng == null) {
      return const SizedBox.shrink();
    }

    final previewWidth = maxWidth.clamp(180.0, 260.0).toDouble();
    final previewHeight = previewWidth * 0.6;
    final name = message.locationName?.trim() ?? '';
    final address = message.locationAddress?.trim() ?? '';

    return InkWell(
      onTap: _openInExternalMaps,
      borderRadius: AppRadii.borderRadiusLg,
      child: Container(
        width: previewWidth,
        decoration: BoxDecoration(
          color: AppColors.surfaceTertiary,
          borderRadius: AppRadii.borderRadiusLg,
          border: Border.all(color: AppColors.borderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Image.network(
                  'https://staticmap.openstreetmap.de/staticmap.php'
                  '?center=$lat,$lng&zoom=16&size=${previewWidth.toInt()}x${previewHeight.toInt()}&maptype=mapnik&markers=$lat,$lng,red-pushpin',
                  width: previewWidth,
                  height: previewHeight,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    width: previewWidth,
                    height: previewHeight,
                    color: AppColors.surfaceSecondary,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 40,
                      color: AppColors.neutral400,
                    ),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: previewWidth,
                      height: previewHeight,
                      color: AppColors.surfaceSecondary,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
                // Fallback pin drawn on top in case the tile's marker parameter
                // gets dropped — guarantees the user always sees a pin.
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFEA4335),
                    size: 32,
                  ),
                ),
              ],
            ),
            if (name.isNotEmpty || address.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (name.isNotEmpty)
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral800,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (address.isNotEmpty) ...<Widget>[
                      if (name.isNotEmpty) const SizedBox(height: 4),
                      Text(
                        address,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.neutral500,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Renders a WhatsApp-style interactive card (button list or list picker).
/// Shows header / body / footer + a list of options as read-only items.
/// Also appends the selected option if the customer has already replied.
class _ConversationInteractiveCard extends StatelessWidget {
  const _ConversationInteractiveCard({required this.message});

  final OmnichannelThreadMessageModel message;

  @override
  Widget build(BuildContext context) {
    final header = message.interactiveHeader?.trim() ?? '';
    final body = message.interactiveBody?.trim() ?? message.text.trim();
    final footer = message.interactiveFooter?.trim() ?? '';
    final buttons = message.interactiveButtonOptions;
    final listItems = message.interactiveListOptions;
    final listButtonLabel =
        message.interactiveListButtonTitle?.trim().isNotEmpty == true
        ? message.interactiveListButtonTitle!.trim()
        : 'Pilih Layanan';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: AppColors.borderLight),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (header.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                header,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral800,
                ),
              ),
            ),
          if (body.isNotEmpty)
            Text(
              body,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.neutral800,
              ),
            ),
          if (footer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                footer,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.neutral500,
                ),
              ),
            ),
          if (buttons.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 6),
            for (final label in buttons)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.reply_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (listItems.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Icon(Icons.list_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  listButtonLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final label in listItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• $label',
                  style: TextStyle(fontSize: 12, color: AppColors.neutral500),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ConversationImagePreview extends StatelessWidget {
  const _ConversationImagePreview({
    required this.imageUrl,
    required this.maxWidth,
    this.downloadUrl,
  });

  final String imageUrl;
  final double maxWidth;
  final String? downloadUrl;

  @override
  Widget build(BuildContext context) {
    final previewWidth = maxWidth.clamp(160.0, 240.0).toDouble();

    return SizedBox(
      width: previewWidth,
      height: previewWidth,
      child: Stack(
        children: <Widget>[
          ClipRRect(
            borderRadius: AppRadii.borderRadiusLg,
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
                    decoration: BoxDecoration(color: AppColors.borderDefault),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) {
                  return const DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.borderDefault),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.neutral300,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Gambar tidak tersedia',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.neutral500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: AppColors.neutral800.withValues(alpha: 0.45),
              borderRadius: AppRadii.borderRadiusPill,
              child: InkWell(
                onTap: () => _downloadMediaUrl(downloadUrl ?? imageUrl),
                borderRadius: AppRadii.borderRadiusPill,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.download_rounded,
                    size: 18,
                    color: AppColors.surfacePrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _downloadMediaUrl(String? rawUrl) async {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty) return;

  final uri = Uri.tryParse(value);
  if (uri == null) return;

  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _openMediaUrl(String? rawUrl) async {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty) return;

  final uri = Uri.tryParse(value);
  if (uri == null) return;

  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _ConversationAudioBubble extends StatefulWidget {
  const _ConversationAudioBubble({required this.message, this.compact = false});

  final OmnichannelThreadMessageModel message;
  final bool compact;

  @override
  State<_ConversationAudioBubble> createState() =>
      _ConversationAudioBubbleState();
}

class _ConversationAudioBubbleState extends State<_ConversationAudioBubble> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  String? get _audioUrl => widget.message.audioUrl;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() {
        _position = position;
      });
    });

    _player.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() {
        _duration = duration;
      });
    });

    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final url = _audioUrl;
    if (url == null || url.trim().isEmpty) {
      return;
    }

    if (_isPlaying) {
      await _player.pause();
      return;
    }

    if (_position > Duration.zero) {
      await _player.resume();
      return;
    }

    await _player.play(UrlSource(url));
  }

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final progressMax = _duration.inMilliseconds <= 0
        ? 1.0
        : _duration.inMilliseconds.toDouble();
    final progressValue = _position.inMilliseconds
        .clamp(0, progressMax.toInt())
        .toDouble();

    return Container(
      width: compact ? 220 : 280,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          InkWell(
            onTap: _togglePlay,
            borderRadius: AppRadii.borderRadiusPill,
            child: Container(
              width: compact ? 36 : 42,
              height: compact ? 36 : 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.primary,
                size: compact ? 22 : 26,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: progressMax,
                    value: progressValue,
                    onChanged: (_duration.inMilliseconds <= 0)
                        ? null
                        : (value) async {
                            final target = Duration(
                              milliseconds: value.round(),
                            );
                            await _player.seek(target);
                          },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.neutral500,
                      ),
                    ),
                    if ((widget.message.originalName?.trim().isNotEmpty ??
                            false) &&
                        !compact)
                      Flexible(
                        child: Text(
                          widget.message.originalName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.neutral500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () =>
                _downloadMediaUrl(widget.message.preferredAudioDownloadUrl),
            borderRadius: AppRadii.borderRadiusPill,
            child: Container(
              width: compact ? 32 : 36,
              height: compact ? 32 : 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationVideoCard extends StatefulWidget {
  const _ConversationVideoCard({required this.message, this.compact = false});

  final OmnichannelThreadMessageModel message;
  final bool compact;

  @override
  State<_ConversationVideoCard> createState() => _ConversationVideoCardState();

  Widget buildLegacy(BuildContext context) {
    final width = compact ? 220.0 : 280.0;

    return Container(
      width: width,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: compact ? 120 : 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.borderDefault,
              borderRadius: AppRadii.borderRadiusMd,
            ),
            child: Stack(
              children: <Widget>[
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 54,
                    color: AppColors.primary,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: AppColors.neutral800.withValues(alpha: 0.45),
                    borderRadius: AppRadii.borderRadiusPill,
                    child: InkWell(
                      onTap: () =>
                          _downloadMediaUrl(message.preferredVideoDownloadUrl),
                      borderRadius: AppRadii.borderRadiusPill,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.download_rounded,
                          size: 18,
                          color: AppColors.surfacePrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message.originalName?.trim().isNotEmpty == true
                ? message.originalName!
                : 'Video',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.neutral800,
            ),
          ),
          if ((message.mimeType?.trim().isNotEmpty ?? false) ||
              message.sizeBytes != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              [
                if (message.mimeType?.trim().isNotEmpty ?? false)
                  message.mimeType!,
                if (message.sizeBytes != null)
                  _formatFileSize(message.sizeBytes!),
              ].join(' â€¢ '),
              style: TextStyle(fontSize: 12, color: AppColors.neutral500),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildPlaceholder(BuildContext context) {
    final width = compact ? 220.0 : 280.0;

    return Container(
      width: width,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: compact ? 120 : 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.borderDefault,
              borderRadius: AppRadii.borderRadiusMd,
            ),
            child: Stack(
              children: <Widget>[
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 54,
                    color: AppColors.primary,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: AppColors.neutral800.withValues(alpha: 0.45),
                    borderRadius: AppRadii.borderRadiusPill,
                    child: InkWell(
                      onTap: () =>
                          _downloadMediaUrl(message.preferredVideoDownloadUrl),
                      borderRadius: AppRadii.borderRadiusPill,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.download_rounded,
                          size: 18,
                          color: AppColors.surfacePrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message.originalName?.trim().isNotEmpty == true
                ? message.originalName!
                : 'Video',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.neutral800,
            ),
          ),
          if ((message.mimeType?.trim().isNotEmpty ?? false) ||
              message.sizeBytes != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              [
                if (message.mimeType?.trim().isNotEmpty ?? false)
                  message.mimeType!,
                if (message.sizeBytes != null)
                  _formatFileSize(message.sizeBytes!),
              ].join(' • '),
              style: TextStyle(fontSize: 12, color: AppColors.neutral500),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConversationVideoCardState extends State<_ConversationVideoCard> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  bool _isInitFailed = false;

  String? get _videoUrl {
    final value = widget.message.videoUrl?.trim() ?? '';
    if (value.isEmpty) return null;
    return value;
  }

  @override
  void initState() {
    super.initState();
    _setupVideo();
  }

  @override
  void didUpdateWidget(covariant _ConversationVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.message.videoUrl != widget.message.videoUrl) {
      _disposeController();
      _setupVideo();
    }
  }

  void _setupVideo() {
    final url = _videoUrl;
    if (url == null) {
      _isInitFailed = true;
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      _initializeFuture = controller
          .initialize()
          .then((_) async {
            if (!mounted || _controller != controller) return;
            await controller.setLooping(false);
            if (!mounted || _controller != controller) return;
            setState(() {});
          })
          .catchError((_) {
            if (!mounted || _controller != controller) return;
            setState(() {
              _isInitFailed = true;
            });
          });
    } catch (_) {
      _isInitFailed = true;
    }
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.position >= controller.value.duration &&
          controller.value.duration > Duration.zero) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    _initializeFuture = null;
    _isInitFailed = false;
    controller?.dispose();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.compact ? 220.0 : 280.0;
    final height = widget.compact ? 140.0 : 180.0;
    final controller = _controller;

    return Container(
      width: width,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: AppRadii.borderRadiusMd,
            child: Container(
              width: double.infinity,
              height: height,
              color: AppColors.borderDefault,
              child: _buildVideoSurface(controller),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.message.originalName?.trim().isNotEmpty == true
                ? widget.message.originalName!
                : 'Video',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.neutral800,
            ),
          ),
          if ((widget.message.mimeType?.trim().isNotEmpty ?? false) ||
              widget.message.sizeBytes != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              [
                if (widget.message.mimeType?.trim().isNotEmpty ?? false)
                  widget.message.mimeType!,
                if (widget.message.sizeBytes != null)
                  _formatFileSize(widget.message.sizeBytes!),
              ].join(' • '),
              style: TextStyle(fontSize: 12, color: AppColors.neutral500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoSurface(VideoPlayerController? controller) {
    if (_isInitFailed || _videoUrl == null) {
      return _buildFallbackSurface();
    }

    if (controller == null || _initializeFuture == null) {
      return _buildLoadingSurface();
    }

    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildFallbackSurface();
        }

        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return _buildLoadingSurface();
        }

        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final videoSize = value.size;
            final player = videoSize.width > 0 && videoSize.height > 0
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: videoSize.width,
                      height: videoSize.height,
                      child: VideoPlayer(controller),
                    ),
                  )
                : const SizedBox.shrink();

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                player,
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _togglePlayPause,
                      child: Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: value.isPlaying ? 0.0 : 1.0,
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: AppColors.neutral800.withValues(
                                alpha: 0.45,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              size: 34,
                              color: AppColors.surfacePrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Material(
                    color: AppColors.neutral800.withValues(alpha: 0.45),
                    borderRadius: AppRadii.borderRadiusPill,
                    child: InkWell(
                      onTap: () => _downloadMediaUrl(
                        widget.message.preferredVideoDownloadUrl,
                      ),
                      borderRadius: AppRadii.borderRadiusPill,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.download_rounded,
                          size: 18,
                          color: AppColors.surfacePrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: _VideoProgressBar(controller: controller),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingSurface() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Material(
            color: AppColors.neutral800.withValues(alpha: 0.45),
            borderRadius: AppRadii.borderRadiusPill,
            child: InkWell(
              onTap: () =>
                  _downloadMediaUrl(widget.message.preferredVideoDownloadUrl),
              borderRadius: AppRadii.borderRadiusPill,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.download_rounded,
                  size: 18,
                  color: AppColors.surfacePrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackSurface() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const Center(
          child: Icon(
            Icons.videocam_rounded,
            size: 52,
            color: AppColors.primary,
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Material(
            color: AppColors.neutral800.withValues(alpha: 0.45),
            borderRadius: AppRadii.borderRadiusPill,
            child: InkWell(
              onTap: () =>
                  _downloadMediaUrl(widget.message.preferredVideoDownloadUrl),
              borderRadius: AppRadii.borderRadiusPill,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.download_rounded,
                  size: 18,
                  color: AppColors.surfacePrimary,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 10,
          child: Center(
            child: InkWell(
              onTap: () => _openMediaUrl(
                widget.message.videoUrl ??
                    widget.message.preferredVideoDownloadUrl,
              ),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.neutral800.withValues(alpha: 0.45),
                  borderRadius: AppRadii.borderRadiusPill,
                ),
                child: const Text(
                  'Buka video',
                  style: TextStyle(
                    color: AppColors.surfacePrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoProgressBar extends StatelessWidget {
  const _VideoProgressBar({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final totalMs = value.duration.inMilliseconds;
        final positionMs = value.position.inMilliseconds
            .clamp(0, totalMs > 0 ? totalMs : 0)
            .toDouble();
        final progress = totalMs <= 0 ? 0.0 : positionMs / totalMs;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: AppRadii.borderRadiusPill,
              child: LinearProgressIndicator(
                value: progress.isNaN ? 0.0 : progress,
                minHeight: 4,
                backgroundColor: AppColors.surfacePrimary.withValues(
                  alpha: 0.35,
                ),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  _formatDuration(value.position),
                  style: TextStyle(
                    color: AppColors.surfacePrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatDuration(value.duration),
                  style: TextStyle(
                    color: AppColors.surfacePrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ConversationDocumentCard extends StatelessWidget {
  const _ConversationDocumentCard({
    required this.message,
    this.compact = false,
  });

  final OmnichannelThreadMessageModel message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 220.0 : 280.0;

    return Container(
      width: width,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.borderDefault,
              borderRadius: AppRadii.borderRadiusMd,
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message.originalName?.trim().isNotEmpty == true
                  ? message.originalName!
                  : 'Dokumen',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.neutral800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () =>
                _downloadMediaUrl(message.preferredDocumentDownloadUrl),
            borderRadius: AppRadii.borderRadiusPill,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  final twoDigitsSeconds = seconds.toString().padLeft(2, '0');
  final twoDigitsMinutes = minutes.toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:$twoDigitsMinutes:$twoDigitsSeconds';
  }

  return '$minutes:$twoDigitsSeconds';
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
    required this.isRecordingVoiceNote,
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
  final bool isRecordingVoiceNote;
  final VoidCallback onCallTap;

  @override
  Widget build(BuildContext context) {
    final isWhatsApp = channel == 'whatsapp';

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground.withValues(alpha: 0.8),
        borderRadius: AppRadii.borderRadiusXl,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: <Widget>[
          _ComposerActionButton(
            icon: Icons.person_add_alt_1_rounded,
            label: 'Kontak',
            busy: isSendingContact,
            activeColor: AppColors.primary,
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
            tooltip: isRecordingVoiceNote ? 'Kirim Voice Note' : 'Voice Note',
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
                hintStyle: TextStyle(fontSize: 13, color: AppColors.neutral300),
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: isSending ? AppColors.neutral300 : AppColors.primary,
            borderRadius: AppRadii.borderRadiusPill,
            child: InkWell(
              onTap: isSending ? null : onSubmit,
              borderRadius: AppRadii.borderRadiusPill,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.surfacePrimary,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: AppColors.surfacePrimary,
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
      color: AppColors.surfaceSecondary,
      borderRadius: AppRadii.borderRadiusPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.borderRadiusPill,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadii.borderRadiusPill,
            border: Border.all(color: AppColors.borderLight),
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
                    color: AppColors.primary,
                  ),
                )
              else
                Icon(icon, size: 18, color: activeColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral800,
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
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadii.borderRadiusPill,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.borderRadiusPill,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: AppRadii.borderRadiusPill,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Icon(
              icon,
              color: onTap == null
                  ? AppColors.neutral300
                  : AppColors.neutral500,
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
      insetPadding: EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.borderRadiusXxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: EdgeInsets.all(24),
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
                      color: AppColors.neutral800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kontak ini akan dikirim ke customer melalui WhatsApp.',
                    style: TextStyle(fontSize: 13, color: AppColors.neutral500),
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
                                  color: AppColors.surfacePrimary,
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.neutral500,
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
            fillColor: AppColors.scaffoldBackground,
            border: OutlineInputBorder(
              borderRadius: AppRadii.borderRadiusLg,
              borderSide: BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadii.borderRadiusLg,
              borderSide: BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadii.borderRadiusLg,
              borderSide: BorderSide(color: AppColors.primary),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _PollDraftResult {
  const _PollDraftResult({required this.question, required this.options});

  final String question;
  final List<String> options;
}

class _SendPollDialog extends StatefulWidget {
  const _SendPollDialog();

  @override
  State<_SendPollDialog> createState() => _SendPollDialogState();
}

class _SendPollDialogState extends State<_SendPollDialog> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers =
      <TextEditingController>[TextEditingController(), TextEditingController()];

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 10) {
      return;
    }
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) {
      return;
    }
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);

    if (options.length < 2) {
      return;
    }

    Navigator.of(
      context,
    ).pop(_PollDraftResult(question: question, options: options));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadii.borderRadiusXxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.poll_rounded,
                        color: const Color(0xFFF2B300),
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Buat Polling',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _DialogField(
                    controller: _questionController,
                    label: 'Pertanyaan',
                    hintText: 'Contoh: Kapan jadwal paling cocok?',
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Pertanyaan polling wajib diisi.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pilihan Jawaban',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutral500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _optionControllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              controller: _optionControllers[i],
                              validator: (value) {
                                if (i < 2) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) {
                                    return 'Pilihan ${i + 1} wajib diisi.';
                                  }
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: 'Opsi ${i + 1}',
                                filled: true,
                                fillColor: AppColors.scaffoldBackground,
                                border: OutlineInputBorder(
                                  borderRadius: AppRadii.borderRadiusLg,
                                  borderSide: BorderSide(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: AppRadii.borderRadiusLg,
                                  borderSide: BorderSide(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: AppRadii.borderRadiusLg,
                                  borderSide: BorderSide(
                                    color: AppColors.primary,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          if (_optionControllers.length > 2)
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                              ),
                              color: AppColors.neutral500,
                              onPressed: () => _removeOption(i),
                            ),
                        ],
                      ),
                    ),
                  if (_optionControllers.length < 10)
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Tambah Opsi'),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _handleSubmit,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Kirim Polling'),
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

class _EventDraftResult {
  const _EventDraftResult({
    required this.title,
    required this.location,
    required this.date,
    required this.description,
  });

  final String title;
  final String location;
  final DateTime date;
  final String description;

  String formattedDate() {
    const months = <String>[
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute WIB';
  }
}

class _SendEventDialog extends StatefulWidget {
  const _SendEventDialog();

  @override
  State<_SendEventDialog> createState() => _SendEventDialogState();
}

class _SendEventDialogState extends State<_SendEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDateTime;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _selectedDateTime ?? now.add(const Duration(hours: 1)),
      ),
    );

    if (time == null) {
      return;
    }

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Tanggal & waktu acara wajib dipilih.')),
        );
      return;
    }

    Navigator.of(context).pop(
      _EventDraftResult(
        title: _titleController.text.trim(),
        location: _locationController.text.trim(),
        date: _selectedDateTime!,
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _selectedDateTime == null
        ? 'Pilih tanggal & waktu'
        : _EventDraftResult(
            title: '',
            location: '',
            date: _selectedDateTime!,
            description: '',
          ).formattedDate();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadii.borderRadiusXxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.event_rounded,
                        color: const Color(0xFFFF3B8D),
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Buat Acara',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _DialogField(
                    controller: _titleController,
                    label: 'Judul Acara',
                    hintText: 'Contoh: Rapat Koordinasi Tim',
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Judul acara wajib diisi.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _DialogField(
                    controller: _locationController,
                    label: 'Lokasi',
                    hintText: 'Opsional, contoh: Kantor NCP Lt. 3',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tanggal & Waktu',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutral500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDateTime,
                    borderRadius: AppRadii.borderRadiusLg,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldBackground,
                        borderRadius: AppRadii.borderRadiusLg,
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: AppColors.neutral500,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              dateLabel,
                              style: TextStyle(
                                fontSize: 14,
                                color: _selectedDateTime == null
                                    ? AppColors.neutral300
                                    : AppColors.neutral800,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            color: AppColors.neutral500,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DialogField(
                    controller: _descriptionController,
                    label: 'Deskripsi',
                    hintText: 'Opsional',
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _handleSubmit,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Kirim Acara'),
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
