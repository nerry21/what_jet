import 'package:flutter_test/flutter_test.dart';
import 'package:what_jet/core/network/api_endpoints.dart';
import 'package:what_jet/features/omnichannel/data/models/omnichannel_conversation_list_model.dart';

OmnichannelConversationListItemModel _item({
  required int id,
  required DateTime lastActivityAt,
  bool isPinned = false,
}) {
  return OmnichannelConversationListItemModel(
    id: id,
    title: 'Conv $id',
    preview: '-',
    channel: 'whatsapp',
    statusLabel: 'Active',
    unreadCount: 0,
    lastActivityAt: lastActivityAt,
    mergeKey: 'key-$id',
    isPinned: isPinned,
  );
}

OmnichannelConversationListModel _list(
  List<OmnichannelConversationListItemModel> items,
) {
  return OmnichannelConversationListModel(
    items: items,
    page: 1,
    perPage: 20,
    total: items.length,
    selectedConversationId: null,
  );
}

void main() {
  group('Pin conversation (BRIEF 3C)', () {
    test('fromJson parses is_pinned (true / absent -> false)', () {
      final pinned = OmnichannelConversationListItemModel.fromJson(
        <String, dynamic>{'id': 1, 'channel': 'whatsapp', 'is_pinned': true},
      );
      expect(pinned.isPinned, isTrue);

      final absent = OmnichannelConversationListItemModel.fromJson(
        <String, dynamic>{'id': 2, 'channel': 'whatsapp'},
      );
      expect(absent.isPinned, isFalse);
    });

    test('pinned rises above newer unpinned (comparator pin-aware)', () {
      final newer = _item(id: 1, lastActivityAt: DateTime(2026, 6, 22, 10));
      final olderPinned = _item(
        id: 2,
        lastActivityAt: DateTime(2026, 6, 22, 8),
        isPinned: true,
      );

      final merged = _list(const <OmnichannelConversationListItemModel>[])
          .mergePoll(
            _list(<OmnichannelConversationListItemModel>[newer, olderPinned]),
          );

      expect(merged.items.first.id, 2);
    });

    test('without pin, order stays lastActivityAt desc (baseline identik)', () {
      final newer = _item(id: 1, lastActivityAt: DateTime(2026, 6, 22, 10));
      final older = _item(id: 2, lastActivityAt: DateTime(2026, 6, 22, 8));

      final merged = _list(
        const <OmnichannelConversationListItemModel>[],
      ).mergePoll(_list(<OmnichannelConversationListItemModel>[older, newer]));

      expect(merged.items.first.id, 1);
    });

    test('mergePoll keeps pinned on top when newer unpinned arrives', () {
      final pinnedOld = _item(
        id: 2,
        lastActivityAt: DateTime(2026, 6, 22, 8),
        isPinned: true,
      );
      final newerUnpinned = _item(
        id: 1,
        lastActivityAt: DateTime(2026, 6, 22, 12),
      );

      final merged = _list(
        <OmnichannelConversationListItemModel>[pinnedOld],
      ).mergePoll(_list(<OmnichannelConversationListItemModel>[newerUnpinned]));

      expect(merged.items.first.id, 2);
      expect(merged.items.first.isPinned, isTrue);
    });

    test('pin/unpin endpoints build correct paths', () {
      expect(
        ApiEndpoints.adminConversationPin(42),
        endsWith('/conversations/42/pin'),
      );
      expect(
        ApiEndpoints.adminConversationUnpin(42),
        endsWith('/conversations/42/unpin'),
      );
    });
  });
}
