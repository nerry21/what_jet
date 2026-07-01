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

  group('ApiEndpoints payment builder (BRICK 1-APP)', () {
    test('payment path is conversation-level send-payment', () {
      expect(
        ApiEndpoints.adminConversationPayment(7),
        endsWith('/conversations/7/send-payment'),
      );
    });
  });

  group('OmnichannelRepository.sendPayment (BRICK 1-APP)', () {
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

    test('POSTs payment_type body to send-payment, returns message', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'message': 'Instruksi pembayaran terkirim.',
          }),
          200,
        ),
      );

      final result = await repo.sendPayment(
        conversationId: 42,
        paymentType: 'qris',
      );

      expect(result, 'Instruksi pembayaran terkirim.');
      expect(captured, hasLength(1));
      expect(captured.single.method, 'POST');
      expect(
        captured.single.url.path,
        endsWith('/conversations/42/send-payment'),
      );
      expect(jsonDecode(captured.single.body), <String, Object?>{
        'payment_type': 'qris',
      });
    });

    test('falls back to default message when BE omits message', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) =>
            http.Response(jsonEncode(<String, Object?>{'success': true}), 200),
      );

      final result = await repo.sendPayment(
        conversationId: 42,
        paymentType: 'norek',
      );

      expect(result, 'Instruksi pembayaran berhasil dikirim.');
    });

    test('propagates BE 422 as ApiException carrying the BE message', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'success': false,
            'message': 'Booking ini sudah lunas.',
          }),
          422,
        ),
      );

      await expectLater(
        repo.sendPayment(conversationId: 42, paymentType: 'qris'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Booking ini sudah lunas.',
          ),
        ),
      );
      expect(captured, hasLength(1));
    });
  });

  group('OmnichannelShellController.sendPayment (BRICK 1-APP)', () {
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

        final result = await controller.sendPayment('qris');

        expect(result, 'failed');
        expect(captured, isEmpty);
      },
    );
  });

  group('WhatsApp attachment sheet — QRIS/No-rek tiles (BRICK 1-APP)', () {
    Future<void> openSheet(
      WidgetTester tester, {
      required Future<void> Function()? onSendQrisTap,
      required Future<void> Function()? onSendNorekTap,
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
                  onSendQrisTap: onSendQrisTap,
                  onSendNorekTap: onSendNorekTap,
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

    testWidgets('hidden when both callbacks null (flag OFF maps to null)', (
      tester,
    ) async {
      await openSheet(tester, onSendQrisTap: null, onSendNorekTap: null);
      expect(find.text('Kirim QRIS'), findsNothing);
      expect(find.text('Kirim No-rek'), findsNothing);
    });

    testWidgets('renders both tiles and invokes QRIS when provided', (
      tester,
    ) async {
      var qrisCalled = false;
      await openSheet(
        tester,
        onSendQrisTap: () async {
          qrisCalled = true;
        },
        onSendNorekTap: () async {},
      );
      expect(find.text('Kirim QRIS'), findsOneWidget);
      expect(find.text('Kirim No-rek'), findsOneWidget);

      await tester.tap(find.text('Kirim QRIS'));
      await tester.pumpAndSettle();
      expect(qrisCalled, isTrue);
    });

    testWidgets('invokes No-rek callback when its tile is tapped', (
      tester,
    ) async {
      var norekCalled = false;
      await openSheet(
        tester,
        onSendQrisTap: () async {},
        onSendNorekTap: () async {
          norekCalled = true;
        },
      );

      await tester.tap(find.text('Kirim No-rek'));
      await tester.pumpAndSettle();
      expect(norekCalled, isTrue);
    });
  });
}
