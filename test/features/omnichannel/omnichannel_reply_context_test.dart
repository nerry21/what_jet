import 'package:flutter_test/flutter_test.dart';

import 'package:what_jet/features/omnichannel/data/models/omnichannel_thread_model.dart';

void main() {
  Map<String, dynamic> baseMessage(Map<String, dynamic> extra) {
    return <String, dynamic>{
      'id': 101,
      'message_type': 'text',
      'text': 'Halo',
      ...extra,
    };
  }

  group('OmnichannelReplyContext.fromJson (Wave 2B-4b)', () {
    test('1. reply_context with 4 fields populated parses non-null', () {
      final message = OmnichannelThreadMessageModel.fromJson(
        baseMessage(<String, dynamic>{
          'reply_context': <String, dynamic>{
            'quoted_message_id': 42,
            'quoted_type': 'text',
            'quoted_direction': 'inbound',
            'quoted_text_preview': 'pesan asli',
          },
        }),
      );

      final reply = message.replyContext;
      expect(reply, isNotNull);
      expect(reply!.quotedMessageId, 42);
      expect(reply.quotedType, 'text');
      expect(reply.quotedDirection, 'inbound');
      expect(reply.quotedTextPreview, 'pesan asli');
    });

    test('2. reply_context absent -> null', () {
      final message = OmnichannelThreadMessageModel.fromJson(
        baseMessage(const <String, dynamic>{}),
      );
      expect(message.replyContext, isNull);
    });

    test('3. reply_context explicit null -> null', () {
      final message = OmnichannelThreadMessageModel.fromJson(
        baseMessage(<String, dynamic>{'reply_context': null}),
      );
      expect(message.replyContext, isNull);
    });

    test('4. reply_context non-map -> null (graceful)', () {
      for (final corrupt in <Object>[
        'oops',
        42,
        <int>[1, 2],
      ]) {
        final message = OmnichannelThreadMessageModel.fromJson(
          baseMessage(<String, dynamic>{'reply_context': corrupt}),
        );
        expect(message.replyContext, isNull, reason: 'corrupt=$corrupt');
      }
    });

    test(
      '5. quoted_message_id null + preview present -> non-null pass-through',
      () {
        final message = OmnichannelThreadMessageModel.fromJson(
          baseMessage(<String, dynamic>{
            'reply_context': <String, dynamic>{
              'quoted_message_id': null,
              'quoted_text_preview': 'cuma preview',
            },
          }),
        );

        final reply = message.replyContext;
        expect(reply, isNotNull);
        expect(reply!.quotedMessageId, isNull);
        expect(reply.quotedTextPreview, 'cuma preview');
      },
    );

    test('6. quoted_direction inbound/outbound pass-through', () {
      final inbound = OmnichannelThreadMessageModel.fromJson(
        baseMessage(<String, dynamic>{
          'reply_context': <String, dynamic>{'quoted_direction': 'inbound'},
        }),
      );
      expect(inbound.replyContext?.quotedDirection, 'inbound');

      final outbound = OmnichannelThreadMessageModel.fromJson(
        baseMessage(<String, dynamic>{
          'reply_context': <String, dynamic>{'quoted_direction': 'outbound'},
        }),
      );
      expect(outbound.replyContext?.quotedDirection, 'outbound');
    });

    test('7. regression guard: interactive message without reply_context', () {
      final message = OmnichannelThreadMessageModel.fromJson(<String, dynamic>{
        'id': 7,
        'message_type': 'interactive',
        'text': '',
        'interactive': <String, dynamic>{
          'type': 'button',
          'button_options': <String>['Ya', 'Tidak'],
        },
      });

      expect(message.replyContext, isNull);
      expect(message.hasInteractive, isTrue);
    });

    test('8. all-null reply_context object -> non-null (quoted-not-found)', () {
      final message = OmnichannelThreadMessageModel.fromJson(
        baseMessage(<String, dynamic>{
          'reply_context': <String, dynamic>{
            'quoted_message_id': null,
            'quoted_type': null,
            'quoted_direction': null,
            'quoted_text_preview': null,
          },
        }),
      );

      final reply = message.replyContext;
      expect(reply, isNotNull);
      expect(reply!.quotedMessageId, isNull);
      expect(reply.quotedType, isNull);
      expect(reply.quotedDirection, isNull);
      expect(reply.quotedTextPreview, isNull);
    });
  });
}
