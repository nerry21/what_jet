import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';

Future<void> showWhatsAppAttachmentSheet({
  required BuildContext context,
  required Future<void> Function() onGalleryTap,
  required Future<void> Function() onCameraTap,
  required Future<void> Function() onLocationTap,
  required Future<void> Function() onContactTap,
  required Future<void> Function() onDocumentTap,
  required Future<void> Function() onAudioTap,
  required Future<void> Function() onPollTap,
  required Future<void> Function() onEventTap,
  Future<void> Function()? onVideoFileTap,
  Future<void> Function()? onStickerTap,
  Future<void> Function()? onCarouselTap,
  Future<void> Function()? onGreetingTap,
  Future<void> Function()? onSendQrisTap,
  Future<void> Function()? onSendNorekTap,
  Future<void> Function()? onConfirmCashTap,
  Future<void> Function()? onIssueTicketTap,
  Future<void> Function()? onVerifyTransferTap,
  Future<void> Function()? onCreateRegulerTap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _WhatsAppAttachmentSheet(
        onGalleryTap: onGalleryTap,
        onCameraTap: onCameraTap,
        onLocationTap: onLocationTap,
        onContactTap: onContactTap,
        onDocumentTap: onDocumentTap,
        onAudioTap: onAudioTap,
        onPollTap: onPollTap,
        onEventTap: onEventTap,
        onVideoFileTap: onVideoFileTap,
        onStickerTap: onStickerTap,
        onCarouselTap: onCarouselTap,
        onGreetingTap: onGreetingTap,
        onSendQrisTap: onSendQrisTap,
        onSendNorekTap: onSendNorekTap,
        onConfirmCashTap: onConfirmCashTap,
        onIssueTicketTap: onIssueTicketTap,
        onVerifyTransferTap: onVerifyTransferTap,
        onCreateRegulerTap: onCreateRegulerTap,
      );
    },
  );
}

class _WhatsAppAttachmentSheet extends StatelessWidget {
  const _WhatsAppAttachmentSheet({
    required this.onGalleryTap,
    required this.onCameraTap,
    required this.onLocationTap,
    required this.onContactTap,
    required this.onDocumentTap,
    required this.onAudioTap,
    required this.onPollTap,
    required this.onEventTap,
    this.onVideoFileTap,
    this.onStickerTap,
    this.onCarouselTap,
    this.onGreetingTap,
    this.onSendQrisTap,
    this.onSendNorekTap,
    this.onConfirmCashTap,
    this.onIssueTicketTap,
    this.onVerifyTransferTap,
    this.onCreateRegulerTap,
  });

  final Future<void> Function() onGalleryTap;
  final Future<void> Function() onCameraTap;
  final Future<void> Function() onLocationTap;
  final Future<void> Function() onContactTap;
  final Future<void> Function() onDocumentTap;
  final Future<void> Function() onAudioTap;
  final Future<void> Function() onPollTap;
  final Future<void> Function() onEventTap;
  final Future<void> Function()? onVideoFileTap;
  final Future<void> Function()? onStickerTap;
  final Future<void> Function()? onCarouselTap;
  final Future<void> Function()? onGreetingTap;
  final Future<void> Function()? onSendQrisTap;
  final Future<void> Function()? onSendNorekTap;
  final Future<void> Function()? onConfirmCashTap;
  final Future<void> Function()? onIssueTicketTap;
  final Future<void> Function()? onVerifyTransferTap;
  final Future<void> Function()? onCreateRegulerTap;

