import 'dart:async';

import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/omnichannel_starred_message_item.dart';
import '../../data/repositories/omnichannel_repository.dart';

class OmnichannelStarredMessagesPage extends StatefulWidget {
  const OmnichannelStarredMessagesPage({super.key, required this.repository});

  final OmnichannelRepository repository;

  @override
  State<OmnichannelStarredMessagesPage> createState() =>
      _OmnichannelStarredMessagesPageState();
}

class _OmnichannelStarredMessagesPageState
    extends State<OmnichannelStarredMessagesPage> {
  List<OmnichannelStarredMessageItem> _items =
      const <OmnichannelStarredMessageItem>[];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStarred());
  }

  Future<void> _loadStarred() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await widget.repository.loadStarredMessages();

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
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
        _errorMessage = 'Gagal memuat pesan berbintang: $error';
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
        title: const Text('Pesan Berbintang'),
        actions: <Widget>[
          IconButton(
            onPressed: _isLoading ? null : () => unawaited(_loadStarred()),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Semua pesan berbintang lintas percakapan, dibagikan antar admin, urut terbaru.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage?.trim().isNotEmpty ?? false)
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(12),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.star_border_rounded,
              size: 34,
              color: AppColors.neutral300,
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada pesan berbintang',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.neutral800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pesan yang dibintangi admin akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
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

        return Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.scaffoldBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.customerName.trim().isEmpty
                          ? 'Customer'
                          : item.customerName.trim(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neutral800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatStarredAt(item.starredAt),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _displayText(item),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.neutral500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _displayText(OmnichannelStarredMessageItem item) {
    final text = item.text?.trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }

    switch (item.messageType) {
      case 'image':
        return 'Foto';
      case 'audio':
        return 'Pesan suara';
      case 'video':
        return 'Video';
      case 'document':
        return 'Dokumen';
      case 'location':
        return 'Lokasi';
      case 'sticker':
        return 'Stiker';
      case 'interactive':
        return 'Pesan interaktif';
      default:
        return 'Pesan';
    }
  }

  String _formatStarredAt(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$d/$mo/$y $h:$mi';
  }
}
