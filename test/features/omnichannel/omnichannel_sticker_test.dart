import 'package:flutter_test/flutter_test.dart';

import 'package:what_jet/features/omnichannel/data/models/omnichannel_thread_model.dart';

void main() {
  Map<String, dynamic> baseMessage(Map<String, dynamic> extra) {
    return <String, dynamic>{
      'id': 401,
      'message_type': 'sticker',
      'text': '[Stiker]',
      ...extra,
    };
  }

  group('OmnichannelThreadMessageModel sticker parse (BRIEF 4A)', () {
    test('1. sticker + media.sticker_url -> hasSticker true & url set', () {
      final message = OmnichannelThreadMessageModel.fromJson(
        baseMessage(<String, dynamic>{
          'media': <String, dynamic>{
            'sticker_url': 'https://cdn.example/s.webp',
          },
        }),
      );
      expect(message.hasSticker, isTrue);
      expect(message.stickerUrl, 'https://cdn.example/s.webp');
    });

    test('2. sticker tanpa sticker_url -> hasSticker false', () {
      final message = OmnichannelThreadMessageModel.fromJson(
        baseMessage(const <String, dynamic>{}),
      );
      expect(message.hasSticker, isFalse);
      expect(message.stickerUrl, isNull);
    });

    test('3. sticker_url ada tapi message_type image -> hasSticker false', () {
      final message = OmnichannelThreadMessageModel.fromJson(
        baseMessage(<String, dynamic>{
          'message_type': 'image',
          'media': <String, dynamic>{
            'sticker_url': 'https://cdn.example/s.webp',
          },
        }),
      );
      expect(message.hasSticker, isFalse);
    });

    test('4. sticker_download_url & sticker_animated true terisi', () {
      final message = OmnichannelThreadMessageModel.fromJson(
        baseMessage(<String, dynamic>{
          'media': <String, dynamic>{
            'sticker_url': 'https://cdn.example/s.webp',
            'sticker_download_url': 'https://cdn.example/s-dl.webp',
            'sticker_animated': true,
          },
        }),
      );
      expect(message.stickerDownloadUrl, 'https://cdn.example/s-dl.webp');
      expect(message.stickerAnimated, isTrue);
    });

    test('5. sticker_animated absen -> default false', () {
      final message = OmnichannelThreadMessageModel.fromJson(
        baseMessage(<String, dynamic>{
          'media': <String, dynamic>{
            'sticker_url': 'https://cdn.example/s.webp',
          },
        }),
      );
      expect(message.stickerAnimated, isFalse);
    });

    test(
      '6. K-1: message_text [Stiker] -> hasSticker true & displayText [Stiker]',
      () {
        final message = OmnichannelThreadMessageModel.fromJson(
          baseMessage(<String, dynamic>{
            'message_text': '[Stiker]',
            'media': <String, dynamic>{
              'sticker_url': 'https://cdn.example/s.webp',
            },
          }),
        );
        expect(message.hasSticker, isTrue);
        expect(message.displayText, '[Stiker]');
      },
    );

    test('7. regression: image tetap hasImage & bukan hasSticker', () {
      final message = OmnichannelThreadMessageModel.fromJson(
        baseMessage(<String, dynamic>{
          'message_type': 'image',
          'media': <String, dynamic>{'image_url': 'https://cdn.example/p.jpg'},
        }),
      );
      expect(message.hasImage, isTrue);
      expect(message.hasSticker, isFalse);
    });
  });
}
