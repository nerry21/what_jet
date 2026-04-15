import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import '../../data/models/omnichannel_call_analytics_summary_model.dart';
import '../../data/models/omnichannel_call_daily_trend_item_model.dart';
import '../../data/models/omnichannel_call_history_item_model.dart';
import '../../data/models/omnichannel_call_outcome_item_model.dart';
import '../utils/omnichannel_call_status_ui.dart';
import 'omnichannel_surface.dart';

class OmnichannelCallAnalyticsPanel extends StatelessWidget {
  const OmnichannelCallAnalyticsPanel({
    super.key,
    required this.snapshot,
    required this.isLoading,
    this.errorMessage,
    this.onRetry,
    this.onOpenConversation,
  });

  final OmnichannelCallAnalyticsSnapshotModel? snapshot;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function()? onRetry;
  final ValueChanged<int>? onOpenConversation;

  @override
  Widget build(BuildContext context) {
    return OmnichannelSectionCard(
      title: 'Ringkasan Panggilan',
      trailing: isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (errorMessage?.trim().isNotEmpty ?? false) ...<Widget>[
            _PanelNotice(message: errorMessage!, onRetry: onRetry),
            const SizedBox(height: 12),
          ],
          if (isLoading && snapshot == null)
            const _AnalyticsSkeleton()
          else if (snapshot == null)
            _AnalyticsEmptyState(onRetry: onRetry)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SummaryGrid(summary: snapshot!.summary),
                const SizedBox(height: 16),
                _OutcomeBreakdown(
                  items: snapshot!.outcomeBreakdown,
                  summary: snapshot!.summary,
                ),
                const SizedBox(height: 16),
                _DailyTrendSection(items: snapshot!.dailyTrend),
                const SizedBox(height: 16),
                _RecentCallsSection(
                  items: snapshot!.recentCalls,
                  onOpenConversation: onOpenConversation,
                ),
                const SizedBox(height: 16),
                _CapabilityCard(capabilities: snapshot!.capabilities),
              ],
            ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final OmnichannelCallAnalyticsSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final items = <_SummaryTileData>[
      _SummaryTileData(
        label: 'Total',
        value: '${summary.totalCalls}',
        color: AppColors.neutral800,
      ),
      _SummaryTileData(
        label: 'Completed',
        value: '${summary.completedCalls}',
        color: AppColors.success,
      ),
      _SummaryTileData(
        label: 'Missed',
        value: '${summary.missedCalls}',
        color: AppColors.neutral500,
      ),
      _SummaryTileData(
        label: 'Rejected',
        value: '${summary.rejectedCalls}',
        color: AppColors.error,
      ),
      _SummaryTileData(
        label: 'Failed',
        value: '${summary.failedCalls}',
        color: const Color(0xFFAE4A3B),
      ),
      _SummaryTileData(
        label: 'Rata-rata',
        value: summary.averageDurationHuman,
        color: AppColors.primary,
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map((item) => SizedBox(width: 122, child: _SummaryTile(data: item)))
          .toList(),
    );
  }
}

class _SummaryTileData {
  const _SummaryTileData({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.data});

  final _SummaryTileData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            data.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.neutral300,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: data.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeBreakdown extends StatelessWidget {
  const _OutcomeBreakdown({required this.items, required this.summary});

  final List<OmnichannelCallOutcomeItemModel> items;
  final OmnichannelCallAnalyticsSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Outcome Breakdown',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.neutral500,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Completion rate ${summary.completionRate.toStringAsFixed(1)}% | Missed rate ${summary.missedRate.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.neutral300,
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Text(
            'Breakdown panggilan belum tersedia.',
            style: TextStyle(fontSize: 12, color: AppColors.neutral300),
          )
        else
          Column(
            children: items.map((item) => _OutcomeRow(item: item)).toList(),
          ),
      ],
    );
  }
}

class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({required this.item});

  final OmnichannelCallOutcomeItemModel item;

  @override
  Widget build(BuildContext context) {
    final color = omnichannelCallOutcomeColor(item.finalStatus);

    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                omnichannelCallOutcomeIcon(item.finalStatus),
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral800,
                  ),
                ),
              ),
              Text(
                '${item.count}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item.percentage.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 11, color: AppColors.neutral300),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: AppRadii.borderRadiusPill,
            child: LinearProgressIndicator(
              minHeight: 6,
              value: ((item.percentage / 100).clamp(0, 1)).toDouble(),
              color: color,
              backgroundColor: AppColors.borderLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyTrendSection extends StatelessWidget {
  const _DailyTrendSection({required this.items});

  final List<OmnichannelCallDailyTrendItemModel> items;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.length > 5
        ? items.sublist(items.length - 5)
        : items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Trend Harian',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.neutral500,
          ),
        ),
        const SizedBox(height: 10),
        if (visibleItems.isEmpty)
          const Text(
            'Trend panggilan harian belum tersedia.',
            style: TextStyle(fontSize: 12, color: AppColors.neutral300),
          )
        else
          Column(
            children: visibleItems
                .map((item) => _DailyTrendRow(item: item))
                .toList(),
          ),
      ],
    );
  }
}

