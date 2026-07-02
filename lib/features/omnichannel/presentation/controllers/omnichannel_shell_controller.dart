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
import '../../data/models/sticker_favorite_item.dart';
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
  DateTime? _lastTypingSentAt;

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
  String get tagFilter => _query.tag;

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

    // Presence (Wave 1): reset typing throttle for the (re)selected chat,
    // then fire-and-forget a WhatsApp read receipt (WA channel only).
    _lastTypingSentAt = null;
    if (_isWhatsAppConversation(conversationId)) {
      unawaited(
        _repository.sendConversationReadReceipt(conversationId: conversationId),
      );
    }

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

  /// Returns true unless the conversation's list item is a known non-WhatsApp
  /// channel. Defaults to true when unknown so presence is never wrongly
  /// suppressed — the backend remains the authoritative guard.
  bool _isWhatsAppConversation(int conversationId) {
    final items = _conversationList?.items;
    if (items == null) {
      return true;
    }
    for (final item in items) {
      if (item.id == conversationId) {
        return item.channel == 'whatsapp';
      }
    }
    return true;
  }

  /// Fire-and-forget WhatsApp typing indicator for the active conversation.
  /// Guards: active WA conversation + non-empty text + >=5s throttle.
  void notifyAdminTyping(String text) {
    final conversationId = selectedConversationId;
    if (conversationId == null) {
      return;
    }
    if (_selectedConversation?.channel != 'whatsapp') {
      return;
    }
    if (text.trim().isEmpty) {
      return;
    }
    final now = DateTime.now();
    final last = _lastTypingSentAt;
    if (last != null && now.difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _lastTypingSentAt = now;
    unawaited(
      _repository.sendConversationTyping(conversationId: conversationId),
    );
  }

  /// Send a WhatsApp reaction emoji to a message in the active conversation.
  /// Returns 'sent' | 'skipped' | 'failed'. WhatsApp channel only (K-3).
  Future<String> reactToMessage({
    required int messageId,
    required String emoji,
  }) async {
    final conversationId = selectedConversationId;
    if (conversationId == null) {
      return 'failed';
    }
    if (_selectedConversation?.channel != 'whatsapp') {
      return 'skipped';
    }
    return _repository.sendConversationReaction(
      conversationId: conversationId,
      messageId: messageId,
      emoji: emoji,
    );
  }

  /// Toggle bintang pesan di conversation aktif (BRIEF 5C-APP-1). Internal-only
  /// (NOL WhatsApp). Channel-agnostic (beda dari reaction). Return true bila sukses.
  Future<bool> toggleStar({
    required int messageId,
    required bool currentlyStarred,
  }) async {
    final conversationId = selectedConversationId;
    if (conversationId == null) {
      return false;
    }
    return _repository.setConversationMessageStar(
      conversationId: conversationId,
      messageId: messageId,
      starred: !currentlyStarred,
    );
  }

  Future<bool> forwardMessage({
    required int messageId,
    required int targetConversationId,
  }) async {
    final conversationId = selectedConversationId;
    if (conversationId == null) {
      return false;
    }
    return _repository.forwardConversationMessage(
      conversationId: conversationId,
      messageId: messageId,
      targetConversationId: targetConversationId,
    );
  }

  /// Daftar percakapan tujuan picker teruskan (5A): WhatsApp-only + exclude
  /// percakapan sumber aktif. Baca daftar existing (loadShell), tak fetch baru.
  List<OmnichannelConversationListItemModel> get conversationsForForwardPicker {
    final sourceId = selectedConversationId;
    final items =
        _conversationList?.items ??
        const <OmnichannelConversationListItemModel>[];
    return items
        .where((item) => item.channel == 'whatsapp' && item.id != sourceId)
        .toList(growable: false);
  }

  /// Resends a received WhatsApp sticker to the customer (BRIEF 4C-1).
  /// Returns BE notice string (success) | 'skipped' | 'failed'. WhatsApp only.
  Future<String> resendSticker({required int sourceMessageId}) async {
    final conversationId = selectedConversationId;
    if (conversationId == null) {
      return 'failed';
    }
    if (_selectedConversation?.channel != 'whatsapp') {
      return 'skipped';
    }
    return _repository.sendAdminStickerReply(
      conversationId: conversationId,
      sourceMessageId: sourceMessageId,
    );
  }

  /// Saves a sticker to the shared favorites collection (BRIEF 4C-2).
  /// Returns BE message. NOT conversation-scoped (any sticker, any channel).
  Future<String> saveStickerFavorite({required int sourceMessageId}) async {
    return _repository.saveStickerFavorite(sourceMessageId: sourceMessageId);
  }

  /// Loads the shared sticker favorites collection (BRIEF 4C-3). Fetch each
  /// open (always fresh); throws on BE error -> picker error-state. Not
  /// conversation-scoped (mirror saveStickerFavorite).
  Future<List<StickerFavoriteItem>> loadStickerFavorites() {
    return _repository.fetchStickerFavorites();
  }

  /// Sends a favorite sticker to the selected conversation (BRIEF 4C-3).
  /// Returns BE message (success) | 'skipped' | 'failed'. WhatsApp only
  /// (mirror resendSticker guard).
  Future<String> sendStickerFavorite({required int favoriteId}) async {
    final conversationId = selectedConversationId;
    if (conversationId == null) {
      return 'failed';
    }
    if (_selectedConversation?.channel != 'whatsapp') {
      return 'skipped';
    }
    return _repository.sendStickerFavorite(
      conversationId: conversationId,
      favoriteId: favoriteId,
    );
  }

  Future<String> sendRouteCarousel() async {
    final conversationId = selectedConversationId;
    if (conversationId == null) {
      return 'failed';
    }
    if (_selectedConversation?.channel != 'whatsapp') {
      return 'skipped';
    }
    return _repository.sendRouteCarousel(conversationId: conversationId);
  }

  Future<String> sendGreeting() async {
    final conversationId = selectedConversationId;
    if (conversationId == null) {
      return 'failed';
    }
    if (_selectedConversation?.channel != 'whatsapp') {
      return 'skipped';
    }
    return _repository.sendGreeting(conversationId: conversationId);
  }

  Future<String> sendPayment(String paymentType) async {
    final conversationId = selectedConversationId;
    if (conversationId == null) {
      return 'failed';
    }
    if (_selectedConversation?.channel != 'whatsapp') {
      return 'skipped';
    }
    return _repository.sendPayment(
      conversationId: conversationId,
      paymentType: paymentType,
    );
  }

  Future<List<Map<String, dynamic>>> fetchComposeBookings() async {
    final conversationId = selectedConversationId;
    if (conversationId == null) {
      return const <Map<String, dynamic>>[];
    }
    if (_selectedConversation?.channel != 'whatsapp') {
      return const <Map<String, dynamic>>[];
    }
    return _repository.fetchComposeBookings(conversationId: conversationId);
  }

  Future<String> sendComposedPayment({
    required String paymentType,
    String? bookingCode,
    required int total,
    String? loket,
  }) async {
    final conversationId = selectedConversationId;
    if (conversationId == null) {
      return 'failed';
    }
    if (_selectedConversation?.channel != 'whatsapp') {
      return 'skipped';
    }
    return _repository.sendComposedPayment(
      conversationId: conversationId,
      paymentType: paymentType,
      bookingCode: bookingCode,
      total: total,
      loket: loket,
    );
  }

  /// Marks a conversation as unread (BRIEF 3A): optimistically bumps the local
  /// unread badge, then tells the backend (silent-fail). Inverse of the tap
  /// read-clear flow. Eventual consistency: next poll reconciles with backend.
  Future<void> markUnread(int conversationId) async {
    _bumpUnreadForConversation(conversationId);
    await _repository.markConversationAsUnread(conversationId: conversationId);
  }

  /// Adds a label/tag to a conversation (BRIEF 3B-1), then poll-refreshes so
  /// the chip appears. Mirror of the external-action refresh pattern.
  Future<void> addLabel(int conversationId, String tag) async {
    await _repository.addTag(conversationId: conversationId, tag: tag);
    await softRefreshAfterExternalAction();
  }

  /// Removes a label/tag from a conversation (BRIEF 3B-1), then poll-refreshes.
  Future<void> removeLabel(int conversationId, String tag) async {
    await _repository.removeTag(conversationId: conversationId, tag: tag);
    await softRefreshAfterExternalAction();
  }

  /// Pins a conversation (BRIEF 3C), then poll-refreshes so it rises to the top.
  /// Mirror of the external-action refresh pattern (addLabel/removeLabel).
  Future<void> pin(int conversationId) async {
    await _repository.pinConversation(conversationId: conversationId);
    await softRefreshAfterExternalAction();
  }

  /// Unpins a conversation (BRIEF 3C), then poll-refreshes so ordering returns to normal.
  Future<void> unpin(int conversationId) async {
    await _repository.unpinConversation(conversationId: conversationId);
    await softRefreshAfterExternalAction();
  }

  /// Archives a conversation (BRIEF 3D), then poll-refreshes (server-driven:
  /// archived drops from active scopes). Mirror of addLabel/removeLabel.
  Future<void> archive(int conversationId) async {
    await _repository.archiveConversation(conversationId: conversationId);
    await softRefreshAfterExternalAction();
  }

  /// Unarchives a conversation (BRIEF 3D), then poll-refreshes.
  Future<void> unarchive(int conversationId) async {
    await _repository.unarchiveConversation(conversationId: conversationId);
    await softRefreshAfterExternalAction();
  }

  /// Mutes a conversation (BRIEF 3E), then poll-refreshes. Mirror of archive().
  Future<void> mute(int conversationId) async {
    await _repository.muteConversation(conversationId: conversationId);
    await softRefreshAfterExternalAction();
  }

  /// Unmutes a conversation (BRIEF 3E), then poll-refreshes.
  Future<void> unmute(int conversationId) async {
    await _repository.unmuteConversation(conversationId: conversationId);
    await softRefreshAfterExternalAction();
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
          tags: item.tags,
          isPinned: item.isPinned,
          isMuted: item.isMuted,
        );
      }
      return item;
    }).toList();

    _conversationList = currentList.copyWith(items: updatedItems);
    notifyListeners();
  }

  /// Bumps unread count locally to 1 for a conversation that is currently read
  /// (unreadCount == 0), so the badge appears immediately (BRIEF 3A). Mirror of
  /// [_clearUnreadForConversation]; leaves already-unread items untouched.
  void _bumpUnreadForConversation(int conversationId) {
    final currentList = _conversationList;
    if (currentList == null) return;

    final updatedItems = currentList.items.map((item) {
      if (item.id == conversationId && item.unreadCount == 0) {
        return OmnichannelConversationListItemModel(
          id: item.id,
          title: item.title,
          preview: item.preview,
          channel: item.channel,
          statusLabel: item.statusLabel,
          unreadCount: 1,
          lastActivityAt: item.lastActivityAt,
          mergeKey: item.mergeKey,
          customerLabel: item.customerLabel,
          customerPhone: item.customerPhone,
          mergedConversationCount: item.mergedConversationCount,
          tags: item.tags,
          isPinned: item.isPinned,
          isMuted: item.isMuted,
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

  void setTagFilter(String value) {
    if (_query.tag == value) {
      return;
    }

    _query = _query.copyWith(tag: value).resetPage();
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
