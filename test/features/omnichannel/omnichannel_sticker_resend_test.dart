import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:what_jet/core/network/api_client.dart';
import 'package:what_jet/core/storage/admin_token_storage.dart';
import 'package:what_jet/features/admin_auth/data/repositories/admin_auth_repository.dart';
import 'package:what_jet/features/admin_auth/data/services/admin_auth_api_service.dart';
import 'package:what_jet/features/omnichannel/data/repositories/omnichannel_repository.dart';
import 'package:what_jet/features/omnichannel/data/services/omnichannel_api_service.dart';
import 'package:what_jet/features/omnichannel/presentation/controllers/omnichannel_shell_controller.dart';
import 'package:what_jet/features/omnichannel/presentation/widgets/omnichannel_center_pane.dart';

class _CapturingApiClient extends ApiClient {
  Map<String, Object?>? lastBody;
  Map<String, Object?>? lastFields;
  List<ApiMultipartFile>? lastFiles;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
    Map<String, Object?> body = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
  }) {
    lastBody = body;
    return Future<Map<String, dynamic>>.value(<String, dynamic>{});
  }

  @override
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
    Map<String, Object?> fields = const <String, Object?>{},
    List<ApiMultipartFile> files = const <ApiMultipartFile>[],
    Map<String, String> headers = const <String, String>{},
  }) {
    lastFields = fields;
    lastFiles = files;
    return Future<Map<String, dynamic>>.value(<String, dynamic>{});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OmnichannelApiService.sendAdminStickerReply (BRIEF 4C-1-APP)', () {
    late _CapturingApiClient client;
    late OmnichannelApiService service;

    setUp(() {
      client = _CapturingApiClient();
      service = OmnichannelApiService(client);
    });

    tearDown(() {
      client.dispose();
    });

    test(
      '1. sticker = JSON post message_type+source_message_id, non-file',
      () async {
        await service.sendAdminStickerReply(
          accessToken: 'token',
          conversationId: 1,
          sourceMessageId: 401,
        );

        expect(client.lastBody!['message_type'], 'sticker');
        expect(client.lastBody!['source_message_id'], 401);
        expect(client.lastBody!.containsKey('caption'), isFalse);
        expect(client.lastBody!.containsKey('message'), isFalse);
        expect(client.lastFields, isNull);
        expect(client.lastFiles, isNull);
      },
    );
  });

  group('OmnichannelRepository.sendAdminStickerReply (BRIEF 4C-1-APP)', () {
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

    test(
      '2. POSTs source_message_id to reply endpoint, returns notice',
      () async {
        SharedPreferences.setMockInitialValues(const <String, Object>{
          'admin_mobile_access_token': 'admin-test-token',
        });
        final repo = buildRepository(
          (_) => http.Response(
            jsonEncode(<String, Object?>{'notice': 'Stiker dikirim ulang.'}),
            200,
          ),
        );

        final result = await repo.sendAdminStickerReply(
          conversationId: 42,
          sourceMessageId: 401,
        );

        expect(result, 'Stiker dikirim ulang.');
        expect(captured, hasLength(1));
        expect(captured.single.method, 'POST');
        expect(captured.single.url.path, endsWith('/conversations/42/reply'));
        final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
        expect(body['message_type'], 'sticker');
        expect(body['source_message_id'], 401);
      },
    );

    test('3. empty notice -> fallback string', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(jsonEncode(<String, Object?>{}), 200),
      );

      final result = await repo.sendAdminStickerReply(
        conversationId: 1,
        sourceMessageId: 2,
      );

      expect(result, 'Stiker berhasil diproses.');
    });

    test(
      '3b. BE 422 -> throws ApiException (non-swallow, APP-FINDING-1)',
      () async {
        SharedPreferences.setMockInitialValues(const <String, Object>{
          'admin_mobile_access_token': 'admin-test-token',
        });
        final repo = buildRepository(
          (_) => http.Response(
            jsonEncode(<String, Object?>{
              'message': 'Fitur kirim stiker belum aktif.',
            }),
            422,
          ),
        );

        await expectLater(
          repo.sendAdminStickerReply(conversationId: 1, sourceMessageId: 2),
          throwsA(isA<ApiException>()),
        );
      },
    );
  });

  group('OmnichannelShellController.resendSticker (BRIEF 4C-1-APP)', () {
    test('4. returns failed with no selected conversation (no HTTP)', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final captured = <http.Request>[];
      final apiClient = ApiClient(
        httpClient: MockClient((http.Request request) async {
          captured.add(request);
          return http.Response(
            jsonEncode(<String, Object?>{'notice': 'x'}),
            200,
          );
        }),
      );
      addTearDown(apiClient.dispose);
      final adminAuth = AdminAuthRepository(
        authApiService: AdminAuthApiService(apiClient),
        tokenStorage: AdminTokenStorage(),
      );
      final controller = OmnichannelShellController(
        repository: OmnichannelRepository(
          apiService: OmnichannelApiService(apiClient),
          adminAuthRepository: adminAuth,
        ),
        adminAuthRepository: adminAuth,
      );
      addTearDown(controller.dispose);

      final result = await controller.resendSticker(sourceMessageId: 401);

      expect(result, 'failed');
      expect(captured, isEmpty);
    });
  });

  group('ConversationStickerPreview resend button (BRIEF 4C-1-APP)', () {
    testWidgets('5. onResend null -> no send button', (tester) async {
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

      expect(find.byIcon(Icons.send_rounded), findsNothing);
    });

    testWidgets('6. onResend provided -> send button shown + tap fires', (
      tester,
    ) async {
      var fired = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ConversationStickerPreview(
                stickerUrl: 'https://cdn.example/s.webp',
                onResend: () => fired++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(fired, 1);
    });
  });
}
