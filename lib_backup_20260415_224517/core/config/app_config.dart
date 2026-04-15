import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppConfig {
  const AppConfig._();

  static const String chatbotAiLocalBaseUrl = 'http://127.0.0.1:8000';
  static const String chatbotAiAndroidBaseUrl = 'http://10.0.2.2:8000';
  static const String chatbotAiProductionBaseUrl = 'https://spesial.online';

  static const String appTitle = 'WhatsApp';
  static const String businessDisplayName = 'JET Support';
  static const String businessSubtitle = 'Live Chat Customer Service';
  static const String currentUserLabel = 'Anda';
  static const String guestDisplayName = 'Pengguna Aplikasi';
  static const String sourceApp = 'what_jet_flutter';
  static const String preferredChannel = 'mobile_live_chat';

  static const Color green = Color(0xFF00A884);
  static const Color greenLight = Color(0xFF00D084);
  static const Color purple = Color(0xFF8764D5);
  static const Color purpleLight = Color(0xFFB784D5);
  static const Color softBackground = Color(0xFFF5F5F5);
  static const Color softBackgroundAlt = Color(0xFFE8E8E8);
  static const Color bubbleIncoming = Color(0xFFE5E5EA);
  static const Color bubbleOutgoing = Color(0xFFDCF8C6);
  static const Color bubbleOutgoingAlt = Color(0xFFB3E5FC);
  static const Color danger = Color(0xFFFF4757);
  static const Color success = Color(0xFF31A24C);
  static const Color mutedText = Color(0xFF65676B);
  static const Color subtleText = Color(0xFF999999);
  static const Color readReceipt = Color(0xFF53BDEB);

  static const Duration defaultPollingInterval = Duration(seconds: 3);
  static const Duration reconnectPollingInterval = Duration(seconds: 5);

  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured;
    }

    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();

      if (host == 'localhost' || host == '127.0.0.1') {
        return chatbotAiLocalBaseUrl;
      }

      if (host.isNotEmpty) {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty) {
          return origin;
        }
      }

      return chatbotAiProductionBaseUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // In release/profile mode, always use production URL.
      // The emulator-only 10.0.2.2 address is only useful during debug.
      if (kReleaseMode) {
        return chatbotAiProductionBaseUrl;
      }
      return chatbotAiAndroidBaseUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (kReleaseMode) {
        return chatbotAiProductionBaseUrl;
      }
      return chatbotAiLocalBaseUrl;
    }

    return chatbotAiLocalBaseUrl;
  }

  static ThemeData theme() {
    return ThemeData(
      useMaterial3: false,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      scaffoldBackgroundColor: softBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: green,
        secondary: greenLight,
        surface: Colors.white,
      ),
    );
  }
}
