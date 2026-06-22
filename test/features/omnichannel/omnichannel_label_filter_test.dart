import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:what_jet/core/network/api_client.dart';
import 'package:what_jet/core/storage/admin_token_storage.dart';
import 'package:what_jet/features/admin_auth/data/repositories/admin_auth_repository.dart';
import 'package:what_jet/features/admin_auth/data/services/admin_auth_api_service.dart';
import 'package:what_jet/features/omnichannel/data/models/omnichannel_query_model.dart';
import 'package:what_jet/features/omnichannel/data/models/omnichannel_workspace_model.dart';
import 'package:what_jet/features/omnichannel/data/repositories/omnichannel_repository.dart';
import 'package:what_jet/features/omnichannel/data/services/omnichannel_api_service.dart';
import 'package:what_jet/features/omnichannel/presentation/controllers/omnichannel_shell_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OmnichannelQueryModel.tag (BRIEF 3B-2)', () {
    test('1. tag empty -> omitted (null) in query params', () {
      const query = OmnichannelQueryModel();
      expect(query.tag, '');
      expect(query.toQueryParameters()['tag'], isNull);
    });

    test('2. tag set -> present in query params', () {
      const query = OmnichannelQueryModel(tag: 'vip');
      expect(query.toQueryParameters()['tag'], 'vip');
    });

    test('3. tag with surrounding spaces -> trimmed', () {
      const query = OmnichannelQueryModel(tag: '  vip  ');
      expect(query.toQueryParameters()['tag'], 'vip');
    });

    test('4. copyWith(tag) sets/clears without touching others', () {
      const base = OmnichannelQueryModel(scope: 'bot', channel: 'whatsapp');
      final set = base.copyWith(tag: 'vip');
      expect(set.tag, 'vip');
      expect(set.scope, 'bot');
      expect(set.channel, 'whatsapp');

      final cleared = set.copyWith(tag: '');
      expect(cleared.tag, '');
      expect(cleared.toQueryParameters()['tag'], isNull);
    });
  });

  group('OmnichannelWorkspaceModel.tags parse (BRIEF 3B-2)', () {
    test('5. parses filters.tags', () {
      final workspace = OmnichannelWorkspaceModel.fromSources(
        workspacePayload: <String, dynamic>{
          'filters': <String, dynamic>{
            'tags': <Map<String, dynamic>>[
              <String, dynamic>{'key': 'vip', 'label': 'vip'},
            ],
          },
        },
      );
      expect(workspace.tags, hasLength(1));
      expect(workspace.tags.first.key, 'vip');
    });

    test('6. without tags -> empty list (fallback)', () {
      final workspace = OmnichannelWorkspaceModel.fromSources(
        workspacePayload: const <String, dynamic>{},
      );
      expect(workspace.tags, isEmpty);
    });

    test('7. mergeWith preserves current tags when poll omits them', () {
      const current = OmnichannelWorkspaceModel(
        unreadTotal: 1,
        activeConversations: 1,
        filters: <OmnichannelFilterOptionModel>[],
        channels: <OmnichannelFilterOptionModel>[],
        tags: <OmnichannelFilterOptionModel>[
          OmnichannelFilterOptionModel(key: 'vip', label: 'vip'),
        ],
      );
      const polled = OmnichannelWorkspaceModel(
        unreadTotal: 2,
        activeConversations: 2,
        filters: <OmnichannelFilterOptionModel>[],
        channels: <OmnichannelFilterOptionModel>[],
      );
      final merged = current.mergeWith(polled);
      expect(merged.tags, hasLength(1));
      expect(merged.tags.first.key, 'vip');
    });
  });

  group('OmnichannelShellController.setTagFilter (BRIEF 3B-2)', () {
    test('8. sets tagFilter + notifies; same value is no-op', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final apiClient = ApiClient(
        httpClient: MockClient((http.Request request) async {
          return http.Response(
            jsonEncode(<String, Object?>{'success': true}),
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

      var notifications = 0;
      controller.addListener(() => notifications++);

      // setTagFilter notifies (>=1; setTagFilter + refresh()'s sync prefix
      // both notify synchronously). Don't lock an exact count.
      controller.setTagFilter('vip');
      expect(controller.tagFilter, 'vip');
      expect(notifications, greaterThanOrEqualTo(1));

      // Guard: setting the same value is a no-op -> no further notify.
      final afterFirstSet = notifications;
      controller.setTagFilter('vip');
      expect(controller.tagFilter, 'vip');
      expect(notifications, afterFirstSet);

      // Settle the fire-and-forget refresh() while the controller is still
      // alive so it cannot notifyListeners() after dispose() (tearDown).
      await pumpEventQueue();
    });
  });
}
