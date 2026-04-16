import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../storage/admin_token_storage.dart';

// ─── Background message handler ──────────────────────────────────────────
// HARUS top-level function (bukan method di dalam class).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM Background] Message: ${message.messageId}');
  await PushNotificationService._showLocalNotification(message);
}

/// Service tunggal untuk mengelola push notification.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Callback saat user tap notifikasi → navigate ke conversation.
  void Function(int conversationId)? onNotificationTapped;

  bool _initialized = false;
  String? _currentFcmToken;

  static const String _channelId = 'whatjet_chat_messages';
  static const String _channelName = 'Pesan Chat';
  static const String _channelDescription =
      'Notifikasi pesan masuk dari WhatsApp';

  // ─── Public API ──────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _initLocalNotifications();
    await _requestPermission();

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Listen foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Listen notification tap (app di-background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check apakah app dibuka dari notification tap (app terminated)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Listen token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _currentFcmToken = newToken;
      _registerTokenToBackend(newToken);
    });
  }

  Future<void> registerAfterLogin() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] Failed to get FCM token');
        return;
      }

      _currentFcmToken = token;
      debugPrint('[FCM] Token obtained: ${token.substring(0, 20)}...');
      await _registerTokenToBackend(token);
    } catch (e) {
      debugPrint('[FCM] Error registering token: $e');
    }
  }

  Future<void> unregisterBeforeLogout() async {
    if (_currentFcmToken == null) return;

    try {
      await _unregisterTokenFromBackend(_currentFcmToken!);
      _currentFcmToken = null;
    } catch (e) {
      debugPrint('[FCM] Error unregistering token: $e');
    }
  }

  String? get currentToken => _currentFcmToken;

  // ─── Local Notifications Setup ───────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );
  }

  // ─── Permission ──────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
  }

  // ─── Message Handlers ────────────────────────────────────────────────

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM Foreground] Title: ${message.notification?.title}');
    debugPrint('[FCM Foreground] Body: ${message.notification?.body}');
    _showLocalNotification(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM Tap] Data: ${message.data}');
    final conversationIdStr = message.data['conversation_id'];
    if (conversationIdStr == null) return;
    final conversationId = int.tryParse(conversationIdStr.toString());
    if (conversationId == null || conversationId <= 0) return;
    onNotificationTapped?.call(conversationId);
  }

  // ─── Show Local Notification ─────────────────────────────────────────

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['sender_name'] ?? 'Pesan Baru';
    final body = notification?.body ?? data['body'] ?? 'Pesan baru masuk';
    final unreadCount =
        int.tryParse(data['unread_count']?.toString() ?? '') ?? 1;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      number: unreadCount,
      category: AndroidNotificationCategory.message,
      groupKey: 'whatjet_messages',
    );

    final details = NotificationDetails(android: androidDetails);
    final notificationId =
        int.tryParse(data['conversation_id']?.toString() ?? '') ??
            message.hashCode;
    final payload = jsonEncode(data);

    await _localNotifications.show(notificationId, title, body, details,
        payload: payload);
  }

  // ─── Local Notification Tap Handler ──────────────────────────────────

  void _onLocalNotificationTapped(NotificationResponse response) {
    if (response.payload == null || response.payload!.isEmpty) return;

    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final conversationIdStr = data['conversation_id'];
      if (conversationIdStr == null) return;
      final conversationId = int.tryParse(conversationIdStr.toString());
      if (conversationId == null || conversationId <= 0) return;
      onNotificationTapped?.call(conversationId);
    } catch (e) {
      debugPrint('[LocalNotif Tap] Error parsing payload: $e');
    }
  }

  // ─── Backend Token Registration ──────────────────────────────────────

  Future<void> _registerTokenToBackend(String fcmToken) async {
    try {
      final storage = AdminTokenStorage();
      final accessToken = await storage.readAccessToken();

      if (accessToken == null || accessToken.trim().isEmpty) {
        debugPrint('[FCM] No access token — skip backend registration');
        return;
      }

      final apiClient = ApiClient();
      try {
        await apiClient.post(
          ApiEndpoints.adminDeviceTokenRegister(),
          headers: {'Authorization': 'Bearer ${accessToken.trim()}'},
          body: {
            'fcm_token': fcmToken,
            'device_name': _getDeviceName(),
            'platform': Platform.isIOS ? 'ios' : 'android',
          },
        );
        debugPrint('[FCM] Token registered to backend successfully');
      } finally {
        apiClient.dispose();
      }
    } catch (e) {
      debugPrint('[FCM] Failed to register token to backend: $e');
    }
  }

  Future<void> _unregisterTokenFromBackend(String fcmToken) async {
    try {
      final storage = AdminTokenStorage();
      final accessToken = await storage.readAccessToken();
      if (accessToken == null || accessToken.trim().isEmpty) return;

      final apiClient = ApiClient();
      try {
        await apiClient.post(
          ApiEndpoints.adminDeviceTokenUnregister(),
          headers: {'Authorization': 'Bearer ${accessToken.trim()}'},
          body: {'fcm_token': fcmToken},
        );
        debugPrint('[FCM] Token unregistered from backend');
      } finally {
        apiClient.dispose();
      }
    } catch (e) {
      debugPrint('[FCM] Failed to unregister token: $e');
    }
  }

  String _getDeviceName() {
    try {
      if (Platform.isAndroid) return 'Android Device';
      if (Platform.isIOS) return 'iOS Device';
      return 'Unknown Device';
    } catch (_) {
      return 'Flutter Device';
    }
  }
}