  @override
  Widget build(BuildContext context) {
    final actions = <_AttachmentAction>[
      _AttachmentAction(
        label: 'Galeri',
        icon: Icons.photo_library_rounded,
        color: const Color(0xFF2B7FFF),
        onTap: onGalleryTap,
      ),
      _AttachmentAction(
        label: 'Kamera',
        icon: Icons.camera_alt_rounded,
        color: const Color(0xFFED3A8A),
        onTap: onCameraTap,
      ),
      if (onVideoFileTap != null)
        _AttachmentAction(
          label: 'Video',
          icon: Icons.videocam_rounded,
          color: const Color(0xFFE5484D),
          onTap: onVideoFileTap!,
        ),
      _AttachmentAction(
        label: 'Lokasi',
        icon: Icons.location_on_rounded,
        color: const Color(0xFF22B07D),
        onTap: onLocationTap,
      ),
      _AttachmentAction(
        label: 'Kontak',
        icon: Icons.person_rounded,
        color: const Color(0xFF29A0FF),
        onTap: onContactTap,
      ),
      _AttachmentAction(
        label: 'Dokumen',
        icon: Icons.description_rounded,
        color: const Color(0xFF8D63FF),
        onTap: onDocumentTap,
      ),
      _AttachmentAction(
        label: 'Audio',
        icon: Icons.headphones_rounded,
        color: const Color(0xFFFF8A1C),
        onTap: onAudioTap,
      ),
      _AttachmentAction(
        label: 'Polling',
        icon: Icons.poll_rounded,
        color: const Color(0xFFF2B300),
        onTap: onPollTap,
      ),
      _AttachmentAction(
        label: 'Acara',
        icon: Icons.event_rounded,
        color: const Color(0xFFFF3B8D),
        onTap: onEventTap,
      ),
      if (onStickerTap != null)
        _AttachmentAction(
          label: 'Stiker',
          icon: Icons.emoji_emotions_rounded,
          color: const Color(0xFF00B8D4),
          onTap: onStickerTap!,
        ),
      if (onCarouselTap != null)
        _AttachmentAction(
          label: 'Daftar Rute',
          icon: Icons.alt_route_rounded,
          color: const Color(0xFF2B7FFF),
          onTap: onCarouselTap!,
        ),
      if (onGreetingTap != null)
        _AttachmentAction(
          label: 'Kirim Sapaan',
          icon: Icons.waving_hand_rounded,
          color: const Color(0xFFFFB020),
          onTap: onGreetingTap!,
        ),
      if (onSendQrisTap != null)
        _AttachmentAction(
          label: 'Kirim QRIS',
          icon: Icons.qr_code_rounded,
          color: const Color(0xFF6C5CE7),
          onTap: onSendQrisTap!,
        ),
      if (onSendNorekTap != null)
        _AttachmentAction(
          label: 'Kirim No-rek',
          icon: Icons.account_balance_rounded,
          color: const Color(0xFF22B07D),
          onTap: onSendNorekTap!,
        ),
      if (onConfirmCashTap != null)
        _AttachmentAction(
          label: 'Konfirmasi Cash',
          icon: Icons.payments_rounded,
          color: const Color(0xFF16A34A),
          onTap: onConfirmCashTap!,
        ),
      if (onIssueTicketTap != null)
        _AttachmentAction(
          label: 'Terbit Tiket',
          icon: Icons.confirmation_number_rounded,
          color: const Color(0xFF0284C7),
          onTap: onIssueTicketTap!,
        ),
      if (onVerifyTransferTap != null)
        _AttachmentAction(
          label: 'Verify Transfer',
          icon: Icons.price_check_rounded,
          color: const Color(0xFF7C3AED),
          onTap: onVerifyTransferTap!,
        ),
      if (onCreateRegulerTap != null)
        _AttachmentAction(
          label: 'Buat Booking Reguler',
          icon: Icons.event_seat_rounded,
          color: const Color(0xFF0D9488),
          onTap: onCreateRegulerTap!,
        ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Material(
            color: AppColors.surfaceSecondary,
            borderRadius: AppRadii.borderRadiusXxl,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderDefault,
                        borderRadius: AppRadii.borderRadiusPill,
                      ),
                    ),
                    const SizedBox(height: 18),
                    GridView.builder(
                      shrinkWrap: true,
                      itemCount: actions.length,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 18,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.9,
                          ),
                      itemBuilder: (context, index) {
                        final action = actions[index];
                        return _AttachmentActionTile(action: action);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentAction {
  const _AttachmentAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;
}

class _AttachmentActionTile extends StatelessWidget {
  const _AttachmentActionTile({required this.action});

  final _AttachmentAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          Navigator.of(context).pop();
          await action.onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(action.icon, color: action.color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              action.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