class _DailyTrendRow extends StatelessWidget {
  const _DailyTrendRow({required this.item});

  final OmnichannelCallDailyTrendItemModel item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              omnichannelFormatTrendDate(item.date) ?? item.date,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.neutral800,
              ),
            ),
          ),
          Text(
            '${item.totalCalls} call',
            style: TextStyle(fontSize: 12, color: AppColors.neutral500),
          ),
          const SizedBox(width: 10),
          Text(
            omnichannelCallDurationText(
              durationSeconds: item.totalDurationSeconds,
            ),
            style: TextStyle(fontSize: 11, color: AppColors.neutral300),
          ),
        ],
      ),
    );
  }
}

class _RecentCallsSection extends StatelessWidget {
  const _RecentCallsSection({required this.items, this.onOpenConversation});

  final List<OmnichannelCallHistoryItemModel> items;
  final ValueChanged<int>? onOpenConversation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Panggilan Terbaru',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.neutral500,
          ),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const Text(
            'Belum ada panggilan terbaru untuk ditampilkan.',
            style: TextStyle(fontSize: 12, color: AppColors.neutral300),
          )
        else
          Column(
            children: items
                .map(
                  (item) => _RecentCallRow(
                    item: item,
                    onOpenConversation: onOpenConversation,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _RecentCallRow extends StatelessWidget {
  const _RecentCallRow({required this.item, this.onOpenConversation});

  final OmnichannelCallHistoryItemModel item;
  final ValueChanged<int>? onOpenConversation;

  @override
  Widget build(BuildContext context) {
    final outcomeColor = omnichannelCallOutcomeColor(item.finalStatus);

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
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
                  item.customerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutral800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: outcomeColor.withValues(alpha: 0.12),
                  borderRadius: AppRadii.borderRadiusPill,
                ),
                child: Text(
                  omnichannelCallOutcomeLabel(
                    item.finalStatus,
                    fallback: item.finalStatusLabel ?? 'Sedang berlangsung',
                  ),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: outcomeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.customerContact,
            style: TextStyle(fontSize: 11, color: AppColors.neutral300),
          ),
          const SizedBox(height: 8),
          Text(
            [
              omnichannelFormatCallTimestamp(item.startedAt) ?? '-',
              omnichannelCallDurationText(
                durationSeconds: item.durationSeconds,
                durationHuman: item.durationHuman,
              ),
            ].join(' | '),
            style: TextStyle(fontSize: 11, color: AppColors.neutral500),
          ),
          if (item.conversationId != null &&
              onOpenConversation != null) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => onOpenConversation!(item.conversationId!),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Buka chat'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(0, 0),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.capabilities});

  final OmnichannelCallCapabilityModel capabilities;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Kesiapan Voice',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.neutral500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            capabilities.supportsLiveAudio
                ? 'Audio live tersedia pada build ini.'
                : 'Audio live belum aktif. Analytics dan status panggilan tetap memakai data backend yang nyata.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.neutral300,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _CapabilityChip(
                label: 'Live Audio',
                enabled: capabilities.supportsLiveAudio,
              ),
              _CapabilityChip(
                label: 'WebRTC Signaling',
                enabled: capabilities.supportsWebrtcSignaling,
              ),
              _CapabilityChip(
                label: 'Recording',
                enabled: capabilities.supportsCallRecording,
              ),
              _CapabilityChip(
                label: 'Transfer',
                enabled: capabilities.supportsCallTransfer,
              ),
              _CapabilityChip(
                label: 'Agent Pickup',
                enabled: capabilities.supportsAgentPickup,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.success : AppColors.neutral300;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.borderRadiusPill,
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

class _PanelNotice extends StatelessWidget {
  const _PanelNotice({required this.message, this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: AppRadii.borderRadiusMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.error,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                onRetry!.call();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

class _AnalyticsEmptyState extends StatelessWidget {
  const _AnalyticsEmptyState({this.onRetry});

  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Analytics panggilan belum tersedia. Dashboard tetap aman digunakan, tetapi ringkasan call belum dapat dimuat.',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: AppColors.neutral300,
          ),
        ),
        if (onRetry != null) ...<Widget>[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () {
                onRetry!.call();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Muat ulang'),
            ),
          ),
        ],
      ],
    );
  }
}

class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List<Widget>.generate(
            6,
            (_) => Container(
              width: 122,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadii.borderRadiusLg,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  OmnichannelSkeletonBlock(width: 64, height: 10),
                  SizedBox(height: 8),
                  OmnichannelSkeletonBlock(width: 56, height: 18),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const OmnichannelSkeletonBlock(height: 12, width: 120),
        const SizedBox(height: 12),
        const OmnichannelSkeletonBlock(height: 54, radius: 16),
        const SizedBox(height: 12),
        const OmnichannelSkeletonBlock(height: 54, radius: 16),
      ],
    );
  }
}
