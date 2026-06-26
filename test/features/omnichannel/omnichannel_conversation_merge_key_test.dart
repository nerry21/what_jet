import 'package:flutter_test/flutter_test.dart';
import 'package:what_jet/features/omnichannel/data/models/omnichannel_conversation_list_model.dart';

Map<String, dynamic> _json({
  required int id,
  required String lastActivityAt,
  String channel = 'whatsapp',
  String? customerLabel,
  String? customerPhone,
  String? mergeKey,
}) {
  return <String, dynamic>{
    'id': id,
    'channel': channel,
    'last_activity_at': lastActivityAt,
    if (customerLabel != null) 'customer_label': customerLabel,
    if (customerPhone != null) 'customer_phone_e164': customerPhone,
    if (mergeKey != null) 'merge_key': mergeKey,
  };
}

void main() {
  group('OmnichannelConversationListItemModel merge-key (BRIEF #1-FIX)', () {
    test('(a) dua "Customer" beda-id TAK tertimpa (mergeKey unik per id)', () {
      final a = _json(
        id: 101,
        lastActivityAt: '2026-06-26T10:00:00+07:00',
        customerLabel: 'Customer',
      );
      final b = _json(
        id: 202,
        lastActivityAt: '2026-06-26T11:00:00+07:00',
        customerLabel: 'Customer',
      );

      final itemA = OmnichannelConversationListItemModel.fromJson(a);
      final itemB = OmnichannelConversationListItemModel.fromJson(b);

      expect(itemA.mergeKey, 'whatsapp:conversation:101');
      expect(itemB.mergeKey, 'whatsapp:conversation:202');
      expect(itemA.mergeKey == itemB.mergeKey, isFalse);

      final list = OmnichannelConversationListModel.fromSources(
        conversationsPayload: <String, dynamic>{
          'conversations': <Map<String, dynamic>>[a, b],
        },
      );
      expect(list.items.length, 2);
    });

    test('(b) phone sama TETAP merge (mergeKey by phone)', () {
      final a = _json(
        id: 301,
        lastActivityAt: '2026-06-26T10:00:00+07:00',
        customerPhone: '+628111',
      );
      final b = _json(
        id: 302,
        lastActivityAt: '2026-06-26T11:00:00+07:00',
        customerPhone: '+628111',
      );

      final itemA = OmnichannelConversationListItemModel.fromJson(a);
      final itemB = OmnichannelConversationListItemModel.fromJson(b);

      expect(itemA.mergeKey, 'whatsapp:phone:+628111');
      expect(itemA.mergeKey, itemB.mergeKey);

      final list = OmnichannelConversationListModel.fromSources(
        conversationsPayload: <String, dynamic>{
          'conversations': <Map<String, dynamic>>[a, b],
        },
      );
      expect(list.items.length, 1);
    });

    test('(c) merge_key BE diprioritaskan (fallback tak terpicu)', () {
      final json = _json(
        id: 401,
        lastActivityAt: '2026-06-26T10:00:00+07:00',
        customerLabel: 'Customer',
        mergeKey: 'phone:+62999',
      );

      final item = OmnichannelConversationListItemModel.fromJson(json);
      expect(item.mergeKey, 'phone:+62999');
    });
  });
}
