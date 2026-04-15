// ============================================================================
// WhatsJet Premium Design System — Colors (Dark Emerald Executive)
// ============================================================================
// Dark luxury theme with deep emerald accents for executive/manager use.
// All presentation files already reference these tokens — changing values
// here instantly transforms the entire app appearance.
// ============================================================================

import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // ─── Primary (Deep Emerald — darker & more luxurious) ────────────────────
  static const Color primary = Color(0xFF00A86B);
  static const Color primary50 = Color(0xFFE6FFF4);
  static const Color primary100 = Color(0xFFB3FFE0);
  static const Color primary200 = Color(0xFF66EDBA);
  static const Color primary300 = Color(0xFF2DD89A);
  static const Color primary400 = Color(0xFF00C07A);
  static const Color primary600 = Color(0xFF008C59);
  static const Color primary700 = Color(0xFF006B44);
  static const Color primary800 = Color(0xFF004D31);
  static const Color primary900 = Color(0xFF00331F);

  static const MaterialColor primarySwatch = MaterialColor(0xFF00A86B, {
    50: primary50,
    100: primary100,
    200: primary200,
    300: primary300,
    400: primary400,
    500: primary,
    600: primary600,
    700: primary700,
    800: primary800,
    900: primary900,
  });

  // ─── Accent (Royal Purple) ───────────────────────────────────────────────
  static const Color accent = Color(0xFF9B7FDB);
  static const Color accent50 = Color(0xFFF3EEFF);
  static const Color accent100 = Color(0xFFD9CDF6);
  static const Color accent200 = Color(0xFFBEAAED);
  static const Color accent400 = Color(0xFF9B7FDB);
  static const Color accent600 = Color(0xFF7A5DC4);
  static const Color accent800 = Color(0xFF53399E);
  static const Color accent900 = Color(0xFF33216B);

  // ─── Neutral (Forest-tinted dark grays) ──────────────────────────────────
  static const Color white = Color(0xFFF0F5F2);
  static const Color neutral25 = Color(0xFF1A2920);
  static const Color neutral50 = Color(0xFF131D17);
  static const Color neutral100 = Color(0xFF1A2920);
  static const Color neutral200 = Color(0xFF213529);
  static const Color neutral300 = Color(0xFF3D4F44);
  static const Color neutral400 = Color(0xFF6B7D72);
  static const Color neutral500 = Color(0xFFA3B5AA);
  static const Color neutral600 = Color(0xFFC5D3CA);
  static const Color neutral700 = Color(0xFFD8E3DC);
  static const Color neutral800 = Color(0xFFF0F5F2);
  static const Color neutral900 = Color(0xFFFAFCFB);

  // ─── Semantic ────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF2DD89A);
  static const Color success50 = Color(0xFF0D2E1F);
  static const Color success800 = Color(0xFF7AEDC4);

  static const Color warning = Color(0xFFF5A623);
  static const Color warning50 = Color(0xFF2E1F0A);
  static const Color warning800 = Color(0xFFFFCF73);

  static const Color error = Color(0xFFE85454);
  static const Color error50 = Color(0xFF2E0D0D);
  static const Color error800 = Color(0xFFFF9B9B);

  static const Color info = Color(0xFF4A9EF5);
  static const Color info50 = Color(0xFF0D1F2E);
  static const Color info800 = Color(0xFF9BCAFF);

  // ─── Surface & Background (Deep dark forest) ────────────────────────────
  static const Color scaffoldBackground = Color(0xFF080C0A);
  static const Color surfacePrimary = Color(0xFF0D1410);
  static const Color surfaceSecondary = Color(0xFF131D17);
  static const Color surfaceTertiary = Color(0xFF1A2920);
  static const Color surfaceDark = Color(0xFF080C0A);
  static const Color surfaceDarkAlt = Color(0xFF060A08);
  static const Color surfaceOverlay = Color(0x40000000);

  // ─── Border (Subtle emerald-tinted) ──────────────────────────────────────
  static const Color borderLight = Color(0xFF1A2920);
  static const Color borderDefault = Color(0xFF213529);
  static const Color borderDark = Color(0xFF3D4F44);
  static const Color borderFocus = primary400;

  // ─── Chat-specific ───────────────────────────────────────────────────────
  static const Color bubbleOutgoing = Color(0xFF008C59);
  static const Color bubbleOutgoingGradientEnd = Color(0xFF006B44);
  static const Color bubbleIncoming = Color(0xFF1A2920);
  static const Color readReceipt = Color(0xFF66EDBA);
  static const Color onlineIndicator = success;

  // ─── Gradient Presets ────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary400, primary700],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent400, accent600],
  );

  static const LinearGradient darkSurfaceGradient = LinearGradient(
    begin: Alignment(-.3, -1),
    end: Alignment(.3, 1),
    colors: [surfacePrimary, scaffoldBackground],
  );

  static const LinearGradient subtleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceSecondary, surfaceTertiary],
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    begin: Alignment(-1.5, -0.3),
    end: Alignment(1.5, 0.3),
    colors: [borderLight, surfaceSecondary, borderLight],
    stops: [0.0, 0.5, 1.0],
  );

  // ─── Glow / Shadow Colors ───────────────────────────────────────────────
  static const Color primaryGlow = Color(0x4000A86B);
  static const Color accentGlow = Color(0x339B7FDB);
  static const Color successGlow = Color(0x402DD89A);
  static const Color errorGlow = Color(0x33E85454);

  // ─── Channel Colors ──────────────────────────────────────────────────────
  static Color channelColor(String channel) {
    return switch (channel) {
      'whatsapp' || 'wa' => primary,
      'mobile_live_chat' || 'chat' => accent,
      'telegram' => const Color(0xFF2AABEE),
      'instagram' => const Color(0xFFE4405F),
      'facebook' => const Color(0xFF1877F2),
      'email' => const Color(0xFF6B7280),
      _ => neutral400,
    };
  }

  /// Returns an avatar gradient for a given channel.
  static LinearGradient channelAvatarGradient(String channel) {
    final base = channelColor(channel);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [base.withValues(alpha: 0.7), base],
    );
  }

  /// Conversation status dot color.
  static Color statusColor(String status) {
    return switch (status) {
      'active' || 'open' => success,
      'waiting' || 'pending' => warning,
      'resolved' || 'closed' => neutral300,
      'bot' => accent,
      _ => neutral400,
    };
  }
}
