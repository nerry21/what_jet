class CustomerModel {
  const CustomerModel({
    required this.id,
    this.mobileUserId,
    this.name,
    this.email,
    this.avatarUrl,
    this.preferredChannel,
    this.mobileDeviceId,
    this.displayContact,
    this.status,
    this.lastInteractionAt,
  });

  const CustomerModel.empty() : this(id: 0);

  final int id;
  final String? mobileUserId;
  final String? name;
  final String? email;
  final String? avatarUrl;
  final String? preferredChannel;
  final String? mobileDeviceId;
  final String? displayContact;
  final String? status;
  final DateTime? lastInteractionAt;

  String get displayName =>
      _nullableString(name) ??
      _nullableString(displayContact) ??
      _nullableString(mobileUserId) ??
      'Mobile Visitor';

  bool get exists => id > 0;

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      mobileUserId: _nullableString(json['mobile_user_id']),
      name: _nullableString(json['name']),
      email: _nullableString(json['email']),
      avatarUrl: _nullableString(json['avatar_url']),
      preferredChannel: _nullableString(json['preferred_channel']),
      mobileDeviceId: _nullableString(json['mobile_device_id']),
      displayContact:
          _nullableString(json['display_contact']) ??
          _nullableString(json['display_name']),
      status: _nullableString(json['status']),
      lastInteractionAt: _parseDateTime(json['last_interaction_at']),
    );
  }

  CustomerModel copyWith({
    int? id,
    String? mobileUserId,
    String? name,
    String? email,
    String? avatarUrl,
    String? preferredChannel,
    String? mobileDeviceId,
    String? displayContact,
    String? status,
    DateTime? lastInteractionAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      mobileUserId: mobileUserId ?? this.mobileUserId,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      preferredChannel: preferredChannel ?? this.preferredChannel,
      mobileDeviceId: mobileDeviceId ?? this.mobileDeviceId,
      displayContact: displayContact ?? this.displayContact,
      status: status ?? this.status,
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  final text = _nullableString(value);
  if (text == null) {
    return null;
  }

  return DateTime.tryParse(text)?.toLocal();
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
