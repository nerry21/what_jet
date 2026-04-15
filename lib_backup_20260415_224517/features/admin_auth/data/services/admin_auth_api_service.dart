import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/admin_auth_session_model.dart';
import '../models/admin_user_model.dart';

class AdminAuthApiService {
  AdminAuthApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<AdminAuthSessionModel> login({
    required String email,
    required String password,
  }) async {
    final payload = await _apiClient.post(
      ApiEndpoints.adminLogin(),
      body: <String, Object?>{'email': email.trim(), 'password': password},
    );

    return AdminAuthSessionModel.fromJson(payload);
  }

  Future<AdminUserModel> me({required String accessToken}) async {
    final payload = await _apiClient.get(
      ApiEndpoints.adminMe(),
      headers: _headers(accessToken),
    );

    return AdminUserModel.fromJson(_resolveUserPayload(payload));
  }

  Future<void> logout({required String accessToken}) async {
    await _apiClient.post(
      ApiEndpoints.adminLogout(),
      headers: _headers(accessToken),
    );
  }

  Map<String, String> _headers(String accessToken) {
    return <String, String>{'Authorization': 'Bearer $accessToken'};
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
