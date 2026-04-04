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
    int? afterMessageId,
  }) {
    return _apiClient.get(
      ApiEndpoints.adminConversationPoll(conversationId),
      headers: _headers(accessToken),
      queryParameters: <String, Object?>{
        if (afterMessageId != null) 'after_message_id': afterMessageId,
      },
    );
  }

  Future<Map<String, dynamic>> startConversationCall({
    required String accessToken,
    required String conversationId,
    String callType = 'audio',
  }) {
    return _apiClient.post(
      ApiEndpoints.adminConversationCallStart(conversationId),
      headers: _headers(accessToken),
      body: <String, Object?>{'call_type': callType},
    );
  }

  Future<Map<String, dynamic>> acceptConversationCall({
    required String accessToken,
    required String conversationId,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminConversationCallAccept(conversationId),
      headers: _headers(accessToken),
      body: const <String, Object?>{},
    );
  }

  Future<Map<String, dynamic>> rejectConversationCall({
    required String accessToken,
    required String conversationId,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminConversationCallReject(conversationId),
      headers: _headers(accessToken),
      body: const <String, Object?>{},
    );
  }

  Future<Map<String, dynamic>> endConversationCall({
    required String accessToken,
    required String conversationId,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminConversationCallEnd(conversationId),
      headers: _headers(accessToken),
      body: const <String, Object?>{},
    );
  }

  Future<Map<String, dynamic>> fetchConversationCallStatus({
    required String accessToken,
    required String conversationId,
  }) {
    return _apiClient.get(
      ApiEndpoints.adminConversationCallStatus(conversationId),
      headers: _headers(accessToken),
    );
  }

  Future<Map<String, dynamic>> fetchCallReadiness({
    required String accessToken,
    bool forceRefresh = false,
  }) {
    final endpoint = forceRefresh
        ? '${ApiEndpoints.adminCallReadiness()}?force_refresh=1'
        : ApiEndpoints.adminCallReadiness();

    return _apiClient.get(endpoint, headers: _headers(accessToken));
  }

  Future<Map<String, dynamic>> clearCallReadinessCache({
    required String accessToken,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminCallReadinessClearCache(),
      headers: _headers(accessToken),
      body: const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> requestConversationCallPermission({
    required String accessToken,
    required String conversationId,
    String callType = 'audio',
  }) {
    return _apiClient.post(
      ApiEndpoints.adminConversationCallRequestPermission(conversationId),
      headers: _headers(accessToken),
      body: <String, Object?>{'call_type': callType},
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
      body: <String, Object?>{'message_type': 'text', 'message': message},
    );
  }

  Future<Map<String, dynamic>> sendAdminImageReply({
    required String accessToken,
    required int conversationId,
    required List<int> fileBytes,
    required String fileName,
    String? caption,
    String? mimeType,
  }) {
    final fields = <String, Object?>{
      'message_type': 'image',
      'caption': _normalizedNullableText(caption),
      'mime_type': _normalizedNullableText(mimeType),
    };

    return _apiClient.postMultipart(
      ApiEndpoints.adminConversationReply(conversationId),
      headers: _headers(accessToken),
      fields: fields,
      files: <ApiMultipartFile>[
        ApiMultipartFile(
          field: 'image_file',
          bytes: fileBytes,
          filename: fileName,
          contentType: mimeType,
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> sendAdminAudioReply({
    required String accessToken,
    required int conversationId,
    required List<int> fileBytes,
    required String fileName,
    String? mimeType,
    String? caption,
  }) {
    final normalizedMimeType = _normalizedNullableText(mimeType);

    final fields = <String, Object?>{
      'message_type': 'audio',
      'caption': _normalizedNullableText(caption),
      'voice': '1',
      'mime_type': normalizedMimeType,
    };

    return _apiClient.postMultipart(
      ApiEndpoints.adminConversationReply(conversationId),
      headers: _headers(accessToken),
      fields: fields,
      files: <ApiMultipartFile>[
        ApiMultipartFile(
          field: 'audio_file',
          bytes: fileBytes,
          filename: fileName,
          contentType: normalizedMimeType,
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

  Future<Map<String, dynamic>> fetchCallAnalyticsSummary({
    required String accessToken,
    Map<String, Object?> queryParameters = const <String, Object?>{},
  }) {
    return _apiClient.get(
      ApiEndpoints.adminCallAnalyticsSummary(),
      headers: _headers(accessToken),
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> fetchRecentCalls({
    required String accessToken,
    Map<String, Object?> queryParameters = const <String, Object?>{},
  }) {
    return _apiClient.get(
      ApiEndpoints.adminCallAnalyticsRecent(),
      headers: _headers(accessToken),
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> fetchConversationCallHistory({
    required String accessToken,
    required int conversationId,
    Map<String, Object?> queryParameters = const <String, Object?>{},
  }) {
    return _apiClient.get(
      ApiEndpoints.adminConversationCallHistory(conversationId),
      headers: _headers(accessToken),
      queryParameters: queryParameters,
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

  String? _normalizedNullableText(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
