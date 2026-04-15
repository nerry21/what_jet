class CustomerStatusItem {
  const CustomerStatusItem({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.statusType,
    required this.text,
    required this.caption,
    required this.backgroundColor,
    required this.textColor,
    required this.fontStyle,
    required this.mediaUrl,
    required this.mediaMimeType,
    required this.musicTitle,
    required this.musicArtist,
    required this.postedAt,
    required this.expiresAt,
    required this.isViewed,
    required this.viewerCount,
    required this.durationSeconds,
    required this.segmentIndex,
    required this.segmentTotal,
  });

  final int id;
  final int authorId;
  final String authorName;
  final String statusType;
  final String? text;
  final String? caption;
  final String? backgroundColor;
  final String? textColor;
  final String? fontStyle;
  final String? mediaUrl;
  final String? mediaMimeType;
  final String? musicTitle;
  final String? musicArtist;
  final DateTime? postedAt;
  final DateTime? expiresAt;
  final bool isViewed;
  final int viewerCount;
  final int? durationSeconds;
  final int segmentIndex;
  final int segmentTotal;

  bool get isText => statusType == 'text';
  bool get isImage => statusType == 'image';
  bool get isVideo => statusType == 'video';
  bool get isAudio => statusType == 'audio';
  bool get isMusic => statusType == 'music';

  factory CustomerStatusItem.fromJson(Map<String, dynamic> json) {
    final musicMeta = _asStringMap(json['music_meta']);

    return CustomerStatusItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      authorId: (json['author_id'] as num?)?.toInt() ?? 0,
      authorName: (json['author_name'] as String?) ?? 'Admin',
      statusType: (json['status_type'] as String?) ?? 'text',
      text: json['text'] as String?,
      caption: json['caption'] as String?,
      backgroundColor: json['background_color'] as String?,
      textColor: json['text_color'] as String?,
      fontStyle: json['font_style'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaMimeType: json['media_mime_type'] as String?,
      musicTitle: musicMeta?['title'] as String?,
      musicArtist: musicMeta?['artist'] as String?,
      postedAt: _parseDate(json['posted_at']),
      expiresAt: _parseDate(json['expires_at']),
      isViewed: json['is_viewed'] == true,
      viewerCount: (json['viewer_count'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      segmentIndex: (json['segment_index'] as num?)?.toInt() ?? 0,
      segmentTotal: (json['segment_total'] as num?)?.toInt() ?? 1,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static Map<String, dynamic>? _asStringMap(Object? value) {
    if (value is Map) {
      return value.map(
        (Object? key, Object? item) => MapEntry(key.toString(), item),
      );
    }

    return null;
  }
}
