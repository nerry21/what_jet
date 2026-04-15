import 'customer_status_item.dart';

class CustomerStatusGroup {
  const CustomerStatusGroup({
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.hasUnviewed,
    required this.statuses,
  });

  final int authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final bool hasUnviewed;
  final List<CustomerStatusItem> statuses;

  String get heroTag => 'status-ring-author-$authorId';

  factory CustomerStatusGroup.fromJson(Map<String, dynamic> json) {
    final rawStatuses =
        (json['statuses'] as List<dynamic>?) ?? const <dynamic>[];

    return CustomerStatusGroup(
      authorId: (json['author_id'] as num?)?.toInt() ?? 0,
      authorName: (json['author_name'] as String?) ?? 'Admin',
      authorAvatarUrl: json['author_avatar_url'] as String?,
      hasUnviewed: json['has_unviewed'] == true,
      statuses: rawStatuses
          .whereType<Map>()
          .map(
            (Map item) => CustomerStatusItem.fromJson(
              item.map(
                (Object? key, Object? value) => MapEntry(key.toString(), value),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
