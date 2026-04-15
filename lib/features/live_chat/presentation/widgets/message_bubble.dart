import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import '../../data/models/chat_message_model.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.timeLabel,
    required this.maxWidth,
    this.onRetry,
  });

  final ChatMessageModel message;
  final String timeLabel;
  final double maxWidth;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.isMine;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: EdgeInsets.only(bottom: 6),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              // Outgoing: emerald gradient with glow
              gradient: isOutgoing
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[AppColors.primary, AppColors.primary700],
                    )
                  : null,
              // Incoming: dark glass surface
              color: isOutgoing ? null : AppColors.surfaceTertiary,
              borderRadius: isOutgoing
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                    )
                  : const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(18),
                    ),
              border: isOutgoing
                  ? null
                  : Border.all(
                      color: AppColors.borderLight.withValues(alpha: 0.5),
                    ),
              boxShadow: <BoxShadow>[
                if (isOutgoing)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                BoxShadow(
                  color: const Color(0x20000000),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                // Message text
                Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: isOutgoing ? AppColors.white : AppColors.neutral800,
                  ),
                ),
                const SizedBox(height: 4),

                // Time + status row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: isOutgoing
                            ? AppColors.white.withValues(alpha: 0.60)
                            : AppColors.neutral300,
                      ),
                    ),
                    if (isOutgoing) ...<Widget>[
                      const SizedBox(width: 4),
                      _PremiumStatusIcon(message: message, onRetry: onRetry),
                    ],
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

class _PremiumStatusIcon extends StatelessWidget {
  const _PremiumStatusIcon({required this.message, this.onRetry});

  final ChatMessageModel message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (message.isFailed) {
      return InkWell(
        onTap: onRetry,
        borderRadius: AppRadii.borderRadiusXl,
        child: Padding(
          padding: EdgeInsets.all(2),
          child: Icon(Icons.refresh_rounded, size: 16, color: AppColors.error),
        ),
      );
    }

    if (message.isSending) {
      return Icon(
        Icons.schedule_rounded,
        size: 14,
        color: AppColors.white.withValues(alpha: 0.50),
      );
    }

    if (message.isReadByCustomer) {
      return Icon(
        Icons.done_all_rounded,
        size: 14,
        color: AppColors.readReceipt, // Bright emerald green
      );
    }

    if (message.isDelivered) {
      return Icon(
        Icons.done_all_rounded,
        size: 14,
        color: AppColors.white.withValues(alpha: 0.70),
      );
    }

    return Icon(
      Icons.done_rounded,
      size: 14,
      color: AppColors.white.withValues(alpha: 0.60),
    );
  }
}
