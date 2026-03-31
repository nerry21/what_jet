import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../live_chat/presentation/widgets/channel_badge.dart';
import '../../data/models/omnichannel_conversation_detail_model.dart';
import '../../data/models/omnichannel_thread_model.dart';
import 'omnichannel_surface.dart';

class OmnichannelCenterPane extends StatelessWidget {
  const OmnichannelCenterPane({
    super.key,
    required this.conversation,
    required this.threadGroups,
    required this.isShellLoading,
    required this.isConversationLoading,
  });

  final OmnichannelConversationDetailModel? conversation;
  final List<OmnichannelThreadGroupModel> threadGroups;
  final bool isShellLoading;
  final bool isConversationLoading;

  @override
  Widget build(BuildContext context) {
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
              conversation: conversation!,
              isConversationLoading: isConversationLoading,
            ),
            const SizedBox(height: 18),
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
                        final bubbleMaxWidth = constraints.maxWidth * 0.72;

                        return ListView.builder(
                          padding: EdgeInsets.zero,
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
            const SizedBox(height: 16),
            const _ComposerPlaceholder(),
          ],
        ],
      ),
    );
  }
}

class _CenterHeader extends StatelessWidget {
  const _CenterHeader({
    required this.conversation,
    required this.isConversationLoading,
  });

  final OmnichannelConversationDetailModel conversation;
  final bool isConversationLoading;

  @override
  Widget build(BuildContext context) {
    final initial = _safeInitial(conversation.customerName, fallback: 'C');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConfig.softBackground.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppConfig.softBackgroundAlt),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
                        _safeText(conversation.title, fallback: 'Conversation'),
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
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppConfig.mutedText,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _HeaderBadge(label: conversation.statusLabel),
                    _HeaderBadge(label: conversation.operationalModeLabel),
                    ...conversation.badges.map(
                      (badge) => _HeaderBadge(label: badge),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isConversationLoading)
            const Padding(
              padding: EdgeInsets.only(left: 12, top: 4),
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
              Text(
                message.text,
                style: const TextStyle(
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

class _ComposerPlaceholder extends StatelessWidget {
  const _ComposerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConfig.softBackground.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppConfig.softBackgroundAlt),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.add_circle_outline, color: AppConfig.subtleText),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppConfig.softBackgroundAlt),
              ),
              child: const Text(
                'Composer admin akan diaktifkan pada tahap action berikutnya.',
                style: TextStyle(fontSize: 13, color: AppConfig.mutedText),
              ),
            ),
          ),
          const SizedBox(width: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppConfig.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(11),
              child: Icon(Icons.send_rounded, color: AppConfig.green, size: 18),
            ),
          ),
        ],
      ),
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
                    OmnichannelSkeletonBlock(width: 260, height: 12),
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
        const Row(
          children: <Widget>[
            Expanded(child: Divider(color: AppConfig.softBackgroundAlt)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: OmnichannelSkeletonBlock(
                width: 96,
                height: 28,
                radius: 999,
              ),
            ),
            Expanded(child: Divider(color: AppConfig.softBackgroundAlt)),
          ],
        ),
        const SizedBox(height: 14),
        const Align(
          alignment: Alignment.centerLeft,
          child: OmnichannelSkeletonBlock(width: 340, height: 92, radius: 20),
        ),
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerRight,
          child: OmnichannelSkeletonBlock(width: 300, height: 84, radius: 20),
        ),
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerLeft,
          child: OmnichannelSkeletonBlock(width: 280, height: 72, radius: 20),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppConfig.softBackground.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppConfig.softBackgroundAlt),
          ),
          child: const Row(
            children: <Widget>[
              OmnichannelSkeletonBlock(width: 24, height: 24, radius: 12),
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
