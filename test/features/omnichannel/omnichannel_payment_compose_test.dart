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
import 'package:what_jet/features/omnichannel/presentation/widgets/manual_payment_compose_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiEndpoints compose builders (B-APP)', () {
    test('bookings path is conversation-level manual-payment/bookings', () {
      expect(
        ApiEndpoints.adminConversationComposeBookings(7),
        endsWith('/conversations/7/manual-payment/bookings'),
      );
    });

    test('send-composed path is conversation-level send-composed', () {
      expect(
        ApiEndpoints.adminConversationSendComposed(7),
        endsWith('/conversations/7/manual-payment/send-composed'),
      );
    });
  });

  group('OmnichannelRepository compose (B-APP)', () {
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

    // C-1 LOCK: ApiClient._decodeResponse FLATTENS `data` to top-level, so the
    // repo MUST read via _extractPayloadData(payload)['bookings'], NOT
    // res['data']['bookings'] (which would be null -> always empty).
    test('fetchComposeBookings parses flattened data.bookings', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'bookings': <Object?>[
                <String, Object?>{
                  'booking_code': 'JET-1',
                  'from_city': 'Pekanbaru',
                  'to_city': 'Pasir',
                  'total_amount': 150000,
                  'payment_status': 'belum_lunas',
                },
              ],
            },
          }),
          200,
        ),
      );

      final result = await repo.fetchComposeBookings(conversationId: 42);

      expect(result, hasLength(1));
      expect(result.first['booking_code'], 'JET-1');
      expect(result.first['total_amount'], 150000);
      expect(captured.single.method, 'GET');
      expect(
        captured.single.url.path,
        endsWith('/conversations/42/manual-payment/bookings'),
      );
    });

    test('sendComposedPayment POSTs full body and returns message', () async {
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

      final result = await repo.sendComposedPayment(
        conversationId: 42,
        paymentType: 'qris',
        bookingCode: null,
        total: 150000,
        loket: 'pasir',
      );

      expect(result, 'Instruksi pembayaran terkirim.');
      expect(captured.single.method, 'POST');
      expect(
        captured.single.url.path,
        endsWith('/conversations/42/manual-payment/send-composed'),
      );
      expect(jsonDecode(captured.single.body), <String, Object?>{
        'payment_type': 'qris',
        'booking_code': null,
        'total': 150000,
        'loket': 'pasir',
      });
    });

    test('sendComposedPayment falls back when BE omits message', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) =>
            http.Response(jsonEncode(<String, Object?>{'success': true}), 200),
      );

      final result = await repo.sendComposedPayment(
        conversationId: 42,
        paymentType: 'norek',
        bookingCode: 'JET-9',
        total: 200000,
        loket: null,
      );

      expect(result, 'Instruksi pembayaran berhasil dikirim.');
    });
  });

  group('ManualPaymentComposeDialog (B-APP)', () {
    testWidgets('renders bookings and returns result-object on confirm', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ManualPaymentComposeResult? result;
      var popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog<ManualPaymentComposeResult>(
                    context: context,
                    builder: (_) => ManualPaymentComposeDialog(
                      paymentType: 'norek',
                      onFetchBookings: () async => <Map<String, dynamic>>[
                        <String, dynamic>{
                          'booking_code': 'JET-1',
                          'from_city': 'PKU',
                          'to_city': 'Pasir',
                          'trip_date': '2026-07-02',
                          'total_amount': 150000,
                        },
                      ],
                    ),
                  );
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('JET-1 · PKU → Pasir'), findsOneWidget);
      expect(find.text('Tanpa kode booking'), findsOneWidget);

      await tester.tap(find.text('JET-1 · PKU → Pasir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Konfirmasi'));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(result, isNotNull);
      expect(result!.bookingCode, 'JET-1');
      expect(result!.total, 150000);
      expect(result!.loket, isNull);
    });

    testWidgets('QRIS tanpa-kode: Konfirmasi disabled until total & loket', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<ManualPaymentComposeResult>(
                  context: context,
                  builder: (_) => ManualPaymentComposeDialog(
                    paymentType: 'qris',
                    onFetchBookings: () async => const <Map<String, dynamic>>[],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tanpa kode booking'));
      await tester.pumpAndSettle();

      final konfirmasi = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Konfirmasi'),
      );
      expect(konfirmasi.onPressed, isNull);
    });
  });
}
