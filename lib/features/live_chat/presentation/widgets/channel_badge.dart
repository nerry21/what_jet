import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';

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
        ? AppConfig.green.withValues(alpha: 0.12)
        : AppConfig.purple.withValues(alpha: 0.12);
    final foregroundColor = isMobileLiveChat
        ? AppConfig.green
        : AppConfig.purple;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
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
