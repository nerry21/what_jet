import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import '../models/poll_response_model.dart';

class LiveChatApiService {
  LiveChatApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<ConversationListResponseModel> fetchConversations({
    required String accessToken,
  }) async {
    final payload = await _apiClient.get(
      ApiEndpoints.conversations(),
      headers: _headers(accessToken),
    );

    return ConversationListResponseModel.fromJson(payload);
  }

  Future<PollResponseModel> startConversation({
    required String accessToken,
    String? openingMessage,
    String? clientMessageId,
  }) async {
    final payload = await _apiClient.post(
      ApiEndpoints.startConversation(),
      headers: _headers(accessToken),
      body: <String, Object?>{
        'source_app': AppConfig.sourceApp,
        'opening_message': _nullableString(openingMessage),
        'client_message_id': _nullableString(clientMessageId),
      },
    );

    return PollResponseModel.fromJson(payload);
  }

  Future<PollResponseModel> getConversationMessages({
    required String accessToken,
    required int conversationId,
  }) async {
    final payload = await _apiClient.get(
      ApiEndpoints.conversationMessages(conversationId),
      headers: _headers(accessToken),
    );

    return PollResponseModel.fromJson(payload);
  }

  Future<PollResponseModel> pollConversation({
    required String accessToken,
    required int conversationId,
    int? afterMessageId,
  }) async {
    final payload = await _apiClient.get(
      ApiEndpoints.pollConversation(conversationId),
      headers: _headers(accessToken),
      queryParameters: <String, Object?>{'after_message_id': afterMessageId},
    );

    return PollResponseModel.fromJson(payload);
  }

  Future<SendMessageResponseModel> sendMessage({
    required String accessToken,
    required int conversationId,
    required String message,
    required String clientMessageId,
  }) async {
    final payload = await _apiClient.post(
      ApiEndpoints.sendMessage(conversationId),
      headers: _headers(accessToken),
      body: <String, Object?>{
        'message': message.trim(),
        'client_message_id': clientMessageId.trim(),
      },
    );

    return SendMessageResponseModel.fromJson(payload);
  }

  Future<ReadReceiptModel> markRead({
    required String accessToken,
    required int conversationId,
    int? lastReadMessageId,
  }) async {
    final payload = await _apiClient.post(
      ApiEndpoints.markRead(conversationId),
      headers: _headers(accessToken),
      body: <String, Object?>{'last_read_message_id': lastReadMessageId},
    );

    return ReadReceiptModel.fromJson(payload);
  }

  Map<String, String> _headers(String accessToken) {
    return <String, String>{'Authorization': 'Bearer $accessToken'};
  }
}

String? _nullableString(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}
