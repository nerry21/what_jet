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

  group('ApiEndpoints confirm-cash builder (BRICK 3-APP)', () {
    test('confirm-cash path is conversation-level flat confirm-cash', () {
      expect(
        ApiEndpoints.adminConversationConfirmCash(7),
        endsWith('/conversations/7/confirm-cash'),
      );
    });
  });

  group('OmnichannelRepository.confirmCash (BRICK 3-APP)', () {
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

    test('POSTs booking_code only and returns top-level message', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'message': 'Pembayaran cash dikonfirmasi (lunas).',
            'data': <String, Object?>{
              'booking_code': 'JET-1',
              'payment_status': 'paid',
            },
          }),
          200,
        ),
      );

      final result = await repo.confirmCash(
        conversationId: 42,
        bookingCode: 'JET-1',
      );

      expect(result, 'Pembayaran cash dikonfirmasi (lunas).');
      expect(captured, hasLength(1));
      expect(captured.single.method, 'POST');
      expect(
        captured.single.url.path,
        endsWith('/conversations/42/confirm-cash'),
      );
      expect(jsonDecode(captured.single.body), <String, Object?>{
        'booking_code': 'JET-1',
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
            'message': 'Booking ini sudah lunas.',
          }),
          422,
        ),
      );

      await expectLater(
        repo.confirmCash(conversationId: 42, bookingCode: 'JET-1'),
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
}
