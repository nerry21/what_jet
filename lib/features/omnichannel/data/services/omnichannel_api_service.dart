import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';

class OmnichannelApiService {
  OmnichannelApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchWorkspace({required String accessToken}) {
    return _apiClient.get(
      ApiEndpoints.adminWorkspace(),
      headers: _headers(accessToken),
    );
  }

  Future<Map<String, dynamic>> fetchConversations({
    required String accessToken,
    Map<String, Object?> queryParameters = const <String, Object?>{},
  }) {
    return _apiClient.get(
      ApiEndpoints.adminConversations(),
      headers: _headers(accessToken),
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> fetchConversationDetail({
    required String accessToken,
    required int conversationId,
  }) {
    return _apiClient.get(
      ApiEndpoints.adminConversationDetail(conversationId),
      headers: _headers(accessToken),
    );
  }

  Future<Map<String, dynamic>> fetchThread({
    required String accessToken,
    required int conversationId,
  }) {
    return _apiClient.get(
      ApiEndpoints.adminConversationMessages(conversationId),
      headers: _headers(accessToken),
    );
  }

  Future<Map<String, dynamic>> fetchConversationPoll({
    required String accessToken,
    required int conversationId,
  }) {
    return _apiClient.get(
      ApiEndpoints.adminConversationPoll(conversationId),
      headers: _headers(accessToken),
    );
  }

  Future<Map<String, dynamic>> sendAdminReply({
    required String accessToken,
    required int conversationId,
    required String message,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminConversationReply(conversationId),
      headers: _headers(accessToken),
      body: <String, Object?>{'message': message},
    );
  }

  Future<Map<String, dynamic>> sendAdminImageReply({
    required String accessToken,
    required int conversationId,
    required List<int> fileBytes,
    required String fileName,
    String? caption,
  }) {
    return _apiClient.postMultipart(
      ApiEndpoints.adminConversationReply(conversationId),
      headers: _headers(accessToken),
      fields: <String, Object?>{'message_type': 'image', 'caption': caption},
      files: <ApiMultipartFile>[
        ApiMultipartFile(
          field: 'image_file',
          bytes: fileBytes,
          filename: fileName,
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> sendAdminContact({
    required String accessToken,
    required int conversationId,
    required String fullName,
    required String phone,
    String? email,
    String? company,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminConversationSendContact(conversationId),
      headers: _headers(accessToken),
      body: <String, Object?>{
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'company': company,
      },
    );
  }

  Future<Map<String, dynamic>> fetchBotControlStatus({
    required String accessToken,
    required int conversationId,
  }) {
    return _apiClient.get(
      ApiEndpoints.adminConversationBotControl(conversationId),
      headers: _headers(accessToken),
    );
  }

  Future<Map<String, dynamic>> turnBotOn({
    required String accessToken,
    required int conversationId,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminConversationBotOn(conversationId),
      headers: _headers(accessToken),
      body: const <String, Object?>{},
    );
  }

  Future<Map<String, dynamic>> turnBotOff({
    required String accessToken,
    required int conversationId,
    int autoResumeMinutes = 15,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminConversationBotOff(conversationId),
      headers: _headers(accessToken),
      body: <String, Object?>{'auto_resume_minutes': autoResumeMinutes},
    );
  }

  Future<Map<String, dynamic>> fetchPollList({
    required String accessToken,
    Map<String, Object?> queryParameters = const <String, Object?>{},
  }) {
    return _apiClient.get(
      ApiEndpoints.adminPollList(),
      headers: _headers(accessToken),
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> fetchDashboardSummary({
    required String accessToken,
  }) {
    return _apiClient.get(
      ApiEndpoints.adminDashboardSummary(),
      headers: _headers(accessToken),
    );
  }

  Future<Map<String, dynamic>> fetchMetaFilters({required String accessToken}) {
    return _apiClient.get(
      ApiEndpoints.adminMetaFilters(),
      headers: _headers(accessToken),
    );
  }

  Map<String, String> _headers(String accessToken) {
    return <String, String>{'Authorization': 'Bearer $accessToken'};
  }
}
