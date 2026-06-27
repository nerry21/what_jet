import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:what_jet/core/network/api_client.dart';
import 'package:what_jet/core/storage/admin_token_storage.dart';
import 'package:what_jet/features/admin_auth/data/repositories/admin_auth_repository.dart';
import 'package:what_jet/features/admin_auth/data/services/admin_auth_api_service.dart';
import 'package:what_jet/features/omnichannel/data/repositories/omnichannel_repository.dart';
import 'package:what_jet/features/omnichannel/data/services/omnichannel_api_service.dart';
import 'package:what_jet/features/omnichannel/presentation/widgets/omnichannel_new_chat_page.dart';

class _CapturingApiClient extends ApiClient {
  int postCount = 0;
  Map<String, Object?>? lastBody;
  Completer<Map<String, dynamic>>? gate;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
    Map<String, Object?> body = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
  }) {
    postCount++;
    lastBody = body;
    final pending = gate;
    if (pending != null) {
      return pending.future;
    }
    return Future<Map<String, dynamic>>.value(<String, dynamic>{});
  }
}

OmnichannelRepository _buildRepository(_CapturingApiClient client) {
  return OmnichannelRepository(
    apiService: OmnichannelApiService(client),
    adminAuthRepository: AdminAuthRepository(
      authApiService: AdminAuthApiService(client),
      tokenStorage: AdminTokenStorage(),
    ),
  );
}

Future<void> _pushCreatePage(
  WidgetTester tester,
  OmnichannelRepository repository, {
  String initialFirstName = '',
  String initialPhone = '',
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push<int>(
              MaterialPageRoute<int>(
                builder: (_) => OmnichannelCreateContactPage(
                  repository: repository,
                  initialFirstName: initialFirstName,
                  initialPhone: initialPhone,
                ),
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'admin_mobile_access_token': 'admin-test-token',
    });
  });

  group('OmnichannelCreateContactPage — Simpan Kontak (BRIEF #3)', () {
    testWidgets('a. prefill kosong = New Chat lama identik', (tester) async {
      final client = _CapturingApiClient();
      await _pushCreatePage(tester, _buildRepository(client));

      expect(find.text('ID +62'), findsOneWidget);
      expect(find.text('Nama depan'), findsOneWidget);
      expect(find.text('Telepon'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(client.postCount, 0);
    });

    testWidgets('b. prefill set → field terisi', (tester) async {
      final client = _CapturingApiClient();
      await _pushCreatePage(
        tester,
        _buildRepository(client),
        initialFirstName: 'Maidianasari',
        initialPhone: '+6281267975175',
      );

      expect(find.text('Maidianasari'), findsOneWidget);
      expect(find.text('+6281267975175'), findsOneWidget);
    });

    testWidgets('c. submit valid → POST body lengkap + country ID', (
      tester,
    ) async {
      final client = _CapturingApiClient();
      await _pushCreatePage(tester, _buildRepository(client));

      await tester.enterText(
        find.widgetWithText(TextField, 'Nama depan'),
        'Budi',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Telepon'),
        '0812345678',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Email (opsional)'),
        'budi@mail.com',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(client.lastBody!['first_name'], 'Budi');
      expect(client.lastBody!['phone'], '+62812345678');
      expect(client.lastBody!['email'], 'budi@mail.com');
      expect(client.lastBody!['country_code'], '+62');
      expect(client.lastBody!.containsKey('sync_to_device'), isTrue);
    });

    testWidgets('d. negara non-ID (MY +60) → prefix telepon & country ikut', (
      tester,
    ) async {
      final client = _CapturingApiClient();
      await _pushCreatePage(tester, _buildRepository(client));

      await tester.tap(find.text('ID +62'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MY +60'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nama depan'),
        'Lim',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Telepon'),
        '0123456789',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(client.lastBody!['country_code'], '+60');
      expect(client.lastBody!['phone'], '+60123456789');
    });

    testWidgets('g1. anti-double-prefix ID: 62812… → +62812… (bukan +6262…)', (
      tester,
    ) async {
      final client = _CapturingApiClient();
      await _pushCreatePage(tester, _buildRepository(client));

      await tester.enterText(
        find.widgetWithText(TextField, 'Nama depan'),
        'Budi',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Telepon'),
        '62812345678',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(client.lastBody!['phone'], '+62812345678');
    });

    testWidgets('g2. anti-double-prefix MY: 60123… → +60123… (bukan +6060…)', (
      tester,
    ) async {
      final client = _CapturingApiClient();
      await _pushCreatePage(tester, _buildRepository(client));

      await tester.tap(find.text('ID +62'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MY +60'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nama depan'),
        'Lim',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Telepon'),
        '60123456789',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(client.lastBody!['phone'], '+60123456789');
    });

    testWidgets('g3. input ber-+ → apa adanya (passthrough)', (tester) async {
      final client = _CapturingApiClient();
      await _pushCreatePage(tester, _buildRepository(client));

      await tester.enterText(
        find.widgetWithText(TextField, 'Nama depan'),
        'Lim',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Telepon'),
        '+60123456789',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(client.lastBody!['phone'], '+60123456789');
    });

    testWidgets('f. double-tap Simpan → POST sekali (guard _isSaving)', (
      tester,
    ) async {
      final client = _CapturingApiClient();
      client.gate = Completer<Map<String, dynamic>>();
      await _pushCreatePage(tester, _buildRepository(client));

      await tester.enterText(
        find.widgetWithText(TextField, 'Nama depan'),
        'Budi',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Telepon'),
        '0812345678',
      );

      await tester.tap(find.text('Simpan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // POST pertama in-flight (gate belum complete): tepat 1 POST, dan guard
      // _isSaving menonaktifkan tombol (child → spinner, onPressed null) sehingga
      // tap kedua mustahil menembak POST lagi.
      expect(client.postCount, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text('Simpan'), findsNothing);

      client.gate!.complete(<String, dynamic>{});
      await tester.pumpAndSettle();
      expect(client.postCount, 1);
    });

    testWidgets('e. account picker kosong (host) → fallback, tak crash', (
      tester,
    ) async {
      final client = _CapturingApiClient();
      await _pushCreatePage(tester, _buildRepository(client));

      await tester.tap(find.text('Akun perangkat (default)'));
      await tester.pumpAndSettle();
      expect(find.text('Akun perangkat (default)'), findsWidgets);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
