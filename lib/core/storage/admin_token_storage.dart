import 'package:shared_preferences/shared_preferences.dart';

class AdminTokenStorage {
  AdminTokenStorage();

  static const String _accessTokenKey = 'admin_mobile_access_token';
  static const String _tokenTypeKey = 'admin_mobile_token_type';
  static const String _userIdKey = 'admin_mobile_user_id';
  static const String _displayNameKey = 'admin_mobile_display_name';
  static const String _emailKey = 'admin_mobile_email';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

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

  Future<int?> readUserId() async {
    final prefs = await _prefs;
    return prefs.getInt(_userIdKey);
  }

  Future<void> writeUserId(int? value) async {
    final prefs = await _prefs;
    if (value == null) {
      await prefs.remove(_userIdKey);
      return;
    }

    await prefs.setInt(_userIdKey, value);
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

  Future<void> clearAuth() async {
    final prefs = await _prefs;
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_tokenTypeKey);
  }

  Future<void> clearProfile() async {
    final prefs = await _prefs;
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_tokenTypeKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_emailKey);
  }
}
