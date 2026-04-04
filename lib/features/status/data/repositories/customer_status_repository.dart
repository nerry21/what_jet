import '../models/customer_status_group.dart';
import '../services/customer_status_api_service.dart';

class CustomerStatusRepository {
  const CustomerStatusRepository({
    required CustomerStatusApiService apiService,
    required Future<String> Function() readAccessToken,
  }) : _apiService = apiService,
       _readAccessToken = readAccessToken;

  final CustomerStatusApiService _apiService;
  final Future<String> Function() _readAccessToken;

  Future<List<CustomerStatusGroup>> loadFeed() async {
    final token = await _readAccessToken();
    final payload = await _apiService.fetchStatusFeed(accessToken: token);
    final items = payload['items'] as List<dynamic>? ?? const <dynamic>[];

    return items
        .whereType<Map>()
        .map(
          (Map item) => CustomerStatusGroup.fromJson(
            item.map(
              (Object? key, Object? value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> markViewed(int statusId) async {
    final token = await _readAccessToken();
    await _apiService.markViewed(accessToken: token, statusId: statusId);
  }
}
