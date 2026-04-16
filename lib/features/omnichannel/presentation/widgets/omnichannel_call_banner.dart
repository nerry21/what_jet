import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
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

    final card = _buildCard(context, color, statusText, detailText);

    // When the card can be dismissed (onClose provided), allow swipe in either
    // horizontal direction to hide it. This makes the card much easier to get
    // rid of than relying solely on the small close button.
    if (onClose != null) {
      return Dismissible(
        key: ValueKey<String>(
          'omnichannel-call-banner-${session?.id ?? session?.waCallId ?? 'placeholder'}',
        ),
        direction: DismissDirection.horizontal,
        dismissThresholds: const <DismissDirection, double>{
          DismissDirection.startToEnd: 0.25,
          DismissDirection.endToStart: 0.25,
        },
        onDismissed: (_) => onClose!.call(),
        background: _buildSwipeBackground(alignLeft: true),
        secondaryBackground: _buildSwipeBackground(alignLeft: false),
        child: card,
      );
    }

    return card;
  }

  Widget _buildSwipeBackground({required bool alignLeft}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.close_rounded, color: AppColors.error, size: 22),
          const SizedBox(width: 6),
          Text(
            'Sembunyikan',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Color color,
    String statusText,
    String detailText,
  ) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.surfaceSecondary,
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0x10000000),
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
              borderRadius: AppRadii.borderRadiusMd,
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutral800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detailText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
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
                    style: TextStyle(
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: AppRadii.borderRadiusPill,
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Text(
                          'ID ${session!.waCallId}',
                          style: TextStyle(
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
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onClose,
                    borderRadius: AppRadii.borderRadiusPill,
                    // Larger tap target with extra padding for easier dismissal.
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.10),
                        borderRadius: AppRadii.borderRadiusPill,
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 24,
                        color: AppColors.error,
                      ),
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
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
