import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/data/models/login_response_model.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/customer_model.dart';
import '../../data/repositories/live_chat_repository.dart';

class LiveChatController extends ChangeNotifier {
  LiveChatController({required LiveChatRepository repository})
    : _repository = repository;

  final LiveChatRepository _repository;

  bool _isInitializing = false;
  bool _isRefreshing = false;
  bool _isAuthenticating = false;
  bool _requiresProfile = false;
  bool _isUnauthorized = false;
  bool _isOffline = false;
  String? _errorMessage;
  String _searchQuery = '';
  CustomerModel? _customer;
  List<ConversationModel> _conversations = <ConversationModel>[];
  int? _selectedConversationId;
  int _pollIntervalMs = 3000;

  bool get isInitializing => _isInitializing;
  bool get isRefreshing => _isRefreshing;
  bool get isAuthenticating => _isAuthenticating;
  bool get requiresProfile => _requiresProfile;
  bool get isUnauthorized => _isUnauthorized;
  bool get isOffline => _isOffline;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  CustomerModel? get customer => _customer;
  List<ConversationModel> get conversations =>
      List<ConversationModel>.unmodifiable(_conversations);
  int? get selectedConversationId => _selectedConversationId;
  int get pollIntervalMs => _pollIntervalMs;

  List<ConversationModel> get filteredConversations {
    final search = _searchQuery.trim().toLowerCase();
    if (search.isEmpty) {
      return conversations;
    }

    return _conversations.where((conversation) {
      final preview = conversation.latestMessagePreview?.toLowerCase() ?? '';
      final status = conversation.operationalModeLabel.toLowerCase();
      final customerName = conversation.customer.displayName.toLowerCase();
      final sourceLabel = conversation.sourceLabel?.toLowerCase() ?? '';

      return preview.contains(search) ||
          status.contains(search) ||
          customerName.contains(search) ||
          sourceLabel.contains(search) ||
          conversation.channelLabel.toLowerCase().contains(search);
    }).toList();
  }

  Future<void> initialize() async {
    if (_isInitializing) {
      return;
    }

    _isInitializing = true;
    _resetTransientErrors();
    notifyListeners();

    try {
      final restored = await _repository.restoreSession();
      final response = restored ?? await _bootstrapGuestSession();
      _applyBootstrapResponse(response);
    } catch (error) {
      _applyError(error, allowShellFallback: _customer != null);
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> loginOrRegister({
    required String displayName,
    String? email,
  }) async {
    _isAuthenticating = true;
    _resetTransientErrors();
    notifyListeners();

    try {
      final response = await _repository.loginOrRegister(
        displayName: displayName,
        email: email,
      );
      _applyBootstrapResponse(response);
      return true;
    } catch (error) {
      _applyError(error, allowShellFallback: false);
      return false;
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;
    _resetTransientErrors();
    notifyListeners();

    try {
      final response = await _repository.fetchConversations();
      _customer = response.customer.exists ? response.customer : _customer;
      _conversations = _sortConversations(response.conversations);
      _pollIntervalMs = response.pollIntervalMs;

      if (_selectedConversationId != null &&
          _conversations.every(
            (conversation) => conversation.id != _selectedConversationId,
          )) {
        _selectedConversationId = null;
      }

      if (_selectedConversationId == null && _conversations.isNotEmpty) {
        _selectedConversationId = _conversations.first.id;
      }
    } catch (error) {
      if (_looksUnauthorized(error)) {
        await reconnectSession(clearSession: true);
        return;
      }

      _applyError(error, allowShellFallback: true);
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<ConversationModel?> startConversation({
    String? openingMessage,
    String? clientMessageId,
  }) async {
    _resetTransientErrors();
    notifyListeners();

    try {
      final response = await _repository.startConversation(
        openingMessage: openingMessage,
        clientMessageId: clientMessageId,
      );

      updateConversation(response.conversation);
      selectConversation(response.conversation.id);
      return response.conversation;
    } catch (error) {
      if (_looksUnauthorized(error)) {
        await reconnectSession(clearSession: true);
      } else {
        _applyError(error, allowShellFallback: true);
        notifyListeners();
      }
      return null;
    }
  }

  Future<void> reconnectSession({bool clearSession = false}) async {
    if (_isInitializing || _isAuthenticating) {
      return;
    }

    _isInitializing = true;
    _resetTransientErrors();
    notifyListeners();

    try {
      if (clearSession) {
        await _repository.clearProfile();
      }

      final response = await _bootstrapGuestSession();
      _applyBootstrapResponse(response);
    } catch (error) {
      _applyError(error, allowShellFallback: false);
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void selectConversation(int? conversationId) {
    _selectedConversationId = conversationId;
    _repository.saveActiveConversationId(conversationId);
    notifyListeners();
  }

  void updateConversation(ConversationModel conversation) {
    final index = _conversations.indexWhere(
      (item) => item.id == conversation.id,
    );

    if (index >= 0) {
      _conversations[index] = conversation;
    } else {
      _conversations.add(conversation);
    }

    _conversations = _sortConversations(_conversations);
    _selectedConversationId ??= conversation.id;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _isOffline = false;
    _isUnauthorized = false;
    notifyListeners();
  }

  ConversationModel? conversationById(int? conversationId) {
    if (conversationId == null) {
      return null;
    }

    for (final conversation in _conversations) {
      if (conversation.id == conversationId) {
        return conversation;
      }
    }

    return null;
  }

  Future<void> resetProfile() {
    return reconnectSession(clearSession: true);
  }

  void _applyBootstrapResponse(LiveChatBootstrapModel response) {
    _customer = response.customer;
    _conversations = _sortConversations(response.conversations);
    _pollIntervalMs = response.pollIntervalMs;
    _selectedConversationId =
        response.activeConversationId ?? _conversations.firstOrNull?.id;
    _requiresProfile = false;
    _resetTransientErrors();
  }

  Future<LiveChatBootstrapModel> _bootstrapGuestSession() {
    return _repository.loginOrRegister(displayName: AppConfig.guestDisplayName);
  }

  void _applyError(Object error, {required bool allowShellFallback}) {
    _errorMessage = _friendlyMessage(error);
    _isUnauthorized = _looksUnauthorized(error);
    _isOffline = _looksOffline(error);
    _requiresProfile = false;

    if (allowShellFallback && _customer == null) {
      _customer = const CustomerModel.empty();
    }
  }

  void _resetTransientErrors() {
    _errorMessage = null;
    _isUnauthorized = false;
    _isOffline = false;
  }

  List<ConversationModel> _sortConversations(
    List<ConversationModel> conversations,
  ) {
    final sorted = List<ConversationModel>.from(conversations);
    sorted.sort((left, right) {
      final leftTime = left.lastMessageAt?.millisecondsSinceEpoch ?? 0;
      final rightTime = right.lastMessageAt?.millisecondsSinceEpoch ?? 0;
      return rightTime.compareTo(leftTime);
    });
    return sorted;
  }

  bool _looksUnauthorized(Object error) {
    if (error is ApiException) {
      return error.isUnauthorized;
    }

    final text = error.toString().toLowerCase();
    return text.contains('unauth') ||
        text.contains('login kembali') ||
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
      return 'Sesi live chat terputus. Menyiapkan sesi baru...';
    }

    if (_looksOffline(error)) {
      return 'Perangkat sedang offline atau server tidak bisa dijangkau.';
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

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
