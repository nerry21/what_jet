import 'dart:async';

import '../../../../core/network/api_client.dart';
import '../../../admin_auth/data/repositories/admin_auth_repository.dart';
import '../../domain/models/omnichannel_call_readiness_model.dart';
import '../models/omnichannel_call_action_result.dart';
import '../models/omnichannel_call_analytics_summary_model.dart';
import '../models/omnichannel_call_history_item_model.dart';
import '../models/omnichannel_conversation_detail_model.dart';
import '../models/omnichannel_conversation_list_model.dart';
import '../models/omnichannel_insight_model.dart';
import '../models/omnichannel_query_model.dart';
import '../models/omnichannel_shell_snapshot_model.dart';
import '../models/omnichannel_status_update_model.dart';
import '../models/omnichannel_thread_model.dart';
import '../models/omnichannel_workspace_model.dart';
import '../models/sticker_favorite_item.dart';
import '../models/whatsapp_contact_model.dart';
import '../services/omnichannel_api_service.dart';

class OmnichannelRepository {
  OmnichannelRepository({
    required OmnichannelApiService apiService,
    required AdminAuthRepository adminAuthRepository,
  }) : _apiService = apiService,
       _adminAuthRepository = adminAuthRepository;

  final OmnichannelApiService _apiService;
  final AdminAuthRepository _adminAuthRepository;

  Future<OmnichannelShellSnapshotModel> loadShell({
    required OmnichannelQueryModel query,
    int? preferredConversationId,
  }) async {
    final accessToken = await _ensureAdminSession();
    final results = await Future.wait<Object>(<Future<Object>>[
      _safeOptionalRead(
        () => _apiService.fetchWorkspace(accessToken: accessToken),
      ),
      _safeOptionalRead(
        () => _apiService.fetchDashboardSummary(accessToken: accessToken),
      ),
      _safeOptionalRead(
        () => _apiService.fetchMetaFilters(accessToken: accessToken),
      ),
      _readWithRetry(
        () => _apiService.fetchConversations(
          accessToken: accessToken,
          queryParameters: query.toQueryParameters(),
        ),
      ),
      _safeOptionalRead(
        () => _apiService.fetchPollList(
          accessToken: accessToken,
          queryParameters: query.toQueryParameters(),
        ),
      ),
    ]);

    final workspacePayload = results[0] as Map<String, dynamic>;
    final summaryPayload = results[1] as Map<String, dynamic>;
    final filtersPayload = results[2] as Map<String, dynamic>;
    final conversationsPayload = results[3] as Map<String, dynamic>;
    final pollListPayload = results[4] as Map<String, dynamic>;

    final workspace = OmnichannelWorkspaceModel.fromSources(
      workspacePayload: workspacePayload,
      summaryPayload: summaryPayload,
      filtersPayload: filtersPayload,
      pollListPayload: pollListPayload,
    );
    final conversationList = OmnichannelConversationListModel.fromSources(
      conversationsPayload: conversationsPayload,
      pollListPayload: pollListPayload,
      preferredConversationId: preferredConversationId,
    );

    return OmnichannelShellSnapshotModel(
      workspace: workspace,
      conversationList: conversationList,
      selectedConversation: null,
      threadGroups: const <OmnichannelThreadGroupModel>[],
      insight: OmnichannelInsightModel.empty(),
    );
  }

  Future<OmnichannelShellSnapshotModel> pollShell({
    required OmnichannelQueryModel query,
    required OmnichannelWorkspaceModel currentWorkspace,
    required OmnichannelConversationListModel currentConversationList,
    int? preferredConversationId,
  }) async {
    final accessToken = await _ensureAdminSession();
    final pollListPayload = await _readWithRetry(
      () => _apiService.fetchPollList(
        accessToken: accessToken,
        queryParameters: query.toQueryParameters(),
      ),
    );

    final polledWorkspace = OmnichannelWorkspaceModel.fromSources(
      pollListPayload: pollListPayload,
    );
    final polledList = OmnichannelConversationListModel.fromSources(
      conversationsPayload: pollListPayload,
      pollListPayload: pollListPayload,
      preferredConversationId: preferredConversationId,
    );

    return OmnichannelShellSnapshotModel(
      workspace: currentWorkspace.mergeWith(polledWorkspace),
      conversationList: currentConversationList.mergePoll(polledList),
      selectedConversation: null,
      threadGroups: const <OmnichannelThreadGroupModel>[],
      insight: OmnichannelInsightModel.empty(),
    );
  }

