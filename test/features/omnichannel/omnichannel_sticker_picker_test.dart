import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:what_jet/core/network/api_client.dart';
import 'package:what_jet/core/network/api_endpoints.dart';
import 'package:what_jet/core/storage/admin_token_storage.dart';
import 'package:what_jet/features/admin_auth/data/repositories/admin_auth_repository.dart';
import 'package:what_jet/features/admin_auth/data/services/admin_auth_api_service.dart';
import 'package:what_jet/features/omnichannel/data/models/sticker_favorite_item.dart';
import 'package:what_jet/features/omnichannel/data/repositories/omnichannel_repository.dart';
import 'package:what_jet/features/omnichannel/data/services/omnichannel_api_service.dart';
import 'package:what_jet/features/omnichannel/presentation/widgets/sticker_picker_sheet.dart';

class _CapturingApiClient extends ApiClient {
  Map<String, Object?>? lastBody;
  String? lastPath;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
    Map<String, Object?> body = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
  }) {
    lastPath = path;
    lastBody = body;
    return Future<Map<String, dynamic>>.value(<String, dynamic>{});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StickerFavoriteItem.fromJson (BRIEF 4C-3-APP-1)', () {
    test('1. baca media_url/mime_type/sticker_animated/id', () {
      final item = StickerFavoriteItem.fromJson(<String, dynamic>{
        'id': 7,
        'media_url': 'https://cdn.example/s.webp',
        'mime_type': 'image/webp',
        'sticker_animated': true,
      });

      expect(item.id, 7);
      expect(item.mediaUrl, 'https://cdn.example/s.webp');
      expect(item.mimeType, 'image/webp');
      expect(item.animated, isTrue);
    });

    test('2. media_url absen (BE picker flag OFF) -> null graceful', () {
      final item = StickerFavoriteItem.fromJson(<String, dynamic>{
        'id': 3,
        'mime_type': 'image/webp',
        'sticker_animated': false,
      });

      expect(item.id, 3);
      expect(item.mediaUrl, isNull);
      expect(item.animated, isFalse);
    });

    test(
      '3. media_url whitespace -> null; sticker_animated absen -> false',
      () {
        final item = StickerFavoriteItem.fromJson(<String, dynamic>{
          'id': 9,
          'media_url': '   ',
        });

        expect(item.id, 9);
        expect(item.mediaUrl, isNull);
        expect(item.animated, isFalse);
      },
    );
  });

  group('OmnichannelRepository sticker favorites (BRIEF 4C-3-APP-1)', () {
    late List<http.Request> captured;

    OmnichannelRepository buildRepository(
      http.Response Function(http.Request request) handler,
    ) {
      captured = <http.Request>[];
      final apiClient = ApiClient(
        httpClient: MockClient((http.Request request) async {
          captured.add(request);
          return handler(request);
        }),
      );
      addTearDown(apiClient.dispose);
      return OmnichannelRepository(
        apiService: OmnichannelApiService(apiClient),
        adminAuthRepository: AdminAuthRepository(
          authApiService: AdminAuthApiService(apiClient),
          tokenStorage: AdminTokenStorage(),
        ),
      );
    }

    void setToken() {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
    }

    test('4. fetch parse data.favorites (shape BE-1 asli)', () async {
      setToken();
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'message': 'Koleksi stiker berhasil dimuat.',
            'data': <String, Object?>{
              'favorites': <Map<String, Object?>>[
                <String, Object?>{
                  'id': 1,
                  'media_url': 'https://example.test/a.webp',
                  'mime_type': 'image/webp',
                  'sticker_animated': false,
                },
              ],
              'total': 1,
            },
          }),
          200,
        ),
      );

      final result = await repo.fetchStickerFavorites();

      expect(result, hasLength(1));
      expect(result.single.id, 1);
      expect(result.single.mediaUrl, 'https://example.test/a.webp');
      expect(captured.single.method, 'GET');
      expect(captured.single.url.path, endsWith('/sticker-favorites'));
    });

    test('5. fetch data tanpa favorites / bukan list -> empty', () async {
      setToken();
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{'total': 0},
          }),
          200,
        ),
      );

      final result = await repo.fetchStickerFavorites();

      expect(result, isEmpty);
    });

    test('6. fetch item id<=0 difilter (cegah favorite_id=0)', () async {
      setToken();
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'favorites': <Map<String, Object?>>[
                <String, Object?>{'id': 0, 'media_url': 'https://x/a.webp'},
                <String, Object?>{'id': 5, 'media_url': 'https://x/b.webp'},
              ],
            },
          }),
          200,
        ),
      );

      final result = await repo.fetchStickerFavorites();

      expect(result, hasLength(1));
      expect(result.single.id, 5);
    });

    test(
      '7. send POST send-favorite, body favorite_id, baca message',
      () async {
        setToken();
        final repo = buildRepository(
          (_) => http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'message': 'Stiker berhasil diantrekan ke WhatsApp.',
              'data': <String, Object?>{
                'notice': 'Stiker berhasil diantrekan ke WhatsApp.',
                'conversation_id': 42,
              },
            }),
            201,
          ),
        );

        final result = await repo.sendStickerFavorite(
          conversationId: 42,
          favoriteId: 5,
        );

        expect(result, 'Stiker berhasil diantrekan ke WhatsApp.');
        expect(captured.single.method, 'POST');
        expect(
          captured.single.url.path,
          endsWith('/conversations/42/send-favorite'),
        );
        final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
        expect(body['favorite_id'], 5);
      },
    );
  });

  group('OmnichannelApiService.sendStickerFavorite (BRIEF 4C-3-APP-1)', () {
    test('8. endpoint + body hanya favorite_id', () async {
      final client = _CapturingApiClient();
      addTearDown(client.dispose);
      final service = OmnichannelApiService(client);

      await service.sendStickerFavorite(
        accessToken: 'token',
        conversationId: 7,
        favoriteId: 13,
      );

      expect(client.lastPath, ApiEndpoints.adminConversationSendFavorite(7));
      expect(client.lastPath, endsWith('/conversations/7/send-favorite'));
      expect(client.lastBody!['favorite_id'], 13);
      expect(client.lastBody!.containsKey('source_message_id'), isFalse);
    });
  });

  group('showStickerPickerSheet (BRIEF 4C-3-APP-1)', () {
    Widget harness({
      required Future<List<StickerFavoriteItem>> Function() onLoad,
      required void Function(int favoriteId) onPick,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showStickerPickerSheet(
                context: ctx,
                onLoad: onLoad,
                onPick: onPick,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    Future<void> present(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    testWidgets('9. loading state -> spinner', (tester) async {
      final completer = Completer<List<StickerFavoriteItem>>();
      await tester.pumpWidget(
        harness(onLoad: () => completer.future, onPick: (_) {}),
      );
      await present(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(const <StickerFavoriteItem>[]);
      await tester.pump();
    });

    testWidgets('10. empty state -> teks', (tester) async {
      await tester.pumpWidget(
        harness(
          onLoad: () async => const <StickerFavoriteItem>[],
          onPick: (_) {},
        ),
      );
      await present(tester);

      expect(find.text('Belum ada stiker favorit'), findsOneWidget);
    });

    testWidgets('11. grid render -> N Image cells', (tester) async {
      await tester.pumpWidget(
        harness(
          onLoad: () async => const <StickerFavoriteItem>[
            StickerFavoriteItem(id: 1, mediaUrl: 'https://x/a.webp'),
            StickerFavoriteItem(id: 2, mediaUrl: 'https://x/b.webp'),
            StickerFavoriteItem(id: 3, mediaUrl: 'https://x/c.webp'),
          ],
          onPick: (_) {},
        ),
      );
      await present(tester);

      expect(find.byType(Image), findsNWidgets(3));
    });

    testWidgets('12. error state -> pesan + Coba lagi', (tester) async {
      await tester.pumpWidget(
        harness(
          onLoad: () =>
              Future<List<StickerFavoriteItem>>.error(Exception('boom')),
          onPick: (_) {},
        ),
      );
      await present(tester);

      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('13. tap cell -> onPick(id) + sheet tertutup', (tester) async {
      var picked = -1;
      await tester.pumpWidget(
        harness(
          onLoad: () async => const <StickerFavoriteItem>[
            StickerFavoriteItem(id: 11, mediaUrl: 'https://x/a.webp'),
          ],
          onPick: (id) => picked = id,
        ),
      );
      await present(tester);

      await tester.tap(find.byType(Image));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(picked, 11);
      expect(find.byType(Image), findsNothing);
    });
  });
}
