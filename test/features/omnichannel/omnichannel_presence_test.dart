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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiEndpoints presence builders (Wave 1)', () {
    test('read-receipt path mirrors mark-read', () {
      expect(
        ApiEndpoints.adminConversationReadReceipt(7),
        ApiEndpoints.adminConversationMarkRead(
          7,
        ).replaceFirst('/mark-read', '/read-receipt'),
      );
      expect(
        ApiEndpoints.adminConversationReadReceipt(7),
        endsWith('/conversations/7/read-receipt'),
      );
    });

    test('typing path mirrors mark-read', () {
      expect(
        ApiEndpoints.adminConversationTyping(7),
        ApiEndpoints.adminConversationMarkRead(
          7,
        ).replaceFirst('/mark-read', '/typing'),
      );
      expect(
        ApiEndpoints.adminConversationTyping(7),
        endsWith('/conversations/7/typing'),
      );
    });
  });

  group('OmnichannelRepository presence (Wave 1)', () {
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

    http.Response okResponse(http.Request _) {
      return http.Response(
        jsonEncode(<String, Object?>{
          'success': true,
          'message': 'OK',
          'data': <String, Object?>{'status': 'sent'},
        }),
        200,
      );
    }

    test('read receipt POSTs to the read-receipt endpoint', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(okResponse);

      await repo.sendConversationReadReceipt(conversationId: 42);

      expect(captured, hasLength(1));
      expect(captured.single.method, 'POST');
      expect(
        captured.single.url.path,
        endsWith('/conversations/42/read-receipt'),
      );
    });

    test('typing POSTs to the typing endpoint', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(okResponse);

      await repo.sendConversationTyping(conversationId: 42);

      expect(captured, hasLength(1));
      expect(captured.single.method, 'POST');
      expect(captured.single.url.path, endsWith('/conversations/42/typing'));
    });

    test(
      'presence fails silently with no admin session (no HTTP call)',
      () async {
        SharedPreferences.setMockInitialValues(const <String, Object>{});
        final repo = buildRepository((_) => http.Response('error', 500));

        await expectLater(
          repo.sendConversationReadReceipt(conversationId: 1),
          completes,
        );
        await expectLater(
          repo.sendConversationTyping(conversationId: 1),
          completes,
        );
        expect(captured, isEmpty);
      },
    );

    test('presence fails silently when the backend errors', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository((_) => http.Response('boom', 500));

      await expectLater(
        repo.sendConversationReadReceipt(conversationId: 9),
        completes,
      );
      expect(captured, isNotEmpty);
    });
  });
}
