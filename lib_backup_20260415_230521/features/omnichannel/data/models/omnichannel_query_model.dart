class OmnichannelQueryModel {
  const OmnichannelQueryModel({
    this.scope = 'all',
    this.channel = 'all',
    this.search = '',
    this.page = 1,
    this.perPage = 20,
  });

  final String scope;
  final String channel;
  final String search;
  final int page;
  final int perPage;

  bool get hasSearch => search.trim().isNotEmpty;

  Map<String, Object?> toQueryParameters() {
    return <String, Object?>{
      'scope': scope,
      'channel': channel,
      'search': search.trim().isEmpty ? null : search.trim(),
      'page': page,
      'per_page': perPage,
    };
  }

  OmnichannelQueryModel copyWith({
    String? scope,
    String? channel,
    String? search,
    int? page,
    int? perPage,
  }) {
    return OmnichannelQueryModel(
      scope: scope ?? this.scope,
      channel: channel ?? this.channel,
      search: search ?? this.search,
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
    );
  }

  OmnichannelQueryModel nextPage() {
    return copyWith(page: page + 1);
  }

  OmnichannelQueryModel resetPage() {
    return copyWith(page: 1);
  }
}
