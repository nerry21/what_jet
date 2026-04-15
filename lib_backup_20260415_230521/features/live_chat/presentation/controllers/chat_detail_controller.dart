import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/poll_response_model.dart';
import '../../data/repositories/live_chat_repository.dart';

class ChatDetailController extends ChangeNotifier {
  ChatDetailController({
    required LiveChatRepository repository,
    required int conversationId,
    ConversationModel? initialConversation,
    int? initialPollIntervalMs,
    this.onConversationChanged,
  }) : _repository = repository,
       _conversationId = conversationId,
       _conversation = initialConversation,
       _pollIntervalMs =
           initialPollIntervalMs ??
           AppConfig.defaultPollingInterval.inMilliseconds;

  final LiveChatRepository _repository;
  final int _conversationId;
  final ValueChanged<ConversationModel>? onConversationChanged;

  ConversationModel? _conversation;
  final List<ChatMessageModel> _messages = <ChatMessageModel>[];
  Timer? _pollingTimer;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isPolling = false;
  bool _isMarkingRead = false;
  bool _isUnauthorized = false;
  bool _isOffline = false;
  String? _errorMessage;
  String? _connectionMessage;
  int _pollIntervalMs;

  ConversationModel? get conversation => _conversation;

  List<ChatMessageModel> get messages =>
      List<ChatMessageModel>.unmodifiable(_messages);

  bool get isLoading => _isLoading;

  bool get isRefreshing => _isRefreshing;

  bool get isPolling => _isPolling;

  bool get isMarkingRead => _isMarkingRead;

  bool get isUnauthorized => _isUnauthorized;

  bool get isOffline => _isOffline;

  bool get hasMessages => _messages.isNotEmpty;

  bool get isComposerBusy =>
      _messages.any((message) => message.isMine && message.isSending);

  String? get errorMessage => _errorMessage;

  String? get connectionMessage => _connectionMessage;

  int get conversationId => _conversationId;

  Future<void> initialize() async {
    await load();
    if (!_isUnauthorized) {
      _restartPolling();
    }
  }

  Future<void> load() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _clearErrors();
    notifyListeners();

