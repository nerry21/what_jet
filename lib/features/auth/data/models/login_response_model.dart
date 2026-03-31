import '../../../live_chat/data/models/conversation_model.dart';
import '../../../live_chat/data/models/customer_model.dart';

class LoginResponseModel {
  const LoginResponseModel({
    required this.customer,
    required this.accessToken,
    this.tokenType = 'Bearer',
  });

  final CustomerModel customer;
  final String accessToken;
  final String tokenType;

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      customer: CustomerModel.fromJson(
        (json['customer'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      accessToken: _nullableString(json['access_token']) ?? '',
      tokenType: _nullableString(json['token_type']) ?? 'Bearer',
    );
  }

  LoginResponseModel copyWith({
    CustomerModel? customer,
    String? accessToken,
    String? tokenType,
  }) {
    return LoginResponseModel(
      customer: customer ?? this.customer,
      accessToken: accessToken ?? this.accessToken,
      tokenType: tokenType ?? this.tokenType,
    );
  }
}

class LiveChatBootstrapModel {
  const LiveChatBootstrapModel({
    required this.customer,
    required this.conversations,
    required this.pollIntervalMs,
    this.activeConversationId,
  });

  final CustomerModel customer;
  final List<ConversationModel> conversations;
  final int pollIntervalMs;
  final int? activeConversationId;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
