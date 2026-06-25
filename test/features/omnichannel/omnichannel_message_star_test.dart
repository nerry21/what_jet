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
import 'package:what_jet/features/omnichannel/data/models/omnichannel_thread_model.dart';
import 'package:what_jet/features/omnichannel/data/repositories/omnichannel_repository.dart';
import 'package:what_jet/features/omnichannel/data/services/omnichannel_api_service.dart';
import 'package:what_jet/features/omnichannel/presentation/controllers/omnichannel_shell_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiEndpoints message-star builder (5C-APP-1)', () {
    test('star path is message-level under conversation', () {
      expect(
        ApiEndpoints.adminConversationMessageStar(7, 9),
        endsWith('/conversations/7/messages/9/star'),
      );
    });

    test('unstar path is message-level under conversation', () {
      expect(
        ApiEndpoints.adminConversationMessageUnstar(7, 9),
        endsWith('/conversations/7/messages/9/unstar'),
      );
    });
  });

  group('OmnichannelThreadMessageModel.fromJson starred (5C-APP-1)', () {
    Map<String, dynamic> base(Object? starred) => <String, dynamic>{
      'id': 1,
      'message_type': 'text',
      'text': 'halo',
      'sent_at': '2026-06-25T08:00:00+07:00',
      'sender_type': 'inbound',
      if (starred != _absent) 'starred': starred,
    };

    test('key absent => false', () {
      expect(
        OmnichannelThreadMessageModel.fromJson(base(_absent)).starred,
        isFalse,
      );
    });

    test('null => false', () {
      expect(
        OmnichannelThreadMessageModel.fromJson(base(null)).starred,
        isFalse,
      );
    });

    test('object {starred:true} => true', () {
      expect(
        OmnichannelThreadMessageModel.fromJson(
          base(<String, dynamic>{
            'starred': true,
            'starred_at': '2026-06-25T08:00:00+07:00',
          }),
        ).starred,
        isTrue,
      );
    });

    test('object {starred:false} => false (defensif)', () {
      expect(
        OmnichannelThreadMessageModel.fromJson(
          base(<String, dynamic>{'starred': false}),
        ).starred,
        isFalse,
      );
    });

    test('bool true => true, bool false => false (defensif)', () {
      expect(
        OmnichannelThreadMessageModel.fromJson(base(true)).starred,
        isTrue,
      );
      expect(
        OmnichannelThreadMessageModel.fromJson(base(false)).starred,
        isFalse,
      );
    });
  });

  group('OmnichannelRepository.setConversationMessageStar (5C-APP-1)', () {
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

    http.Response okStar(bool starred) => http.Response(
      jsonEncode(<String, Object?>{
        'success': true,
        'message': starred ? 'Pesan berhasil dibintangi.' : 'Bintang dilepas.',
        'message_id': 9,
        'starred': starred,
      }),
      200,
    );

    test('starred:true POSTs to /star with empty body, returns true', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository((_) => okStar(true));

      final ok = await repo.setConversationMessageStar(
        conversationId: 42,
        messageId: 9,
        starred: true,
      );

      expect(ok, isTrue);
      expect(captured, hasLength(1));
      expect(captured.single.method, 'POST');
      expect(
        captured.single.url.path,
        endsWith('/conversations/42/messages/9/star'),
      );
      expect(captured.single.body, anyOf('', '{}'));
    });

    test('starred:false POSTs to /unstar, returns true', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository((_) => okStar(false));

      final ok = await repo.setConversationMessageStar(
        conversationId: 42,
        messageId: 9,
        starred: false,
      );

      expect(ok, isTrue);
      expect(
        captured.single.url.path,
        endsWith('/conversations/42/messages/9/unstar'),
      );
    });

    test('returns false on backend error', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository((_) => http.Response('boom', 500));

      final ok = await repo.setConversationMessageStar(
        conversationId: 1,
        messageId: 2,
        starred: true,
      );

      expect(ok, isFalse);
    });

    test('returns false with no admin session (no HTTP call)', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final repo = buildRepository((_) => http.Response('error', 500));

      final ok = await repo.setConversationMessageStar(
        conversationId: 1,
        messageId: 2,
        starred: true,
      );

      expect(ok, isFalse);
      expect(captured, isEmpty);
    });
  });

  group('OmnichannelShellController.toggleStar (5C-APP-1)', () {
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

        final ok = await controller.toggleStar(
          messageId: 5,
          currentlyStarred: false,
        );

        expect(ok, isFalse);
        expect(captured, isEmpty);
      },
    );
  });
}

const Object _absent = Object();
