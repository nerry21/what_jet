import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart'; // ApiException — PIN: verifikasi path saat apply

/// Murni & testable — mirror RealtimeSeatAvailabilityService:144-151.
List<Map<String, dynamic>> visibleSeatsForCapacity(
  List<Map<String, dynamic>> seatLayout,
  int? totalCount,
) {
  final seats = seatLayout
      .where((seat) => seat['kind'] == 'seat')
      .toList(growable: false);
  // M4(v4.2): defensif — total_count negatif/berlebih di-clamp ke [0, jumlah kursi].
  final total = (totalCount ?? seats.length).clamp(0, seats.length).toInt();
  if (total >= seats.length) {
    return seats.take(total).toList(growable: false);
  }
  final withoutOptional = seats
      .where((seat) => seat['is_optional'] != true)
      .toList(growable: false);
  return withoutOptional.take(total).toList(growable: false);
}

/// Kursi yang BOLEH dipilih (authoritative) — mirror RealtimeSeatAvailabilityService:152-157:
/// visible layout − occupied, lalu take available_count. Hanya kode di sini yang selectable.
List<String> availableSeatCodesForTrip(
  List<Map<String, dynamic>> seatLayout,
  int? totalCount,
  Set<String> occupied,
  int? availableCount,
) {
  final free = visibleSeatsForCapacity(seatLayout, totalCount)
      .map((seat) => seat['code'].toString())
      .where((code) => !occupied.contains(code))
      .toList(growable: false);
  final avail = (availableCount ?? free.length).clamp(0, free.length).toInt();
  return free.take(avail).toList(growable: false);
}

class CreateRegulerPage extends StatefulWidget {
  const CreateRegulerPage({
    super.key,
    required this.onFetchRoutes,
    required this.onFetchSeatAvailability,
    required this.onFetchSeatLayout,
    required this.onFetchFare,
    required this.onSubmit,
    this.initialCustomerName = '',
    this.initialCustomerContact = '',
  });

  final Future<List<Map<String, dynamic>>> Function() onFetchRoutes;
  final Future<List<Map<String, dynamic>>> Function(
    String tripDate,
    String direction,
    String routeVia,
    String fromCity,
    String toCity,
  )
  onFetchSeatAvailability;
  final Future<List<Map<String, dynamic>>> Function() onFetchSeatLayout;
  final Future<Map<String, dynamic>> Function(String fromCity, String toCity)
  onFetchFare;
  final Future<Map<String, dynamic>> Function(Map<String, Object?> body)
  onSubmit;
  final String initialCustomerName;
  final String initialCustomerContact;

  @override
  State<CreateRegulerPage> createState() => _CreateRegulerPageState();
}

class _CreateRegulerPageState extends State<CreateRegulerPage> {
  final String _idempotencyKey = _generateIdempotencyKey();

  bool _isLoadingRoutes = true;
  String? _routesError;
  List<Map<String, dynamic>> _routes = const <Map<String, dynamic>>[];
  String? _routeVia;
  List<String> _stops = const <String>[];
  String? _fromCity;
  String? _toCity;

  DateTime? _tripDate;
  bool _isLoadingTrips = false;
  String? _tripsError;
  List<Map<String, dynamic>> _trips = const <Map<String, dynamic>>[];
  Map<String, dynamic>? _selectedTrip;

