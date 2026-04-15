class AdminUserModel {
  const AdminUserModel({
    required this.id,
    required this.name,
    required this.email,
    this.isChatbotAdmin = false,
    this.isChatbotOperator = false,
  });

  const AdminUserModel.empty() : this(id: 0, name: 'Admin', email: '');

  final int id;
  final String name;
  final String email;
  final bool isChatbotAdmin;
  final bool isChatbotOperator;

  bool get exists => id > 0;

  String get displayName => name.trim().isEmpty ? 'Admin' : name.trim();

  String get roleLabel {
    if (isChatbotAdmin) {
      return 'Chatbot Admin';
    }

    if (isChatbotOperator) {
      return 'Chatbot Operator';
    }

    return 'Admin Workspace';
  }

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    return AdminUserModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: _nullableString(json['name']) ?? 'Admin',
      email: _nullableString(json['email']) ?? '',
      isChatbotAdmin: json['is_chatbot_admin'] == true,
      isChatbotOperator: json['is_chatbot_operator'] == true,
    );
  }

  AdminUserModel copyWith({
    int? id,
    String? name,
    String? email,
    bool? isChatbotAdmin,
    bool? isChatbotOperator,
  }) {
    return AdminUserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      isChatbotAdmin: isChatbotAdmin ?? this.isChatbotAdmin,
      isChatbotOperator: isChatbotOperator ?? this.isChatbotOperator,
    );
  }
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
