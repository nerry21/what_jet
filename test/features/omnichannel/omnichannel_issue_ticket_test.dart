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

  group('ApiEndpoints issue-ticket builder (BRICK 2-APP)', () {
    test('issue-ticket path is conversation-level flat issue-ticket', () {
      expect(
        ApiEndpoints.adminConversationIssueTicket(7),
        endsWith('/conversations/7/issue-ticket'),
      );
    });

    test('issue-ticket bookings path is conversation-level nested', () {
      expect(
        ApiEndpoints.adminConversationIssueTicketBookings(7),
        endsWith('/conversations/7/issue-ticket/bookings'),
      );
    });
  });

  group('OmnichannelRepository.issueTicket (BRICK 2-APP)', () {
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
            'message': 'Tiket dropping dikirim ke owner.',
            'data': <String, Object?>{
              'booking_code': 'DBK-1',
              'category': 'dropping',
              'flow': 'direct',
            },
          }),
          200,
        ),
      );

      final result = await repo.issueTicket(
        conversationId: 42,
        bookingCode: 'DBK-1',
      );

      expect(result, 'Tiket dropping dikirim ke owner.');
      expect(captured, hasLength(1));
      expect(captured.single.method, 'POST');
      expect(
        captured.single.url.path,
        endsWith('/conversations/42/issue-ticket'),
      );
      expect(jsonDecode(captured.single.body), <String, Object?>{
        'booking_code': 'DBK-1',
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
            'message': 'Booking belum lunas.',
          }),
          422,
        ),
      );

      await expectLater(
        repo.issueTicket(conversationId: 42, bookingCode: 'DBK-1'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Booking belum lunas.',
          ),
        ),
      );
      expect(captured, hasLength(1));
    });
  });

  group('OmnichannelRepository.fetchIssueTicketBookings (BRICK 2-APP)', () {
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

    test('GETs bookings and unwraps data.bookings list', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'admin_mobile_access_token': 'admin-test-token',
      });
      final repo = buildRepository(
        (_) => http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'message': 'Daftar booking diambil.',
            'data': <String, Object?>{
              'bookings': <Object?>[
                <String, Object?>{
                  'booking_code': 'DBK-1',
                  'category': 'dropping',
                  'payment_status': 'paid',
                },
              ],
            },
          }),
          200,
        ),
      );

      final result = await repo.fetchIssueTicketBookings(conversationId: 42);

      expect(result, hasLength(1));
      expect(result.single['booking_code'], 'DBK-1');
      expect(captured, hasLength(1));
      expect(captured.single.method, 'GET');
      expect(
        captured.single.url.path,
        endsWith('/conversations/42/issue-ticket/bookings'),
      );
    });
  });
}
