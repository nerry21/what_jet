import 'package:flutter_test/flutter_test.dart';

import 'package:what_jet/features/omnichannel/data/models/omnichannel_thread_model.dart';

void main() {
  group('OmnichannelThreadMessageModel.displayText — sumber Copy (5D)', () {
    OmnichannelThreadMessageModel build({
      required String messageType,
      required String text,
      String? imageUrl,
      String? audioUrl,
      String? mediaCaption,
    }) {
      return OmnichannelThreadMessageModel(
        id: 1,
        messageType: messageType,
        senderLabel: 'Admin',
        text: text,
        sentAt: DateTime(2026, 6, 25, 8),
        isMine: false,
        imageUrl: imageUrl,
        audioUrl: audioUrl,
        mediaCaption: mediaCaption,
      );
    }

    test('teks biasa => trimmed, non-empty (opsi Salin MUNCUL)', () {
      final m = build(messageType: 'text', text: '  Halo dunia  ');
      expect(m.displayText, 'Halo dunia');
      expect(m.displayText.trim().isNotEmpty, isTrue);
    });

    test('image tanpa caption => empty (opsi Salin DISEMBUNYIKAN)', () {
      final m = build(
        messageType: 'image',
        text: '',
        imageUrl: 'https://cdn.example/x.jpg',
      );
      expect(m.displayText, '');
      expect(m.displayText.trim().isNotEmpty, isFalse);
    });

    test('voice-note placeholder (tanpa url) => empty', () {
      final m = build(messageType: 'audio', text: '[Voice note]');
      expect(m.displayText, '');
    });

    test('voice-note admin placeholder => empty', () {
      final m = build(messageType: 'audio', text: '[Voice note admin]');
      expect(m.displayText, '');
    });

    test('voice-note dengan audio url => empty (cabang media)', () {
      final m = build(
        messageType: 'audio',
        text: '[Voice note]',
        audioUrl: 'https://cdn.example/v.ogg',
      );
      expect(m.displayText, '');
    });

    test('image dengan caption => caption (trimmed)', () {
      final m = build(
        messageType: 'image',
        text: '',
        imageUrl: 'https://cdn.example/x.jpg',
        mediaCaption: '  Lihat ini  ',
      );
      expect(m.displayText, 'Lihat ini');
      expect(m.displayText.trim().isNotEmpty, isTrue);
    });
  });
}
