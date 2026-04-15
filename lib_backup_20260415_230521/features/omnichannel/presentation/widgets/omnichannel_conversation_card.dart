import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppConfig.green.withValues(alpha: 0.08)
                : AppConfig.softBackground.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? AppConfig.green.withValues(alpha: 0.28)
                  : AppConfig.softBackgroundAlt.withValues(alpha: 0.9),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          item.channel == 'mobile_live_chat'
                              ? AppConfig.green
                              : AppConfig.purple,
                          item.channel == 'mobile_live_chat'
                              ? AppConfig.greenLight
                              : AppConfig.purpleLight,
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.customerLabel ?? item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppConfig.mutedText,
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
                      fontWeight: item.hasUnread
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: item.hasUnread
                          ? AppConfig.green
                          : AppConfig.subtleText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppConfig.mutedText,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        ChannelBadge(channel: item.channel, compact: true),
                        _MiniStatusChip(
                          label: item.statusLabel,
                          color: statusColor,
                        ),
                      ],
                    ),
                  ),
                  if (item.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppConfig.green,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${item.unreadCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
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

class _MiniStatusChip extends StatelessWidget {
  const _MiniStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

Color _statusColor(String statusLabel) {
  final normalized = statusLabel.toLowerCase();
  if (normalized.contains('takeover') || normalized.contains('human')) {
    return AppConfig.purple;
  }

  return AppConfig.green;
}

String _safeInitial(String? value, {required String fallback}) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return fallback;
  }
  return text.characters.first.toUpperCase();
}
