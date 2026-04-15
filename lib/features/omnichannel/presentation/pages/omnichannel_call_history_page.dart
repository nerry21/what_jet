import 'dart:async';

import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/omnichannel_call_history_item_model.dart';
import '../../data/repositories/omnichannel_repository.dart';
import '../utils/omnichannel_call_status_ui.dart';
import '../widgets/omnichannel_call_history_section.dart';
import '../widgets/omnichannel_surface.dart';

class OmnichannelCallHistoryPage extends StatefulWidget {
  const OmnichannelCallHistoryPage({
    super.key,
    required this.repository,
    required this.conversationId,
    required this.conversationTitle,
    this.initialSummary,
    this.initialItems = const <OmnichannelCallHistoryItemModel>[],
  });

  final OmnichannelRepository repository;
  final int conversationId;
  final String conversationTitle;
  final OmnichannelConversationCallHistorySummaryModel? initialSummary;
  final List<OmnichannelCallHistoryItemModel> initialItems;

  @override
  State<OmnichannelCallHistoryPage> createState() =>
      _OmnichannelCallHistoryPageState();
}

class _OmnichannelCallHistoryPageState
    extends State<OmnichannelCallHistoryPage> {
  static const List<_HistoryFilter> _filters = <_HistoryFilter>[
    _HistoryFilter(key: 'all', label: 'Semua'),
    _HistoryFilter(key: 'completed', label: 'Berhasil'),
    _HistoryFilter(key: 'missed', label: 'Tidak dijawab'),
    _HistoryFilter(key: 'rejected', label: 'Ditolak'),
    _HistoryFilter(key: 'failed', label: 'Gagal'),
    _HistoryFilter(key: 'permission_pending', label: 'Menunggu izin'),
  ];

  OmnichannelConversationCallHistorySummaryModel? _summary;
  List<OmnichannelCallHistoryItemModel> _items =
      const <OmnichannelCallHistoryItemModel>[];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _summary = widget.initialSummary;
    _items = widget.initialItems;
    unawaited(_loadHistory(silent: _summary != null || _items.isNotEmpty));
  }

  Future<void> _loadHistory({bool silent = false}) async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      if (!silent) {
        _errorMessage = null;
      }
    });

    try {
      final history = await widget.repository.loadConversationCallHistory(
        conversationId: widget.conversationId,
        limit: 25,
        finalStatus: _selectedFilter == 'all' ? null : _selectedFilter,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _summary = history.summary;
        _items = history.items;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Gagal memuat riwayat panggilan: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Riwayat Panggilan'),
        actions: <Widget>[
          IconButton(
            onPressed: _isLoading ? null : () => unawaited(_loadHistory()),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.conversationTitle.trim().isEmpty
                    ? 'Conversation'
                    : widget.conversationTitle.trim(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Semua outcome panggilan di conversation ini dirangkum dari backend WhatsApp call session.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: OmnichannelPaneCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      OmnichannelCallHistorySection(
                        summary: _summary,
                        items: const <OmnichannelCallHistoryItemModel>[],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _filters.map((filter) {
                          final selected = _selectedFilter == filter.key;

                          return ChoiceChip(
                            label: Text(filter.label),
                            selected: selected,
                            onSelected: _isLoading
                                ? null
                                : (value) {
                                    if (!value ||
                                        _selectedFilter == filter.key) {
                                      return;
                                    }

                                    setState(
                                      () => _selectedFilter = filter.key,
                                    );
                                    unawaited(_loadHistory());
                                  },
                            selectedColor: AppColors.primary.withValues(
                              alpha: 0.14,
                            ),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.28)
                                  : AppColors.borderLight,
                            ),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? AppColors.primary
                                  : Colors.black87,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      if (_errorMessage?.trim().isNotEmpty ?? false)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: AppRadii.borderRadiusMd,
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 16,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(child: _buildHistoryList()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.call_made_rounded,
              size: 34,
              color: AppColors.neutral300,
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada riwayat panggilan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedFilter == 'all'
                  ? 'Riwayat panggilan untuk conversation ini belum tersedia.'
                  : 'Tidak ada panggilan dengan filter ${_filters.firstWhere((item) => item.key == _selectedFilter).label.toLowerCase()}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.neutral500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _items[index];
        final outcomeColor = omnichannelCallOutcomeColor(item.finalStatus);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.scaffoldBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: outcomeColor.withValues(alpha: 0.12),
                  borderRadius: AppRadii.borderRadiusMd,
                ),
                alignment: Alignment.center,
                child: Icon(
                  omnichannelCallOutcomeIcon(item.finalStatus),
                  size: 18,
                  color: outcomeColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            omnichannelCallOutcomeLabel(
                              item.finalStatus,
                              fallback:
                                  item.finalStatusLabel ?? 'Sedang berlangsung',
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          omnichannelCallDurationText(
                            durationSeconds: item.durationSeconds,
                            durationHuman: item.durationHuman,
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        omnichannelFormatCallTimestamp(item.startedAt) ?? '-',
                        item.customerLabel,
                        if ((item.customerContact).trim().isNotEmpty)
                          item.customerContact,
                      ].join(' | '),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.neutral500,
                      ),
                    ),
                    if (item.waCallId?.trim().isNotEmpty ?? false) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'WA Call ID: ${item.waCallId}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.neutral300,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryFilter {
  const _HistoryFilter({required this.key, required this.label});

  final String key;
  final String label;
}
