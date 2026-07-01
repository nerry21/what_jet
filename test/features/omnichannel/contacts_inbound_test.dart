import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:what_jet/features/omnichannel/data/models/omnichannel_thread_model.dart';
import 'package:what_jet/features/omnichannel/presentation/widgets/omnichannel_center_pane.dart';

void main() {
  Map<String, dynamic> baseMessage(Map<String, dynamic> extra) {
    return <String, dynamic>{
      'id': 501,
      'message_type': 'contacts',
      'text': '[Kontak] A.my Wife',
      ...extra,
    };
  }

  group('OmnichannelThreadMessageModel contacts parse (BRICK 2-APP)', () {
    test('1. contacts valid -> hasContacts true + name + phone + wa_id', () {
      final message = OmnichannelThreadMessageModel.fromJson(
        baseMessage(<String, dynamic>{
          'contacts': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'A.my Wife',
              'phones': <Map<String, dynamic>>[
                <String, dynamic>{
                  'phone': '+62 812-7959-0001',
                  'wa_id': '6281279590001',
                },
              ],
            },
          ],
        }),
      );
      expect(message.hasContacts, isTrue);
      expect(message.contacts, hasLength(1));
      expect(message.contacts.first.name, 'A.my Wife');
      expect(message.contacts.first.phones, hasLength(1));
      expect(message.contacts.first.phones.first.phone, '+62 812-7959-0001');
      expect(message.contacts.first.phones.first.waId, '6281279590001');
      // Flag OFF (const false) => displayText TIDAK disuppress (0-delta).
      expect(message.displayText, '');
    });

    test('2. tanpa contacts -> hasContacts false, list kosong', () {
      final message = OmnichannelThreadMessageModel.fromJson(
        baseMessage(const <String, dynamic>{}),
      );
      expect(message.hasContacts, isFalse);
      expect(message.contacts, isEmpty);
    });

    test('3. contacts [] (BE flag OFF) -> hasContacts false', () {
      final message = OmnichannelThreadMessageModel.fromJson(
        baseMessage(<String, dynamic>{'contacts': const <dynamic>[]}),
      );
      expect(message.hasContacts, isFalse);
    });

    test('4. message_type text walau contacts terisi -> hasContacts false '
        '(guard tipe)', () {
      final message = OmnichannelThreadMessageModel.fromJson(
        baseMessage(<String, dynamic>{
          'message_type': 'text',
          'contacts': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'A.my Wife',
              'phones': <Map<String, dynamic>>[
                <String, dynamic>{'phone': '+62811', 'wa_id': '62811'},
              ],
            },
          ],
        }),
      );
      expect(message.hasContacts, isFalse);
      expect(message.displayText, '[Kontak] A.my Wife');
    });

    test('5. payload rusak (contacts bukan list / item bukan map) -> aman', () {
      final notList = OmnichannelThreadMessageModel.fromJson(
        baseMessage(<String, dynamic>{'contacts': 'rusak'}),
      );
      expect(notList.hasContacts, isFalse);

      final badItem = OmnichannelThreadMessageModel.fromJson(
        baseMessage(<String, dynamic>{
          'contacts': <dynamic>['rusak', 42],
        }),
      );
      expect(badItem.hasContacts, isFalse);
    });
  });

  group('ConversationContactCard widget (BRICK 2-APP)', () {
    OmnichannelThreadMessageModel buildMessage(
      List<OmnichannelThreadContact> contacts,
    ) {
      return OmnichannelThreadMessageModel(
        id: 601,
        messageType: 'contacts',
        senderLabel: 'Customer',
        text: '[Kontak] A.my Wife',
        sentAt: DateTime(2026, 7, 1, 10),
        isMine: false,
        contacts: contacts,
      );
    }

    Future<void> pumpCard(
      WidgetTester tester,
      OmnichannelThreadMessageModel message,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationContactCard(message: message, maxWidth: 300),
          ),
        ),
      );
    }

    testWidgets('6. render nama + nomor + tombol Simpan & Message aktif', (
      tester,
    ) async {
      final message = buildMessage(const <OmnichannelThreadContact>[
        OmnichannelThreadContact(
          name: 'A.my Wife',
          phones: <OmnichannelThreadContactPhone>[
            OmnichannelThreadContactPhone(
              phone: '+62 812-7959-0001',
              waId: '6281279590001',
            ),
          ],
        ),
      ]);
      await pumpCard(tester, message);

      expect(find.text('A.my Wife'), findsOneWidget);
      expect(find.text('+62 812-7959-0001'), findsOneWidget);
      final saveButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Simpan Kontak'),
      );
      expect(saveButton.onPressed, isNotNull);
      final messageButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Message'),
      );
      expect(messageButton.onPressed, isNotNull);
    });

    testWidgets('7. kontak tanpa nomor -> Message & Simpan disabled', (
      tester,
    ) async {
      final message = buildMessage(const <OmnichannelThreadContact>[
        OmnichannelThreadContact(name: 'Tanpa Nomor'),
      ]);
      await pumpCard(tester, message);

      expect(find.text('Tanpa Nomor'), findsOneWidget);
      final saveButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Simpan Kontak'),
      );
      expect(saveButton.onPressed, isNull);
      final messageButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Message'),
      );
      expect(messageButton.onPressed, isNull);
    });

    testWidgets('8. contacts kosong -> SizedBox.shrink (nol render)', (
      tester,
    ) async {
      await pumpCard(tester, buildMessage(const <OmnichannelThreadContact>[]));
      expect(find.byType(TextButton), findsNothing);
      expect(find.text('Kontak'), findsNothing);
    });
  });
}
