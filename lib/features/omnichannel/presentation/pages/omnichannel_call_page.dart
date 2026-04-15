import 'dart:async';

import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import '../../data/models/omnichannel_call_session_model.dart';
import '../../data/services/omnichannel_call_media_service.dart';
import '../controllers/omnichannel_call_controller.dart';
import '../utils/omnichannel_call_status_ui.dart';
import '../widgets/omnichannel_call_status_chip.dart';
import '../widgets/omnichannel_call_timeline_section.dart';

class OmnichannelCallPage extends StatefulWidget {
  const OmnichannelCallPage({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.customerName,
    required this.customerContact,
    this.initialSession,
  });

  final OmnichannelCallController controller;
  final String conversationId;
  final String customerName;
  final String customerContact;
  final OmnichannelCallSessionModel? initialSession;

  @override
  State<OmnichannelCallPage> createState() => _OmnichannelCallPageState();
}

class _OmnichannelCallPageState extends State<OmnichannelCallPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.bindInitialSession(widget.initialSession);
    unawaited(widget.controller.initializeMediaLayer());
    widget.controller.startPolling(conversationId: widget.conversationId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        widget.controller.refreshStatus(
          conversationId: widget.conversationId,
          silent: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Panggilan WhatsApp'),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final call = widget.controller.currentCall ?? widget.initialSession;
            final color = omnichannelCallStatusColor(call);
            final status = omnichannelCallPrimaryStatusText(call);
            final statusDetail = omnichannelCallSecondaryStatusText(call);
            final mediaSnapshot = widget.controller.mediaSnapshot;
            final initials = _buildInitials(widget.customerName);
            final isFinished = call?.isFinished ?? false;
            final canAcceptReject =
                call != null &&
                call.direction == 'inbound' &&
                !call.isFinished &&
                !call.isConnected;
            final supportsRealtimeVoice =
                widget.controller.callCapabilities.supportsWhatsAppVoiceMedia;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    color.withValues(alpha: 0.24),
                    const Color(0xFF0D1B18),
                    const Color(0xFF09110F),
                  ],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                color.withValues(alpha: 0.94),
                                AppColors.primary200,
                              ],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: color.withValues(alpha: 0.28),
                                blurRadius: 28,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.customerName.trim().isEmpty
                              ? 'Customer'
                              : widget.customerName.trim(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.customerContact.trim().isEmpty
                              ? 'Kontak belum tersedia'
                              : widget.customerContact.trim(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFC2D4CE),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Panggilan Suara WhatsApp',
                          style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 0.4,
                            color: Color(0xFF8AA19A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        OmnichannelCallStatusChip(session: call),
                        const SizedBox(height: 16),
                        Text(
                          status,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          statusDetail,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: Color(0xFFB8C7C2),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _FallbackNoticeCard(
                          headline: omnichannelCallFallbackHeadline(),
                          description: widget.controller.fallbackMessage,
                        ),
                        const SizedBox(height: 16),
                        _MediaStatusCard(
                          mediaSnapshot: mediaSnapshot,
                          isPolling: widget.controller.isPolling,
                        ),
                        if (widget.controller.lastMessage?.trim().isNotEmpty ??
                            false) ...<Widget>[
                          const SizedBox(height: 16),
                          _InlineNoticeCard(
                            message: widget.controller.lastMessage!,
                          ),
                        ],
                        const SizedBox(height: 20),
                        _CallInfoCard(
                          call: call,
                          isPolling: widget.controller.isPolling,
                        ),
                        const SizedBox(height: 20),
                        OmnichannelCallTimelineSection(
                          items: widget.controller.timeline,
                          session: call,
                          dark: true,
                          title: 'Progress panggilan',
                          subtitle:
                              'Event di bawah ini disinkronkan dari backend dan tetap bisa dipakai walau audio live belum tersedia di build admin ini.',
                          emptyMessage:
                              'Timeline panggilan belum tersedia. Gunakan refresh status untuk meminta pembaruan terbaru dari server.',
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            if (supportsRealtimeVoice)
                              OutlinedButton.icon(
                                onPressed: widget.controller.isLoading
                                    ? null
                                    : () => unawaited(
                                        widget.controller.setMuted(
                                          !widget.controller.isMuted,
                                        ),
                                      ),
                                icon: Icon(
                                  widget.controller.isMuted
                                      ? Icons.mic_off_rounded
                                      : Icons.mic_none_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  widget.controller.isMuted ? 'Unmute' : 'Mute',
                                ),
                                style: _outlinedActionButtonStyle(),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(
                                  Icons.mic_off_rounded,
                                  size: 18,
                                ),
                                label: const Text('Mute belum tersedia'),
                              ),
                            if (supportsRealtimeVoice)
                              OutlinedButton.icon(
                                onPressed: widget.controller.isLoading
                                    ? null
                                    : () => unawaited(
                                        widget.controller.setSpeakerEnabled(
                                          !widget.controller.isSpeakerEnabled,
                                        ),
                                      ),
                                icon: Icon(
                                  widget.controller.isSpeakerEnabled
                                      ? Icons.volume_up_rounded
                                      : Icons.hearing_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  widget.controller.isSpeakerEnabled
                                      ? 'Speaker On'
                                      : 'Speaker Off',
                                ),
                                style: _outlinedActionButtonStyle(),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(
                                  Icons.hearing_disabled_rounded,
                                  size: 18,
                                ),
                                label: const Text('Speaker belum tersedia'),
                              ),
                            OutlinedButton.icon(
                              onPressed: widget.controller.isLoading
                                  ? null
                                  : () => unawaited(
                                      widget.controller.refreshStatus(
                                        conversationId: widget.conversationId,
                                      ),
                                    ),
                              icon: widget.controller.isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Refresh Status'),
                              style: _outlinedActionButtonStyle(),
                            ),
                            if (canAcceptReject)
                              FilledButton.tonalIcon(
                                onPressed: widget.controller.isLoading
                                    ? null
                                    : () => unawaited(
                                        widget.controller.acceptCall(
                                          conversationId: widget.conversationId,
                                        ),
                                      ),
                                icon: const Icon(Icons.call_rounded, size: 18),
                                label: const Text('Terima'),
                              ),
                            if (canAcceptReject)
                              FilledButton.tonalIcon(
                                onPressed: widget.controller.isLoading
                                    ? null
                                    : () => unawaited(
                                        widget.controller.rejectCall(
                                          conversationId: widget.conversationId,
                                        ),
                                      ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(
                                  Icons.call_end_rounded,
                                  size: 18,
                                ),
                                label: const Text('Tolak'),
                              ),
                            if (!isFinished)
                              FilledButton.icon(
                                onPressed: widget.controller.isLoading
                                    ? null
                                    : () => unawaited(
                                        widget.controller.endCall(
                                          conversationId: widget.conversationId,
                                        ),
                                      ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.call_end_rounded,
                                  size: 18,
                                ),
                                label: const Text('Akhiri Panggilan'),
                              ),
                            FilledButton.tonalIcon(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                              ),
                              label: Text(
                                isFinished
                                    ? 'Kembali ke Chat'
                                    : 'Kembali ke Chat',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  ButtonStyle _outlinedActionButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    );
  }
}

class _FallbackNoticeCard extends StatelessWidget {
  const _FallbackNoticeCard({
    required this.headline,
    required this.description,
  });

  final String headline;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0C24A).withValues(alpha: 0.10),
        borderRadius: AppRadii.borderRadiusXl,
        border: Border.all(
          color: const Color(0xFFF0C24A).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFF0C24A),
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mode fallback operasional',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFFB8C7C2),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNoticeCard extends StatelessWidget {
  const _InlineNoticeCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: Colors.white),
      ),
    );
  }
}

