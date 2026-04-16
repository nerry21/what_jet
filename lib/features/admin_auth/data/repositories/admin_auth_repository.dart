import 'dart:async';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/admin_token_storage.dart';
import '../../../../core/services/push_notification_service.dart';
import '../models/admin_auth_session_model.dart';
import '../models/admin_user_model.dart';
import '../services/admin_auth_api_service.dart';

class StoredAdminSession {
  const StoredAdminSession({
    this.accessToken,
    this.tokenType,
    this.userId,
    this.displayName,
    this.email,
  });

  final String? accessToken;
  final String? tokenType;
  final int? userId;
  final String? displayName;
  final String? email;

  bool get hasAccessToken =>
      accessToken != null && accessToken!.trim().isNotEmpty;
}

class AdminAuthRepository {
  AdminAuthRepository({
    required AdminAuthApiService authApiService,
    required AdminTokenStorage tokenStorage,
  }) : _authApiService = authApiService,
       _tokenStorage = tokenStorage;

  final AdminAuthApiService _authApiService;
  final AdminTokenStorage _tokenStorage;

  Future<StoredAdminSession> readStoredSession() async {
    return StoredAdminSession(
      accessToken: await _tokenStorage.readAccessToken(),
      tokenType: await _tokenStorage.readTokenType(),
      userId: await _tokenStorage.readUserId(),
      displayName: await _tokenStorage.readDisplayName(),
      email: await _tokenStorage.readEmail(),
    );
  }

  Future<AdminUserModel?> restoreSession() async {
    final session = await readStoredSession();
    final accessToken = session.accessToken?.trim();

    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    try {
      final user = await _authApiService.me(accessToken: accessToken);
      await _persistSession(
        accessToken: accessToken,
        tokenType: session.tokenType ?? 'Bearer',
        user: user,
      );

      // Re-register FCM token saat session restored (app restart)
      unawaited(PushNotificationService.instance.registerAfterLogin());

      return user;
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _tokenStorage.clearProfile();
        return null;
      }

      rethrow;
    }
  }

  Future<AdminAuthSessionModel> login({
    required String email,
    required String password,
  }) async {
    final session = await _authApiService.login(
      email: email,
      password: password,
    );
    await _persistSession(
      accessToken: session.accessToken,
      tokenType: session.tokenType,
      user: session.user,
    );

    // Register FCM token ke backend setelah login berhasil
    unawaited(PushNotificationService.instance.registerAfterLogin());

    return session;
  }

  Future<void> logout() async {
    // Unregister FCM token sebelum logout
    await PushNotificationService.instance.unregisterBeforeLogout();

    final accessToken = await _tokenStorage.readAccessToken();

    try {
      if (accessToken != null && accessToken.trim().isNotEmpty) {
        await _authApiService.logout(accessToken: accessToken.trim());
      }
    } on ApiException catch (error) {
      if (!error.isUnauthorized && !error.isOffline) {
        rethrow;
      }
    } finally {
      await _tokenStorage.clearProfile();
    }
  }

  Future<String> requireAccessToken() async {
    final accessToken = await _tokenStorage.readAccessToken();
    final normalized = accessToken?.trim();

    if (normalized == null || normalized.isEmpty) {
      throw StateError('Sesi admin belum tersedia. Silakan login ulang.');
    }

    return normalized;
  }

  Future<void> clearSession() {
    return _tokenStorage.clearProfile();
  }

  Future<void> _persistSession({
    required String accessToken,
    required String tokenType,
    required AdminUserModel user,
  }) async {
    await _tokenStorage.writeAccessToken(accessToken);
    await _tokenStorage.writeTokenType(tokenType);
    await _tokenStorage.writeUserId(user.id);
    await _tokenStorage.writeDisplayName(user.displayName);
    await _tokenStorage.writeEmail(user.email);
  }
}
