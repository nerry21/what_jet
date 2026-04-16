import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../admin_auth/data/models/admin_user_model.dart';
import '../../../admin_auth/data/repositories/admin_auth_repository.dart';
import '../../data/models/omnichannel_conversation_detail_model.dart';
import '../../data/models/omnichannel_conversation_list_model.dart';
import '../../data/models/omnichannel_insight_model.dart';
import '../../data/models/omnichannel_query_model.dart';
import '../../data/models/omnichannel_shell_snapshot_model.dart';
import '../../data/models/omnichannel_thread_model.dart';
import '../../data/models/omnichannel_workspace_model.dart';
import '../../data/repositories/omnichannel_repository.dart';

/// Event yang dipancarkan saat ada pesan masuk baru terdeteksi via polling.
/// Digunakan untuk memicu in-app notification di UI layer.
class ChatNotificationEvent {
  const ChatNotificationEvent({
    required this.conversationId,
    required this.senderName,
    required this.preview,
    required this.totalNewCount,
    required this.affectedConversationIds,
  });

  final int conversationId;
  final String senderName;
  final String preview;
  final int totalNewCount;
  final List<int> affectedConversationIds;
}

typedef ChatNotificationListener = void Function(ChatNotificationEvent event);

class OmnichannelShellController extends ChangeNotifier {
  OmnichannelShellController({
    required OmnichannelRepository repository,
    required AdminAuthRepository adminAuthRepository,
  }) : _repository = repository,
       _adminAuthRepository = adminAuthRepository;

  final OmnichannelRepository _repository;
  final AdminAuthRepository _adminAuthRepository;

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoggingOut = false;
  bool _isConversationLoading = false;
  bool _isLoadingMore = false;
  bool _isPollingList = false;
  bool _isPollingConversation = false;
  bool _requiresLogin = false;
  bool _isPageActive = true;
  String? _errorMessage;
  AdminUserModel? _currentUser;
  OmnichannelWorkspaceModel? _workspace;
  OmnichannelConversationListModel? _conversationList;
  OmnichannelConversationDetailModel? _selectedConversation;
  List<OmnichannelThreadGroupModel> _threadGroups =
      const <OmnichannelThreadGroupModel>[];
  OmnichannelInsightModel _insight = OmnichannelInsightModel.empty();
  OmnichannelQueryModel _query = const OmnichannelQueryModel();
  Timer? _searchDebounce;
  Timer? _listPollingTimer;
  Timer? _conversationPollingTimer;
  int _selectionVersion = 0;

  // ─── Chat notification (in-app banner) ─────────────────────────────────
  final List<ChatNotificationListener> _notificationListeners =
      <ChatNotificationListener>[];

  void addChatNotificationListener(ChatNotificationListener listener) {
    if (!_notificationListeners.contains(listener)) {
      _notificationListeners.add(listener);
    }
  }

  void removeChatNotificationListener(ChatNotificationListener listener) {
    _notificationListeners.remove(listener);
  }

  void _emitChatNotification(ChatNotificationEvent event) {
    for (final listener in List<ChatNotificationListener>.from(
      _notificationListeners,
    )) {
      try {
        listener(event);
      } catch (_) {}
    }
  }

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isLoggingOut => _isLoggingOut;
  bool get isConversationLoading => _isConversationLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isPollingList => _isPollingList;
  bool get isPollingConversation => _isPollingConversation;
  bool get requiresLogin => _requiresLogin;
  String? get errorMessage => _errorMessage;
  AdminUserModel? get currentUser => _currentUser;
  OmnichannelWorkspaceModel? get workspace => _workspace;
  OmnichannelConversationListModel? get conversationList => _conversationList;
  OmnichannelConversationDetailModel? get selectedConversation =>
      _selectedConversation;
  List<OmnichannelThreadGroupModel> get threadGroups =>
      List<OmnichannelThreadGroupModel>.unmodifiable(_threadGroups);
  OmnichannelInsightModel get insight => _insight;
  String get scopeFilter => _query.scope;
  String get channelFilter => _query.channel;
  String get searchQuery => _query.search;

  bool get hasShellData => _workspace != null && _conversationList != null;
  bool get hasMoreConversations => _conversationList?.hasMore == true;

  int? get selectedConversationId =>
      _conversationList?.selectedConversationId ?? _selectedConversation?.id;

  /// Increments each time a conversation is (re)selected — useful for
  /// widgets that need to react to selection events even when the ID is
  /// the same (e.g. to scroll to the bottom again).
  int get selectionVersion => _selectionVersion;

