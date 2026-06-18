import 'package:flutter_test/flutter_test.dart';

import 'package:what_jet/features/omnichannel/data/models/omnichannel_thread_model.dart';

void main() {
  group('OmnichannelReactions.fromJson', () {
    test('null value returns null', () {
      expect(OmnichannelReactions.fromJson(null), isNull);
    });

    test('non-map value returns null', () {
      expect(OmnichannelReactions.fromJson('not-a-map'), isNull);
    });

    test('empty map returns null', () {
      expect(OmnichannelReactions.fromJson(<String, dynamic>{}), isNull);
    });

    test('both actors null returns null', () {
      expect(
        OmnichannelReactions.fromJson(<String, dynamic>{
          'customer': null,
          'admin': null,
        }),
        isNull,
      );
    });

    test('empty admin string returns null', () {
      expect(
        OmnichannelReactions.fromJson(<String, dynamic>{'admin': ''}),
        isNull,
      );
    });

    test('admin only sets admin, customer null', () {
      final reactions = OmnichannelReactions.fromJson(<String, dynamic>{
        'admin': '👍',
      });
      expect(reactions, isNotNull);
      expect(reactions!.admin, '👍');
      expect(reactions.customer, isNull);
    });

    test('customer only sets customer, admin null', () {
      final reactions = OmnichannelReactions.fromJson(<String, dynamic>{
        'customer': '😄',
      });
      expect(reactions, isNotNull);
      expect(reactions!.customer, '😄');
      expect(reactions.admin, isNull);
    });

    test('both actors set', () {
      final reactions = OmnichannelReactions.fromJson(<String, dynamic>{
        'customer': '😄',
        'admin': '👍',
      });
      expect(reactions, isNotNull);
      expect(reactions!.admin, '👍');
      expect(reactions.customer, '😄');
    });
  });
}
