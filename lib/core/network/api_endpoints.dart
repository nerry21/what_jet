class ApiEndpoints {
  const ApiEndpoints._();

  static const String _mobileAuthBase = '/api/mobile/auth';
  static const String _mobileLiveChatBase = '/api/mobile/live-chat';
  static const String _mobileStatusFeedBase = '/api/mobile/status-feed';
  static const String _adminMobileAuthBase = '/api/admin-mobile/auth';
  static const String _adminMobileBase = '/api/admin-mobile';

  static String register() => '$_mobileAuthBase/register';

  static String login() => '$_mobileAuthBase/login';

  static String me() => '$_mobileAuthBase/me';

  static String logout() => '$_mobileAuthBase/logout';

  static String adminLogin() => '$_adminMobileAuthBase/login';

  static String adminLogout() => '$_adminMobileAuthBase/logout';

  static String adminMe() => '$_adminMobileAuthBase/me';

  static String adminWorkspace() => '$_adminMobileBase/workspace';

  static String adminConversations() => '$_adminMobileBase/conversations';

  static String adminStickerFavorites() =>
      '$_adminMobileBase/sticker-favorites';

  static String adminConversationDetail(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId';

  static String adminConversationMessages(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/messages';

  static String adminConversationPoll(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/poll';

  static String adminConversationReply(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/reply';

  static String adminConversationCarousel(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/send-carousel';

  static String adminConversationPayment(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/send-payment';

  static String adminConversationMarkRead(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/mark-read';

  static String adminConversationMarkUnread(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/mark-unread';

  static String adminConversationPin(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/pin';

  static String adminConversationUnpin(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/unpin';

  static String adminConversationArchive(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/archive';

  static String adminConversationUnarchive(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/unarchive';

  static String adminConversationMute(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/mute';

  static String adminConversationUnmute(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/unmute';

  static String adminConversationTags(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/tags';

  static String adminConversationReadReceipt(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/read-receipt';

  static String adminConversationTyping(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/typing';

  static String adminConversationReaction(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/reaction';

  static String adminConversationMessageStar(
    int conversationId,
    int messageId,
  ) =>
      '$_adminMobileBase/conversations/$conversationId/messages/$messageId/star';

  static String adminConversationMessageUnstar(
    int conversationId,
    int messageId,
  ) =>
      '$_adminMobileBase/conversations/$conversationId/messages/$messageId/unstar';

  static String adminConversationMessageForward(
    int conversationId,
    int messageId,
  ) =>
      '$_adminMobileBase/conversations/$conversationId/messages/$messageId/forward';

  static String adminConversationSendContact(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/send-contact';

  static String adminConversationSendFavorite(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/send-favorite';

  static String adminConversationBotControl(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/bot-control';

  static String adminConversationBotOn(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/bot-control/on';

  static String adminConversationBotOff(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/bot-control/off';

  static String adminConversationCallStart(String conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/call/start';

  static String adminConversationCallAccept(String conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/call/accept';

  static String adminConversationCallReject(String conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/call/reject';

  static String adminConversationCallEnd(String conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/call/end';

  static String adminConversationCallStatus(String conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/call/status';

  static String adminConversationCallRequestPermission(String conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/call/request-permission';

  static String adminConversationCallHistory(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/call-history';

  static String adminCallReadiness() => '$_adminMobileBase/call/readiness';

  static String adminCallReadinessClearCache() =>
      '$_adminMobileBase/call/readiness/clear-cache';

  static String adminStatusUpdates() => '$_adminMobileBase/status-updates';

  static String adminStarredMessages() => '$_adminMobileBase/starred-messages';

  static String adminStatusUpdateDetail(int statusId) =>
      '$_adminMobileBase/status-updates/$statusId';

  static String adminPollList() => '$_adminMobileBase/poll/list';

  static String adminDashboardSummary() =>
      '$_adminMobileBase/dashboard/summary';

  static String adminCallAnalyticsSummary() =>
      '$_adminMobileBase/call-analytics/summary';

  static String adminCallAnalyticsRecent() =>
      '$_adminMobileBase/call-analytics/recent';

  static String adminMetaFilters() => '$_adminMobileBase/meta/filters';

  // ─── WhatsApp Contacts (address book) ────────────────────────────────
  static String adminContacts() => '$_adminMobileBase/contacts';

  // ─── Device FCM Token (Push Notification) ────────────────────────────
  static String adminDeviceTokenRegister() =>
      '$_adminMobileBase/device-token/register';
  static String adminDeviceTokenUnregister() =>
      '$_adminMobileBase/device-token/unregister';

  static String startConversation() => '$_mobileLiveChatBase/start';

  static String conversations() => '$_mobileLiveChatBase/conversations';

  static String conversationDetail(int conversationId) =>
      '$_mobileLiveChatBase/conversations/$conversationId';

  static String conversationMessages(int conversationId) =>
      '$_mobileLiveChatBase/conversations/$conversationId/messages';

  static String pollConversation(int conversationId) =>
      '$_mobileLiveChatBase/conversations/$conversationId/poll';

  static String sendMessage(int conversationId) =>
      '$_mobileLiveChatBase/conversations/$conversationId/messages';

  static String markRead(int conversationId) =>
      '$_mobileLiveChatBase/conversations/$conversationId/mark-read';

  static String customerStatusFeed() => _mobileStatusFeedBase;

  static String customerStatusDetail(int statusId) =>
      '$_mobileStatusFeedBase/$statusId';

  static String customerStatusMarkViewed(int statusId) =>
      '$_mobileStatusFeedBase/$statusId/view';
}