class _CallInfoCard extends StatelessWidget {
  const _CallInfoCard({required this.call, required this.isPolling});

  final OmnichannelCallSessionModel? call;
  final bool isPolling;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: AppRadii.borderRadiusXl,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: <Widget>[
          _CallInfoRow(
            label: 'Permission',
            value: omnichannelCallPermissionLabel(call?.permissionStatus),
          ),
          const SizedBox(height: 12),
          _CallInfoRow(
            label: 'Status backend',
            value: humanizeStatusLabel(call?.status ?? '-'),
          ),
          const SizedBox(height: 12),
          _CallInfoRow(
            label: 'Outcome akhir',
            value: omnichannelCallOutcomeLabel(
              call?.finalStatus,
              fallback: call?.finalStatusLabel ?? '-',
            ),
          ),
          const SizedBox(height: 12),
          _CallInfoRow(label: 'WA Call ID', value: call?.waCallId ?? '-'),
          const SizedBox(height: 12),
          _CallInfoRow(
            label: 'Waktu mulai',
            value: omnichannelFormatCallTimestamp(call?.startedAt) ?? '-',
          ),
          const SizedBox(height: 12),
          _CallInfoRow(
            label: 'Connected',
            value:
                omnichannelFormatCallTimestamp(call?.connectedAt) ??
                omnichannelFormatCallTimestamp(call?.answeredAt) ??
                '-',
          ),
          const SizedBox(height: 12),
          _CallInfoRow(
            label: 'Berakhir',
            value: omnichannelFormatCallTimestamp(call?.endedAt) ?? '-',
          ),
          const SizedBox(height: 12),
          _CallInfoRow(
            label: 'Durasi',
            value: omnichannelCallDurationLabel(call),
          ),
          const SizedBox(height: 12),
          _CallInfoRow(
            label: 'Alasan akhir',
            value: omnichannelCallEndReasonLabel(call?.endReason),
          ),
          const SizedBox(height: 12),
          _CallInfoRow(
            label: 'Sinkronisasi',
            value: isPolling ? 'Polling aktif' : 'Menunggu refresh',
          ),
        ],
      ),
    );
  }
}

