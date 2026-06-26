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
import 'package:what_jet/features/omnichannel/data/models/omnichannel_starred_message_item.dart';
import 'package:what_jet/features/omnichannel/data/repositories/omnichannel_repository.dart';
import 'package:what_jet/features/omnichannel/data/services/omnichannel_api_service.dart';
import 'package:what_jet/features/omnichannel/presentation/pages/omnichannel_starred_messages_page.dart';

class _CapturingApiClient extends ApiClient {
  String? lastPath;
  Map<String, String>? lastHeaders;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
  }) {
    lastPath = path;
    lastHeaders = headers;
    return Future<Map<String, dynamic>>.value(<String, dynamic>{});
  }
}

class _FakeStarredRepository extends OmnichannelRepository {
  _FakeStarredRepository(this._canned)
    : super(
        apiService: OmnichannelApiService(ApiClient()),
        adminAuthRepository: AdminAuthRepository(
          authApiService: AdminAuthApiService(ApiClient()),
          tokenStorage: AdminTokenStorage(),
        ),
      );

  final List<OmnichannelStarredMessageItem> _canned;

  @override
  Future<List<OmnichannelStarredMessageItem>> loadStarredMessages() async {
    return _canned;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiEndpoints.adminStarredMessages (BRIEF 5C-2-APP)', () {
    test('1. global endpoint /admin-mobile/starred-messages', () {
      expect(
        ApiEndpoints.adminStarredMessages(),
        '/api/admin-mobile/starred-messages',
      );
      expect(
        ApiEndpoints.adminStarredMessages(),
        endsWith('/starred-messages'),
      );
    });
  });

  group('OmnichannelApiService.fetchStarredMessages (BRIEF 5C-2-APP)', () {
    test('2. GET endpoint + bearer header (nol body)', () async {
      final client = _CapturingApiClient();
      addTearDown(client.dispose);
      final service = OmnichannelApiService(client);

      await service.fetchStarredMessages(accessToken: 'token');

      expect(client.lastPath, ApiEndpoints.adminStarredMessages());
      expect(client.lastPath, endsWith('/starred-messages'));
      expect(client.lastHeaders?['Authorization'], 'Bearer token');
    });
  });

  group('OmnichannelRepository.loadStarredMessages (BRIEF 5C-2-APP)', () {
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

    test('3. FLATTEN-safe: reads data.starred_messages via GET', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'message': 'ok',
            'data': <String, Object?>{
              'starred_messages': <Map<String, Object?>>[
                <String, Object?>{
                  'id': 11,
                  'conversation_id': 5,
                  'conversation_customer_name': 'Budi',
                  'message_text': 'Halo dunia',
                  'message_type': 'text',
                  'starred_at': '2026-06-20T08:30:00Z',
                },
              ],
            },
          }),
          200,
        ),
      );

      final items = await repo.loadStarredMessages();

      expect(captured, hasLength(1));
      expect(captured.single.method, 'GET');
      expect(captured.single.url.path, endsWith('/starred-messages'));
      expect(items, hasLength(1));
      expect(items.single.id, 11);
      expect(items.single.conversationId, 5);
      expect(items.single.customerName, 'Budi');
      expect(items.single.text, 'Halo dunia');
      expect(items.single.messageType, 'text');
      expect(items.single.starredAt, isNotNull);
    });

    test('4. already top-level (flattened) starred_messages', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'starred_messages': <Map<String, Object?>>[
              <String, Object?>{'id': 1, 'conversation_id': 2},
            ],
          }),
          200,
        ),
      );

      final items = await repo.loadStarredMessages();

      expect(items, hasLength(1));
      expect(items.single.id, 1);
      expect(items.single.text, isNull);
    });

    test('5. missing key -> empty list', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{'data': <String, Object?>{}}),
          200,
        ),
      );

      final items = await repo.loadStarredMessages();

      expect(items, isEmpty);
    });

    test('6. malformed (not a list) -> empty list', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{'starred_messages': 'oops'},
          }),
          200,
        ),
      );

      final items = await repo.loadStarredMessages();

      expect(items, isEmpty);
    });
  });

  group('OmnichannelStarredMessageItem.fromJson (BRIEF 5C-2-APP)', () {
    test('7. full parse + trim', () {
      final item = OmnichannelStarredMessageItem.fromJson(<String, dynamic>{
        'id': 9,
        'conversation_id': 4,
        'conversation_customer_name': '  Siti  ',
        'message_text': '  hai  ',
        'message_type': 'text',
        'starred_at': '2026-06-20T08:30:00Z',
      });

      expect(item.id, 9);
      expect(item.conversationId, 4);
      expect(item.customerName, 'Siti');
      expect(item.text, 'hai');
      expect(item.messageType, 'text');
      expect(item.starredAt, isNotNull);
    });

    test('8. defensive defaults on missing/null', () {
      final item = OmnichannelStarredMessageItem.fromJson(
        const <String, dynamic>{},
      );

      expect(item.id, 0);
      expect(item.conversationId, 0);
      expect(item.customerName, '');
      expect(item.text, isNull);
      expect(item.messageType, '');
      expect(item.starredAt, isNull);
    });
  });

  group('OmnichannelStarredMessagesPage fallback (BRIEF 5C-2-APP)', () {
    testWidgets('9. null-text image -> "Foto"; text item shown', (
      tester,
    ) async {
      final repo = _FakeStarredRepository(<OmnichannelStarredMessageItem>[
        const OmnichannelStarredMessageItem(
          id: 1,
          conversationId: 1,
          customerName: 'Budi',
          text: null,
          messageType: 'image',
          starredAt: null,
        ),
        const OmnichannelStarredMessageItem(
          id: 2,
          conversationId: 1,
          customerName: 'Ani',
          text: 'pesan teks',
          messageType: 'text',
          starredAt: null,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(home: OmnichannelStarredMessagesPage(repository: repo)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Foto'), findsOneWidget);
      expect(find.text('pesan teks'), findsOneWidget);
      expect(find.text('Budi'), findsOneWidget);
      expect(find.text('Ani'), findsOneWidget);
    });
  });
}
