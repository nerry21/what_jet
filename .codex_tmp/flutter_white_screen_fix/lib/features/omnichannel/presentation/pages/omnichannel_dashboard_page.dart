import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../admin_auth/data/models/admin_user_model.dart';
import '../../../admin_auth/data/repositories/admin_auth_repository.dart';
import '../../data/models/omnichannel_conversation_list_model.dart';
import '../../data/models/omnichannel_workspace_model.dart';
import '../../data/repositories/omnichannel_repository.dart';
import '../controllers/omnichannel_shell_controller.dart';
import '../widgets/omnichannel_center_pane.dart';
import '../widgets/omnichannel_left_pane.dart';
import '../widgets/omnichannel_right_pane.dart';
import '../widgets/omnichannel_shell_header.dart';
import '../widgets/omnichannel_surface.dart';

class OmnichannelDashboardPage extends StatefulWidget {
  const OmnichannelDashboardPage({
    super.key,
    required this.repository,
    required this.adminAuthRepository,
    this.initialUser,
  });

  final OmnichannelRepository repository;
  final AdminAuthRepository adminAuthRepository;
  final AdminUserModel? initialUser;

  @override
  State<OmnichannelDashboardPage> createState() =>
      _OmnichannelDashboardPageState();
}

class _OmnichannelDashboardPageState extends State<OmnichannelDashboardPage>
    with WidgetsBindingObserver {
  late final OmnichannelShellController _controller;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _conversationListScrollController = ScrollController();
  bool _hasRedirected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = OmnichannelShellController(
      repository: widget.repository,
      adminAuthRepository: widget.adminAuthRepository,
    )..addListener(_handleControllerChanged);

    _searchController.addListener(_handleSearchChanged);
    _conversationListScrollController.addListener(_handleListScroll);
    unawaited(_controller.initialize(initialUser: widget.initialUser));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _searchController.removeListener(_handleSearchChanged);
    _conversationListScrollController.removeListener(_handleListScroll);
    _searchController.dispose();
    _conversationListScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    _controller.setPageActive(isActive);
  }

  void _handleSearchChanged() {
    _controller.setSearchQuery(_searchController.text);
  }

  void _handleListScroll() {
    if (!_conversationListScrollController.hasClients) {
      return;
    }

    final position = _conversationListScrollController.position;
    if (position.maxScrollExtent - position.pixels <= 240) {
      unawaited(_controller.loadMoreConversations());
    }
  }

  void _handleControllerChanged() {
    if (!_controller.requiresLogin || _hasRedirected || !mounted) {
      return;
    }

    _hasRedirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacementNamed(AppRoutes.adminLogin);
    });
  }

  Future<void> _retryBootstrap() {
    _hasRedirected = false;
    return _controller.initialize(initialUser: widget.initialUser);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.softBackground,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final shellLoading =
                _controller.isLoading && !_controller.hasShellData;
            final showFatalError =
                _controller.errorMessage != null &&
                !_controller.hasShellData &&
                !shellLoading &&
                !_controller.requiresLogin;
            final workspace =
                _controller.workspace ??
                OmnichannelWorkspaceModel.placeholder();
            final conversationList = _controller.conversationList;

            if (showFatalError) {
              return Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppConfig.softBackground,
                      AppConfig.softBackgroundAlt,
                    ],
                  ),
                ),
                child: OmnichannelErrorState(
                  title: 'Dashboard admin belum siap',
                  message: _controller.errorMessage!,
                  onRetry: _retryBootstrap,
                ),
              );
            }

            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppConfig.softBackground,
                    AppConfig.softBackgroundAlt,
                  ],
                ),
              ),
              child: Column(
                children: <Widget>[
                  OmnichannelShellHeader(
                    currentUser: _controller.currentUser,
                    isLoggingOut: _controller.isLoggingOut,
                    onLogout: () => unawaited(_controller.logout()),
                  ),
                  if (_controller.errorMessage != null && _controller.hasShellData)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: OmnichannelInlineBanner(
                        message: _controller.errorMessage!,
                        onRetry: _controller.isRefreshing
                            ? () async {}
                            : _controller.refresh,
                      ),
                    ),
                  if (_controller.isRefreshing || _controller.isConversationLoading)
                    const LinearProgressIndicator(
                      minHeight: 2,
                      color: AppConfig.green,
                      backgroundColor: Colors.transparent,
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final gap = constraints.maxWidth >= 1440 ? 20.0 : 16.0;
                          final leftWidth =
                              constraints.maxWidth >= 1440 ? 360.0 : 336.0;
                          final rightWidth =
                              constraints.maxWidth >= 1440 ? 340.0 : 320.0;
                          final minShellWidth =
                              leftWidth + rightWidth + 540 + (gap * 2);

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: max(constraints.maxWidth, minShellWidth),
                                minHeight: constraints.maxHeight,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  SizedBox(
                                    width: leftWidth,
                                    child: OmnichannelLeftPane(
                                      workspace: workspace,
                                      items:
                                          conversationList?.items ??
                                          const <OmnichannelConversationListItemModel>[],
                                      selectedConversationId:
                                          conversationList?.selectedConversationId,
                                      scrollController:
                                          _conversationListScrollController,
                                      searchController: _searchController,
                                      selectedScope: _controller.scopeFilter,
                                      selectedChannel:
                                          _controller.channelFilter,
                                      onScopeChanged:
                                          _controller.setScopeFilter,
                                      onChannelChanged:
                                          _controller.setChannelFilter,
                                      onConversationTap: (conversationId) =>
                                          unawaited(
                                            _controller.selectConversation(
                                              conversationId,
                                            ),
                                          ),
                                      isLoading: shellLoading,
                                      isLoadingMore:
                                          _controller.isLoadingMore,
                                      hasMore: _controller.hasMoreConversations,
                                    ),
                                  ),
                                  SizedBox(width: gap),
                                  Expanded(
                                    child: OmnichannelCenterPane(
                                      conversation:
                                          _controller.selectedConversation,
                                      threadGroups: _controller.threadGroups,
                                      isShellLoading: shellLoading,
                                      isConversationLoading:
                                          _controller.isConversationLoading,
                                    ),
                                  ),
                                  SizedBox(width: gap),
                                  SizedBox(
                                    width: rightWidth,
                                    child: OmnichannelRightPane(
                                      conversation:
                                          _controller.selectedConversation,
                                      insight: _controller.insight,
                                      isLoading: shellLoading,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