class _MediaStatusCard extends StatelessWidget {
  const _MediaStatusCard({
    required this.mediaSnapshot,
    required this.isPolling,
  });

  final OmnichannelCallMediaSnapshot mediaSnapshot;
  final bool isPolling;

  @override
  Widget build(BuildContext context) {
    final statusColor = mediaSnapshot.supportsRealtimeVoice
        ? AppColors.success
        : const Color(0xFFE0B24A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: AppRadii.borderRadiusXl,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: AppRadii.borderRadiusMd,
                ),
                alignment: Alignment.center,
                child: Icon(
                  mediaSnapshot.supportsRealtimeVoice
                      ? Icons.graphic_eq_rounded
                      : Icons.hearing_disabled_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Status media',
                      style: TextStyle(fontSize: 12, color: Color(0xFF8AA19A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mediaSnapshot.statusText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mediaSnapshot.detailText,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFFB8C7C2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isPolling
                ? 'Sinkronisasi server aktif.'
                : 'Sinkronisasi server menunggu refresh.',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8AA19A),
            ),
          ),
          if (mediaSnapshot.lastError?.trim().isNotEmpty ?? false) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x33FFB3B3),
                borderRadius: AppRadii.borderRadiusMd,
                border: Border.all(color: const Color(0x44FFB3B3)),
              ),
              child: Text(
                mediaSnapshot.lastError!,
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CallInfoRow extends StatelessWidget {
  const _CallInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8AA19A)),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

String _buildInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return 'C';
  }

  final parts = trimmed
      .split(' ')
      .where((part) => part.trim().isNotEmpty)
      .take(2)
      .toList();

  if (parts.isEmpty) {
    return 'C';
  }

  return parts.map((part) => part.trim().characters.first.toUpperCase()).join();
}
