/// Item koleksi stiker favorit (BRIEF 4C-3-APP-1).
///
/// Dikonsumsi picker grid dari GET admin-mobile `sticker-favorites` (BE-1).
/// Shape item: `id`, `mime_type`, `sticker_animated`, dan `media_url` (signed
/// absolut) — `media_url` HANYA ada saat flag picker BE ON, jadi [mediaUrl]
/// nullable & di-guard saat render. Model self-contained: nol normalisasi
/// cross-file (media_url BE sudah absolut; `_normalizeMediaUrl` thread_model
/// privat tak dapat dipanggil dari sini).
class StickerFavoriteItem {
  const StickerFavoriteItem({
    required this.id,
    this.mediaUrl,
    this.mimeType,
    this.animated = false,
  });

  factory StickerFavoriteItem.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['media_url'];
    final url = rawUrl is String ? rawUrl.trim() : '';

    return StickerFavoriteItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      mediaUrl: url.isEmpty ? null : url,
      mimeType: json['mime_type'] as String?,
      animated: json['sticker_animated'] == true,
    );
  }

  final int id;
  final String? mediaUrl;
  final String? mimeType;
  final bool animated;
}
