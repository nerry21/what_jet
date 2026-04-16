import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import '../../../live_chat/presentation/widgets/channel_badge.dart';
import '../../data/models/omnichannel_conversation_list_model.dart';
import 'omnichannel_surface.dart';

class OmnichannelConversationCard extends StatelessWidget {
  const OmnichannelConversationCard({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final OmnichannelConversationListItemModel item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item.statusLabel);
    final initial = _safeInitial(item.customerLabel, fallback: 'C');
    final avatarColors = _cardAvatarColors(
      item.channel,
      item.customerLabel ?? '',
    );
    final hasUnread = item.unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.borderRadiusLg,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surfaceSecondary,
            borderRadius: AppRadii.borderRadiusLg,
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.20)
                  : AppColors.borderLight.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Rounded avatar with gradient + glow
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.borderRadiusLg,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: avatarColors,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: avatarColors.last.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: AppColors.neutral800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.customerLabel ?? item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.neutral400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatOmnichannelListTime(item.lastActivityAt),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                      color: hasUnread
                          ? AppColors.primary
                          : AppColors.neutral300,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.neutral400,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        ChannelBadge(channel: item.channel, compact: true),
                        _PremiumStatusChip(
                          label: item.statusLabel,
                          color: statusColor,
                        ),
                      ],
                    ),
                  ),
                  if (item.unreadCount > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primary700],
                        ),
                        borderRadius: AppRadii.borderRadiusPill,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${item.unreadCount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumStatusChip extends StatelessWidget {
  const _PremiumStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadii.borderRadiusPill,
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

Color _statusColor(String statusLabel) {
  final normalized = statusLabel.toLowerCase();
  if (normalized.contains('takeover') || normalized.contains('human')) {
    return AppColors.accent;
  }
  return AppColors.primary;
}

String _safeInitial(String? value, {required String fallback}) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return fallback;
  }
  return text.characters.first.toUpperCase();
}

List<Color> _cardAvatarColors(String channel, String name) {
  if (channel == 'mobile_live_chat' || channel == 'chat') {
    return <Color>[AppColors.accent, AppColors.accent600];
  }

  final seed = name.isEmpty ? 0 : name.characters.first.codeUnitAt(0);
  switch (seed % 5) {
    case 0:
      return <Color>[AppColors.primary, AppColors.primary700];
    case 1:
      return <Color>[AppColors.accent, AppColors.accent600];
    case 2:
      return const <Color>[Color(0xFF4A9EF5), Color(0xFF2563EB)];
    case 3:
      return const <Color>[Color(0xFFF5A623), Color(0xFFD48806)];
    default:
      return const <Color>[Color(0xFF2DD89A), Color(0xFF00A86B)];
  }
}
