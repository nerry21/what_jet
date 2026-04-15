import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../data/models/customer_status_group.dart';
import '../../data/repositories/customer_status_repository.dart';
import '../pages/customer_status_viewer_page.dart';
import 'segmented_status_ring_avatar.dart';
import 'status_strip_shimmer.dart';

class CustomerStatusStrip extends StatefulWidget {
  const CustomerStatusStrip({super.key, required this.repository});

  final CustomerStatusRepository repository;

  @override
  State<CustomerStatusStrip> createState() => _CustomerStatusStripState();
}

class _CustomerStatusStripState extends State<CustomerStatusStrip> {
  bool _isLoading = true;
  String? _error;
  List<CustomerStatusGroup> _items = const <CustomerStatusGroup>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await widget.repository.loadFeed();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _describeError(error);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const StatusStripShimmer();
    }

    if (_error != null) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('Belum ada status aktif')),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = _items[index];
          final viewedSegments = item.statuses.where((e) => e.isViewed).length;

          return GestureDetector(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CustomerStatusViewerPage(
                    group: item,
                    repository: widget.repository,
                  ),
                ),
              );
              if (!mounted) return;
              await _load();
            },
            child: SegmentedStatusRingAvatar(
              label: item.authorName,
              totalSegments: item.statuses.length,
              viewedSegments: viewedSegments,
              imageUrl: item.authorAvatarUrl,
              heroTag: item.heroTag,
            ),
          );
        },
      ),
    );
  }

  String _describeError(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    final text = error.toString();
    if (text.startsWith('Bad state: ')) {
      return text.substring('Bad state: '.length);
    }

    return text;
  }
}
