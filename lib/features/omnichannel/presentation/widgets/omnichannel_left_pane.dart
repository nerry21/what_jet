import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import '../../data/models/omnichannel_conversation_list_model.dart';
import '../../data/models/omnichannel_workspace_model.dart';
import 'omnichannel_conversation_card.dart';
import 'omnichannel_new_chat_page.dart';
import 'omnichannel_surface.dart';

class OmnichannelLeftPane extends StatelessWidget {
  const OmnichannelLeftPane({
    super.key,
    required this.workspace,
    required this.items,
    required this.selectedConversationId,
    required this.scrollController,
    required this.searchController,
    required this.selectedScope,
    required this.selectedChannel,
    required this.onScopeChanged,
    required this.onChannelChanged,
    required this.onConversationTap,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    this.useMobileInboxLayout = false,
  });

  final OmnichannelWorkspaceModel workspace;
  final List<OmnichannelConversationListItemModel> items;
  final int? selectedConversationId;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final String selectedScope;
  final String selectedChannel;
  final ValueChanged<String> onScopeChanged;
  final ValueChanged<String> onChannelChanged;
  final ValueChanged<int> onConversationTap;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool useMobileInboxLayout;

  @override
  Widget build(BuildContext context) {
    if (useMobileInboxLayout) {
      return _MobileWhatsAppInbox(
        workspace: workspace,
        items: items,
        selectedConversationId: selectedConversationId,
        scrollController: scrollController,
        searchController: searchController,
        selectedScope: selectedScope,
        onScopeChanged: onScopeChanged,
        onConversationTap: onConversationTap,
        isLoading: isLoading,
        isLoadingMore: isLoadingMore,
        hasMore: hasMore,
      );
    }

    return OmnichannelPaneCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.of(context).size.height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Inbox Omnichannel',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: AppRadii.borderRadiusPill,
                      ),
                      child: Text(
                        '${workspace.unreadTotal} unread',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: isLoading
                      ? const _ConversationListSkeleton()
                      : CustomScrollView(
                          controller: scrollController,
                          primary: false,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: <Widget>[
                            SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  _SummaryStrip(
                                    workspace: workspace,
                                    isLoading: isLoading,
                                  ),
                                  const SizedBox(height: 16),
                                  _SearchField(
                                    controller: searchController,
                                    enabled: !isLoading,
                                  ),
                                  const SizedBox(height: 16),
                                  _FilterGroup(
                                    title: 'Scope',
                                    options: workspace.filters,
                                    selectedKey: selectedScope,
                                    onSelected: onScopeChanged,
                                    isLoading: isLoading,
                                  ),
                                  const SizedBox(height: 16),
                                  _FilterGroup(
                                    title: 'Channel',
                                    options: workspace.channels,
                                    selectedKey: selectedChannel,
                                    onSelected: onChannelChanged,
                                    isLoading: isLoading,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: <Widget>[
                                      const Expanded(
                                        child: Text(
                                          'Conversation',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${items.length}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.neutral300,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                            if (items.isEmpty)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 24),
                                    child: OmnichannelEmptyState(
                                      icon: Icons.inbox_outlined,
                                      title: 'Belum ada conversation',
                                      message:
                                          'Tidak ada conversation yang cocok dengan filter atau search yang aktif.',
                                    ),
                                  ),
                                ),
                              )
                            else
                              SliverList.separated(
                                itemCount:
                                    items.length +
                                    ((isLoadingMore || hasMore) ? 1 : 0),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  if (index >= items.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        top: 6,
                                        bottom: 10,
                                      ),
                                      child: Center(
                                        child: isLoadingMore
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: AppColors.primary,
                                                    ),
                                              )
                                            : const Text(
                                                'Scroll untuk memuat lagi',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.neutral300,
                                                ),
                                              ),
                                      ),
                                    );
                                  }

                                  final item = items[index];
                                  return OmnichannelConversationCard(
                                    item: item,
                                    selected: selectedConversationId == item.id,
                                    onTap: () => onConversationTap(item.id),
                                  );
                                },
                              ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 12),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.workspace, required this.isLoading});

  final OmnichannelWorkspaceModel workspace;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.primary.withValues(alpha: 0.10),
            AppColors.primary200.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: AppRadii.borderRadiusXxl,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Workspace Summary',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.neutral500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricTile(
                  label: 'Unread',
                  value: isLoading ? null : '${workspace.unreadTotal}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Aktif',
                  value: isLoading ? null : '${workspace.activeConversations}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Ringkasan ini mengikuti data workspace backend dan akan terus diperbarui lewat polling ringan.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
          ),
          const SizedBox(height: 8),
          if (value == null)
            const OmnichannelSkeletonBlock(width: 42, height: 22, radius: 8)
          else
            Text(
              value!,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground.withValues(alpha: 0.9),
        borderRadius: AppRadii.borderRadiusXl,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, color: AppColors.neutral300),
          hintText: 'Cari customer, preview, atau channel',
          hintStyle: TextStyle(color: AppColors.neutral300),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.title,
    required this.options,
    required this.selectedKey,
    required this.onSelected,
    required this.isLoading,
  });

  final String title;
  final List<OmnichannelFilterOptionModel> options;
  final String selectedKey;
  final ValueChanged<String> onSelected;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.neutral500,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: isLoading
              ? List<Widget>.generate(
                  4,
                  (_) => const OmnichannelSkeletonBlock(width: 92, height: 34),
                )
              : options.map((option) {
                  return _FilterChip(
                    label: option.label,
                    count: option.count,
                    active: selectedKey == option.key,
                    onTap: () => onSelected(option.key),
                  );
                }).toList(),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.borderRadiusPill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.scaffoldBackground.withValues(alpha: 0.9),
            borderRadius: AppRadii.borderRadiusPill,
            border: Border.all(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : AppColors.borderLight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.primary : AppColors.neutral500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : Colors.white,
                  borderRadius: AppRadii.borderRadiusPill,
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: active ? AppColors.primary : AppColors.neutral500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationListSkeleton extends StatelessWidget {
  const _ConversationListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.zero,
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.scaffoldBackground.withValues(alpha: 0.75),
            borderRadius: AppRadii.borderRadiusXl,
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Row(
                children: <Widget>[
                  OmnichannelSkeletonBlock(width: 42, height: 42, radius: 21),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        OmnichannelSkeletonBlock(width: 120),
                        SizedBox(height: 8),
                        OmnichannelSkeletonBlock(width: 88, height: 12),
                      ],
                    ),
                  ),
                  OmnichannelSkeletonBlock(width: 32, height: 12, radius: 8),
                ],
              ),
              SizedBox(height: 12),
              OmnichannelSkeletonBlock(height: 12),
              SizedBox(height: 8),
              OmnichannelSkeletonBlock(width: 180, height: 12),
              SizedBox(height: 14),
              Row(
                children: <Widget>[
                  OmnichannelSkeletonBlock(width: 76, height: 24, radius: 999),
                  SizedBox(width: 8),
                  OmnichannelSkeletonBlock(width: 96, height: 24, radius: 999),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MobileWhatsAppInbox extends StatelessWidget {
  const _MobileWhatsAppInbox({
    required this.workspace,
    required this.items,
    required this.selectedConversationId,
    required this.scrollController,
    required this.searchController,
    required this.selectedScope,
    required this.onScopeChanged,
    required this.onConversationTap,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
  });

  final OmnichannelWorkspaceModel workspace;
  final List<OmnichannelConversationListItemModel> items;
  final int? selectedConversationId;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final String selectedScope;
  final ValueChanged<String> onScopeChanged;
  final ValueChanged<int> onConversationTap;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final listBottomPadding = 102.0 + bottomInset;

    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFEDE6E2))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'WhatsApp',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.8,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        _MobileHeaderIcon(
                          icon: Icons.camera_alt_outlined,
                          onTap: () {},
                        ),
                        const SizedBox(width: 2),
                        _MobileHeaderIcon(
                          icon: Icons.more_vert_rounded,
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4EFEC),
                        borderRadius: AppRadii.borderRadiusPill,
                      ),
                      child: TextField(
                        controller: searchController,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(
                          fontSize: 17,
                          color: Colors.black87,
                        ),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 24,
                            color: Color(0xFF7C7B7A),
                          ),
                          hintText: 'Tanya Meta AI atau cari',
                          hintStyle: TextStyle(
                            color: Color(0xFF7C7B7A),
                            fontSize: 17,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: workspace.filters
                            .map(
                              (option) => Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _MobileScopeChip(
                                  label: option.label,
                                  count: option.count,
                                  selected: selectedScope == option.key,
                                  onTap: () => onScopeChanged(option.key),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isLoading
                    ? const _MobileWhatsAppListSkeleton()
                    : items.isEmpty
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          32,
                          20,
                          listBottomPadding,
                        ),
                        child: const OmnichannelEmptyState(
                          icon: Icons.inbox_outlined,
                          title: 'Belum ada chat',
                          message:
                              'Tidak ada conversation yang cocok dengan filter yang aktif.',
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          0,
                          2,
                          0,
                          listBottomPadding,
                        ),
                        itemCount:
                            items.length + ((isLoadingMore || hasMore) ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox.shrink(),
                        itemBuilder: (context, index) {
                          if (index >= items.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                              child: Center(
                                child: isLoadingMore
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : const Text(
                                        'Scroll untuk memuat lagi',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.neutral300,
                                        ),
                                      ),
                              ),
                            );
                          }

                          final item = items[index];
                          return _MobileWhatsAppConversationTile(
                            item: item,
                            selected:
                                selectedConversationId == item.id ||
                                (selectedConversationId == null && index == 0),
                            onTap: () => onConversationTap(item.id),
                          );
                        },
                      ),
              ),
              const _MobileWhatsAppBottomBar(),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 78 + bottomInset,
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
              elevation: 5,
              shadowColor: Colors.black.withValues(alpha: 0.24),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => OmnichannelNewChatPage(
                        items: items,
                        onConversationSelected: onConversationTap,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(18),
                child: const SizedBox(
                  width: 58,
                  height: 58,
                  child: Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileHeaderIcon extends StatelessWidget {
  const _MobileHeaderIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.borderRadiusPill,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, color: Colors.black87, size: 23),
        ),
      ),
    );
  }
}

