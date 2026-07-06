import 'package:flutter/material.dart';

/// BRICK 3B-APP — picker Verify Transfer. Fetch booking belum-lunas via
/// [onFetchBookings], pilih SATU, isi/konfirmasi NOMINAL (prefill total_amount,
/// editable) + reference opsional, lalu pop {booking_code, amount, reference}.
/// Beda dari ConfirmCashPickerDialog: verify-transfer WAJIB nominal (Opsi B).
class VerifyTransferPickerDialog extends StatefulWidget {
  const VerifyTransferPickerDialog({super.key, required this.onFetchBookings});

  final Future<List<Map<String, dynamic>>> Function() onFetchBookings;

  @override
  State<VerifyTransferPickerDialog> createState() =>
      _VerifyTransferPickerDialogState();
}

class _VerifyTransferPickerDialogState
    extends State<VerifyTransferPickerDialog> {
  bool _loading = true;
  String? _fetchError;
  List<Map<String, dynamic>> _bookings = const <Map<String, dynamic>>[];
  String? _selection;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();

  static int _asInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    return int.tryParse('$raw') ?? 0;
  }

  int get _parsedAmount =>
      int.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
      0;

  bool get _canSubmit => _selection != null && _parsedAmount > 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
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

  void _selectBooking(Map<String, dynamic> booking) {
    setState(() {
      _selection = booking['booking_code']?.toString();
      _amountController.text = _asInt(booking['total_amount']).toString();
    });
  }

  void _submit() {
    if (!_canSubmit) {
      return;
    }
    final reference = _referenceController.text.trim();
    Navigator.of(context).pop(<String, dynamic>{
      'booking_code': _selection,
      'amount': _parsedAmount,
      'reference': reference.isEmpty ? null : reference,
    });
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
      title: const Text('Verify Transfer'),
      content: SizedBox(width: double.maxFinite, child: _buildContent()),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text('Verify'),
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
        child: Text('Tidak ada booking belum lunas untuk percakapan ini.'),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Pilih booking transfer',
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
        if (_selection != null) ...<Widget>[
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}), // DEVIASI-1 (reaktif Opsi B)
            decoration: const InputDecoration(
              labelText: 'Nominal transfer (Rp)',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _referenceController,
            decoration: const InputDecoration(
              labelText: 'Referensi (opsional)',
              isDense: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBookingTile(Map<String, dynamic> booking) {
    final code = booking['booking_code']?.toString() ?? '-';
    final from = booking['from_city']?.toString() ?? '';
    final to = booking['to_city']?.toString() ?? '';
    final date = booking['trip_date']?.toString() ?? '';
    final amount = _asInt(booking['total_amount']);
    final selected = _selection == code;
    return ListTile(
      dense: true,
      onTap: () => _selectBooking(booking),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text('$code · $from → $to'),
      subtitle: Text('${_formatRupiah(amount)} · $date'),
    );
  }
}
