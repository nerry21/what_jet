import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
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
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: message.isMine
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: message.isMine
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        AppColors.bubbleOutgoing,
                        AppColors.bubbleOutgoingGradientEnd,
                      ],
                    )
                  : null,
              color: message.isMine ? null : AppColors.bubbleIncoming,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Flexible(
                  child: Text(
                    message.text,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  timeLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xB3999999),
                  ),
                ),
                if (message.isMine) ...<Widget>[
                  const SizedBox(width: 4),
                  _StatusIcon(message: message, onRetry: onRetry),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.message, this.onRetry});

  final ChatMessageModel message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (message.isFailed) {
      return InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.all(2),
          child: Icon(Icons.refresh_rounded, size: 16, color: AppColors.error),
        ),
      );
    }

    if (message.isSending) {
      return const Icon(
        Icons.schedule_rounded,
        size: 14,
        color: AppColors.neutral500,
      );
    }

    if (message.isReadByCustomer) {
      return const Icon(
        Icons.done_all_rounded,
        size: 14,
        color: AppColors.readReceipt,
      );
    }

    if (message.isDelivered) {
      return const Icon(
        Icons.done_all_rounded,
        size: 14,
        color: AppColors.primary,
      );
    }

    return const Icon(Icons.done_rounded, size: 14, color: AppColors.primary);
  }
}
