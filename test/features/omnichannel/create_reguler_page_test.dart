import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_jet/core/network/api_client.dart';
import 'package:what_jet/features/omnichannel/presentation/pages/create_reguler_page.dart';

void main() {
  // Form is a long lazy ListView; widen the test surface so off-screen widgets
  // (submit button, seat chips) build for finders. Per-SDK widget-test tweak (see PIN).
  void tallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  List<Map<String, dynamic>> layout() => <Map<String, dynamic>>[
    <String, dynamic>{'code': 'driver', 'kind': 'driver', 'is_optional': false},
    <String, dynamic>{'code': '1A', 'kind': 'seat', 'is_optional': false},
    <String, dynamic>{'code': '2A', 'kind': 'seat', 'is_optional': false},
    <String, dynamic>{'code': '2B', 'kind': 'seat', 'is_optional': true},
    <String, dynamic>{'code': '3A', 'kind': 'seat', 'is_optional': false},
    <String, dynamic>{'code': '4A', 'kind': 'seat', 'is_optional': false},
    <String, dynamic>{'code': '5A', 'kind': 'seat', 'is_optional': false},
  ];

  List<String> codes(List<Map<String, dynamic>> s) =>
      s.map((e) => e['code'].toString()).toList();

  group('visibleSeatsForCapacity', () {
    test(
      '6 -> all incl 2B',
      () => expect(codes(visibleSeatsForCapacity(layout(), 6)), [
        '1A',
        '2A',
        '2B',
        '3A',
        '4A',
        '5A',
      ]),
    );
    test(
      '5 -> drop 2B',
      () => expect(codes(visibleSeatsForCapacity(layout(), 5)), [
        '1A',
        '2A',
        '3A',
        '4A',
        '5A',
      ]),
    );
    test(
      '2 -> two non-optional',
      () => expect(codes(visibleSeatsForCapacity(layout(), 2)), ['1A', '2A']),
    );
    test(
      'null -> all 6',
      () => expect(codes(visibleSeatsForCapacity(layout(), null)).length, 6),
    );
    test(
      'negative -> empty (defensif)',
      () => expect(codes(visibleSeatsForCapacity(layout(), -1)), isEmpty),
    );
  });

  group('availableSeatCodesForTrip (authoritative)', () {
    test(
      'total5 occupied[1A] avail2 -> [2A,3A]',
      () => expect(availableSeatCodesForTrip(layout(), 5, {'1A'}, 2), <String>[
        '2A',
        '3A',
      ]),
    );
    test(
      'avail0 -> empty',
      () => expect(
        availableSeatCodesForTrip(layout(), 5, <String>{}, 0),
        isEmpty,
      ),
    );
    test(
      'total6 avail6 no occupied -> 6 incl 2B',
      () => expect(
        availableSeatCodesForTrip(layout(), 6, <String>{}, 6).length,
        6,
      ),
    );
    test(
      'null available -> all free (5)',
      () => expect(
        availableSeatCodesForTrip(layout(), 5, <String>{}, null).length,
        5,
      ),
    );
  });

  List<Map<String, dynamic>> routesTwo() => <Map<String, dynamic>>[
    <String, dynamic>{
      'route_via': 'BANGKINANG',
      'stops': <String>['Pasirpengaraian', 'Pekanbaru'],
      'directions': <String>[],
    },
    <String, dynamic>{
      'route_via': 'PETAPAHAN',
      'stops': <String>['Suram', 'Pekanbaru'],
      'directions': <String>[],
    },
  ];

  Map<String, dynamic> trip() => <String, dynamic>{
    'trip_id': 1,
    'trip_time': '08:00',
    'mobil_plat': 'BM1',
    'route_via': 'BANGKINANG',
    'occupied_seats': <String>[],
    'available_count': 5,
    'total_count': 5,
  };

  Widget harness({
    Future<Map<String, dynamic>> Function(Map<String, Object?>)? onSubmit,
    List<Map<String, dynamic>>? trips,
  }) {
    return MaterialApp(
      home: CreateRegulerPage(
        onFetchRoutes: () async => routesTwo(),
        onFetchSeatAvailability: (d, dir, t) async =>
            trips ?? <Map<String, dynamic>>[],
        onFetchSeatLayout: () async => layout(),
        onFetchFare: (f, t) async => <String, dynamic>{
          'auto_fare_available': false,
          'fare': null,
        },
        onSubmit:
            onSubmit ?? (b) async => <String, dynamic>{'booking_code': 'X'},
        initialCustomerName: 'Budi',
        initialCustomerContact: '628111000111',
      ),
    );
  }

  Future<void> pickDropdown(
    WidgetTester tester,
    int index,
    String value,
  ) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(index));
    await tester.pumpAndSettle();
    await tester.tap(find.text(value).last);
    await tester.pumpAndSettle();
  }

  // Isi form sampai valid (BANGKINANG → kota → tanggal → trip → kursi 1A → override tarif).
  // PIN: interaksi showDatePicker ('OK') & item dropdown mungkin butuh tweak per-SDK.
  Future<void> fillValidForm(WidgetTester tester) async {
    tallSurface(tester);
    await tester.pumpAndSettle();
    await pickDropdown(tester, 0, 'BANGKINANG');
    await pickDropdown(tester, 1, 'Pasirpengaraian');
    await pickDropdown(tester, 2, 'Pekanbaru');
    await tester.tap(find.text('Pilih tanggal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // terima tanggal default (hari ini)
    await tester.pumpAndSettle();
    await tester.tap(find.text('Muat trip & kursi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jam 08:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '1A'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Titik jemput'), 'A');
    await tester.enterText(find.widgetWithText(TextField, 'Titik turun'), 'B');
    await tester.pump();
    await tester.tap(find.text('Cek tarif'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Tarif per kursi (wajib)'),
      '50000',
    );
    await tester.pump();
  }

  testWidgets('smoke: title + prefill + submit disabled', (tester) async {
    tallSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text('Buat Booking Reguler'), findsOneWidget);
    expect(find.text('Budi'), findsOneWidget);
    final btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Buat Booking (Draft)'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('route filter + changing cluster clears additional fare', (
    tester,
  ) async {
    tallSurface(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await pickDropdown(tester, 0, 'BANGKINANG');
    await pickDropdown(tester, 1, 'Pasirpengaraian');
    await pickDropdown(tester, 2, 'Pekanbaru');
    expect(find.text('Arah booking: to_pkb'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Ongkos tambahan per kursi (opsional)'),
      '5000',
    );
    await tester.pump();
    await pickDropdown(tester, 0, 'PETAPAHAN'); // cluster BEDA → reset
    expect(find.text('5000'), findsNothing);
  });

  testWidgets('submit success pops with booking_code', (tester) async {
    Map<String, Object?>? sent;
    await tester.pumpWidget(
      harness(
        trips: <Map<String, dynamic>>[trip()],
        onSubmit: (b) async {
          sent = b;
          return <String, dynamic>{
            'booking_code': 'RBK-1',
            'booking_status': 'Draft',
          };
        },
      ),
    );
    await tester.pumpAndSettle();
    await fillValidForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Buat Booking (Draft)'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Buat (Draft)'),
    ); // konfirmasi
    await tester.pumpAndSettle();
    expect(find.text('Buat Booking Reguler'), findsNothing); // page popped
    expect(sent?['from_city'], 'Pasirpengaraian');
    expect(sent?['selected_seats'], <String>['1A']);
  });

  testWidgets('submit 422 keeps form open with error', (tester) async {
    await tester.pumpWidget(
      harness(
        trips: <Map<String, dynamic>>[trip()],
        onSubmit: (b) async =>
            throw ApiException(message: 'Gagal buat', statusCode: 422),
      ),
    );
    await tester.pumpAndSettle();
    await fillValidForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Buat Booking (Draft)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Buat (Draft)'));
    await tester.pumpAndSettle();
    expect(find.text('Buat Booking Reguler'), findsOneWidget); // masih terbuka
    expect(find.text('Gagal buat'), findsOneWidget);
  });

  testWidgets('submit 503 keeps form and locks submit (reconcile)', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        trips: <Map<String, dynamic>>[trip()],
        onSubmit: (b) async => throw ApiException(
          message: 'timeout',
          statusCode: 503,
          payload: <String, dynamic>{'reconcile_required': true},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await fillValidForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Buat Booking (Draft)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Buat (Draft)'));
    await tester.pumpAndSettle();
    expect(find.text('Buat Booking Reguler'), findsOneWidget);
    expect(find.textContaining('belum pasti'), findsOneWidget);
    final btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Buat Booking (Draft)'),
    );
    expect(btn.onPressed, isNull); // terkunci (reconcile)
  });

  testWidgets('trips filtered to selected cluster only', (tester) async {
    await tester.pumpWidget(
      harness(
        trips: <Map<String, dynamic>>[
          <String, dynamic>{
            'trip_time': '08:00',
            'route_via': 'BANGKINANG',
            'occupied_seats': <String>[],
            'available_count': 5,
            'total_count': 5,
          },
          <String, dynamic>{
            'trip_time': '09:00',
            'route_via': 'PETAPAHAN',
            'occupied_seats': <String>[],
            'available_count': 5,
            'total_count': 5,
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    await pickDropdown(tester, 0, 'BANGKINANG');
    await pickDropdown(tester, 1, 'Pasirpengaraian');
    await pickDropdown(tester, 2, 'Pekanbaru');
    await tester.tap(find.text('Pilih tanggal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Muat trip & kursi'));
    await tester.pumpAndSettle();
    expect(find.text('Jam 08:00'), findsOneWidget); // BANGKINANG
    expect(find.text('Jam 09:00'), findsNothing); // PETAPAHAN difilter keluar
  });

  testWidgets('offline POST (statusCode null) locks submit', (tester) async {
    await tester.pumpWidget(
      harness(
        trips: <Map<String, dynamic>>[trip()],
        onSubmit: (b) async => throw ApiException(message: 'Koneksi gagal'),
      ),
    );
    await tester.pumpAndSettle();
    await fillValidForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Buat Booking (Draft)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Buat (Draft)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('belum pasti'), findsOneWidget);
    final btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Buat Booking (Draft)'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('reconcile is terminal — survives cluster change', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        trips: <Map<String, dynamic>>[trip()],
        onSubmit: (b) async => throw ApiException(
          message: 'timeout',
          statusCode: 503,
          payload: <String, dynamic>{'reconcile_required': true},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await fillValidForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Buat Booking (Draft)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Buat (Draft)'));
    await tester.pumpAndSettle();
    await pickDropdown(tester, 0, 'PETAPAHAN'); // ganti cluster
    final btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Buat Booking (Draft)'),
    );
    expect(btn.onPressed, isNull); // TETAP terkunci (reconcile terminal)
  });
}
