import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';

/// Action sheet untuk kartu/tile percakapan (BRIEF 3A — gesture surface).
/// Dipicu long-press. Aksi awal: "Tandai belum dibaca". Slot 3B–3E menyusul.
Future<void> showConversationActionSheet({
  required BuildContext context,
  required VoidCallback onMarkUnread,
  required VoidCallback onManageLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _ConversationActionSheet(
        onMarkUnread: onMarkUnread,
        onManageLabel: onManageLabel,
      );
    },
  );
}

class _ConversationActionSheet extends StatelessWidget {
  const _ConversationActionSheet({
    required this.onMarkUnread,
    required this.onManageLabel,
  });

  final VoidCallback onMarkUnread;
  final VoidCallback onManageLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Material(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadii.borderRadiusXxl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 14, 8, 8),
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
                const SizedBox(height: 14),
                _ConversationActionTile(
                  icon: Icons.mark_chat_unread_outlined,
                  label: 'Tandai belum dibaca',
                  onTap: () {
                    Navigator.of(context).pop();
                    onMarkUnread();
                  },
                ),
                _ConversationActionTile(
                  icon: Icons.label_outline,
                  label: 'Kelola label',
                  onTap: () {
                    Navigator.of(context).pop();
                    onManageLabel();
                  },
                ),
                // Slot aksi berikut (3B label / 3C pin / 3D arsip / 3E mute)
                // ditambahkan di sini sebagai _ConversationActionTile.
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationActionTile extends StatelessWidget {
  const _ConversationActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.borderRadiusLg,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: <Widget>[
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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
