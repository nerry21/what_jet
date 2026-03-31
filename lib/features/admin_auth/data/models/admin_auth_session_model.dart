import 'admin_user_model.dart';

class AdminAuthSessionModel {
  const AdminAuthSessionModel({
    required this.user,
    required this.accessToken,
    this.tokenType = 'Bearer',
  });

  final AdminUserModel user;
  final String accessToken;
  final String tokenType;

  factory AdminAuthSessionModel.fromJson(Map<String, dynamic> json) {
    final userPayload = _resolveUserPayload(json);

    return AdminAuthSessionModel(
      user: AdminUserModel.fromJson(userPayload),
      accessToken: _nullableString(json['access_token']) ?? '',
      tokenType: _nullableString(json['token_type']) ?? 'Bearer',
    );
  }
}

Map<String, dynamic> _resolveUserPayload(Map<String, dynamic> json) {
  final candidates = <Object?>[json['user'], json['admin'], json['profile']];

  for (final candidate in candidates) {
    if (candidate is Map<String, dynamic>) {
      return candidate;
    }
  }

  return json;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
