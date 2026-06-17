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
import 'package:what_jet/features/omnichannel/presentation/controllers/omnichannel_shell_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiEndpoints reaction builder (Wave 2A)', () {
    test('reaction path mirrors mark-read', () {
      expect(
        ApiEndpoints.adminConversationReaction(7),
        ApiEndpoints.adminConversationMarkRead(
          7,
        ).replaceFirst('/mark-read', '/reaction'),
      );
      expect(
        ApiEndpoints.adminConversationReaction(7),
        endsWith('/conversations/7/reaction'),
      );
    });
  });

  group('OmnichannelRepository.sendConversationReaction (Wave 2A)', () {
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

    http.Response statusResponse(String status, {String? reason}) {
      final body = <String, Object?>{'status': status};
      if (reason != null) {
        body['reason'] = reason;
      }
      return http.Response(jsonEncode(body), 200);
    }

    test(
      'POSTs message_id + emoji to the reaction endpoint and returns sent',
      () async {
        SharedPreferences.setMockInitialValues(const <String, Object>{
          'admin_mobile_access_token': 'admin-test-token',
        });
        final repo = buildRepository((_) => statusResponse('sent'));

        final status = await repo.sendConversationReaction(
          conversationId: 42,
          messageId: 99,
          emoji: '👍',
        );

        expect(status, 'sent');
        expect(captured, hasLength(1));
        expect(captured.single.method, 'POST');
        expect(
          captured.single.url.path,
          endsWith('/conversations/42/reaction'),
        );
        final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
        expect(body['message_id'], 99);
        expect(body['emoji'], '👍');
      },
    );

    test('returns skipped when the backend skips', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => statusResponse('skipped', reason: 'not_customer_message'),
      );

      final status = await repo.sendConversationReaction(
        conversationId: 1,
        messageId: 2,
        emoji: '❤️',
      );

      expect(status, 'skipped');
    });

    test('returns failed on backend error', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository((_) => http.Response('boom', 500));

      final status = await repo.sendConversationReaction(
        conversationId: 1,
        messageId: 2,
        emoji: '😂',
      );

      expect(status, 'failed');
    });

    test('returns failed with no admin session (no HTTP call)', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final repo = buildRepository((_) => http.Response('error', 500));

      final status = await repo.sendConversationReaction(
        conversationId: 1,
        messageId: 2,
        emoji: '🙏',
      );

      expect(status, 'failed');
      expect(captured, isEmpty);
    });
  });

  group('OmnichannelShellController.reactToMessage (Wave 2A)', () {
    test(
      'returns failed with no selected conversation (no HTTP call)',
      () async {
        SharedPreferences.setMockInitialValues(const <String, Object>{
          'admin_mobile_access_token': 'admin-test-token',
        });
        final captured = <http.Request>[];
        final apiClient = ApiClient(
          httpClient: MockClient((http.Request request) async {
            captured.add(request);
            return http.Response(
              jsonEncode(<String, Object?>{'status': 'sent'}),
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

        final status = await controller.reactToMessage(
          messageId: 5,
          emoji: '👍',
        );

        expect(status, 'failed');
        expect(captured, isEmpty);
      },
    );
  });

  // Proof of the C-6 gesture-scope mechanism used by both bubbles:
  // GestureDetector(behavior: deferToChild) wrapping an Align confines the
  // long-press to where the aligned child renders (the bubble box) — the empty
  // space beside an aligned bubble has no child there, so it does NOT fire.
  testWidgets(
    'deferToChild confines long-press to the aligned bubble (whitespace excluded)',
    (WidgetTester tester) async {
      var fired = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                height: 80,
                child: GestureDetector(
                  behavior: HitTestBehavior.deferToChild,
                  onLongPress: () => fired++,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Container(
                        width: 120,
                        height: 40,
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Long-press ON the bubble (left side) -> fires.
      await tester.longPressAt(const Offset(40, 40));
      await tester.pump();
      expect(fired, 1);

      // Long-press on the whitespace beside the bubble (right side) -> no fire.
      await tester.longPressAt(const Offset(340, 40));
      await tester.pump();
      expect(fired, 1);
    },
  );
}
