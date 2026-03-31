import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage();

  static const String _accessTokenKey = 'mobile_access_token';
  static const String _tokenTypeKey = 'mobile_token_type';
  static const String _mobileUserIdKey = 'mobile_user_id';
  static const String _deviceIdKey = 'mobile_device_id';
  static const String _legacyDeviceIdKey = 'mobile_client_key';
  static const String _displayNameKey = 'mobile_display_name';
  static const String _emailKey = 'mobile_email';
  static const String _activeConversationIdKey = 'active_conversation_id';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<String> ensureDeviceId() async {
    final prefs = await _prefs;
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }

    final legacy = prefs.getString(_legacyDeviceIdKey);
    if (legacy != null && legacy.trim().isNotEmpty) {
      await prefs.setString(_deviceIdKey, legacy.trim());
      return legacy.trim();
    }

    final generated = _generateStableId(prefix: 'mlc-device');
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }

  Future<String> ensureMobileUserId() async {
    final prefs = await _prefs;
    final existing = prefs.getString(_mobileUserIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }

    final generated = _generateStableId(prefix: 'mlc-user');
    await prefs.setString(_mobileUserIdKey, generated);
    return generated;
  }

  Future<String?> readAccessToken() async {
    final prefs = await _prefs;
    return prefs.getString(_accessTokenKey);
  }

  Future<void> writeAccessToken(String? value) async {
    final prefs = await _prefs;
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_accessTokenKey);
      return;
    }

    await prefs.setString(_accessTokenKey, value.trim());
  }

  Future<String?> readTokenType() async {
    final prefs = await _prefs;
    return prefs.getString(_tokenTypeKey);
  }

  Future<void> writeTokenType(String? value) async {
    final prefs = await _prefs;
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_tokenTypeKey);
      return;
    }

    await prefs.setString(_tokenTypeKey, value.trim());
  }

  Future<String?> readMobileUserId() async {
    final prefs = await _prefs;
    return prefs.getString(_mobileUserIdKey);
  }

  Future<void> writeMobileUserId(String? value) async {
    final prefs = await _prefs;
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_mobileUserIdKey);
      return;
    }

    await prefs.setString(_mobileUserIdKey, value.trim());
  }

  Future<String?> readDisplayName() async {
    final prefs = await _prefs;
    return prefs.getString(_displayNameKey);
  }

  Future<void> writeDisplayName(String? value) async {
    final prefs = await _prefs;
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_displayNameKey);
      return;
    }

    await prefs.setString(_displayNameKey, value.trim());
  }

  Future<String?> readEmail() async {
    final prefs = await _prefs;
    return prefs.getString(_emailKey);
  }

  Future<void> writeEmail(String? value) async {
    final prefs = await _prefs;
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_emailKey);
      return;
    }

    await prefs.setString(_emailKey, value.trim());
  }

  Future<int?> readActiveConversationId() async {
    final prefs = await _prefs;
    return prefs.getInt(_activeConversationIdKey);
  }

  Future<void> writeActiveConversationId(int? value) async {
    final prefs = await _prefs;
    if (value == null) {
      await prefs.remove(_activeConversationIdKey);
      return;
    }

    await prefs.setInt(_activeConversationIdKey, value);
  }

  Future<void> clearAuth() async {
    final prefs = await _prefs;
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_tokenTypeKey);
  }

  Future<void> clearProfile() async {
    final prefs = await _prefs;
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_tokenTypeKey);
    await prefs.remove(_mobileUserIdKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_activeConversationIdKey);
  }

  String _generateStableId({required String prefix}) {
    final random = Random.secure();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final nonce = List<int>.generate(
      10,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

    return '$prefix-$timestamp-$nonce';
  }
}
