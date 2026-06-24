import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import 'package:what_jet/features/omnichannel/data/models/sticker_favorite_item.dart';

/// Picker stiker favorit (BRIEF 4C-3-APP-1).
///
/// Modal bottom sheet berisi grid 4-kolom thumbnail favorit. [onLoad] di-fetch
/// tiap buka (selalu fresh); tap sel -> tutup sheet -> [onPick] dengan `id`
/// favorit. State: loading / error (+coba lagi) / empty / grid. Render thumbnail
/// mirror `ConversationStickerPreview` (Image.network + loading/error builder).
/// Di-gate flag `stickerPickerEnabled` di call site (center pane).
Future<void> showStickerPickerSheet({
  required BuildContext context,
  required Future<List<StickerFavoriteItem>> Function() onLoad,
  required void Function(int favoriteId) onPick,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _StickerPickerSheet(onLoad: onLoad, onPick: onPick);
    },
  );
}

class _StickerPickerSheet extends StatefulWidget {
  const _StickerPickerSheet({required this.onLoad, required this.onPick});

  final Future<List<StickerFavoriteItem>> Function() onLoad;
  final void Function(int favoriteId) onPick;

  @override
  State<_StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<_StickerPickerSheet> {
  late Future<List<StickerFavoriteItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.onLoad();
  }

  void _reload() {
    setState(() {
      _future = widget.onLoad();
    });
  }

  void _handlePick(StickerFavoriteItem item) {
    Navigator.of(context).pop();
    widget.onPick(item.id);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Material(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadii.borderRadiusXxl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDefault,
                    borderRadius: AppRadii.borderRadiusPill,
                  ),
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: FutureBuilder<List<StickerFavoriteItem>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _StickerPickerLoading();
                      }
                      if (snapshot.hasError) {
                        return _StickerPickerError(onRetry: _reload);
                      }
                      final items =
                          snapshot.data ?? const <StickerFavoriteItem>[];
                      if (items.isEmpty) {
                        return const _StickerPickerEmpty();
                      }
                      return _StickerPickerGrid(
                        items: items,
                        onPick: _handlePick,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StickerPickerLoading extends StatelessWidget {
  const _StickerPickerLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _StickerPickerEmpty extends StatelessWidget {
  const _StickerPickerEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          'Belum ada stiker favorit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral500,
          ),
        ),
      ),
    );
  }
}

class _StickerPickerError extends StatelessWidget {
  const _StickerPickerError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.neutral300,
            size: 32,
          ),
          const SizedBox(height: 12),
          const Text(
            'Gagal memuat stiker favorit',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral500,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class _StickerPickerGrid extends StatelessWidget {
  const _StickerPickerGrid({required this.items, required this.onPick});

  final List<StickerFavoriteItem> items;
  final void Function(StickerFavoriteItem item) onPick;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      itemCount: items.length,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _StickerPickerCell(item: item, onTap: () => onPick(item));
      },
    );
  }
}

class _StickerPickerCell extends StatelessWidget {
  const _StickerPickerCell({required this.item, required this.onTap});

  final StickerFavoriteItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = item.mediaUrl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: (url == null || url.isEmpty)
              ? const _StickerPickerBroken()
              : Image.network(
                  url,
                  fit: BoxFit.contain,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }
                    return const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => const _StickerPickerBroken(),
                ),
        ),
      ),
    );
  }
}

class _StickerPickerBroken extends StatelessWidget {
  const _StickerPickerBroken();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.broken_image_outlined, color: AppColors.neutral300),
    );
  }
}
