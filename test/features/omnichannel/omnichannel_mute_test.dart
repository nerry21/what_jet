import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_jet/core/network/api_endpoints.dart';
import 'package:what_jet/features/omnichannel/data/models/omnichannel_conversation_list_model.dart';
import 'package:what_jet/features/omnichannel/presentation/widgets/omnichannel_action_sheet.dart';

void main() {
  group('Mute conversation (BRIEF 3E)', () {
    test('mute/unmute endpoints build correct paths', () {
      expect(
        ApiEndpoints.adminConversationMute(7),
        endsWith('/conversations/7/mute'),
      );
      expect(
        ApiEndpoints.adminConversationUnmute(7),
        endsWith('/conversations/7/unmute'),
      );
    });

    test('fromJson parses is_muted (true / absent -> false)', () {
      final muted = OmnichannelConversationListItemModel.fromJson(
        <String, dynamic>{'id': 1, 'channel': 'whatsapp', 'is_muted': true},
      );
      expect(muted.isMuted, isTrue);

      final absent = OmnichannelConversationListItemModel.fromJson(
        <String, dynamic>{'id': 2, 'channel': 'whatsapp'},
      );
      expect(absent.isMuted, isFalse);
    });

    test('constructor defaults isMuted to false', () {
      final item = OmnichannelConversationListItemModel(
        id: 1,
        title: 'Conv 1',
        preview: '-',
        channel: 'whatsapp',
        statusLabel: 'Active',
        unreadCount: 0,
        lastActivityAt: DateTime(2026, 6, 22, 10),
        mergeKey: 'key-1',
      );
      expect(item.isMuted, isFalse);
    });

    testWidgets('action sheet tile toggles label by isMuted', (tester) async {
      var muteTapped = 0;

      Future<void> pump({required bool isMuted}) async {
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
                      isArchived: false,
                      onToggleArchive: () {},
                      isMuted: isMuted,
                      onToggleMute: () => muteTapped++,
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

      // isMuted=false -> tile "Bisukan"
      await pump(isMuted: false);
      expect(find.text('Bisukan'), findsOneWidget);
      expect(find.text('Bunyikan'), findsNothing);
      await tester.tap(find.text('Bisukan'));
      await tester.pumpAndSettle();
      expect(muteTapped, 1);

      // isMuted=true -> tile "Bunyikan"
      await pump(isMuted: true);
      expect(find.text('Bunyikan'), findsOneWidget);
      await tester.tap(find.text('Bunyikan'));
      await tester.pumpAndSettle();
      expect(muteTapped, 2);
    });
  });
}
