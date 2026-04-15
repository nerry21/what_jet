import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import '../../data/models/omnichannel_call_history_item_model.dart';
import '../utils/omnichannel_call_status_ui.dart';
import 'omnichannel_surface.dart';

class OmnichannelCallHistorySection extends StatelessWidget {
  const OmnichannelCallHistorySection({
    super.key,
    this.summary,
    this.items = const <OmnichannelCallHistoryItemModel>[],
    this.maxItems = 4,
    this.onOpenAll,
  });

  final OmnichannelConversationCallHistorySummaryModel? summary;
  final List<OmnichannelCallHistoryItemModel> items;
  final int maxItems;
  final VoidCallback? onOpenAll;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.length > maxItems
        ? items.take(maxItems).toList()
        : items;

    if (summary == null && visibleItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return OmnichannelSectionCard(
      title: 'Riwayat Panggilan',
      trailing: onOpenAll != null && items.isNotEmpty
          ? TextButton(onPressed: onOpenAll, child: const Text('Lihat semua'))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (summary != null) _HistorySummaryCard(summary: summary!),
          if (summary != null && visibleItems.isNotEmpty)
            const SizedBox(height: 12),
          if (visibleItems.isEmpty)
            const Text(
              'Riwayat panggilan belum tersedia untuk percakapan ini.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.neutral300,
              ),
            )
          else
            Column(
              children: visibleItems
                  .map((item) => _HistoryRow(item: item))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _HistorySummaryCard extends StatelessWidget {
  const _HistorySummaryCard({required this.summary});

  final OmnichannelConversationCallHistorySummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final outcomeColor = omnichannelCallOutcomeColor(summary.lastCallStatus);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Panggilan terakhir',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral500,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: outcomeColor.withValues(alpha: 0.12),
                  borderRadius: AppRadii.borderRadiusPill,
                ),
                child: Text(
                  summary.lastCallLabel ??
                      omnichannelCallOutcomeLabel(summary.lastCallStatus),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: outcomeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              _MetaPill(
                label: 'Total panggilan',
                value: '${summary.totalCalls}',
              ),
              _MetaPill(
                label: 'Waktu',
                value:
                    omnichannelFormatCallTimestamp(summary.lastCallAt) ?? '-',
              ),
              _MetaPill(
                label: 'Durasi',
                value: omnichannelCallDurationText(
                  durationSeconds: summary.lastCallDurationSeconds,
                  durationHuman: summary.lastCallDurationHuman,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final OmnichannelCallHistoryItemModel item;

  @override
  Widget build(BuildContext context) {
    final color = omnichannelCallOutcomeColor(item.finalStatus);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadii.borderRadiusMd,
            ),
            alignment: Alignment.center,
            child: Icon(
              omnichannelCallOutcomeIcon(item.finalStatus),
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  omnichannelCallOutcomeLabel(
                    item.finalStatus,
                    fallback: item.finalStatusLabel ?? 'Sedang berlangsung',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutral800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    omnichannelFormatCallTimestamp(item.startedAt) ?? '-',
                    omnichannelCallDurationText(
                      durationSeconds: item.durationSeconds,
                      durationHuman: item.durationHuman,
                    ),
                    if ((item.waCallId?.trim().isNotEmpty ?? false))
                      'ID ${item.waCallId}',
                  ].join(' | '),
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.neutral500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: AppRadii.borderRadiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.neutral300,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.neutral800,
            ),
          ),
        ],
      ),
    );
  }
}
