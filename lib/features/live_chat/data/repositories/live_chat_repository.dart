import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../auth/data/models/login_response_model.dart';
import '../../../auth/data/services/auth_api_service.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import '../models/customer_model.dart';
import '../models/poll_response_model.dart';
import '../services/live_chat_api_service.dart';

class StoredCustomerSession {
  const StoredCustomerSession({
    required this.deviceId,
    this.accessToken,
    this.tokenType,
    this.mobileUserId,
    this.displayName,
    this.email,
    this.activeConversationId,
  });

  final String deviceId;
  final String? accessToken;
  final String? tokenType;
  final String? mobileUserId;
  final String? displayName;
  final String? email;
  final int? activeConversationId;

  bool get hasProfile =>
      (displayName != null && displayName!.trim().isNotEmpty) ||
      (email != null && email!.trim().isNotEmpty);

  bool get hasAccessToken =>
      accessToken != null && accessToken!.trim().isNotEmpty;

  bool get hasMobileIdentity =>
      mobileUserId != null && mobileUserId!.trim().isNotEmpty;
}

class LiveChatRepository {
  LiveChatRepository({
    required AuthApiService authApiService,
    required LiveChatApiService liveChatApiService,
    required TokenStorage tokenStorage,
  }) : _authApiService = authApiService,
       _liveChatApiService = liveChatApiService,
       _tokenStorage = tokenStorage;

  final AuthApiService _authApiService;
  final LiveChatApiService _liveChatApiService;
  final TokenStorage _tokenStorage;

  Future<StoredCustomerSession> readStoredSession() async {
    return StoredCustomerSession(
      deviceId: await _tokenStorage.ensureDeviceId(),
      accessToken: await _tokenStorage.readAccessToken(),
      tokenType: await _tokenStorage.readTokenType(),
      mobileUserId: await _tokenStorage.readMobileUserId(),
      displayName: await _tokenStorage.readDisplayName(),
      email: await _tokenStorage.readEmail(),
      activeConversationId: await _tokenStorage.readActiveConversationId(),
    );
  }

  Future<LiveChatBootstrapModel?> restoreSession() async {
    final session = await readStoredSession();
    if (!session.hasAccessToken && !session.hasMobileIdentity) {
      return null;
    }

    return _withAuthorized<LiveChatBootstrapModel>((String accessToken) async {
      final results = await Future.wait<Object>(<Future<Object>>[
        _authApiService.me(accessToken: accessToken),
        _liveChatApiService.fetchConversations(accessToken: accessToken),
      ]);

      final customer = results[0] as CustomerModel;
      final response = results[1] as ConversationListResponseModel;
      final resolvedActiveConversationId = _resolveActiveConversationId(
        session.activeConversationId,
        response.conversations,
      );

      await _persistProfile(
        accessToken: accessToken,
        tokenType: 'Bearer',
        mobileUserId: customer.mobileUserId ?? session.mobileUserId,
        displayName: customer.name ?? customer.displayName,
        email: customer.email ?? session.email,
        activeConversationId: resolvedActiveConversationId,
      );

      return LiveChatBootstrapModel(
        customer: customer.exists ? customer : response.customer,
        conversations: response.conversations,
        pollIntervalMs: response.pollIntervalMs,
        activeConversationId: resolvedActiveConversationId,
      );
    });
  }

  Future<LiveChatBootstrapModel> loginOrRegister({
    required String displayName,
    String? email,
  }) async {
    final session = await readStoredSession();
    final mobileUserId =
        session.mobileUserId ?? await _tokenStorage.ensureMobileUserId();
    final normalizedEmail = email == null || email.trim().isEmpty
        ? null
        : email.trim();

    final authResponse = await _authApiService.register(
      deviceId: session.deviceId,
      displayName: displayName.trim(),
      email: normalizedEmail,
      mobileUserId: mobileUserId,
    );
    final conversationsResponse = await _liveChatApiService.fetchConversations(
      accessToken: authResponse.accessToken,
    );
    final resolvedActiveConversationId = _resolveActiveConversationId(
      session.activeConversationId,
      conversationsResponse.conversations,
    );

    await _persistProfile(
      accessToken: authResponse.accessToken,
      tokenType: authResponse.tokenType,
      mobileUserId: authResponse.customer.mobileUserId ?? mobileUserId,
      displayName: authResponse.customer.name ?? displayName,
      email: authResponse.customer.email ?? normalizedEmail,
      activeConversationId: resolvedActiveConversationId,
    );

    return LiveChatBootstrapModel(
      customer: authResponse.customer,
      conversations: conversationsResponse.conversations,
      pollIntervalMs: conversationsResponse.pollIntervalMs,
      activeConversationId: resolvedActiveConversationId,
    );
  }

