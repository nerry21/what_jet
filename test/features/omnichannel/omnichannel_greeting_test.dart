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
import 'package:what_jet/features/omnichannel/presentation/widgets/whatsapp_attachment_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiEndpoints greeting builder (BRICK 0-APP)', () {
    test('greeting path is conversation-level send-greeting', () {
      expect(
        ApiEndpoints.adminConversationGreeting(7),
        endsWith('/conversations/7/send-greeting'),
      );
    });
  });

  group('OmnichannelRepository.sendGreeting (BRICK 0-APP)', () {
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
        'message': 'Sapaan berhasil dikirim.',
      }),
      201,
    );

    test('POSTs empty body to send-greeting, returns message', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository((_) => ok());

      final result = await repo.sendGreeting(conversationId: 42);

      expect(result, 'Sapaan berhasil dikirim.');
      expect(captured, hasLength(1));
      expect(captured.single.method, 'POST');
      expect(
        captured.single.url.path,
        endsWith('/conversations/42/send-greeting'),
      );
      expect(jsonDecode(captured.single.body), <String, Object?>{});
    });
  });

  group('OmnichannelShellController.sendGreeting (BRICK 0-APP)', () {
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

        final result = await controller.sendGreeting();

        expect(result, 'failed');
        expect(captured, isEmpty);
      },
    );
  });

  group('WhatsApp attachment sheet — "Kirim Sapaan" tile (BRICK 0-APP)', () {
    Future<void> openSheet(
      WidgetTester tester, {
      required Future<void> Function()? onGreetingTap,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showWhatsAppAttachmentSheet(
                  context: context,
                  onGalleryTap: () async {},
                  onCameraTap: () async {},
                  onLocationTap: () async {},
                  onContactTap: () async {},
                  onDocumentTap: () async {},
                  onAudioTap: () async {},
                  onPollTap: () async {},
                  onEventTap: () async {},
                  onGreetingTap: onGreetingTap,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('hidden when onGreetingTap null (flag OFF maps to null)', (
      tester,
    ) async {
      await openSheet(tester, onGreetingTap: null);
      expect(find.text('Kirim Sapaan'), findsNothing);
    });

    testWidgets('renders and invokes callback when provided (flag ON)', (
      tester,
    ) async {
      var called = false;
      await openSheet(
        tester,
        onGreetingTap: () async {
          called = true;
        },
      );
      expect(find.text('Kirim Sapaan'), findsOneWidget);
      await tester.tap(find.text('Kirim Sapaan'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });
  });
}
