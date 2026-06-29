import 'dart:convert';

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

  group('ApiEndpoints message-forward builder (5A-FORWARD-APP)', () {
    test('forward path is message-level under conversation', () {
      expect(
        ApiEndpoints.adminConversationMessageForward(7, 9),
        endsWith('/conversations/7/messages/9/forward'),
      );
    });
  });

  group(
    'OmnichannelRepository.forwardConversationMessage (5A-FORWARD-APP)',
    () {
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

      http.Response ok() => http.Response(
        jsonEncode(<String, Object?>{
          'success': true,
          'message': 'Pesan diteruskan.',
        }),
        200,
      );

      test('POSTs to /forward with target body, returns true', () async {
        SharedPreferences.setMockInitialValues(const <String, Object>{
          'admin_mobile_access_token': 'admin-test-token',
        });
        final repo = buildRepository((_) => ok());

        final result = await repo.forwardConversationMessage(
          conversationId: 42,
          messageId: 9,
          targetConversationId: 7,
        );

        expect(result, isTrue);
        expect(captured, hasLength(1));
        expect(captured.single.method, 'POST');
        expect(
          captured.single.url.path,
          endsWith('/conversations/42/messages/9/forward'),
        );
        expect(jsonDecode(captured.single.body), <String, Object?>{
          'target_conversation_id': 7,
        });
      });

      test('returns false on backend error', () async {
        SharedPreferences.setMockInitialValues(const <String, Object>{
          'admin_mobile_access_token': 'admin-test-token',
        });
        final repo = buildRepository((_) => http.Response('boom', 500));

        final result = await repo.forwardConversationMessage(
          conversationId: 1,
          messageId: 2,
          targetConversationId: 3,
        );

        expect(result, isFalse);
      });

      test('returns false with no admin session (no HTTP call)', () async {
        SharedPreferences.setMockInitialValues(const <String, Object>{});
        final repo = buildRepository((_) => http.Response('error', 500));

        final result = await repo.forwardConversationMessage(
          conversationId: 1,
          messageId: 2,
          targetConversationId: 3,
        );

        expect(result, isFalse);
        expect(captured, isEmpty);
      });
    },
  );

  group('OmnichannelShellController.forwardMessage (5A-FORWARD-APP)', () {
    test(
      'returns false with no selected conversation (no HTTP call)',
      () async {
        SharedPreferences.setMockInitialValues(const <String, Object>{
          'admin_mobile_access_token': 'admin-test-token',
        });
        final captured = <http.Request>[];
        final apiClient = ApiClient(
          httpClient: MockClient((http.Request request) async {
            captured.add(request);
            return http.Response('{}', 200);
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

        final ok = await controller.forwardMessage(
          messageId: 5,
          targetConversationId: 7,
        );

        expect(ok, isFalse);
        expect(captured, isEmpty);
      },
    );
  });
}
