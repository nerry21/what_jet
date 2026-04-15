import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import '../../data/models/omnichannel_call_session_model.dart';
import '../../data/models/omnichannel_call_timeline_item_model.dart';
import '../utils/omnichannel_call_status_ui.dart';

class OmnichannelCallTimelineSection extends StatelessWidget {
  const OmnichannelCallTimelineSection({
    super.key,
    required this.items,
    this.session,
    this.title = 'Timeline panggilan',
    this.subtitle,
    this.emptyMessage =
        'Histori panggilan belum tersedia. Status aktif tetap dipantau dari server.',
    this.dark = false,
    this.maxItems = 6,
  });

  final List<OmnichannelCallTimelineItemModel> items;
  final OmnichannelCallSessionModel? session;
  final String title;
  final String? subtitle;
  final String emptyMessage;
  final bool dark;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final containerColor = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white;
    final borderColor = dark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.borderLight;
    final titleColor = dark ? Colors.white : Colors.black87;
    final subtitleColor = dark
        ? const Color(0xFFB8C7C2)
        : AppColors.neutral500;
    final visibleItems = items.length > maxItems
        ? items.sublist(items.length - maxItems)
        : items;
    final showSummary =
        session?.isFinished == true ||
        (visibleItems.isNotEmpty && visibleItems.last.isTerminal);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: AppRadii.borderRadiusXl,
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          if (subtitle?.trim().isNotEmpty ?? false) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12, height: 1.45, color: subtitleColor),
            ),
          ],
          if (showSummary) ...<Widget>[
            const SizedBox(height: 14),
            _CallSummaryCard(
              session: session,
              items: visibleItems,
              dark: dark,
            ),
          ],
          const SizedBox(height: 14),
          if (visibleItems.isEmpty)
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 12, height: 1.45, color: subtitleColor),
            )
          else
            Column(
              children: <Widget>[
                for (var index = 0; index < visibleItems.length; index++) ...<
                  Widget
                >[
                  _TimelineRow(item: visibleItems[index], dark: dark),
                  if (index != visibleItems.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: Container(
                        height: 14,
                        width: 1.5,
                        color: dark
                            ? Colors.white.withValues(alpha: 0.12)
                            : AppColors.borderLight,
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

class _CallSummaryCard extends StatelessWidget {
  const _CallSummaryCard({
    required this.session,
    required this.items,
    required this.dark,
  });

  final OmnichannelCallSessionModel? session;
  final List<OmnichannelCallTimelineItemModel> items;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final surface = dark
        ? Colors.white.withValues(alpha: 0.06)
        : AppColors.scaffoldBackground;
    final border = dark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.borderLight;
    final titleColor = dark ? Colors.white : Colors.black87;
    final detailColor = dark
        ? const Color(0xFFB8C7C2)
        : AppColors.neutral500;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            omnichannelCallFinishedSummaryTitle(session, items),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            omnichannelCallFinishedSummaryDetail(session, items),
            style: TextStyle(fontSize: 12, height: 1.4, color: detailColor),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.dark});

  final OmnichannelCallTimelineItemModel item;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = omnichannelCallTimelineColor(item);
    final labelColor = dark ? Colors.white : Colors.black87;
    final detailColor = dark
        ? const Color(0xFFB8C7C2)
        : AppColors.neutral500;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: AppRadii.borderRadiusMd,
          ),
          alignment: Alignment.center,
          child: Icon(omnichannelCallTimelineIcon(item), size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  omnichannelCallTimelineLabel(item),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  omnichannelCallTimelineMetaText(item),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: detailColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