  Future<OmnichannelConversationListModel> loadConversationPage({
    required OmnichannelQueryModel query,
    int? preferredConversationId,
  }) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.fetchConversations(
        accessToken: accessToken,
        queryParameters: query.toQueryParameters(),
      ),
    );

    return OmnichannelConversationListModel.fromSources(
      conversationsPayload: payload,
      preferredConversationId: preferredConversationId,
    );
  }

  Future<OmnichannelConversationSnapshotModel> loadConversationSnapshot(
    int conversationId,
  ) async {
    final accessToken = await _ensureAdminSession();
    return _loadConversationSnapshot(conversationId, accessToken: accessToken);
  }

  Future<OmnichannelConversationSnapshotModel> pollConversationSnapshot(
    int conversationId, {
    OmnichannelConversationDetailModel? currentConversation,
    List<OmnichannelThreadGroupModel> currentThreadGroups =
        const <OmnichannelThreadGroupModel>[],
    OmnichannelInsightModel currentInsight = const OmnichannelInsightModel(
      customerName: 'Belum ada percakapan',
      customerContact: '-',
      customerTags: <String>[],
      conversationTags: <String>[],
      quickDetails: <String, String>{},
      noteLines: <String>[],
    ),
  }) async {
    final accessToken = await _ensureAdminSession();
    final afterMessageId = _latestThreadMessageId(currentThreadGroups);
    final pollPayload = await _readWithRetry(
      () => _apiService.fetchConversationPoll(
        accessToken: accessToken,
        conversationId: conversationId,
        afterMessageId: afterMessageId,
      ),
    );

    final incomingConversation = OmnichannelConversationDetailModel.fromSources(
      detailPayload: pollPayload,
      pollPayload: pollPayload,
    );
    final mergedConversation = currentConversation == null
        ? (incomingConversation.id > 0 ? incomingConversation : null)
        : currentConversation.mergeWith(incomingConversation);

    final incomingThreadGroups = OmnichannelThreadGroupModel.fromSources(
      messagesPayload: pollPayload,
      pollPayload: pollPayload,
    );
    final mergedThreadGroups = OmnichannelThreadGroupModel.mergeGroups(
      currentThreadGroups,
      incomingThreadGroups,
    );

    final incomingInsight = OmnichannelInsightModel.fromSources(
      detailPayload: pollPayload,
      messagesPayload: pollPayload,
      pollPayload: pollPayload,
      conversation: mergedConversation,
    );

    return OmnichannelConversationSnapshotModel(
      conversation: mergedConversation,
      threadGroups: mergedThreadGroups,
      insight: currentInsight.mergeWith(incomingInsight),
    );
  }

  int? _latestThreadMessageId(List<OmnichannelThreadGroupModel> groups) {
    int? latestId;

    for (final group in groups) {
      for (final message in group.messages) {
        final id = message.id;
        if (latestId == null || id > latestId) {
          latestId = id;
        }
      }
    }

    return latestId;
  }

  Future<OmnichannelWorkspaceModel> loadWorkspace({
    OmnichannelQueryModel query = const OmnichannelQueryModel(),
  }) async {
    final snapshot = await loadShell(query: query);
    return snapshot.workspace;
  }

  Future<OmnichannelConversationListModel> loadConversationList({
    OmnichannelQueryModel query = const OmnichannelQueryModel(),
    int? preferredConversationId,
  }) async {
    final snapshot = await loadShell(
      query: query,
      preferredConversationId: preferredConversationId,
    );
    return snapshot.conversationList;
  }

  Future<OmnichannelConversationDetailModel?> loadConversationDetail(
    int conversationId,
  ) async {
    final snapshot = await loadConversationSnapshot(conversationId);
    return snapshot.conversation;
  }

  Future<List<OmnichannelThreadGroupModel>> loadThread(
    int conversationId,
  ) async {
    final snapshot = await loadConversationSnapshot(conversationId);
    return snapshot.threadGroups;
  }

  Future<OmnichannelInsightModel> loadInsight(int conversationId) async {
    final snapshot = await loadConversationSnapshot(conversationId);
    return snapshot.insight;
  }

  Future<String> sendAdminReply({
    required int conversationId,
    required String message,
    int? replyToMessageId,
  }) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.sendAdminReply(
        accessToken: accessToken,
        conversationId: conversationId,
        message: message,
        replyToMessageId: replyToMessageId,
      ),
    );

    final notice = payload['notice']?.toString().trim();
    if (notice != null && notice.isNotEmpty) {
      return notice;
    }

    return 'Balasan admin berhasil diproses.';
  }

  Future<String> sendAdminStickerReply({
    required int conversationId,
    required int sourceMessageId,
  }) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.sendAdminStickerReply(
        accessToken: accessToken,
        conversationId: conversationId,
        sourceMessageId: sourceMessageId,
      ),
    );

    final notice = payload['notice']?.toString().trim();
    if (notice != null && notice.isNotEmpty) {
      return notice;
    }

    return 'Stiker berhasil diproses.';
  }

  Future<String> saveStickerFavorite({required int sourceMessageId}) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.saveStickerFavorite(
        accessToken: accessToken,
        sourceMessageId: sourceMessageId,
      ),
    );

    final message = payload['message']?.toString().trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }

    return 'Stiker disimpan ke koleksi.';
  }

  /// Loads the shared sticker favorites collection (BRIEF 4C-3, BE-1).
  /// Throws on BE error (`_readWithRetry` rethrow) -> picker error-state;
  /// filters malformed `id<=0`. NB: ApiClient._decodeResponse FLATTENS the
  /// successResponse `data` into top-level, so favorites are read via
  /// `_extractPayloadData(payload)['favorites']` (mirror loadStatusUpdates),
  /// NOT payload['data']['favorites'].
  Future<List<StickerFavoriteItem>> fetchStickerFavorites() async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.fetchStickerFavorites(accessToken: accessToken),
    );

    final data = _extractPayloadData(payload);
    final rawFavorites = data['favorites'];
    if (rawFavorites is! List) {
      return const <StickerFavoriteItem>[];
    }

    return rawFavorites
        .whereType<Map<String, dynamic>>()
        .map(StickerFavoriteItem.fromJson)
        .where((item) => item.id > 0)
        .toList();
  }

  /// Sends a favorite sticker to a conversation (BRIEF 4C-3, BE-2).
  /// successResponse -> notice di top-level `message`. Mirror saveStickerFavorite.
  Future<String> sendStickerFavorite({
    required int conversationId,
    required int favoriteId,
  }) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.sendStickerFavorite(
        accessToken: accessToken,
        conversationId: conversationId,
        favoriteId: favoriteId,
      ),
    );

    final message = payload['message']?.toString().trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }

    return 'Stiker favorit berhasil dikirim.';
  }

  /// Mark conversation as read on the backend.
  /// Fails silently — this is a non-critical UX enhancement.
  Future<void> markConversationAsRead({required int conversationId}) async {
    try {
      final accessToken = await _ensureAdminSession();
      await _apiService.markConversationAsRead(
        accessToken: accessToken,
        conversationId: conversationId,
      );
    } catch (_) {
      // Silent fail — unread badge will be recalculated on next poll.
    }
  }

  /// Mark conversation as unread on the backend (BRIEF 3A).
  /// Fails silently — eventual consistency: badge recalculated on next poll.
  Future<void> markConversationAsUnread({required int conversationId}) async {
    try {
      final accessToken = await _ensureAdminSession();
      await _apiService.markConversationAsUnread(
        accessToken: accessToken,
        conversationId: conversationId,
      );
    } catch (_) {
      // Silent fail — unread badge will be recalculated on next poll.
    }
  }

  /// Pin a conversation (BRIEF 3C). Fails silently — eventual consistency:
  /// ordering reconciled on next poll.
  Future<void> pinConversation({required int conversationId}) async {
    try {
      final accessToken = await _ensureAdminSession();
      await _apiService.pinConversation(
        accessToken: accessToken,
        conversationId: conversationId,
      );
    } catch (_) {
      // Silent fail — ordering reconciled on next poll.
    }
  }

  /// Unpin a conversation (BRIEF 3C). Fails silently — eventual consistency:
  /// ordering reconciled on next poll.
  Future<void> unpinConversation({required int conversationId}) async {
    try {
      final accessToken = await _ensureAdminSession();
      await _apiService.unpinConversation(
        accessToken: accessToken,
        conversationId: conversationId,
      );
    } catch (_) {
      // Silent fail — ordering reconciled on next poll.
    }
  }

  /// Archive a conversation (BRIEF 3D). Fails silently — eventual consistency:
  /// list reconciled on next poll.
  Future<void> archiveConversation({required int conversationId}) async {
    try {
      final accessToken = await _ensureAdminSession();
      await _apiService.archiveConversation(
        accessToken: accessToken,
        conversationId: conversationId,
      );
    } catch (_) {
      // Silent fail — list reconciled on next poll.
    }
  }

  /// Unarchive a conversation (BRIEF 3D). Fails silently — eventual consistency:
  /// list reconciled on next poll.
  Future<void> unarchiveConversation({required int conversationId}) async {
    try {
      final accessToken = await _ensureAdminSession();
      await _apiService.unarchiveConversation(
        accessToken: accessToken,
        conversationId: conversationId,
      );
    } catch (_) {
      // Silent fail — list reconciled on next poll.
    }
  }

  /// Mute a conversation (BRIEF 3E). Fails silently — eventual consistency:
  /// list reconciled on next poll.
  Future<void> muteConversation({required int conversationId}) async {
    try {
      final accessToken = await _ensureAdminSession();
      await _apiService.muteConversation(
        accessToken: accessToken,
        conversationId: conversationId,
      );
    } catch (_) {
      // Silent fail — list reconciled on next poll.
    }
  }

  /// Unmute a conversation (BRIEF 3E). Fails silently — eventual consistency:
  /// list reconciled on next poll.
  Future<void> unmuteConversation({required int conversationId}) async {
    try {
      final accessToken = await _ensureAdminSession();
      await _apiService.unmuteConversation(
        accessToken: accessToken,
        conversationId: conversationId,
      );
    } catch (_) {
      // Silent fail — list reconciled on next poll.
    }
  }

  /// Add a label/tag to a conversation (BRIEF 3B-1). Fails silently —
  /// eventual consistency: chip reconciled on next poll.
  Future<void> addTag({
    required int conversationId,
    required String tag,
  }) async {
    try {
      final accessToken = await _ensureAdminSession();
      await _apiService.addConversationTag(
        accessToken: accessToken,
        conversationId: conversationId,
        tag: tag,
      );
    } catch (_) {
      // Silent fail — label list reconciled on next poll.
    }
  }

  /// Remove a label/tag from a conversation (BRIEF 3B-1). Fails silently.
  Future<void> removeTag({
    required int conversationId,
    required String tag,
  }) async {
    try {
      final accessToken = await _ensureAdminSession();
      await _apiService.removeConversationTag(
        accessToken: accessToken,
        conversationId: conversationId,
        tag: tag,
      );
    } catch (_) {
      // Silent fail — label list reconciled on next poll.
    }
  }

  /// Send a WhatsApp Cloud API read receipt for the conversation's latest
  /// inbound message. Fire-and-forget — failure never blocks chat UX.
  Future<void> sendConversationReadReceipt({
    required int conversationId,
  }) async {
    try {
      final accessToken = await _ensureAdminSession();
      await _apiService.sendConversationReadReceipt(
        accessToken: accessToken,
        conversationId: conversationId,
      );
    } catch (_) {
      // Silent fail — presence is a non-critical enhancement.
    }
  }

  /// Send a WhatsApp typing indicator for the conversation. Fire-and-forget.
  Future<void> sendConversationTyping({required int conversationId}) async {
    try {
      final accessToken = await _ensureAdminSession();
      await _apiService.sendConversationTyping(
        accessToken: accessToken,
        conversationId: conversationId,
      );
    } catch (_) {
      // Silent fail — presence is a non-critical enhancement.
    }
  }

  /// Send a WhatsApp reaction for [messageId]. Returns the backend status
  /// ('sent' | 'skipped' | 'failed') — reports outcome (NOT silent).
  Future<String> sendConversationReaction({
    required int conversationId,
    required int messageId,
    required String emoji,
  }) async {
    try {
      final accessToken = await _ensureAdminSession();
      final payload = await _apiService.sendConversationReaction(
        accessToken: accessToken,
        conversationId: conversationId,
        messageId: messageId,
        emoji: emoji,
      );
      return payload['status']?.toString() ?? 'failed';
    } catch (_) {
      return 'failed';
    }
  }

  /// Set/lepas bintang pesan (BRIEF 5C-APP-1). Internal-only, channel-agnostic.
  /// Return true bila BE 2xx (tak throw), false bila gagal — UI surface snackbar.
  /// Tak baca body (404 BE-OFF => ApiException => catch => false; nol false-success).
  Future<bool> setConversationMessageStar({
    required int conversationId,
    required int messageId,
    required bool starred,
  }) async {
    try {
      final accessToken = await _ensureAdminSession();
      await _apiService.setConversationMessageStar(
        accessToken: accessToken,
        conversationId: conversationId,
        messageId: messageId,
        starred: starred,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> sendAdminImageReply({
    required int conversationId,
    required List<int> fileBytes,
    required String fileName,
    String? caption,
    String? mimeType,
    int? replyToMessageId,
  }) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.sendAdminImageReply(
        accessToken: accessToken,
        conversationId: conversationId,
        fileBytes: fileBytes,
        fileName: fileName,
        caption: caption,
        mimeType: mimeType,
        replyToMessageId: replyToMessageId,
      ),
    );

    final notice = payload['notice']?.toString().trim();
    if (notice != null && notice.isNotEmpty) {
      return notice;
    }

    return 'Gambar admin berhasil diproses.';
  }

  Future<String> sendAdminVideoReply({
    required int conversationId,
    required List<int> fileBytes,
    required String fileName,
    String? caption,
    String? mimeType,
    int? replyToMessageId,
  }) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.sendAdminVideoReply(
        accessToken: accessToken,
        conversationId: conversationId,
        fileBytes: fileBytes,
        fileName: fileName,
        caption: caption,
        mimeType: mimeType,
        replyToMessageId: replyToMessageId,
      ),
    );

    final notice = payload['notice']?.toString().trim();
    if (notice != null && notice.isNotEmpty) {
      return notice;
    }

    return 'Video admin berhasil diproses.';
  }

  Future<String> sendAdminAudioReply({
    required int conversationId,
    required List<int> fileBytes,
    required String fileName,
    String? mimeType,
    String? caption,
    int? replyToMessageId,
  }) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.sendAdminAudioReply(
        accessToken: accessToken,
        conversationId: conversationId,
        fileBytes: fileBytes,
        fileName: fileName,
        mimeType: mimeType,
        caption: caption,
        replyToMessageId: replyToMessageId,
      ),
    );

    final notice = payload['notice']?.toString().trim();
    if (notice != null && notice.isNotEmpty) {
      return notice;
    }

    return 'Voice note admin berhasil diproses.';
  }

  Future<String> sendAdminDocumentReply({
    required int conversationId,
    required List<int> fileBytes,
    required String fileName,
    String? caption,
    String? mimeType,
    int? replyToMessageId,
  }) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.sendAdminDocumentReply(
        accessToken: accessToken,
        conversationId: conversationId,
        fileBytes: fileBytes,
        fileName: fileName,
        caption: caption,
        mimeType: mimeType,
        replyToMessageId: replyToMessageId,
      ),
    );

    final notice = payload['notice']?.toString().trim();
    if (notice != null && notice.isNotEmpty) {
      return notice;
    }

    return 'Dokumen admin berhasil diproses.';
  }

  Future<String> sendAdminLocationReply({
    required int conversationId,
    required double latitude,
    required double longitude,
    String? locationName,
    String? locationAddress,
  }) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.sendAdminLocationReply(
        accessToken: accessToken,
        conversationId: conversationId,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
        locationAddress: locationAddress,
      ),
    );

    final notice = payload['notice']?.toString().trim();
    if (notice != null && notice.isNotEmpty) {
      return notice;
    }

    return 'Lokasi berhasil diproses.';
  }

  // ─── WhatsApp Contacts (address book) ────────────────────────────────

  /// Buat kontak WhatsApp baru di backend.
  /// Backend akan otomatis menyiapkan customer & conversation placeholder
  /// sehingga admin bisa langsung mulai chat di UI.
  Future<WhatsAppContactCreateResult> createWhatsAppContact({
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    String? countryCode,
    bool syncToDevice = true,
  }) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.createWhatsAppContact(
        accessToken: accessToken,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        email: email,
        countryCode: countryCode,
        syncToDevice: syncToDevice,
      ),
    );

    return WhatsAppContactCreateResult.fromJson(payload);
  }

  /// Ambil daftar kontak WhatsApp tersimpan.
  Future<List<WhatsAppContactModel>> listWhatsAppContacts() async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.fetchWhatsAppContacts(accessToken: accessToken),
    );

    final data = _asStringMap(payload['data']);
    final raw = data['contacts'];
    if (raw is! List) {
      return const <WhatsAppContactModel>[];
    }

    return raw
        .whereType<Map>()
        .map(
          (e) => WhatsAppContactModel.fromJson(
            e.map((k, v) => MapEntry(k.toString(), v)),
          ),
        )
        .toList();
  }

  Future<String> turnBotOn({required int conversationId}) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.turnBotOn(
        accessToken: accessToken,
        conversationId: conversationId,
      ),
    );

    final notice = payload['message']?.toString().trim();
    return (notice != null && notice.isNotEmpty)
        ? notice
        : 'Bot berhasil diaktifkan.';
  }

  Future<String> turnBotOff({
    required int conversationId,
    int autoResumeMinutes = 15,
  }) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.turnBotOff(
        accessToken: accessToken,
        conversationId: conversationId,
        autoResumeMinutes: autoResumeMinutes,
      ),
    );

    final notice = payload['message']?.toString().trim();
    return (notice != null && notice.isNotEmpty)
        ? notice
        : 'Bot berhasil dinonaktifkan sementara.';
  }

  Future<String> sendAdminContact({
    required int conversationId,
    required String fullName,
    required String phone,
    String? email,
    String? company,
  }) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.sendAdminContact(
        accessToken: accessToken,
        conversationId: conversationId,
        fullName: fullName,
        phone: phone,
        email: email,
        company: company,
      ),
    );

    final notice = payload['notice']?.toString().trim();
    if (notice != null && notice.isNotEmpty) {
      return notice;
    }

    return 'Kontak berhasil diproses.';
  }

  Future<OmnichannelCallActionResult> startConversationCall({
    required String conversationId,
    String callType = 'audio',
  }) async {
    return _performCallAction(() async {
      final accessToken = await _ensureAdminSession();
      return _apiService.startConversationCall(
        accessToken: accessToken,
        conversationId: conversationId,
        callType: callType,
      );
    }, fallbackMessage: 'Panggilan WhatsApp berhasil diproses.');
  }

  Future<OmnichannelCallActionResult> acceptConversationCall({
    required String conversationId,
  }) async {
    return _performCallAction(() async {
      final accessToken = await _ensureAdminSession();
      return _apiService.acceptConversationCall(
        accessToken: accessToken,
        conversationId: conversationId,
      );
    }, fallbackMessage: 'Panggilan WhatsApp diterima.');
  }

  Future<OmnichannelCallActionResult> rejectConversationCall({
    required String conversationId,
  }) async {
    return _performCallAction(() async {
      final accessToken = await _ensureAdminSession();
      return _apiService.rejectConversationCall(
        accessToken: accessToken,
        conversationId: conversationId,
      );
    }, fallbackMessage: 'Panggilan WhatsApp ditolak.');
  }

  Future<OmnichannelCallActionResult> endConversationCall({
    required String conversationId,
  }) async {
    return _performCallAction(() async {
      final accessToken = await _ensureAdminSession();
      return _apiService.endConversationCall(
        accessToken: accessToken,
        conversationId: conversationId,
      );
    }, fallbackMessage: 'Panggilan WhatsApp diakhiri.');
  }

  Future<OmnichannelCallActionResult> fetchConversationCallStatus({
    required String conversationId,
  }) async {
    return _performCallAction(() async {
      final accessToken = await _ensureAdminSession();
      return _apiService.fetchConversationCallStatus(
        accessToken: accessToken,
        conversationId: conversationId,
      );
    }, fallbackMessage: 'Status panggilan berhasil diperbarui.');
  }

  Future<OmnichannelCallReadinessModel> loadCallReadiness({
    bool forceRefresh = false,
  }) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.fetchCallReadiness(
        accessToken: accessToken,
        forceRefresh: forceRefresh,
      ),
    );

    final data = _extractPayloadData(payload);
    return OmnichannelCallReadinessModel.fromJson(data);
  }

  Future<Map<String, dynamic>> clearCallReadinessCache() async {
    final accessToken = await _ensureAdminSession();

    final payload = await _readWithRetry(
      () => _apiService.clearCallReadinessCache(accessToken: accessToken),
    );

    return _extractPayloadData(payload);
  }

  Future<OmnichannelCallActionResult> requestConversationCallPermission({
    required String conversationId,
    String callType = 'audio',
  }) async {
    return _performCallAction(() async {
      final accessToken = await _ensureAdminSession();
      return _apiService.requestConversationCallPermission(
        accessToken: accessToken,
        conversationId: conversationId,
        callType: callType,
      );
    }, fallbackMessage: 'Permintaan izin panggilan berhasil diproses.');
  }

  Future<OmnichannelCallAnalyticsSnapshotModel> loadCallAnalytics({
    int recentLimit = 8,
    String? finalStatus,
    String? callType,
  }) async {
    final accessToken = await _ensureAdminSession();
    final queryParameters = _buildCallAnalyticsQueryParameters(
      limit: recentLimit,
      finalStatus: finalStatus,
      callType: callType,
    );
    final results = await Future.wait<Object>(<Future<Object>>[
      _safeOptionalRead(
        () => _apiService.fetchCallAnalyticsSummary(
          accessToken: accessToken,
          queryParameters: queryParameters,
        ),
      ),
      _safeOptionalRead(
        () => _apiService.fetchRecentCalls(
          accessToken: accessToken,
          queryParameters: queryParameters,
        ),
      ),
    ]);

    return OmnichannelCallAnalyticsSnapshotModel.fromPayload(
      summaryPayload: _extractPayloadData(results[0] as Map<String, dynamic>),
      recentPayload: _extractPayloadData(results[1] as Map<String, dynamic>),
    );
  }

  Future<OmnichannelConversationCallHistoryModel> loadConversationCallHistory({
    required int conversationId,
    int limit = 20,
    String? finalStatus,
    String? callType,
  }) async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.fetchConversationCallHistory(
        accessToken: accessToken,
        conversationId: conversationId,
        queryParameters: _buildCallAnalyticsQueryParameters(
          limit: limit,
          finalStatus: finalStatus,
          callType: callType,
        ),
      ),
    );

    return OmnichannelConversationCallHistoryModel.fromPayload(
      _extractPayloadData(payload),
    );
  }

  Future<List<OmnichannelStatusUpdateModel>> loadStatusUpdates() async {
    final accessToken = await _ensureAdminSession();
    final payload = await _readWithRetry(
      () => _apiService.fetchStatusUpdates(accessToken: accessToken),
    );

    final data = _extractPayloadData(payload);
    final rawItems = data['my_statuses'] as List<dynamic>? ?? const <dynamic>[];

    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(OmnichannelStatusUpdateModel.fromJson)
        .toList(growable: false);
  }

  Future<OmnichannelStatusUpdateModel> createStatusUpdate({
    required String statusType,
    String? text,
    String? caption,
    String? backgroundColor,
    String? textColor,
    String? fontStyle,
    String? musicTitle,
    String? musicArtist,
    List<int>? fileBytes,
    String? fileName,
    String? mimeType,
  }) async {
    final accessToken = await _ensureAdminSession();

    final payload = await _readWithRetry(
      () => _apiService.createStatusUpdate(
        accessToken: accessToken,
        fields: <String, Object?>{
          'status_type': statusType,
          'text': text?.trim(),
          'caption': caption?.trim(),
          'background_color': backgroundColor?.trim(),
          'text_color': textColor?.trim(),
          'font_style': fontStyle?.trim(),
          'music_title': musicTitle?.trim(),
          'music_artist': musicArtist?.trim(),
        },
        fileBytes: fileBytes,
        fileName: fileName,
        mimeType: mimeType,
      ),
    );

    final data = _extractPayloadData(payload);
    final statusJson = data['status'];

    if (statusJson is! Map<String, dynamic>) {
      throw StateError('Payload status update tidak valid.');
    }

    return OmnichannelStatusUpdateModel.fromJson(statusJson);
  }

  Future<OmnichannelConversationSnapshotModel> _loadConversationSnapshot(
    int conversationId, {
    required String accessToken,
  }) async {
    final results = await Future.wait<Object>(<Future<Object>>[
      _readWithRetry(
        () => _apiService.fetchConversationDetail(
          accessToken: accessToken,
          conversationId: conversationId,
        ),
      ),
      _readWithRetry(
        () => _apiService.fetchThread(
          accessToken: accessToken,
          conversationId: conversationId,
        ),
      ),
      _safeOptionalRead(
        () => _apiService.fetchConversationPoll(
          accessToken: accessToken,
          conversationId: conversationId,
        ),
      ),
    ]);

    final detailPayload = results[0] as Map<String, dynamic>;
    final messagesPayload = results[1] as Map<String, dynamic>;
    final pollPayload = results[2] as Map<String, dynamic>;

    final conversation = OmnichannelConversationDetailModel.fromSources(
      detailPayload: detailPayload,
      pollPayload: pollPayload,
    );
    final threadGroups = OmnichannelThreadGroupModel.fromSources(
      messagesPayload: messagesPayload,
      pollPayload: pollPayload,
    );
    final insight = OmnichannelInsightModel.fromSources(
      detailPayload: detailPayload,
      messagesPayload: messagesPayload,
      pollPayload: pollPayload,
      conversation: conversation.id > 0 ? conversation : null,
    );

    return OmnichannelConversationSnapshotModel(
      conversation: conversation.id > 0 ? conversation : null,
      threadGroups: threadGroups,
      insight: insight,
    );
  }

  Future<String> _ensureAdminSession() {
    return _adminAuthRepository.requireAccessToken();
  }

  Future<OmnichannelCallActionResult> _performCallAction(
    Future<Map<String, dynamic>> Function() action, {
    required String fallbackMessage,
  }) async {
    try {
      final payload = await _readWithRetry(action);
      return OmnichannelCallActionResult.fromPayload(
        _normalizeCallPayload(payload),
        fallbackMessage: fallbackMessage,
      );
    } on ApiException catch (error) {
      return OmnichannelCallActionResult.fromPayload(
        _normalizeFailedCallPayload(error),
        defaultSuccess: false,
        fallbackMessage: error.message,
      );
    }
  }

  Future<Map<String, dynamic>> _safeOptionalRead(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    try {
      return await _readWithRetry(action);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        rethrow;
      }

      return <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> _readWithRetry(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    const attempts = 2;
    var currentAttempt = 0;

    while (true) {
      currentAttempt += 1;

      try {
        return await action();
      } on ApiException catch (error) {
        final shouldRetry =
            currentAttempt < attempts &&
            !error.isUnauthorized &&
            (error.isOffline ||
                (error.statusCode != null && error.statusCode! >= 500));

        if (!shouldRetry) {
          rethrow;
        }

        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }
  }
}

Map<String, Object?> _buildCallAnalyticsQueryParameters({
  int? limit,
  String? finalStatus,
  String? callType,
}) {
  return <String, Object?>{
    if (limit != null && limit > 0) 'limit': limit,
    if (finalStatus != null && finalStatus.trim().isNotEmpty)
      'final_status': finalStatus.trim(),
    if (callType != null && callType.trim().isNotEmpty)
      'call_type': callType.trim(),
  };
}

Map<String, dynamic> _extractPayloadData(Map<String, dynamic> payload) {
  final data = _asStringMap(payload['data']);
  return data.isNotEmpty ? data : payload;
}

Map<String, dynamic> _normalizeCallPayload(Map<String, dynamic> payload) {
  final data = _extractPayloadData(payload);
  if (data.isEmpty) {
    return payload;
  }

  return <String, dynamic>{
    ...data,
    if (!data.containsKey('success') && payload['success'] != null)
      'success': payload['success'],
    if (!data.containsKey('message') && payload['message'] != null)
      'message': payload['message'],
    if (!data.containsKey('meta_error') && payload['meta_error'] != null)
      'meta_error': payload['meta_error'],
    if (!data.containsKey('call_action') && payload['call_action'] != null)
      'call_action': payload['call_action'],
    if (!data.containsKey('permission_required') &&
        payload['permission_required'] != null)
      'permission_required': payload['permission_required'],
  };
}

Map<String, dynamic> _normalizeFailedCallPayload(ApiException error) {
  final payload = _asStringMap(error.payload);
  final normalized = _normalizeCallPayload(payload);

  if (normalized.isNotEmpty) {
    return <String, dynamic>{
      ...normalized,
      'success': false,
      'message': error.message,
    };
  }

  return <String, dynamic>{
    'success': false,
    'message': error.message,
    if (payload['call_action'] != null) 'call_action': payload['call_action'],
    if (payload['permission_required'] != null)
      'permission_required': payload['permission_required'],
    if (payload['meta_error'] != null) 'meta_error': payload['meta_error'],
  };
}

Map<String, dynamic> _asStringMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }

  return <String, dynamic>{};
}
