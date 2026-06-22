import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_jet/core/network/api_endpoints.dart';
import 'package:what_jet/features/omnichannel/data/models/omnichannel_conversation_list_model.dart';
import 'package:what_jet/features/omnichannel/presentation/widgets/omnichannel_action_sheet.dart';

void main() {
  group('Archive conversation (BRIEF 3D)', () {
    test('archive/unarchive endpoints build correct paths', () {
      expect(
        ApiEndpoints.adminConversationArchive(7),
        endsWith('/conversations/7/archive'),
      );
      expect(
        ApiEndpoints.adminConversationUnarchive(7),
        endsWith('/conversations/7/unarchive'),
      );
    });

    test(
      'fromJson status_label Archived -> statusLabel lowercases to archived',
      () {
        final item = OmnichannelConversationListItemModel.fromJson(
          <String, dynamic>{
            'id': 1,
            'channel': 'whatsapp',
            'status_label': 'Archived',
          },
        );
        expect(item.statusLabel.trim().toLowerCase(), 'archived');
      },
    );

    testWidgets('action sheet tile toggles label by isArchived', (
      tester,
    ) async {
      var archivedTapped = 0;

      Future<void> pump({required bool isArchived}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => showConversationActionSheet(
                      context: context,
                      onMarkUnread: () {},
                      onManageLabel: () {},
                      isPinned: false,
                      onTogglePin: () {},
                      isArchived: isArchived,
                      onToggleArchive: () => archivedTapped++,
                    ),
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      // isArchived=false -> tile "Arsip"
      await pump(isArchived: false);
      expect(find.text('Arsip'), findsOneWidget);
      expect(find.text('Batalkan arsip'), findsNothing);
      await tester.tap(find.text('Arsip'));
      await tester.pumpAndSettle();
      expect(archivedTapped, 1);

      // isArchived=true -> tile "Batalkan arsip"
      await pump(isArchived: true);
      expect(find.text('Batalkan arsip'), findsOneWidget);
      await tester.tap(find.text('Batalkan arsip'));
      await tester.pumpAndSettle();
      expect(archivedTapped, 2);
    });
  });
}
