// ============================================================================
// WhatsJet Premium Design System — Colors
// ============================================================================
// Replaces all 246 hardcoded Color(0x...) across the codebase.
// Usage: AppColors.primary, AppColors.primary50, AppColors.neutral700, etc.
// ============================================================================

import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // ─── Primary (Emerald Green) ─────────────────────────────────────────────
  static const Color primary = Color(0xFF00C896);
  static const Color primary50 = Color(0xFFE8FAF4);
  static const Color primary100 = Color(0xFFB8F0DC);
  static const Color primary200 = Color(0xFF7AE4BF);
  static const Color primary400 = Color(0xFF00C896);
  static const Color primary600 = Color(0xFF00A878);
  static const Color primary800 = Color(0xFF007A57);
  static const Color primary900 = Color(0xFF004D36);

  static const MaterialColor primarySwatch = MaterialColor(0xFF00C896, {
    50: primary50,
    100: primary100,
    200: primary200,
    300: Color(0xFF3CD6A8),
    400: primary400,
    500: Color(0xFF00B888),
    600: primary600,
    700: Color(0xFF008C68),
    800: primary800,
    900: primary900,
  });

  // ─── Accent (Royal Purple) ───────────────────────────────────────────────
  static const Color accent = Color(0xFF8B6FD4);
  static const Color accent50 = Color(0xFFF0EAFF);
  static const Color accent100 = Color(0xFFD1C4F6);
  static const Color accent200 = Color(0xFFB39DEB);
  static const Color accent400 = Color(0xFF8B6FD4);
  static const Color accent600 = Color(0xFF6B4FB8);
  static const Color accent800 = Color(0xFF4A3390);
  static const Color accent900 = Color(0xFF2E1F5E);

  // ─── Neutral (Warm Gray) ─────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color neutral25 = Color(0xFFFAFAF9);
  static const Color neutral50 = Color(0xFFF5F4F2);
  static const Color neutral100 = Color(0xFFECEAE6);
  static const Color neutral200 = Color(0xFFD8D6D0);
  static const Color neutral300 = Color(0xFFB5B3AD);
  static const Color neutral400 = Color(0xFF8A8884);
  static const Color neutral500 = Color(0xFF6B6966);
  static const Color neutral600 = Color(0xFF4A4845);
  static const Color neutral700 = Color(0xFF33312F);
  static const Color neutral800 = Color(0xFF1E1D1B);
  static const Color neutral900 = Color(0xFF0D0D0C);

  // ─── Semantic ────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color success50 = Color(0xFFECFDF5);
  static const Color success800 = Color(0xFF166534);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warning50 = Color(0xFFFEF3C7);
  static const Color warning800 = Color(0xFF92400E);

  static const Color error = Color(0xFFEF4444);
  static const Color error50 = Color(0xFFFEF2F2);
  static const Color error800 = Color(0xFF991B1B);

  static const Color info = Color(0xFF3B82F6);
  static const Color info50 = Color(0xFFEFF6FF);
  static const Color info800 = Color(0xFF1E40AF);

  // ─── Surface & Background ────────────────────────────────────────────────
  static const Color scaffoldBackground = neutral50;
  static const Color surfacePrimary = white;
  static const Color surfaceSecondary = neutral25;
  static const Color surfaceTertiary = neutral50;
  static const Color surfaceDark = Color(0xFF0F1512);
  static const Color surfaceDarkAlt = Color(0xFF0B0F0D);
  static const Color surfaceOverlay = Color(0x29000000); // 16% black

  // ─── Border ──────────────────────────────────────────────────────────────
  static const Color borderLight = neutral100;
  static const Color borderDefault = neutral200;
  static const Color borderDark = neutral300;
  static const Color borderFocus = primary400;

  // ─── Chat-specific ───────────────────────────────────────────────────────
  static const Color bubbleOutgoing = primary400;
  static const Color bubbleOutgoingGradientEnd = primary600;
  static const Color bubbleIncoming = white;
  static const Color readReceipt = Color(0xFF53BDEB);
  static const Color onlineIndicator = success;

  // ─── Gradient Presets ────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary400, primary600],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent400, accent600],
  );

  static const LinearGradient darkSurfaceGradient = LinearGradient(
    begin: Alignment(-.3, -1),
    end: Alignment(.3, 1),
    colors: [surfaceDark, surfaceDarkAlt],
  );

  static const LinearGradient subtleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neutral50, neutral100],
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    begin: Alignment(-1.5, -0.3),
    end: Alignment(1.5, 0.3),
    colors: [neutral100, neutral50, neutral100],
    stops: [0.0, 0.5, 1.0],
  );

  // ─── Glow / Shadow Colors ───────────────────────────────────────────────
  static const Color primaryGlow = Color(0x4000C896); // 25%
  static const Color accentGlow = Color(0x338B6FD4); // 20%
  static const Color successGlow = Color(0x4022C55E);
  static const Color errorGlow = Color(0x33EF4444);

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
