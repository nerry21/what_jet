import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../live_chat/data/models/customer_model.dart';
import '../models/login_response_model.dart';

class AuthApiService {
  AuthApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<LoginResponseModel> register({
    required String deviceId,
    required String displayName,
    String? email,
    String? mobileUserId,
  }) async {
    final payload = await _apiClient.post(
      ApiEndpoints.register(),
      body: <String, Object?>{
        'device_id': deviceId,
        'name': displayName.trim(),
        'email': _nullableString(email),
        'mobile_user_id': _nullableString(mobileUserId),
        'preferred_channel': AppConfig.preferredChannel,
      },
    );

    return LoginResponseModel.fromJson(payload);
  }

  Future<LoginResponseModel> login({
    required String mobileUserId,
    required String deviceId,
  }) async {
    final payload = await _apiClient.post(
      ApiEndpoints.login(),
      body: <String, Object?>{
        'mobile_user_id': mobileUserId.trim(),
        'device_id': deviceId.trim(),
      },
    );

    return LoginResponseModel.fromJson(payload);
  }

  Future<CustomerModel> me({required String accessToken}) async {
    final payload = await _apiClient.get(
      ApiEndpoints.me(),
      headers: _headers(accessToken),
    );

    return CustomerModel.fromJson(
      (payload['customer'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
    );
  }

  Future<void> logout({required String accessToken}) async {
    await _apiClient.post(
      ApiEndpoints.logout(),
      headers: _headers(accessToken),
    );
  }

  Map<String, String> _headers(String accessToken) {
    return <String, String>{'Authorization': 'Bearer $accessToken'};
  }
}

String? _nullableString(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}
