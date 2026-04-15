import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/omnichannel_call_session_model.dart';
import '../utils/omnichannel_call_status_ui.dart';
import 'omnichannel_call_status_chip.dart';

class OmnichannelCallBanner extends StatelessWidget {
  const OmnichannelCallBanner({
    super.key,
    required this.session,
    required this.onOpenCall,
    this.isFallbackMode = false,
    this.fallbackNote,
    this.onEndCall,
    this.onClose,
    this.isBusy = false,
  });

  final OmnichannelCallSessionModel? session;
  final VoidCallback onOpenCall;
  final bool isFallbackMode;
  final String? fallbackNote;
  final Future<void> Function()? onEndCall;
  final VoidCallback? onClose;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final color = omnichannelCallStatusColor(session);
    final statusText = omnichannelCallPrimaryStatusText(session);
    final detailText = omnichannelCallSecondaryStatusText(session);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Colors.white, color.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              omnichannelCallStatusIcon(session),
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detailText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.neutral500,
                  ),
                ),
                if (isFallbackMode) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    fallbackNote?.trim().isNotEmpty == true
                        ? fallbackNote!.trim()
                        : omnichannelCallFallbackBannerNote(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral500,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OmnichannelCallStatusChip(session: session, compact: true),
                    if ((session?.waCallId?.trim().isNotEmpty ?? false))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.borderLight,
                          ),
                        ),
                        child: Text(
                          'ID ${session!.waCallId}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.neutral500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (onClose != null) ...<Widget>[
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Color(0xFF667085),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.tonalIcon(
                onPressed: onOpenCall,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(session?.isFinished == true ? 'Lihat' : 'Buka'),
              ),
              if (session != null &&
                  !session!.isFinished &&
                  onEndCall != null) ...<Widget>[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: isBusy ? null : () => onEndCall!.call(),
                  icon: isBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.call_end_rounded, size: 18),
                  label: const Text('Akhiri'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
