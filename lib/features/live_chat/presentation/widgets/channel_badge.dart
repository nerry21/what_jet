import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';

class ChannelBadge extends StatelessWidget {
  const ChannelBadge({super.key, required this.channel, this.compact = false});

  final String channel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isMobileLiveChat = channel == 'mobile_live_chat';
    final label = isMobileLiveChat
        ? 'Live Chat'
        : channel == 'whatsapp'
        ? 'WhatsApp'
        : channel.replaceAll('_', ' ');
    final backgroundColor = isMobileLiveChat
        ? AppColors.primary.withValues(alpha: 0.12)
        : AppColors.accent.withValues(alpha: 0.12);
    final foregroundColor = isMobileLiveChat
        ? AppColors.primary
        : AppColors.accent;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadii.borderRadiusPill,
        border: Border.all(color: foregroundColor.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}