  List<Map<String, dynamic>> _seatLayout = const <Map<String, dynamic>>[];
  final Set<String> _selectedSeats = <String>{};

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final TextEditingController _pickupCtrl = TextEditingController();
  final TextEditingController _dropoffCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  bool _isLoadingFare = false;
  String? _fareError;
  bool? _autoFareAvailable;
  int? _autoFarePrice;
  final TextEditingController _overrideCtrl = TextEditingController();
  final TextEditingController _additionalCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _submitError;
  bool _reconcileRequired = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialCustomerName);
    _phoneCtrl = TextEditingController(text: widget.initialCustomerContact);
    _loadInitial();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    _notesCtrl.dispose();
    _overrideCtrl.dispose();
    _additionalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final results = await Future.wait(<Future<List<Map<String, dynamic>>>>[
        widget.onFetchRoutes(),
        widget.onFetchSeatLayout(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _routes = results[0];
        _seatLayout = results[1];
        _isLoadingRoutes = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _routesError = 'Gagal memuat rute: $error';
        _isLoadingRoutes = false;
      });
    }
  }

  // M4/M6: reset trip+kursi+fare+ongkos saat route/kota berubah.
  // M1(v4.2): _reconcileRequired TIDAK di-reset di sini — status uncertain bersifat
  // TERMINAL (submit tetap terkunci meski form diedit; recovery = keluar sadar + sesi baru).
  void _resetTripSeatFare() {
    _tripDate = null;
    _trips = const <Map<String, dynamic>>[];
    _selectedTrip = null;
    _tripsError = null;
    _selectedSeats.clear();
    _fareError = null;
    _autoFareAvailable = null;
    _autoFarePrice = null;
    _overrideCtrl.clear();
    _additionalCtrl.clear();
    _submitError = null;
  }

  void _onRouteViaChanged(String? routeVia) {
    if (routeVia == null) {
      return;
    }
    final match = _routes.firstWhere(
      (route) => route['route_via'] == routeVia,
      orElse: () => const <String, dynamic>{},
    );
    final rawStops = match['stops'] as List<dynamic>? ?? const <dynamic>[];
    setState(() {
      _routeVia = routeVia;
      _stops = rawStops.map((stop) => stop.toString()).toList(growable: false);
      _fromCity = null;
      _toCity = null;
      _resetTripSeatFare();
    });
  }

  String? get _bookingDirection {
    final from = _fromCity;
    final to = _toCity;
    if (from == null || to == null) {
      return null;
    }
    final fromIdx = _stops.indexOf(from);
    final toIdx = _stops.indexOf(to);
    if (fromIdx < 0 || toIdx < 0 || fromIdx == toIdx) {
      return null;
    }
    return fromIdx < toIdx ? 'to_pkb' : 'from_pkb';
  }

  String? get _tripPlanningDirection {
    switch (_bookingDirection) {
      case 'to_pkb':
        return 'ROHUL_TO_PKB';
      case 'from_pkb':
        return 'PKB_TO_ROHUL';
      default:
        return null;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _tripDate = picked;
      _trips = const <Map<String, dynamic>>[];
      _selectedTrip = null;
      _selectedSeats.clear();
    });
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _loadTrips() async {
    final direction = _tripPlanningDirection;
    final date = _tripDate;
    final routeVia = _routeVia;
    if (direction == null ||
        date == null ||
        routeVia == null ||
        _fromCity == null ||
        _toCity == null) {
      return;
    }
    setState(() {
      _isLoadingTrips = true;
      _tripsError = null;
      _trips = const <Map<String, dynamic>>[];
      _selectedTrip = null;
      _selectedSeats.clear();
    });
    try {
      final trips = await widget.onFetchSeatAvailability(
        _formatDate(date),
        direction,
        routeVia,
        _fromCity!,
        _toCity!,
      );
      if (!mounted) {
        return;
      }
      final filtered = trips
          .where((trip) => trip['route_via'] == routeVia)
          .toList(growable: false);
      setState(() {
        _trips = filtered;
        _isLoadingTrips = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _tripsError = 'Gagal memuat kursi: $error';
        _isLoadingTrips = false;
      });
    }
  }

  Set<String> get _occupiedSeats {
    final trip = _selectedTrip;
    if (trip == null) {
      return const <String>{};
    }
    final raw = trip['occupied_seats'] as List<dynamic>? ?? const <dynamic>[];
    return raw.map((seat) => seat.toString()).toSet();
  }

  List<Map<String, dynamic>> get _visibleSeats => visibleSeatsForCapacity(
    _seatLayout,
    (_selectedTrip?['total_count'] as num?)?.toInt(),
  );

  Set<String> get _availableSeatCodes => availableSeatCodesForTrip(
    _seatLayout,
    (_selectedTrip?['total_count'] as num?)?.toInt(),
    _occupiedSeats,
    (_selectedTrip?['available_count'] as num?)?.toInt(),
  ).toSet();

  int? get _effectiveUnitFare {
    if (_autoFareAvailable == true) {
      return _autoFarePrice;
    }
    if (_autoFareAvailable == false) {
      return int.tryParse(_overrideCtrl.text.trim());
    }
    return null;
  }

  Future<void> _loadFare() async {
    final from = _fromCity;
    final to = _toCity;
    if (from == null || to == null) {
      return;
    }
    setState(() {
      _isLoadingFare = true;
      _fareError = null;
    });
    try {
      final fare = await widget.onFetchFare(from, to);
      if (!mounted) {
        return;
      }
      final available = fare['auto_fare_available'] == true;
      final fareData = fare['fare'];
      int? price;
      if (fareData is Map) {
        final rawPrice = fareData['price'];
        if (rawPrice is int) {
          price = rawPrice;
        } else if (rawPrice != null) {
          price = int.tryParse(rawPrice.toString());
        }
      }
      setState(() {
        _autoFareAvailable = available;
        _autoFarePrice = price;
        _isLoadingFare = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _fareError = 'Gagal cek tarif (jaringan/LKT). Coba lagi.';
        _autoFareAvailable = null;
        _autoFarePrice = null;
        _isLoadingFare = false;
      });
    }
  }

  bool get _canSubmit {
    if (_isSubmitting || _reconcileRequired) {
      return false;
    }
    if (_fromCity == null || _toCity == null || _bookingDirection == null) {
      return false;
    }
    if (_tripDate == null || _selectedTrip == null || _selectedSeats.isEmpty) {
      return false;
    }
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().length < 9) {
      return false;
    }
    if (_pickupCtrl.text.trim().isEmpty || _dropoffCtrl.text.trim().isEmpty) {
      return false;
    }
    // M10: fare wajib sukses + harga > 0 (auto) atau override >= 1.
    final unit = _effectiveUnitFare;
    if (unit == null || unit < 1) {
      return false;
    }
    return true;
  }

  Map<String, Object?> _buildBody() {
    final trip = _selectedTrip!;
    final body = <String, Object?>{
      'idempotency_key': _idempotencyKey,
      'customer_phone': _phoneCtrl.text.trim(),
      'customer_name': _nameCtrl.text.trim(),
      'trip_date': _formatDate(_tripDate!),
      'trip_time': trip['trip_time']?.toString() ?? '',
      'trip_id': (trip['trip_id'] as num?)?.toInt(),
      'route_via': 'BANGKINANG',
      'direction': _bookingDirection,
      'from_city': _fromCity,
      'to_city': _toCity,
      'selected_seats': _selectedSeats.toList(growable: false),
      'pickup_location': _pickupCtrl.text.trim(),
      'dropoff_location': _dropoffCtrl.text.trim(),
    };
    final notes = _notesCtrl.text.trim();
    if (notes.isNotEmpty) {
      body['notes'] = notes;
    }
    if (_autoFareAvailable == false) {
      body['unit_fare_override'] = int.tryParse(_overrideCtrl.text.trim());
    }
    final additional = int.tryParse(_additionalCtrl.text.trim());
    if (additional != null && additional > 0) {
      body['additional_fare'] = additional;
    }
    return body;
  }

  Future<void> _confirmAndSubmit() async {
    if (!_canSubmit) {
      return;
    }
    final trip = _selectedTrip!;
    final seatCount = _selectedSeats.length;
    final unitFare = _effectiveUnitFare ?? 0;
    final additional = int.tryParse(_additionalCtrl.text.trim()) ?? 0;
    final total = (unitFare + additional) * seatCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi booking (Draft)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Rute: $_fromCity → $_toCity'),
              Text('Arah: ${_bookingDirection ?? '-'}'),
              Text(
                'Tanggal/jam: ${_formatDate(_tripDate!)}  ${trip['trip_time'] ?? ''}',
              ),
              Text('Kursi: ${_selectedSeats.join(', ')} ($seatCount)'),
              Text('Perkiraan total: $total'),
              const SizedBox(height: 8),
              const Text(
                'Catatan: armada final ditentukan LKT saat approval.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Buat (Draft)'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final result = await widget.onSubmit(_buildBody());
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result); // SUKSES → parent snackbar + refresh.
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      final payload = error.payload;
      // M2(v4.2): untuk POST create, statusCode null (koneksi APP→backend putus) =
      // UNCERTAIN (request mungkin sudah sampai & booking terbuat) → kunci submit.
      final reconcile =
          error.statusCode == null ||
          error.statusCode == 503 ||
          (payload is Map && payload['reconcile_required'] == true);
      setState(() {
        _isSubmitting = false;
        _submitError = error.message;
        _reconcileRequired = reconcile;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submitError = 'Gagal membuat booking: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // M10/M3(v4.2): cegah keluar saat submit berjalan ATAU setelah uncertain (reconcile) —
    // booking bisa terlanjur dibuat; keluar hanya via tombol/back sadar (konfirmasi).
    return PopScope(
      canPop: !_isSubmitting && !_reconcileRequired,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _isSubmitting
                ? null
                : (_reconcileRequired
                      ? _exitAfterReconcile
                      : () => Navigator.of(context).pop()),
          ),
          title: const Text('Buat Booking Reguler'),
        ),
        body: _buildBodyWidget(),
      ),
    );
  }

  Future<void> _exitAfterReconcile() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Status booking belum pasti'),
        content: const Text(
          'Periksa booking di LKT sebelum membuat booking baru. Tetap keluar?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildBodyWidget() {
    if (_isLoadingRoutes) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_routesError != null) {
      return Center(child: Text(_routesError!));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _buildRouteSection(),
        const SizedBox(height: 16),
        _buildDateTripSection(),
        const SizedBox(height: 16),
        _buildSeatSection(),
        const SizedBox(height: 16),
        _buildPassengerSection(),
        const SizedBox(height: 16),
        _buildFareSection(),
        const SizedBox(height: 16),
        if (_submitError != null)
          Text(_submitError!, style: const TextStyle(color: Color(0xFFDC2626))),
        if (_reconcileRequired) ...<Widget>[
          const SizedBox(height: 8),
          const Text(
            'Status booking belum pasti. Cek dulu di LKT sebelum membuat ulang.',
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _exitAfterReconcile,
            child: const Text('Keluar — sudah cek LKT'),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: (_canSubmit && !_isSubmitting) ? _confirmAndSubmit : null,
          child: Text(_isSubmitting ? 'Memproses...' : 'Buat Booking (Draft)'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSection() {
    return _sectionCard(
      title: '1. Rute',
      children: <Widget>[
        DropdownButtonFormField<String>(
          initialValue: _routeVia,
          decoration: const InputDecoration(labelText: 'Cluster / rute'),
          items: _routes
              .map((route) => route['route_via']?.toString() ?? '')
              .where((value) => value.isNotEmpty)
              .map(
                (value) =>
                    DropdownMenuItem<String>(value: value, child: Text(value)),
              )
              .toList(growable: false),
          onChanged: _onRouteViaChanged,
        ),
        if (_stops.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _fromCity,
            decoration: const InputDecoration(labelText: 'Kota asal'),
            items: _stops
                .map(
                  (stop) =>
                      DropdownMenuItem<String>(value: stop, child: Text(stop)),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() {
              _fromCity = value;
              _resetTripSeatFare();
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _toCity,
            decoration: const InputDecoration(labelText: 'Kota tujuan'),
            items: _stops
                .map(
                  (stop) =>
                      DropdownMenuItem<String>(value: stop, child: Text(stop)),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() {
              _toCity = value;
              _resetTripSeatFare();
            }),
          ),
          if (_bookingDirection != null) ...<Widget>[
            const SizedBox(height: 8),
            Text('Arah booking: ${_bookingDirection!}'),
          ],
        ],
      ],
    );
  }

  Widget _buildDateTripSection() {
    final enabled = _bookingDirection != null;
    return _sectionCard(
      title: '2. Tanggal & trip',
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: enabled ? _pickDate : null,
          icon: const Icon(Icons.calendar_today_rounded),
          label: Text(
            _tripDate == null ? 'Pilih tanggal' : _formatDate(_tripDate!),
          ),
        ),
        if (_tripDate != null) ...<Widget>[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isLoadingTrips ? null : _loadTrips,
            child: Text(_isLoadingTrips ? 'Memuat...' : 'Muat trip & kursi'),
          ),
        ],
        if (_tripsError != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(_tripsError!),
        ],
        ..._trips.map((trip) {
          final selected = identical(_selectedTrip, trip);
          final time = trip['trip_time']?.toString() ?? '-';
          final avail = trip['available_count']?.toString() ?? '';
          final plat = trip['mobil_plat']?.toString() ?? '-';
          return ListTile(
            leading: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
            ),
            title: Text('Jam $time · $plat'),
            subtitle: Text('Sisa $avail kursi'),
            onTap: () => setState(() {
              _selectedTrip = trip;
              _selectedSeats.clear();
            }),
          );
        }),
      ],
    );
  }

  Widget _buildSeatSection() {
    if (_selectedTrip == null) {
      return _sectionCard(
        title: '3. Kursi',
        children: const <Widget>[Text('Pilih trip dulu untuk lihat kursi.')],
      );
    }
    final availableCodes = _availableSeatCodes;
    return _sectionCard(
      title: '3. Kursi',
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _visibleSeats
              .map((seat) {
                final code = seat['code']?.toString() ?? '';
                final isOptional = seat['is_optional'] == true;
                final isSelected = _selectedSeats.contains(code);
                // M6: hanya kursi authoritative (visible − occupied, take available_count) yang selectable.
                final selectable = availableCodes.contains(code);
                final disabled = !isSelected && !selectable;
                return FilterChip(
                  label: Text(isOptional ? '$code (ADMIN)' : code),
                  selected: isSelected,
                  onSelected: disabled
                      ? null
                      : (value) => setState(() {
                          if (value) {
                            _selectedSeats.add(code);
                          } else {
                            _selectedSeats.remove(code);
                          }
                        }),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        Text(
          'Dipilih: ${_selectedSeats.length} / sisa ${availableCodes.length} kursi',
        ),
      ],
    );
  }

  Widget _buildPassengerSection() {
    return _sectionCard(
      title: '4. Penumpang',
      children: <Widget>[
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Nama penumpang'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'No HP customer'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pickupCtrl,
          decoration: const InputDecoration(labelText: 'Titik jemput'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dropoffCtrl,
          decoration: const InputDecoration(labelText: 'Titik turun'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesCtrl,
          decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
        ),
      ],
    );
  }

  Widget _buildFareSection() {
    final canFare = _fromCity != null && _toCity != null;
    return _sectionCard(
      title: '5. Tarif',
      children: <Widget>[
        OutlinedButton(
          onPressed: (!canFare || _isLoadingFare) ? null : _loadFare,
          child: Text(_isLoadingFare ? 'Memuat...' : 'Cek tarif'),
        ),
        if (_fareError != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(_fareError!),
        ],
        if (_autoFareAvailable == true) ...<Widget>[
          const SizedBox(height: 8),
          Text('Tarif otomatis: ${_autoFarePrice ?? '-'} / kursi'),
        ],
        if (_autoFareAvailable == false) ...<Widget>[
          const SizedBox(height: 8),
          const Text('Tarif otomatis tidak tersedia — isi tarif per kursi:'),
          const SizedBox(height: 8),
          TextField(
            controller: _overrideCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Tarif per kursi (wajib)',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _additionalCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Ongkos tambahan per kursi (opsional)',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}

String _generateIdempotencyKey() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'cr-$hex';
}
