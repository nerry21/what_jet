import 'package:flutter/material.dart';

/// Hasil dialog compose (B-APP). `bookingCode` null = "Tanpa kode booking";
/// `loket` non-null hanya untuk QRIS tanpa-kode.
class ManualPaymentComposeResult {
  const ManualPaymentComposeResult({
    required this.bookingCode,
    required this.total,
    required this.loket,
  });

  final String? bookingCode;
  final int total;
  final String? loket;
}

/// BRICK B-APP — dialog compose Manual Payment (picker kode + total + loket).
/// Murni input-collector: fetch bookings via [onFetchBookings], lalu
/// `Navigator.pop(ManualPaymentComposeResult)` saat Konfirmasi / `pop(null)`
/// saat Batal. Pengiriman + error ditangani pemanggil (dashboard).
class ManualPaymentComposeDialog extends StatefulWidget {
  const ManualPaymentComposeDialog({
    super.key,
    required this.paymentType,
    required this.onFetchBookings,
  });

  final String paymentType;
  final Future<List<Map<String, dynamic>>> Function() onFetchBookings;

  @override
  State<ManualPaymentComposeDialog> createState() =>
      _ManualPaymentComposeDialogState();
}

class _ManualPaymentComposeDialogState
    extends State<ManualPaymentComposeDialog> {
  static const String _noCodeValue = '__tanpa_kode__';

  bool _loading = true;
  String? _fetchError;
  List<Map<String, dynamic>> _bookings = const <Map<String, dynamic>>[];
  String? _selection;
  int _total = 0;
  String? _loket;
  bool _submitting = false;

  bool get _isQris => widget.paymentType == 'qris';
  bool get _noCode => _selection == _noCodeValue;
  String? get _selectedBookingCode =>
      (_selection == null || _selection == _noCodeValue) ? null : _selection;

  int get _baseTotal {
    final code = _selectedBookingCode;
    if (code == null) {
      return 0;
    }
    for (final booking in _bookings) {
      if (booking['booking_code'] == code) {
        return _asInt(booking['total_amount']);
      }
    }
    return 0;
  }

  bool get _canSubmit {
    if (_submitting) {
      return false;
    }
    if (_selection == null) {
      return false;
    }
    if (_total <= 0) {
      return false;
    }
    if (_isQris && _noCode && _loket == null) {
      return false;
    }
    return true;
  }

  static int _asInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    return int.tryParse('$raw') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _fetchError = null;
    });
    try {
      final items = await widget.onFetchBookings();
      if (!mounted) {
        return;
      }
      setState(() {
        _bookings = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _fetchError = 'Gagal memuat daftar booking.';
        _loading = false;
      });
    }
  }

  void _selectBooking(String code) {
    setState(() {
      _selection = code;
      _loket = null;
      _total = _baseTotal;
    });
  }

  void _selectNoCode() {
    setState(() {
      _selection = _noCodeValue;
      _loket = null;
      _total = 0;
    });
  }

  Future<void> _promptAmount({required bool add}) async {
    final controller = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (amountContext) {
        return AlertDialog(
          title: Text(add ? 'Tambah ongkos' : 'Edit total'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nominal (angka)'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(amountContext).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                amountContext,
              ).pop(int.tryParse(controller.text.trim())),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    if (value == null || value <= 0) {
      return;
    }
    setState(() {
      _total = add ? _baseTotal + value : value;
    });
  }

  void _submit() {
    if (!_canSubmit) {
      return;
    }
    setState(() => _submitting = true);
    Navigator.of(context).pop(
      ManualPaymentComposeResult(
        bookingCode: _selectedBookingCode,
        total: _total,
        loket: (_isQris && _noCode) ? _loket : null,
      ),
    );
  }

  String _formatRupiah(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return 'Rp $buffer';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isQris ? 'Kirim QRIS' : 'Kirim No-rek'),
      content: SizedBox(width: double.maxFinite, child: _buildContent()),
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text('Konfirmasi'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_fetchError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(_fetchError!),
          const SizedBox(height: 12),
          TextButton(onPressed: _fetch, child: const Text('Coba lagi')),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Pilih kode booking (belum lunas)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final booking in _bookings) _buildBookingTile(booking),
                _buildSelectTile(
                  selected: _noCode,
                  title: 'Tanpa kode booking',
                  subtitle: null,
                  onTap: _selectNoCode,
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        _buildTotalRow(),
        if (_isQris && _noCode) _buildLoketRow(),
      ],
    );
  }

  Widget _buildBookingTile(Map<String, dynamic> booking) {
    final code = booking['booking_code']?.toString() ?? '-';
    final from = booking['from_city']?.toString() ?? '';
    final to = booking['to_city']?.toString() ?? '';
    final date = booking['trip_date']?.toString() ?? '';
    final amount = _asInt(booking['total_amount']);
    return _buildSelectTile(
      selected: _selection == code,
      title: '$code · $from → $to',
      subtitle: '${_formatRupiah(amount)} · $date',
      onTap: () => _selectBooking(code),
    );
  }

  Widget _buildSelectTile({
    required bool selected,
    required String title,
    required String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
    );
  }

  Widget _buildTotalRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Total: ${_formatRupiah(_total)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            TextButton(
              onPressed: (_selection == null || _noCode)
                  ? null
                  : () => _promptAmount(add: true),
              child: const Text('Tambah ongkos'),
            ),
            TextButton(
              onPressed: _selection == null
                  ? null
                  : () => _promptAmount(add: false),
              child: const Text('Edit total'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoketRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(),
        const Text(
          'Loket QRIS (wajib)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        _buildSelectTile(
          selected: _loket == 'pasir',
          title: 'Pasir',
          subtitle: null,
          onTap: () => setState(() => _loket = 'pasir'),
        ),
        _buildSelectTile(
          selected: _loket == 'pku',
          title: 'PKU',
          subtitle: null,
          onTap: () => setState(() => _loket = 'pku'),
        ),
      ],
    );
  }
}