    try {
      final response = await _repository.getConversationMessages(
        _conversationId,
      );
      _applyPollResponse(response);
      _restartPolling();
      await markRead();
    } catch (error) {
      _applyError(error, fromPolling: false);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;
    _clearErrors();
    notifyListeners();

    try {
      final response = await _repository.getConversationMessages(
        _conversationId,
      );
      _applyPollResponse(response);
      _restartPolling();
      await markRead();
    } catch (error) {
      _applyError(error, fromPolling: false);
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> poll() async {
    if (_isPolling || _isLoading || _isUnauthorized) {
      return;
    }

    _isPolling = true;

    try {
      final response = await _repository.pollConversation(
        _conversationId,
        afterMessageId: _latestServerMessageId,
      );
      _applyPollResponse(response);
      _connectionMessage = null;
      _isOffline = false;
      _restartPolling();
      notifyListeners();

      if (response.messages.isNotEmpty || response.unreadCount > 0) {
        await markRead();
      }
    } catch (error) {
      _applyError(error, fromPolling: true);
      if (_isOffline) {
        _restartPolling(
          intervalMs: AppConfig.reconnectPollingInterval.inMilliseconds,
        );
      }
    } finally {
      _isPolling = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(
    String text, {
    ChatMessageModel? retryingMessage,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _conversation == null || _isUnauthorized) {
      return;
    }

    final clientMessageId =
        retryingMessage?.clientMessageId ?? _buildClientMessageId();
    final localId = retryingMessage?.localId ?? _buildLocalMessageId();

    final optimistic = ChatMessageModel.optimistic(
      localId: localId,
      conversationId: _conversation!.id,
      text: trimmed,
      clientMessageId: clientMessageId,
    );

    _upsertMessage(optimistic);
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _repository.sendMessage(
        _conversationId,
        message: trimmed,
        clientMessageId: clientMessageId,
      );

      _replaceOptimisticMessage(
        clientMessageId: clientMessageId,
        incoming: response.message,
      );
      _applyConversation(response.conversation);
      _pollIntervalMs = response.pollIntervalMs;
      _isOffline = false;
      _isUnauthorized = false;
      _connectionMessage = null;
      _restartPolling();
      notifyListeners();
    } catch (error) {
      final message = _friendlyMessage(error);
      _markMessageFailed(clientMessageId, message);
      _applyError(error, fromPolling: false, overrideMessage: message);
      notifyListeners();
    }
  }

  Future<void> retryMessage(ChatMessageModel message) {
    return sendMessage(
      message.text,
      retryingMessage: message.copyWith(
        localState: ChatMessageLocalState.sending,
        deliveryStatus: 'pending',
        deliveryError: null,
      ),
    );
  }

  Future<void> markRead() async {
    final latestReadableMessageId = _latestReadableMessageId;
    if (latestReadableMessageId == null || _isMarkingRead || _isUnauthorized) {
      return;
    }

    _isMarkingRead = true;

    try {
      final response = await _repository.markRead(
        _conversationId,
        lastReadMessageId: latestReadableMessageId,
      );

      _applyConversation(response.conversation);
      final readAt = response.conversation.lastReadAtCustomer ?? DateTime.now();

      for (var index = 0; index < _messages.length; index++) {
        final message = _messages[index];
        if (!message.isMine &&
            message.id != null &&
            message.id! <= latestReadableMessageId) {
          _messages[index] = message.copyWith(readAt: readAt);
        }
      }
    } catch (_) {
      // mark-read failure should not break reading flow
    } finally {
      _isMarkingRead = false;
      notifyListeners();
    }
  }

  void disposePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void dispose() {
    disposePolling();
    super.dispose();
  }

  void _applyPollResponse(PollResponseModel response) {
    _pollIntervalMs = response.pollIntervalMs;
    _applyConversation(response.conversation);
    _errorMessage = null;
    _isUnauthorized = false;
    _isOffline = false;

    for (final message in response.messages) {
      _upsertMessage(message);
    }

    if (response.submittedMessage != null) {
      _upsertMessage(response.submittedMessage!);
    }
  }

  void _applyConversation(ConversationModel conversation) {
    _conversation = conversation;
    onConversationChanged?.call(conversation);
  }

  void _upsertMessage(ChatMessageModel incoming) {
    final index = _messages.indexWhere(
      (existing) => existing.matches(incoming),
    );

    if (index >= 0) {
      _messages[index] = incoming;
    } else {
      _messages.add(incoming);
    }

    _messages.sort((left, right) {
      final byTime = left.sentAt.compareTo(right.sentAt);
      if (byTime != 0) {
        return byTime;
      }
      final leftId = left.id ?? 0;
      final rightId = right.id ?? 0;
      return leftId.compareTo(rightId);
    });
  }

  void _replaceOptimisticMessage({
    required String clientMessageId,
    required ChatMessageModel incoming,
  }) {
    final index = _messages.indexWhere(
      (message) => message.clientMessageId == clientMessageId,
    );

    if (index >= 0) {
      _messages[index] = incoming;
    } else {
      _upsertMessage(incoming);
      return;
    }

    _messages.sort((left, right) => left.sentAt.compareTo(right.sentAt));
  }

  void _markMessageFailed(String clientMessageId, String deliveryError) {
    final index = _messages.indexWhere(
      (message) => message.clientMessageId == clientMessageId,
    );

    if (index < 0) {
      return;
    }

    final current = _messages[index];
    _messages[index] = current.copyWith(
      deliveryStatus: 'failed',
      deliveryError: deliveryError,
      localState: ChatMessageLocalState.failed,
    );
  }

  void _restartPolling({int? intervalMs}) {
    if (_isUnauthorized) {
      disposePolling();
      return;
    }

    disposePolling();
    final resolvedIntervalMs = max(2000, intervalMs ?? _pollIntervalMs);

    _pollingTimer = Timer.periodic(
      Duration(milliseconds: resolvedIntervalMs),
      (_) => unawaited(poll()),
    );
  }

  void _clearErrors() {
    _errorMessage = null;
    _connectionMessage = null;
    _isUnauthorized = false;
    _isOffline = false;
  }

  void _applyError(
    Object error, {
    required bool fromPolling,
    String? overrideMessage,
  }) {
    final message = overrideMessage ?? _friendlyMessage(error);
    _isUnauthorized = _looksUnauthorized(error);
    _isOffline = _looksOffline(error);

    if (_isUnauthorized) {
      _errorMessage = message;
      _connectionMessage = null;
      disposePolling();
      return;
    }

    if (fromPolling) {
      _connectionMessage = message;
      return;
    }

    _errorMessage = message;
    if (_isOffline) {
      _connectionMessage = message;
    }
  }

  int? get _latestServerMessageId {
    int? latestId;
    for (final message in _messages) {
      if (message.id == null) {
        continue;
      }

      if (latestId == null || message.id! > latestId) {
        latestId = message.id;
      }
    }
    return latestId;
  }

  int? get _latestReadableMessageId {
    int? latestId;
    for (final message in _messages) {
      if (message.isMine || message.id == null) {
        continue;
      }

      if (latestId == null || message.id! > latestId) {
        latestId = message.id;
      }
    }
    return latestId;
  }

  String _buildClientMessageId() {
    final random = Random.secure();
    final nonce = List<int>.generate(
      4,
      (_) => random.nextInt(255),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return 'msg-${DateTime.now().microsecondsSinceEpoch}-$nonce';
  }

  String _buildLocalMessageId() {
    return 'local-${DateTime.now().microsecondsSinceEpoch}';
  }

  bool _looksUnauthorized(Object error) {
    if (error is ApiException) {
      return error.isUnauthorized;
    }

    final text = error.toString().toLowerCase();
    return text.contains('unauth') ||
        text.contains('login ulang') ||
        text.contains('sesi mobile');
  }

  bool _looksOffline(Object error) {
    if (error is ApiException) {
      return error.isOffline;
    }

    final text = error.toString().toLowerCase();
    return text.contains('koneksi') ||
        text.contains('socket') ||
        text.contains('network');
  }

  String _friendlyMessage(Object error) {
    if (_looksUnauthorized(error)) {
      return 'Sesi mobile berakhir. Silakan kembali dan login ulang.';
    }

    if (_looksOffline(error)) {
      return 'Koneksi ke server terputus. Coba lagi sebentar lagi.';
    }

    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }

    if (text.startsWith('ApiException')) {
      final separatorIndex = text.indexOf(': ');
      if (separatorIndex >= 0 && separatorIndex + 2 < text.length) {
        return text.substring(separatorIndex + 2);
      }
    }

    return text.replaceFirst('Bad state: ', '');
  }
}
