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
}) {
  return showModalBottomSheet<void>(
    context: context,
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
  });

  final Future<void> Function() onGalleryTap;
  final Future<void> Function() onCameraTap;
  final Future<void> Function() onLocationTap;
  final Future<void> Function() onContactTap;
  final Future<void> Function() onDocumentTap;
  final Future<void> Function() onAudioTap;
  final Future<void> Function() onPollTap;
  final Future<void> Function() onEventTap;

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
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Material(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadii.borderRadiusXxl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
              style: const TextStyle(
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
