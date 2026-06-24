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
import 'package:what_jet/features/omnichannel/data/repositories/omnichannel_repository.dart';
import 'package:what_jet/features/omnichannel/data/services/omnichannel_api_service.dart';
import 'package:what_jet/features/omnichannel/presentation/widgets/omnichannel_center_pane.dart';

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

  group('OmnichannelApiService.saveStickerFavorite (BRIEF 4C-2-APP)', () {
    test(
      '1. global endpoint + body hanya source_message_id (nol convId)',
      () async {
        final client = _CapturingApiClient();
        addTearDown(client.dispose);
        final service = OmnichannelApiService(client);

        await service.saveStickerFavorite(
          accessToken: 'token',
          sourceMessageId: 401,
        );

        expect(client.lastPath, ApiEndpoints.adminStickerFavorites());
        expect(client.lastPath, endsWith('/sticker-favorites'));
        expect(client.lastBody!['source_message_id'], 401);
        expect(client.lastBody!.containsKey('conversation_id'), isFalse);
        expect(client.lastBody!.containsKey('message_type'), isFalse);
      },
    );
  });

  group('OmnichannelRepository.saveStickerFavorite (BRIEF 4C-2-APP)', () {
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

    test('2. reads payload[message], POST to /sticker-favorites', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'message': 'Stiker disimpan.',
            'data': <String, Object?>{'id': 7},
          }),
          201,
        ),
      );

      final result = await repo.saveStickerFavorite(sourceMessageId: 401);

      expect(result, 'Stiker disimpan.');
      expect(captured, hasLength(1));
      expect(captured.single.method, 'POST');
      expect(captured.single.url.path, endsWith('/sticker-favorites'));
      final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
      expect(body['source_message_id'], 401);
    });

    test('3. empty message -> fallback string', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(jsonEncode(<String, Object?>{}), 201),
      );

      final result = await repo.saveStickerFavorite(sourceMessageId: 2);

      expect(result, 'Stiker disimpan ke koleksi.');
    });

    test(
      '4. BE 422 -> throws ApiException (non-swallow, APP-FINDING-1)',
      () async {
        SharedPreferences.setMockInitialValues(const <String, Object>{
          'admin_mobile_access_token': 'admin-test-token',
        });
        final repo = buildRepository(
          (_) => http.Response(
            jsonEncode(<String, Object?>{
              'message': 'Stiker sumber tidak ditemukan.',
            }),
            422,
          ),
        );

        await expectLater(
          repo.saveStickerFavorite(sourceMessageId: 2),
          throwsA(isA<ApiException>()),
        );
      },
    );
  });

  group('ConversationStickerPreview save button (BRIEF 4C-2-APP)', () {
    testWidgets('5. onSave null -> no bookmark button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ConversationStickerPreview(
                stickerUrl: 'https://cdn.example/s.webp',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.bookmark_add_outlined), findsNothing);
    });

    testWidgets('6. onSave provided -> bookmark shown + tap fires', (
      tester,
    ) async {
      var fired = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ConversationStickerPreview(
                stickerUrl: 'https://cdn.example/s.webp',
                onSave: () => fired++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.bookmark_add_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
      await tester.pump();

      expect(fired, 1);
    });

    testWidgets('7. independensi: onResend+onSave -> 2 tombol, tap mandiri', (
      tester,
    ) async {
      var resend = 0;
      var save = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ConversationStickerPreview(
                stickerUrl: 'https://cdn.example/s.webp',
                onResend: () => resend++,
                onSave: () => save++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_add_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(resend, 1);
      expect(save, 0);

      await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
      await tester.pump();
      expect(resend, 1);
      expect(save, 1);
    });
  });
}
