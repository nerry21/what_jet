import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../live_chat/presentation/widgets/channel_badge.dart';
import '../../data/models/omnichannel_conversation_detail_model.dart';
import '../../data/models/omnichannel_thread_model.dart';
import 'omnichannel_surface.dart';

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
    required this.onSendContact,
    required this.isTogglingBot,
    required this.onToggleBot,
  });

  final OmnichannelConversationDetailModel? conversation;
  final List<OmnichannelThreadGroupModel> threadGroups;
  final bool isShellLoading;
  final bool isConversationLoading;
  final bool isSendingReply;
  final bool isSendingContact;
  final Future<bool> Function(String message) onSendReply;
  final Future<bool> Function({
    required String fullName,
    required String phone,
    String? email,
    String? company,
  })
  onSendContact;
  final bool isTogglingBot;
  final Future<void> Function(bool turnOn) onToggleBot;

  @override
  State<OmnichannelCenterPane> createState() => _OmnichannelCenterPaneState();
}

class _OmnichannelCenterPaneState extends State<OmnichannelCenterPane> {
  final TextEditingController _composerController = TextEditingController();

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final text = _composerController.text.trim();
    if (text.isEmpty || widget.isSendingReply || widget.conversation == null) {
      return;
    }

    final success = await widget.onSendReply(text);
    if (success && mounted) {
      _composerController.clear();
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

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final threadGroups = widget.threadGroups;
    final isShellLoading = widget.isShellLoading;
    final isConversationLoading = widget.isConversationLoading;

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
            _ActiveComposer(
              controller: _composerController,
              channel: conversation.channel,
              isSending: widget.isSendingReply,
              isSendingContact: widget.isSendingContact,
              onSubmit: _submitReply,
              onSendContact: _openSendContactDialog,
              onVoiceNoteTap: () => _showComingSoon('Voice note'),
              onCallTap: () => _showComingSoon('Panggilan telepon'),
            ),
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
    required this.isTogglingBot,
    required this.onToggleBot,
  });

  final OmnichannelConversationDetailModel conversation;
  final bool isConversationLoading;
  final bool isTogglingBot;
  final Future<void> Function(bool turnOn) onToggleBot;

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
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _HeaderBadge(
                        label: conversation.isBotEnabled ? 'Bot: ON' : 'Bot: OFF',
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: isTogglingBot ? null : () => onToggleBot(!conversation.isBotEnabled),
                      icon: isTogglingBot
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              conversation.isBotEnabled ? Icons.toggle_off_rounded : Icons.smart_toy_rounded,
                              size: 18,
                            ),
                      label: Text(conversation.isBotEnabled ? 'Matikan Bot' : 'Aktifkan Bot'),
                    ),
                  ],
                ),
                if (conversation.botAutoResumeEnabled && conversation.botAutoResumeAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Auto aktif lagi: ${conversation.botAutoResumeAt}',
                      style: const TextStyle(fontSize: 12, color: AppConfig.mutedText),
                    ),
                  ),
                const SizedBox(height: 12),
                if (badges.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: badges
                        .map((badge) => _HeaderBadge(label: badge))
                        .toList(),
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

class _ActiveComposer extends StatelessWidget {
  const _ActiveComposer({
    required this.controller,
    required this.channel,
    required this.isSending,
    required this.isSendingContact,
    required this.onSubmit,
    required this.onSendContact,
    required this.onVoiceNoteTap,
    required this.onCallTap,
  });

  final TextEditingController controller;
  final String channel;
  final bool isSending;
  final bool isSendingContact;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onSendContact;
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
              enabled: !isSending,
              minLines: 1,
              maxLines: 4,
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
  final VoidCallback onTap;

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
            child: Icon(icon, color: AppConfig.mutedText, size: 18),
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
