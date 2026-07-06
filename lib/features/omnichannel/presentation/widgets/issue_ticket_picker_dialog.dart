import 'package:flutter/material.dart';

/// BRICK 2-APP — picker ringan Terbit Tiket. Fetch bookings SUDAH-lunas via
/// [onFetchBookings], pilih SATU kode, lalu `Navigator.pop<String>(bookingCode)`
/// saat Terbit / `pop(null)` saat Batal. Konfirmasi + error ditangani pemanggil
/// (dashboard). Sengaja TIDAK reuse ConfirmCashPickerDialog — pisah risiko, kontrak
/// picker sama (kirim kode saja) tapi domain berbeda (lunas vs belum-lunas).
class IssueTicketPickerDialog extends StatefulWidget {
  const IssueTicketPickerDialog({super.key, required this.onFetchBookings});

  final Future<List<Map<String, dynamic>>> Function() onFetchBookings;

  @override
  State<IssueTicketPickerDialog> createState() =>
      _IssueTicketPickerDialogState();
}

class _IssueTicketPickerDialogState extends State<IssueTicketPickerDialog> {
  bool _loading = true;
  String? _fetchError;
  List<Map<String, dynamic>> _bookings = const <Map<String, dynamic>>[];
  String? _selection;

  bool get _canSubmit => _selection != null;

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
    setState(() => _selection = code);
  }

  void _submit() {
    if (!_canSubmit) {
      return;
    }
    Navigator.of(context).pop(_selection);
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
      title: const Text('Terbit Tiket'),
      content: SizedBox(width: double.maxFinite, child: _buildContent()),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text('Terbit'),
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
    if (_bookings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Tidak ada booking lunas untuk percakapan ini.'),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Pilih kode booking (sudah lunas)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final booking in _bookings) _buildBookingTile(booking),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingTile(Map<String, dynamic> booking) {
    final code = booking['booking_code']?.toString() ?? '-';
    final from = booking['from_city']?.toString() ?? '';
    final to = booking['to_city']?.toString() ?? '';
    final date = booking['trip_date']?.toString() ?? '';
    final category = booking['category']?.toString() ?? '';
    final amount = _asInt(booking['total_amount']);
    final selected = _selection == code;
    return ListTile(
      dense: true,
      onTap: () => _selectBooking(code),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text('$code · $from → $to'),
      subtitle: Text('${_formatRupiah(amount)} · $date · $category'),
    );
  }
}
