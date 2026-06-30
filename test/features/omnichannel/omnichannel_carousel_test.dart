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

  group('ApiEndpoints carousel builder (BRIEF 6)', () {
    test('carousel path is conversation-level send-carousel', () {
      expect(
        ApiEndpoints.adminConversationCarousel(7),
        endsWith('/conversations/7/send-carousel'),
      );
    });
  });

  group('OmnichannelRepository.sendRouteCarousel (BRIEF 6)', () {
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
        'message': 'Daftar rute berhasil dikirim.',
      }),
      201,
    );

    test('POSTs empty body to send-carousel, returns message', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository((_) => ok());

      final result = await repo.sendRouteCarousel(conversationId: 42);

      expect(result, 'Daftar rute berhasil dikirim.');
      expect(captured, hasLength(1));
      expect(captured.single.method, 'POST');
      expect(
        captured.single.url.path,
        endsWith('/conversations/42/send-carousel'),
      );
      expect(jsonDecode(captured.single.body), <String, Object?>{});
    });
  });

  group('OmnichannelShellController.sendRouteCarousel (BRIEF 6)', () {
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

        final result = await controller.sendRouteCarousel();

        expect(result, 'failed');
        expect(captured, isEmpty);
      },
    );
  });

  group('WhatsApp attachment sheet — "Daftar Rute" tile (BRIEF 6)', () {
    Future<void> openSheet(
      WidgetTester tester, {
      required Future<void> Function()? onCarouselTap,
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
                  onCarouselTap: onCarouselTap,
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

    testWidgets('hidden when onCarouselTap null (flag OFF maps to null)', (
      tester,
    ) async {
      await openSheet(tester, onCarouselTap: null);
      expect(find.text('Daftar Rute'), findsNothing);
    });

    testWidgets('renders and invokes callback when provided (flag ON)', (
      tester,
    ) async {
      var called = false;
      await openSheet(
        tester,
        onCarouselTap: () async {
          called = true;
        },
      );
      expect(find.text('Daftar Rute'), findsOneWidget);
      await tester.tap(find.text('Daftar Rute'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });
  });
}
