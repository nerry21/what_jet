import 'package:flutter/material.dart';

/// Model untuk kontak WhatsApp tersimpan di backend.
class WhatsAppContactModel {
  const WhatsAppContactModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.phoneE164,
    this.email,
    this.avatarUrl,
    this.isWhatsappVerified = false,
    this.syncToDevice = true,
    this.customerId,
    this.conversationId,
    this.lastSyncedAt,
    this.createdAt,
  });

  factory WhatsAppContactModel.fromJson(Map<String, dynamic> json) {
    return WhatsAppContactModel(
      id: _toInt(json['id']) ?? 0,
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      phoneE164: (json['phone_e164'] ?? '').toString(),
      email: json['email']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      isWhatsappVerified: json['is_whatsapp_verified'] == true,
      syncToDevice: json['sync_to_device'] == true,
      customerId: _toInt(json['customer_id']),
      conversationId: _toInt(json['conversation_id']),
      lastSyncedAt: _parseDate(json['last_synced_at']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  final int id;
  final String firstName;
  final String lastName;
  final String displayName;
  final String phoneE164;
  final String? email;
  final String? avatarUrl;
  final bool isWhatsappVerified;
  final bool syncToDevice;
  final int? customerId;
  final int? conversationId;
  final DateTime? lastSyncedAt;
  final DateTime? createdAt;

  String get initial {
    final name = displayName.trim();
    if (name.isEmpty) return 'C';
    final words = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  List<Color> get avatarColors {
    final seed = displayName.isEmpty ? 0 : displayName.codeUnitAt(0);
    switch (seed % 5) {
      case 0:
        return const <Color>[Color(0xFF02A78F), Color(0xFF18C4A7)];
      case 1:
        return const <Color>[Color(0xFF7E57C2), Color(0xFFB06BFF)];
      case 2:
        return const <Color>[Color(0xFF5C6BC0), Color(0xFF7986CB)];
      case 3:
        return const <Color>[Color(0xFF8D6E63), Color(0xFFB1897E)];
      default:
        return const <Color>[Color(0xFF607D8B), Color(0xFF78909C)];
    }
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

/// Hasil pembuatan kontak baru dari backend.
class WhatsAppContactCreateResult {
  const WhatsAppContactCreateResult({
    required this.notice,
    required this.customerId,
    required this.conversationId,
    required this.whatsappContactId,
    required this.displayName,
    required this.phoneE164,
    required this.customerCreated,
    required this.conversationCreated,
    required this.whatsappContactCreated,
  });

  factory WhatsAppContactCreateResult.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;
    final contact = (data['whatsapp_contact'] is Map<String, dynamic>)
        ? data['whatsapp_contact'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return WhatsAppContactCreateResult(
      notice: (data['notice'] ?? json['message'] ?? '').toString(),
      customerId: WhatsAppContactModel._toInt(data['customer_id']) ?? 0,
      conversationId: WhatsAppContactModel._toInt(data['conversation_id']) ?? 0,
      whatsappContactId:
          WhatsAppContactModel._toInt(data['whatsapp_contact_id']) ?? 0,
      displayName: (contact['display_name'] ?? '').toString(),
      phoneE164: (contact['phone_e164'] ?? '').toString(),
      customerCreated: data['customer_created'] == true,
      conversationCreated: data['conversation_created'] == true,
      whatsappContactCreated: data['whatsapp_contact_created'] == true,
    );
  }

  final String notice;
  final int customerId;
  final int conversationId;
  final int whatsappContactId;
  final String displayName;
  final String phoneE164;
  final bool customerCreated;
  final bool conversationCreated;
  final bool whatsappContactCreated;
}
