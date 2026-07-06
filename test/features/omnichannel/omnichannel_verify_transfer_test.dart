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

  group('ApiEndpoints verify-transfer builder (BRICK 3B-APP)', () {
    test('verify-transfer path is conversation-level flat verify-transfer', () {
      expect(
        ApiEndpoints.adminConversationVerifyTransfer(7),
        endsWith('/conversations/7/verify-transfer'),
      );
    });
  });

  group('OmnichannelRepository.verifyTransfer (BRICK 3B-APP)', () {
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

    test('POSTs booking_code + amount and returns top-level message', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'message': 'Pembayaran transfer diverifikasi (lunas).',
            'data': <String, Object?>{
              'booking_code': 'JET-1',
              'payment_status': 'paid',
            },
          }),
          200,
        ),
      );

      final result = await repo.verifyTransfer(
        conversationId: 42,
        bookingCode: 'JET-1',
        amount: 150000,
      );

      expect(result, 'Pembayaran transfer diverifikasi (lunas).');
      expect(captured, hasLength(1));
      expect(captured.single.method, 'POST');
      expect(
        captured.single.url.path,
        endsWith('/conversations/42/verify-transfer'),
      );
      expect(jsonDecode(captured.single.body), <String, Object?>{
        'booking_code': 'JET-1',
        'amount': 150000,
      });
    });

    test('includes reference when non-empty', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'message': 'Pembayaran transfer diverifikasi (lunas).',
          }),
          200,
        ),
      );

      await repo.verifyTransfer(
        conversationId: 42,
        bookingCode: 'JET-1',
        amount: 150000,
        reference: 'TRX-9',
      );

      expect(jsonDecode(captured.single.body), <String, Object?>{
        'booking_code': 'JET-1',
        'amount': 150000,
        'reference': 'TRX-9',
      });
    });

    test('omits reference when blank/whitespace', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'message': 'Pembayaran transfer diverifikasi (lunas).',
          }),
          200,
        ),
      );

      await repo.verifyTransfer(
        conversationId: 42,
        bookingCode: 'JET-1',
        amount: 150000,
        reference: '   ',
      );

      expect(jsonDecode(captured.single.body), <String, Object?>{
        'booking_code': 'JET-1',
        'amount': 150000,
      });
    });

    test('propagates BE 422 as ApiException carrying the BE message', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'success': false,
            'message': 'Nominal tidak valid.',
          }),
          422,
        ),
      );

      await expectLater(
        repo.verifyTransfer(
          conversationId: 42,
          bookingCode: 'JET-1',
          amount: 0,
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Nominal tidak valid.',
          ),
        ),
      );
      expect(captured, hasLength(1));
    });
  });
}
