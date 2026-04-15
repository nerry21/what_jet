import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class DeviceContactAccountOption {
  const DeviceContactAccountOption({
    required this.account,
    required this.displayLabel,
  });

  final Account account;
  final String displayLabel;
}

class DeviceContactSaveResult {
  const DeviceContactSaveResult({
    required this.success,
    required this.message,
    this.contactId,
  });

  final bool success;
  final String message;
  final String? contactId;
}

class DeviceContactsService {
  const DeviceContactsService._();

  static bool get isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  static String normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) {
      return '';
    }

    if (digits.startsWith('+')) {
      return digits;
    }

    if (digits.startsWith('62')) {
      return '+$digits';
    }

    if (digits.startsWith('0')) {
      return '+62${digits.substring(1)}';
    }

    return '+62$digits';
  }

  static Future<List<DeviceContactAccountOption>> loadAccounts() async {
    if (!isSupportedPlatform) {
      return const <DeviceContactAccountOption>[];
    }

    try {
      final status = await FlutterContacts.permissions.request(
        PermissionType.readWrite,
      );
      if (status != PermissionStatus.granted) {
        return const <DeviceContactAccountOption>[];
      }

      final accounts = await FlutterContacts.accounts.getAll();
      if (accounts.isEmpty) {
        final defaultAccount = await FlutterContacts.accounts.getDefault();
        if (defaultAccount == null) {
          return const <DeviceContactAccountOption>[];
        }
        return <DeviceContactAccountOption>[
          DeviceContactAccountOption(
            account: defaultAccount,
            displayLabel: _formatAccountLabel(defaultAccount),
          ),
        ];
      }

      return accounts
          .map(
            (account) => DeviceContactAccountOption(
              account: account,
              displayLabel: _formatAccountLabel(account),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <DeviceContactAccountOption>[];
    }
  }

  static Future<DeviceContactSaveResult> saveContact({
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    Account? account,
  }) async {
    if (!isSupportedPlatform) {
      return const DeviceContactSaveResult(
        success: false,
        message: 'Sinkron phonebook hanya didukung di Android/iPhone.',
      );
    }

    final normalizedPhone = normalizePhone(phone);
    if (firstName.trim().isEmpty || normalizedPhone.isEmpty) {
      return const DeviceContactSaveResult(
        success: false,
        message: 'Nama depan dan nomor telepon wajib diisi.',
      );
    }

    try {
      final status = await FlutterContacts.permissions.request(
        PermissionType.readWrite,
      );

      if (status != PermissionStatus.granted) {
        return const DeviceContactSaveResult(
          success: false,
          message: 'Izin kontak belum diberikan. Aktifkan izin kontak agar sinkron ke phonebook berjalan.',
        );
      }

      final existing = await FlutterContacts.getAll(
        properties: <ContactProperty>{
          ContactProperty.name,
          ContactProperty.phone,
          ContactProperty.email,
        },
        filter: ContactFilter.phone(
          normalizedPhone.replaceAll('+', ''),
        ),
        limit: 20,
      );

      for (final contact in existing) {
        final match = contact.phones.any(
          (item) => normalizePhone(item.number) == normalizedPhone,
        );
        if (match) {
          return DeviceContactSaveResult(
            success: true,
            message: 'Kontak sudah ada di phonebook Android.',
            contactId: contact.id,
          );
        }
      }

      final newContact = Contact(
        name: Name(
          first: firstName.trim(),
          last: lastName.trim(),
        ),
        phones: <Phone>[
          Phone(
            number: normalizedPhone,
            label: const Label(PhoneLabel.mobile),
          ),
        ],
        emails: email?.trim().isNotEmpty == true
            ? <Email>[
                Email(
                  address: email!.trim(),
                  label: const Label(EmailLabel.work),
                ),
              ]
            : <Email>[],
      );

      final contactId = await FlutterContacts.create(
        newContact,
        account: account,
      );

      return DeviceContactSaveResult(
        success: true,
        message: 'Kontak berhasil disimpan ke phonebook Android.',
        contactId: contactId,
      );
    } catch (error) {
      return DeviceContactSaveResult(
        success: false,
        message: 'Gagal menyimpan kontak ke phonebook Android: $error',
      );
    }
  }

  static String _formatAccountLabel(Account account) {
    final name = account.name.trim();
    final type = account.type.trim();
    if (name.isNotEmpty && type.isNotEmpty) {
      return '$name • $type';
    }
    if (name.isNotEmpty) {
      return name;
    }
    if (type.isNotEmpty) {
      return type;
    }
    return 'Default perangkat';
  }
}
