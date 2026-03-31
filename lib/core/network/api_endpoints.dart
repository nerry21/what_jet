class ApiEndpoints {
  const ApiEndpoints._();

  static const String _mobileAuthBase = '/api/mobile/auth';
  static const String _mobileLiveChatBase = '/api/mobile/live-chat';
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

  static String adminConversationDetail(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId';

  static String adminConversationMessages(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/messages';

  static String adminConversationPoll(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/poll';

  static String adminConversationReply(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/reply';

  static String adminConversationSendContact(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/send-contact';

  static String adminConversationBotControl(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/bot-control';

  static String adminConversationBotOn(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/bot-control/on';

  static String adminConversationBotOff(int conversationId) =>
      '$_adminMobileBase/conversations/$conversationId/bot-control/off';

  static String adminPollList() => '$_adminMobileBase/poll/list';

  static String adminDashboardSummary() =>
      '$_adminMobileBase/dashboard/summary';

  static String adminMetaFilters() => '$_adminMobileBase/meta/filters';

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
}