  Future<void> initialize({AdminUserModel? initialUser}) async {
    if (_isLoading) {
      return;
    }

    _cancelAllPolling();
    _isLoading = true;
    _requiresLogin = false;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = initialUser ?? await _adminAuthRepository.restoreSession();
      if (_currentUser == null) {
        _requiresLogin = true;
        return;
      }

      final shell = await _repository.loadShell(
        query: _query,
        preferredConversationId: selectedConversationId,
      );
      _applyShellSnapshot(shell);

      final nextConversationId = shell.conversationList.selectedConversationId;
      if (nextConversationId != null) {
        await _loadSelectedConversation(
          nextConversationId,
          notify: false,
          incrementSelectionVersion: true,
        );
      } else {
        _clearConversationSelection();
      }
    } catch (error) {
      _applyError(error);
    } finally {
      _isLoading = false;
      _restartPolling();
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_isLoading ||
        _isRefreshing ||
        _isLoadingMore ||
        _isPollingList ||
        _isPollingConversation) {
      return;
    }

    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final shell = await _repository.loadShell(
        query: _query,
        preferredConversationId: selectedConversationId,
      );
      _applyShellSnapshot(shell);

      final nextConversationId = shell.conversationList.selectedConversationId;
      if (nextConversationId != null) {
        final shouldReloadConversation =
            _selectedConversation?.id != nextConversationId;
        if (shouldReloadConversation) {
          _clearConversationSelection();
        }
        await _loadSelectedConversation(
          nextConversationId,
          notify: false,
          incrementSelectionVersion: shouldReloadConversation,
        );
      } else {
        _clearConversationSelection();
      }
    } catch (error) {
      _applyError(error);
    } finally {
      _isRefreshing = false;
      _restartPolling();
      notifyListeners();
    }
  }

  Future<void> loadMoreConversations() async {
    final currentList = _conversationList;
    if (_isLoading ||
        _isRefreshing ||
        _isLoadingMore ||
        _isPollingList ||
        _isLoggingOut ||
        !_isPageActive ||
        _requiresLogin ||
        currentList == null ||
        !currentList.hasMore) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextQuery = _query.copyWith(
        page: (_conversationList?.page ?? 1) + 1,
      );
      final nextPage = await _repository.loadConversationPage(
        query: nextQuery,
        preferredConversationId: selectedConversationId,
      );
      _conversationList = currentList.appendPage(nextPage);
    } catch (error) {
      _applyError(error);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> selectConversation(
    int conversationId, {
    bool notify = true,
  }) async {
    if (_isLoading || _isRefreshing || _isLoggingOut || _requiresLogin) {
      return;
    }

    // Instantly clear unread count for tapped conversation (visual mark-as-read)
    _clearUnreadForConversation(conversationId);

    // Fire-and-forget: tell backend the conversation has been read so
    // subsequent polls won't re-populate the unread badge.
    unawaited(
      _repository.markConversationAsRead(conversationId: conversationId),
    );

    if (_selectedConversation?.id == conversationId &&
        !_isConversationLoading &&
        _threadGroups.isNotEmpty) {
      // Same conversation re-opened. Bump the selection version so
      // listeners (like the thread scroller) can react and auto-scroll
      // to the bottom again even though the content didn't change.
      _selectionVersion++;
      if (notify) {
        notifyListeners();
      }
      return;
    }

    await _loadSelectedConversation(
      conversationId,
      notify: notify,
      incrementSelectionVersion: true,
    );
  }

  /// Clears unread count locally for a conversation so it appears read immediately.
  void _clearUnreadForConversation(int conversationId) {
    final currentList = _conversationList;
    if (currentList == null) return;

    final updatedItems = currentList.items.map((item) {
      if (item.id == conversationId && item.unreadCount > 0) {
        return OmnichannelConversationListItemModel(
          id: item.id,
          title: item.title,
          preview: item.preview,
          channel: item.channel,
          statusLabel: item.statusLabel,
          unreadCount: 0,
          lastActivityAt: item.lastActivityAt,
          mergeKey: item.mergeKey,
          customerLabel: item.customerLabel,
          customerPhone: item.customerPhone,
          mergedConversationCount: item.mergedConversationCount,
        );
      }
      return item;
    }).toList();

    _conversationList = currentList.copyWith(items: updatedItems);
    notifyListeners();
  }

  Future<void> refreshSelectedConversation() async {
    final conversationId = selectedConversationId;
    if (conversationId == null ||
        _isLoading ||
        _isRefreshing ||
        _isPollingConversation ||
        _isLoggingOut ||
        _requiresLogin) {
      return;
    }

    await _loadSelectedConversation(
      conversationId,
      incrementSelectionVersion: false,
    );
  }

  Future<void> softRefreshAfterExternalAction() async {
    if (_isLoading || _isRefreshing || _isLoggingOut || _requiresLogin) {
      return;
    }

    await pollList(force: true);
    await pollSelectedConversation(force: true);
  }

  Future<void> pollList({bool force = false}) async {
    final currentWorkspace = _workspace;
    final currentList = _conversationList;

    if (currentWorkspace == null || currentList == null) {
      return;
    }

    if (!force &&
        (!_isPageActive ||
            _isLoading ||
            _isRefreshing ||
            _isLoadingMore ||
            _isLoggingOut ||
            _isPollingList ||
            _requiresLogin)) {
      return;
    }

    _isPollingList = true;
    notifyListeners();

    try {
      final currentSelectedId = selectedConversationId;
      final selectionVersion = _selectionVersion;

      // Snapshot unreadCount sebelum polling untuk diff notifikasi.
      final Map<int, int> previousUnread = <int, int>{
        for (final item in currentList.items) item.id: item.unreadCount,
      };

      final snapshot = await _repository.pollShell(
        query: _query,
        currentWorkspace: currentWorkspace,
        currentConversationList: currentList,
        preferredConversationId: selectedConversationId,
      );
      _workspace = snapshot.workspace;
      if (_selectionVersion != selectionVersion) {
        _conversationList = snapshot.conversationList.copyWith(
          selectedConversationId: selectedConversationId,
        );
        return;
      }

      _conversationList = snapshot.conversationList;

      // Deteksi pesan masuk baru → emit event ke listener.
      _detectAndEmitNewMessages(
        previousUnread: previousUnread,
        currentItems: snapshot.conversationList.items,
        skipConversationId: currentSelectedId,
      );

      final nextConversationId =
          snapshot.conversationList.selectedConversationId;
      if (nextConversationId == null) {
        _clearConversationSelection();
      } else if (currentSelectedId != nextConversationId) {
        _clearConversationSelection();
        await _loadSelectedConversation(
          nextConversationId,
          notify: false,
          incrementSelectionVersion: true,
        );
      }
    } catch (error) {
      _applyError(error, silent: true);
    } finally {
      _isPollingList = false;
      notifyListeners();
    }
  }

  Future<void> pollSelectedConversation({bool force = false}) async {
    final conversationId = selectedConversationId;
    if (conversationId == null) {
      return;
    }

    if (!force &&
        (!_isPageActive ||
            _isLoading ||
            _isRefreshing ||
            _isConversationLoading ||
            _isLoggingOut ||
            _isPollingConversation ||
            _requiresLogin)) {
      return;
    }

    final selectionVersion = _selectionVersion;
    _isPollingConversation = true;
    notifyListeners();

    try {
      final snapshot = await _repository.pollConversationSnapshot(
        conversationId,
        currentConversation: _selectedConversation,
        currentThreadGroups: _threadGroups,
        currentInsight: _insight,
      );

      if (_selectionVersion != selectionVersion ||
          selectedConversationId != conversationId) {
        return;
      }

      _selectedConversation = snapshot.conversation ?? _selectedConversation;
      _threadGroups = snapshot.threadGroups;
      _insight = snapshot.insight;
    } catch (error) {
      _applyError(error, silent: true);
    } finally {
      _isPollingConversation = false;
      notifyListeners();
    }
  }

  void setScopeFilter(String value) {
    if (_query.scope == value) {
      return;
    }

    _query = _query.copyWith(scope: value).resetPage();
    notifyListeners();
    unawaited(refresh());
  }

  void setChannelFilter(String value) {
    if (_query.channel == value) {
      return;
    }

    _query = _query.copyWith(channel: value).resetPage();
    notifyListeners();
    unawaited(refresh());
  }

  void setSearchQuery(String value) {
    if (_query.search == value) {
      return;
    }

    _query = _query.copyWith(search: value).resetPage();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(refresh());
    });
    notifyListeners();
  }

  void setPageActive(bool active) {
    if (_isPageActive == active) {
      return;
    }

    _isPageActive = active;
    if (active) {
      _restartPolling();
      if (!_isLoading) {
        unawaited(pollList(force: true));
        unawaited(pollSelectedConversation(force: true));
      }
    } else {
      _cancelAllPolling();
    }
  }

  Future<void> logout() async {
    _cancelAllPolling();
    _isLoggingOut = true;
    notifyListeners();

    try {
      await _adminAuthRepository.logout();
      _requiresLogin = true;
    } catch (error) {
      _applyError(error);
    } finally {
      _isLoggingOut = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _cancelAllPolling();
    super.dispose();
  }

  Future<void> _loadSelectedConversation(
    int conversationId, {
    bool notify = true,
    bool incrementSelectionVersion = true,
  }) async {
    if (incrementSelectionVersion) {
      _selectionVersion++;
    }
    final selectionVersion = _selectionVersion;

    _isConversationLoading = true;
    final currentList = _conversationList;
    if (currentList != null) {
      _conversationList = currentList.copyWith(
        selectedConversationId: conversationId,
      );
    }
    if (notify) {
      notifyListeners();
    }

    try {
      final snapshot = await _repository.loadConversationSnapshot(
        conversationId,
      );

      if (_selectionVersion != selectionVersion ||
          selectedConversationId != conversationId) {
        return;
      }

      _selectedConversation = snapshot.conversation;
      _threadGroups = snapshot.threadGroups;
      _insight = snapshot.insight;
    } catch (error) {
      if (_selectionVersion == selectionVersion) {
        _applyError(error);
      }
    } finally {
      if (_selectionVersion == selectionVersion) {
        _isConversationLoading = false;
        _restartConversationPolling();
        notifyListeners();
      }
    }
  }

  void _applyShellSnapshot(OmnichannelShellSnapshotModel snapshot) {
    _workspace = snapshot.workspace;
    _conversationList = snapshot.conversationList;
    if (snapshot.selectedConversation != null) {
      _selectedConversation = snapshot.selectedConversation;
      _threadGroups = snapshot.threadGroups;
      _insight = snapshot.insight;
    }
  }

  void _clearConversationSelection() {
    _selectedConversation = null;
    _threadGroups = const <OmnichannelThreadGroupModel>[];
    _insight = OmnichannelInsightModel.empty();
    _conversationPollingTimer?.cancel();
    _conversationPollingTimer = null;
  }

  void _restartPolling() {
    _restartListPolling();
    _restartConversationPolling();
  }

  void _restartListPolling() {
    _listPollingTimer?.cancel();
    _listPollingTimer = null;

    if (!_isPageActive || _requiresLogin || !hasShellData) {
      return;
    }

    _listPollingTimer = Timer.periodic(
      AppConfig.reconnectPollingInterval,
      (_) => unawaited(pollList()),
    );
  }

  void _restartConversationPolling() {
    _conversationPollingTimer?.cancel();
    _conversationPollingTimer = null;

    if (!_isPageActive || _requiresLogin || selectedConversationId == null) {
      return;
    }

    _conversationPollingTimer = Timer.periodic(
      AppConfig.defaultPollingInterval,
      (_) => unawaited(pollSelectedConversation()),
    );
  }

  void _cancelAllPolling() {
    _listPollingTimer?.cancel();
    _listPollingTimer = null;
    _conversationPollingTimer?.cancel();
    _conversationPollingTimer = null;
  }

  void _applyError(Object error, {bool silent = false}) {
    if (error is ApiException && error.isUnauthorized) {
      _requiresLogin = true;
    } else if (error is StateError) {
      _requiresLogin = true;
    }

    if (silent && !_requiresLogin) {
      return;
    }

    if (error is ApiException) {
      _errorMessage = error.message;
      return;
    }

    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      _errorMessage = text.substring('Exception: '.length);
      return;
    }

    _errorMessage = text.replaceFirst('Bad state: ', '');
  }

  // ─── New-message detection helpers ─────────────────────────────────────

  void _detectAndEmitNewMessages({
    required Map<int, int> previousUnread,
    required List<OmnichannelConversationListItemModel> currentItems,
    required int? skipConversationId,
  }) {
    if (_notificationListeners.isEmpty) {
      return;
    }

    int totalNewCount = 0;
    final List<int> affectedIds = <int>[];
    OmnichannelConversationListItemModel? mostRecent;

    for (final item in currentItems) {
      if (skipConversationId != null && item.id == skipConversationId) {
        continue;
      }

      final previous = previousUnread[item.id] ?? 0;
      final delta = item.unreadCount - previous;

      if (delta > 0) {
        totalNewCount += delta;
        affectedIds.add(item.id);
        if (mostRecent == null) {
          mostRecent = item;
        } else {
          final mostRecentDelta =
              item.unreadCount - (previousUnread[mostRecent.id] ?? 0);
          if (delta > mostRecentDelta) {
            mostRecent = item;
          }
        }
      }
    }

    if (totalNewCount == 0 || mostRecent == null) {
      return;
    }

    final senderName = (mostRecent.customerLabel?.trim().isNotEmpty == true)
        ? mostRecent.customerLabel!.trim()
        : mostRecent.title;

    _emitChatNotification(
      ChatNotificationEvent(
        conversationId: mostRecent.id,
        senderName: senderName,
        preview: mostRecent.preview,
        totalNewCount: totalNewCount,
        affectedConversationIds: affectedIds,
      ),
    );
  }
}
