import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../data/models/omnichannel_conversation_detail_model.dart';
import '../../data/models/omnichannel_insight_model.dart';
import 'omnichannel_surface.dart';

class OmnichannelRightPane extends StatelessWidget {
  const OmnichannelRightPane({
    super.key,
    required this.conversation,
    required this.insight,
    required this.isLoading,
  });

  final OmnichannelConversationDetailModel? conversation;
  final OmnichannelInsightModel insight;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return OmnichannelPaneCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Customer & Insight',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? const _RightPaneSkeleton()
                : conversation == null
                ? const OmnichannelEmptyState(
                    icon: Icons.account_circle_outlined,
                    title: 'Belum ada profil aktif',
                    message:
                        'Pane kanan akan menampilkan profil customer, tags, dan insight ketika conversation dipilih.',
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      _ProfileCard(
                        customerName: insight.customerName,
                        customerContact: insight.customerContact,
                      ),
                      const SizedBox(height: 16),
                      _TagSection(
                        title: 'Conversation Tags',
                        tags: insight.conversationTags,
                      ),
                      const SizedBox(height: 16),
                      _TagSection(
                        title: 'Customer Tags',
                        tags: insight.customerTags,
                      ),
                      const SizedBox(height: 16),
                      _QuickDetailsCard(details: insight.quickDetails),
                      const SizedBox(height: 16),
                      _InsightNotesCard(noteLines: insight.noteLines),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.customerName,
    required this.customerContact,
  });

  final String customerName;
  final String customerContact;

  @override
  Widget build(BuildContext context) {
    final safeName = _safeText(customerName, fallback: 'Customer');
    final safeContact = _safeText(customerContact, fallback: '-');
    final initial = _safeInitial(safeName, fallback: 'C');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConfig.softBackground.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppConfig.softBackgroundAlt),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[AppConfig.green, AppConfig.greenLight],
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  safeName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  safeContact,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppConfig.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({required this.title, required this.tags});

  final String title;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return OmnichannelSectionCard(
      title: title,
      trailing: Text(
        '${tags.length}',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppConfig.subtleText,
        ),
      ),
      child: tags.isEmpty
          ? const Text(
              'Belum ada tag',
              style: TextStyle(fontSize: 13, color: AppConfig.subtleText),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => _TagChip(label: tag)).toList(),
            ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppConfig.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppConfig.green.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppConfig.green,
        ),
      ),
    );
  }
}

class _QuickDetailsCard extends StatelessWidget {
  const _QuickDetailsCard({required this.details});

  final Map<String, String> details;

  @override
  Widget build(BuildContext context) {
    return OmnichannelSectionCard(
      title: 'Quick Details',
      child: details.isEmpty
          ? const Text(
              'Belum ada detail',
              style: TextStyle(fontSize: 13, color: AppConfig.subtleText),
            )
          : Column(
              children: details.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppConfig.subtleText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _InsightNotesCard extends StatelessWidget {
  const _InsightNotesCard({required this.noteLines});

  final List<String> noteLines;

  @override
  Widget build(BuildContext context) {
    return OmnichannelSectionCard(
      title: 'Insight Panel',
      child: noteLines.isEmpty
          ? const Text(
              'Belum ada insight',
              style: TextStyle(fontSize: 13, color: AppConfig.subtleText),
            )
          : Column(
              children: noteLines.map((note) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          color: AppConfig.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          note,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppConfig.mutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _RightPaneSkeleton extends StatelessWidget {
  const _RightPaneSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppConfig.softBackground.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppConfig.softBackgroundAlt),
          ),
          child: const Row(
            children: <Widget>[
              OmnichannelSkeletonBlock(width: 54, height: 54, radius: 27),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    OmnichannelSkeletonBlock(width: 124, height: 16),
                    SizedBox(height: 8),
                    OmnichannelSkeletonBlock(width: 168, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...List<Widget>.generate(
          4,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 3 ? 0 : 16),
            child: OmnichannelSectionCard(
              title: 'Loading',
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  OmnichannelSkeletonBlock(height: 12),
                  SizedBox(height: 8),
                  OmnichannelSkeletonBlock(width: 140, height: 12),
                  SizedBox(height: 12),
                  OmnichannelSkeletonBlock(width: 92, height: 28, radius: 999),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _safeText(String? value, {required String fallback}) {
  final text = value?.trim();
  return (text == null || text.isEmpty) ? fallback : text;
}

String _safeInitial(String? value, {required String fallback}) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return fallback;
  }
  return text.characters.first.toUpperCase();
}