  Future<ConversationListResponseModel> fetchConversations() async {
    return _withAuthorized<ConversationListResponseModel>((
      String accessToken,
    ) async {
      final results = await Future.wait<Object>(<Future<Object>>[
        _authApiService.me(accessToken: accessToken),
        _liveChatApiService.fetchConversations(accessToken: accessToken),
      ]);

      final customer = results[0] as CustomerModel;
      final response = results[1] as ConversationListResponseModel;

      await _persistProfile(
        accessToken: accessToken,
        tokenType: 'Bearer',
        mobileUserId: customer.mobileUserId,
        displayName: customer.name ?? customer.displayName,
        email: customer.email,
        activeConversationId: await _tokenStorage.readActiveConversationId(),
      );

      return ConversationListResponseModel(
        customer: customer.exists ? customer : response.customer,
        conversations: response.conversations,
        pollIntervalMs: response.pollIntervalMs,
      );
    });
  }

  Future<PollResponseModel> startConversation({
    String? openingMessage,
    String? clientMessageId,
  }) async {
    final response = await _withAuthorized<PollResponseModel>((
      String accessToken,
    ) {
      return _liveChatApiService.startConversation(
        accessToken: accessToken,
        openingMessage: openingMessage,
        clientMessageId: clientMessageId,
      );
    });

    await _tokenStorage.writeActiveConversationId(response.conversation.id);
    return response;
  }

  Future<PollResponseModel> getConversationMessages(int conversationId) {
    return _withAuthorized<PollResponseModel>((String accessToken) {
      return _liveChatApiService.getConversationMessages(
        accessToken: accessToken,
        conversationId: conversationId,
      );
    });
  }

  Future<PollResponseModel> pollConversation(
    int conversationId, {
    int? afterMessageId,
  }) {
    return _withAuthorized<PollResponseModel>((String accessToken) {
      return _liveChatApiService.pollConversation(
        accessToken: accessToken,
        conversationId: conversationId,
        afterMessageId: afterMessageId,
      );
    });
  }

  Future<SendMessageResponseModel> sendMessage(
    int conversationId, {
    required String message,
    required String clientMessageId,
  }) {
    return _withAuthorized<SendMessageResponseModel>((String accessToken) {
      return _liveChatApiService.sendMessage(
        accessToken: accessToken,
        conversationId: conversationId,
        message: message,
        clientMessageId: clientMessageId,
      );
    });
  }

  Future<ReadReceiptModel> markRead(
    int conversationId, {
    int? lastReadMessageId,
  }) {
    return _withAuthorized<ReadReceiptModel>((String accessToken) {
      return _liveChatApiService.markRead(
        accessToken: accessToken,
        conversationId: conversationId,
        lastReadMessageId: lastReadMessageId,
      );
    });
  }

  Future<void> saveActiveConversationId(int? conversationId) {
    return _tokenStorage.writeActiveConversationId(conversationId);
  }

  Future<void> clearProfile() {
    return _tokenStorage.clearProfile();
  }

  Future<T> _withAuthorized<T>(
    Future<T> Function(String accessToken) action,
  ) async {
    var accessToken = await _resolveAccessToken();

    try {
      return await action(accessToken);
    } on ApiException catch (error) {
      if (!error.isUnauthorized) {
        rethrow;
      }

      await _tokenStorage.clearAuth();
      accessToken = await _resolveAccessToken(forceRefresh: true);
      return action(accessToken);
    }
  }

  Future<String> _resolveAccessToken({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final existing = await _tokenStorage.readAccessToken();
      if (existing != null && existing.trim().isNotEmpty) {
        return existing.trim();
      }
    }

    return _reauthenticate();
  }

  Future<String> _reauthenticate() async {
    final session = await readStoredSession();
    final mobileUserId = session.mobileUserId?.trim();

    if (mobileUserId == null || mobileUserId.isEmpty) {
      throw StateError('Sesi mobile tidak tersedia. Silakan login kembali.');
    }

    final response = await _authApiService.login(
      mobileUserId: mobileUserId,
      deviceId: session.deviceId,
    );

    await _persistProfile(
      accessToken: response.accessToken,
      tokenType: response.tokenType,
      mobileUserId: response.customer.mobileUserId ?? mobileUserId,
      displayName:
          response.customer.name ??
          session.displayName ??
          response.customer.displayName,
      email: response.customer.email ?? session.email,
      activeConversationId: session.activeConversationId,
    );

    return response.accessToken;
  }

  Future<void> _persistProfile({
    required String accessToken,
    required String tokenType,
    String? mobileUserId,
    required String displayName,
    String? email,
    int? activeConversationId,
  }) async {
    await _tokenStorage.writeAccessToken(accessToken);
    await _tokenStorage.writeTokenType(tokenType);
    await _tokenStorage.writeMobileUserId(mobileUserId);
    await _tokenStorage.writeDisplayName(displayName);
    await _tokenStorage.writeEmail(email);
    await _tokenStorage.writeActiveConversationId(activeConversationId);
  }

  int? _resolveActiveConversationId(
    int? preferredConversationId,
    List<ConversationModel> conversations,
  ) {
    if (preferredConversationId != null &&
        conversations.any((item) => item.id == preferredConversationId)) {
      return preferredConversationId;
    }

    return conversations.isEmpty ? null : conversations.first.id;
  }
}