class _MobileScopeChip extends StatelessWidget {
  const _MobileScopeChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.borderRadiusPill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE1F7DD) : Colors.white,
            borderRadius: AppRadii.borderRadiusPill,
            border: Border.all(
              color: selected
                  ? const Color(0xFFBFE8C2)
                  : const Color(0xFFE2DDDA),
            ),
          ),
          child: Text(
            '$label $count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF2F7D4B)
                  : const Color(0xFF4A4A4A),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileWhatsAppConversationTile extends StatelessWidget {
  const _MobileWhatsAppConversationTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final OmnichannelConversationListItemModel item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = (item.customerLabel ?? item.title).trim();
    final initial = _mobileConversationInitial(displayName);
    final avatarColors = _mobileConversationAvatarColors(displayName);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: selected ? const Color(0xFFEAF6EE) : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 11, 14, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: avatarColors,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            displayName.isEmpty ? item.title : displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatOmnichannelListTime(item.lastActivityAt),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF848484),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.done_all_rounded,
                          size: 18,
                          color: Color(0xFF8A8A8A),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF6E6E6E),
                            ),
                          ),
                        ),
                        if (item.unreadCount > 0) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 22),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: AppRadii.borderRadiusPill,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${item.unreadCount}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileWhatsAppBottomBar extends StatelessWidget {
  const _MobileWhatsAppBottomBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEDE6E2))),
        ),
        child: const Row(
          children: <Widget>[
            Expanded(
              child: _MobileBottomNavItem(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Chat',
                selected: true,
                badgeCount: 1,
              ),
            ),
            Expanded(
              child: _MobileBottomNavItem(
                icon: Icons.autorenew_rounded,
                label: 'Pembaruan',
              ),
            ),
            Expanded(
              child: _MobileBottomNavItem(
                icon: Icons.panorama_fish_eye_rounded,
                label: 'Meta AI',
              ),
            ),
            Expanded(
              child: _MobileBottomNavItem(
                icon: Icons.call_outlined,
                label: 'Panggilan',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileBottomNavItem extends StatelessWidget {
  const _MobileBottomNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? AppColors.primary : Colors.black87;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 48,
          height: 32,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Align(
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFDFF5E6)
                        : Colors.transparent,
                    borderRadius: AppRadii.borderRadiusLg,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 24, color: iconColor),
                ),
              ),
              if (badgeCount != null)
                Positioned(
                  right: 4,
                  top: -1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: AppRadii.borderRadiusPill,
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _MobileWhatsAppListSkeleton extends StatelessWidget {
  const _MobileWhatsAppListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 110),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox.shrink(),
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.fromLTRB(16, 11, 14, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              OmnichannelSkeletonBlock(width: 52, height: 52, radius: 26),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OmnichannelSkeletonBlock(
                            width: 140,
                            height: 16,
                          ),
                        ),
                        SizedBox(width: 8),
                        OmnichannelSkeletonBlock(width: 38, height: 12),
                      ],
                    ),
                    SizedBox(height: 10),
                    OmnichannelSkeletonBlock(width: 200, height: 14),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _mobileConversationInitial(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return 'C';
  }

  final words = text.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  if (words.length >= 2) {
    final first = words.first.characters.first.toUpperCase();
    final second = words.skip(1).first.characters.first.toUpperCase();
    return '$first$second';
  }

  return text.characters.first.toUpperCase();
}

List<Color> _mobileConversationAvatarColors(String value) {
  final text = value.trim();
  final seed = text.isEmpty ? 0 : text.characters.first.codeUnitAt(0);

  switch (seed % 4) {
    case 0:
      return const <Color>[Color(0xFF5B6C7B), Color(0xFF667A8A)];
    case 1:
      return const <Color>[Color(0xFF8D58E8), Color(0xFFB86BFF)];
    case 2:
      return const <Color>[Color(0xFF6B7280), Color(0xFF4B5563)];
    default:
      return const <Color>[Color(0xFF0EAD98), Color(0xFF17C3B2)];
  }
}
