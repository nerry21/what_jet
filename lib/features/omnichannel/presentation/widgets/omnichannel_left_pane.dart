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
                          color: AppColors.neutral800,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: AppRadii.borderRadiusPill,
                      ),
                      child: Text(
                        '${workspace.unreadTotal} unread',
                        style: TextStyle(
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
                                            color: AppColors.neutral800,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${items.length}',
                                        style: TextStyle(
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
                                      padding: EdgeInsets.only(
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
      padding: EdgeInsets.all(16),
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary.withValues(alpha: 0.78),
        borderRadius: AppRadii.borderRadiusLg,
        border: Border.all(color: AppColors.surfaceSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.neutral500),
          ),
          const SizedBox(height: 8),
          if (value == null)
            const OmnichannelSkeletonBlock(width: 42, height: 22, radius: 8)
          else
            Text(
              value!,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.neutral800,
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
          style: TextStyle(
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
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : AppColors.surfaceSecondary,
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
          padding: EdgeInsets.all(14),
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
    final listBottomPadding = 90.0 + bottomInset;

    return ColoredBox(
      color: AppColors.scaffoldBackground,
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              // ═══ PREMIUM HEADER ═══
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, 14, 16, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.surfaceSecondary,
                      AppColors.scaffoldBackground,
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Title row
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'WhatsJet',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Omnichannel Console',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.neutral400,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _PremiumHeaderIcon(
                          icon: Icons.search_rounded,
                          onTap: () {},
                        ),
                        const SizedBox(width: 6),
                        _PremiumHeaderIcon(
                          icon: Icons.more_vert_rounded,
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Search bar - dark glass style
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTertiary,
                        borderRadius: AppRadii.borderRadiusMd,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.06),
                        ),
                      ),
                      child: TextField(
                        controller: searchController,
                        textInputAction: TextInputAction.search,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.neutral800,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: AppColors.neutral300,
                          ),
                          hintText: 'Cari percakapan...',
                          hintStyle: TextStyle(
                            color: AppColors.neutral300,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Scope chips with glow
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: workspace.filters
                            .map(
                              (option) => Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: _PremiumScopeChip(
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

              // ═══ CONVERSATION LIST ═══
              Expanded(
                child: isLoading
                    ? const _PremiumListSkeleton()
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
                    : ListView.builder(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          0,
                          4,
                          0,
                          listBottomPadding,
                        ),
                        itemCount:
                            items.length + ((isLoadingMore || hasMore) ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= items.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                              child: Center(
                                child: isLoadingMore
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : Text(
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
                          return _PremiumConversationTile(
                            item: item,
                            selected:
                                selectedConversationId == item.id ||
                                (selectedConversationId == null && index == 0),
                            onTap: () => onConversationTap(item.id),
                          );
                        },
                      ),
              ),

              // Bottom nav removed — using top _MobilePaneSelector only
            ],
          ),

          // ═══ FAB with glow ring ═══
          Positioned(
            right: 18,
            bottom: 18 + bottomInset,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
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
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primary700],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      color: AppColors.white,
                      size: 26,
                    ),
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

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM HEADER ICON — Rounded dark glass button
// ═══════════════════════════════════════════════════════════════════════════

class _PremiumHeaderIcon extends StatelessWidget {
  const _PremiumHeaderIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surfaceTertiary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.06),
            ),
          ),
          child: Icon(icon, color: AppColors.neutral500, size: 20),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM SCOPE CHIP — With emerald glow on active
// ═══════════════════════════════════════════════════════════════════════════

class _PremiumScopeChip extends StatelessWidget {
  const _PremiumScopeChip({
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceTertiary,
          borderRadius: AppRadii.borderRadiusPill,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderLight,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.white : AppColors.neutral500,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM CONVERSATION TILE — Rounded avatar, glow badge, status dot
// ═══════════════════════════════════════════════════════════════════════════

class _PremiumConversationTile extends StatelessWidget {
  const _PremiumConversationTile({
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
    final avatarColors = _premiumAvatarColors(displayName);
    final hasUnread = item.unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 14, 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.06)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: AppColors.borderLight.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Avatar with rounded corners + glow
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: avatarColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: avatarColors.last.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            displayName.isEmpty ? item.title : displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AppColors.neutral800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatOmnichannelListTime(item.lastActivityAt),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: hasUnread
                                ? AppColors.primary
                                : AppColors.neutral400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.done_all_rounded,
                          size: 16,
                          color: hasUnread
                              ? AppColors.primary
                              : AppColors.neutral300,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.neutral400,
                            ),
                          ),
                        ),
                        if (hasUnread) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 22),
                            padding: EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary700,
                                ],
                              ),
                              borderRadius: AppRadii.borderRadiusPill,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${item.unreadCount}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
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

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM BOTTOM BAR — Dark glass with emerald active indicator
// ═══════════════════════════════════════════════════════════════════════════

class _PremiumListSkeleton extends StatelessWidget {
  const _PremiumListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(0, 4, 0, 110),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.surfaceTertiary,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 140,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTertiary,
                        borderRadius: AppRadii.borderRadiusSm,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 200,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTertiary,
                        borderRadius: AppRadii.borderRadiusSm,
                      ),
                    ),
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

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM AVATAR COLORS — More vibrant gradient pairs
// ═══════════════════════════════════════════════════════════════════════════

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

List<Color> _premiumAvatarColors(String value) {
  final text = value.trim();
  final seed = text.isEmpty ? 0 : text.characters.first.codeUnitAt(0);

  switch (seed % 6) {
    case 0:
      return const <Color>[Color(0xFF00A86B), Color(0xFF006B44)]; // Emerald
    case 1:
      return const <Color>[Color(0xFF9B7FDB), Color(0xFF6B4FB8)]; // Purple
    case 2:
      return const <Color>[Color(0xFF4A9EF5), Color(0xFF2563EB)]; // Blue
    case 3:
      return const <Color>[Color(0xFFE85454), Color(0xFFC02424)]; // Coral
    case 4:
      return const <Color>[Color(0xFFF5A623), Color(0xFFD48806)]; // Amber
    default:
      return const <Color>[Color(0xFF2DD89A), Color(0xFF00A86B)]; // Mint
  }
}
