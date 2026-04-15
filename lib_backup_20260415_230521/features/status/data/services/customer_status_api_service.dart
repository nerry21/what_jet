import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';

class CustomerStatusApiService {
  const CustomerStatusApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchStatusFeed({required String accessToken}) {
    return _apiClient.get(
      ApiEndpoints.customerStatusFeed(),
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );
  }

  Future<Map<String, dynamic>> markViewed({
    required String accessToken,
    required int statusId,
  }) {
    return _apiClient.post(
      ApiEndpoints.customerStatusMarkViewed(statusId),
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
      body: const <String, dynamic>{},
    );
  }
}
