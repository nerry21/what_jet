import 'omnichannel_conversation_detail_model.dart';
import 'omnichannel_conversation_list_model.dart';
import 'omnichannel_insight_model.dart';
import 'omnichannel_thread_model.dart';
import 'omnichannel_workspace_model.dart';

class OmnichannelShellSnapshotModel {
  const OmnichannelShellSnapshotModel({
    required this.workspace,
    required this.conversationList,
    required this.selectedConversation,
    required this.threadGroups,
    required this.insight,
  });

  final OmnichannelWorkspaceModel workspace;
  final OmnichannelConversationListModel conversationList;
  final OmnichannelConversationDetailModel? selectedConversation;
  final List<OmnichannelThreadGroupModel> threadGroups;
  final OmnichannelInsightModel insight;
}

class OmnichannelConversationSnapshotModel {
  const OmnichannelConversationSnapshotModel({
    required this.conversation,
    required this.threadGroups,
    required this.insight,
  });

  final OmnichannelConversationDetailModel? conversation;
  final List<OmnichannelThreadGroupModel> threadGroups;
  final OmnichannelInsightModel insight;
}
