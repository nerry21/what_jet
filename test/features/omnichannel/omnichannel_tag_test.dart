import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:what_jet/core/network/api_client.dart';
import 'package:what_jet/features/omnichannel/data/models/omnichannel_conversation_list_model.dart';
import 'package:what_jet/features/omnichannel/data/services/omnichannel_api_service.dart';

class _CapturingApiClient extends ApiClient {
  String? lastMethod;
  String? lastPath;
  Map<String, Object?>? lastBody;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
    Map<String, Object?> body = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
  }) {
    lastMethod = 'POST';
    lastPath = path;
    lastBody = body;
    return Future<Map<String, dynamic>>.value(<String, dynamic>{});
  }

  @override
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
    Map<String, Object?> body = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
  }) {
    lastMethod = 'DELETE';
    lastPath = path;
    lastBody = body;
    return Future<Map<String, dynamic>>.value(<String, dynamic>{});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationTagModel.fromJson (BRIEF 3B-1)', () {
    test('1. parses id/value/created_at', () {
      final tag = ConversationTagModel.fromJson(<String, dynamic>{
        'id': 12,
        'value': 'follow-up-vip',
        'created_at': '2026-06-20T16:30:00+07:00',
      });
      expect(tag.id, 12);
      expect(tag.value, 'follow-up-vip');
      expect(tag.createdAt, isNotNull);
    });

    test('2. missing fields fall back safely', () {
      final tag = ConversationTagModel.fromJson(<String, dynamic>{});
      expect(tag.id, 0);
      expect(tag.value, '');
      expect(tag.createdAt, isNull);
    });
  });

  group('OmnichannelConversationListItemModel tags parse (BRIEF 3B-1)', () {
    test('3. without tags key -> empty list (backward-compat)', () {
      final item = OmnichannelConversationListItemModel.fromJson(
        <String, dynamic>{'id': 1, 'channel': 'whatsapp'},
      );
      expect(item.tags, isEmpty);
    });

    test('4. with tags -> parsed list', () {
      final item = OmnichannelConversationListItemModel.fromJson(
        <String, dynamic>{
          'id': 1,
          'channel': 'whatsapp',
          'tags': <Map<String, dynamic>>[
            <String, dynamic>{'id': 12, 'value': 'follow-up-vip'},
          ],
        },
      );
      expect(item.tags, hasLength(1));
      expect(item.tags.first.value, 'follow-up-vip');
    });
  });

  group('OmnichannelApiService tag endpoints (BRIEF 3B-1)', () {
    late _CapturingApiClient client;
    late OmnichannelApiService service;

    setUp(() {
      client = _CapturingApiClient();
      service = OmnichannelApiService(client);
    });

    tearDown(() {
      client.dispose();
    });

    test('5. addConversationTag POST path + body {tag, target}', () async {
      await service.addConversationTag(
        accessToken: 'token',
        conversationId: 7,
        tag: 'follow-up-vip',
      );
      expect(client.lastMethod, 'POST');
      expect(client.lastPath, '/api/admin-mobile/conversations/7/tags');
      expect(client.lastBody!['tag'], 'follow-up-vip');
      expect(client.lastBody!['target'], 'conversation');
    });

    test('6. removeConversationTag DELETE path + body {tag}', () async {
      await service.removeConversationTag(
        accessToken: 'token',
        conversationId: 7,
        tag: 'follow-up-vip',
      );
      expect(client.lastMethod, 'DELETE');
      expect(client.lastPath, '/api/admin-mobile/conversations/7/tags');
      expect(client.lastBody!['tag'], 'follow-up-vip');
      expect(client.lastBody!.containsKey('target'), isFalse);
    });
  });

  group('ApiClient.delete real wire via _send (BRIEF 3B-1)', () {
    test('7. delete() sends DELETE + JSON body {tag} to path', () async {
      http.BaseRequest? captured;
      String? capturedBody;

      final mock = MockClient((request) async {
        captured = request;
        capturedBody = request.body;
        return http.Response('{"success": true}', 200);
      });
      final client = ApiClient(httpClient: mock);

      await client.delete(
        '/api/admin-mobile/conversations/7/tags',
        body: <String, Object?>{'tag': 'follow-up-vip'},
      );

      expect(captured, isNotNull);
      expect(captured!.method, 'DELETE');
      expect(captured!.url.path, '/api/admin-mobile/conversations/7/tags');
      expect(jsonDecode(capturedBody!), <String, dynamic>{
        'tag': 'follow-up-vip',
      });

      client.dispose();
    });
  });
}
