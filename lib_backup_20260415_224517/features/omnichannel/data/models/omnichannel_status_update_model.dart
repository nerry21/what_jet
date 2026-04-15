class OmnichannelStatusUpdateModel {
  const OmnichannelStatusUpdateModel({
    required this.id,
    required this.authorType,
    required this.authorName,
    required this.statusType,
    required this.text,
    required this.caption,
    required this.backgroundColor,
    required this.textColor,
    required this.fontStyle,
    required this.mediaUrl,
    required this.mediaMimeType,
    required this.mediaOriginalName,
    required this.viewCount,
    required this.postedAt,
    required this.expiresAt,
    required this.musicTitle,
    required this.musicArtist,
  });

  final int id;
  final String authorType;
  final String authorName;
  final String statusType;
  final String? text;
  final String? caption;
  final String? backgroundColor;
  final String? textColor;
  final String? fontStyle;
  final String? mediaUrl;
  final String? mediaMimeType;
  final String? mediaOriginalName;
  final int viewCount;
  final DateTime? postedAt;
  final DateTime? expiresAt;
  final String? musicTitle;
  final String? musicArtist;

  bool get isText => statusType == 'text';
  bool get isImage => statusType == 'image';
  bool get isVideo => statusType == 'video';
  bool get isAudio => statusType == 'audio';
  bool get isMusic => statusType == 'music';

  factory OmnichannelStatusUpdateModel.fromJson(Map<String, dynamic> json) {
    final musicMeta = json['music_meta'];
    final musicMap = musicMeta is Map<String, dynamic>
        ? musicMeta
        : const <String, dynamic>{};

    return OmnichannelStatusUpdateModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      authorType: (json['author_type'] as String? ?? '').trim(),
      authorName: (json['author_name'] as String? ?? '').trim(),
      statusType: (json['status_type'] as String? ?? '').trim(),
      text: (json['text'] as String?)?.trim(),
      caption: (json['caption'] as String?)?.trim(),
      backgroundColor: (json['background_color'] as String?)?.trim(),
      textColor: (json['text_color'] as String?)?.trim(),
      fontStyle: (json['font_style'] as String?)?.trim(),
      mediaUrl: (json['media_url'] as String?)?.trim(),
      mediaMimeType: (json['media_mime_type'] as String?)?.trim(),
      mediaOriginalName: (json['media_original_name'] as String?)?.trim(),
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      postedAt: _parseDateTime(json['posted_at']),
      expiresAt: _parseDateTime(json['expires_at']),
      musicTitle: (musicMap['title'] as String?)?.trim(),
      musicArtist: (musicMap['artist'] as String?)?.trim(),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.trim());
  }
}
