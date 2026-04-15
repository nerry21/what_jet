// ============================================================================
// WhatsJet Premium Design System — Typography
// ============================================================================
// Replaces all 697 inline TextStyle declarations.
// Usage: AppTypography.display, AppTypography.h1, body, caption, etc.
// Each style has built-in variants: .bold, .muted, .primary, .onDark, etc.
// ============================================================================

import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTypography {
  const AppTypography._();

  static const String _fontFamily = 'SF Pro Display';
  static const String _fontFamilyMono = 'SF Mono';

  // ─── Display (32px / w700) ───────────────────────────────────────────────
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.5,
    color: AppColors.neutral800,
    fontFamily: _fontFamily,
  );

  // ─── H1 (24px / w700) ───────────────────────────────────────────────────
  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
    color: AppColors.neutral800,
    fontFamily: _fontFamily,
  );

  // ─── H2 (20px / w600) ───────────────────────────────────────────────────
  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.2,
    color: AppColors.neutral800,
    fontFamily: _fontFamily,
  );

  // ─── H3 (16px / w600) ───────────────────────────────────────────────────
  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.neutral800,
    fontFamily: _fontFamily,
  );

  // ─── Body (14px / w400) ──────────────────────────────────────────────────
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.neutral800,
    fontFamily: _fontFamily,
  );

  // ─── Body Medium (14px / w500) ───────────────────────────────────────────
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.neutral800,
    fontFamily: _fontFamily,
  );

  // ─── Body Bold (14px / w700) ─────────────────────────────────────────────
  static const TextStyle bodyBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.5,
    color: AppColors.neutral800,
    fontFamily: _fontFamily,
  );

  // ─── Caption (12px / w500) ───────────────────────────────────────────────
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.neutral500,
    fontFamily: _fontFamily,
  );

  // ─── Micro (11px / w600) ─────────────────────────────────────────────────
  static const TextStyle micro = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.2,
    color: AppColors.neutral400,
    fontFamily: _fontFamily,
  );

  // ─── Label (11px / w700 / uppercase) ─────────────────────────────────────
  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0.8,
    color: AppColors.neutral400,
    fontFamily: _fontFamily,
  );

  // ─── Code / Monospace (13px / w400) ──────────────────────────────────────
  static const TextStyle code = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.neutral700,
    fontFamily: _fontFamilyMono,
  );

  // ─── Chat-specific ───────────────────────────────────────────────────────
  static const TextStyle chatMessage = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.neutral800,
    fontFamily: _fontFamily,
  );

  static const TextStyle chatMessageOnPrimary = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.white,
    fontFamily: _fontFamily,
  );

  static const TextStyle chatTimestamp = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.2,
    color: AppColors.neutral300,
    fontFamily: _fontFamily,
  );

  static const TextStyle chatTimestampOnPrimary = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.2,
    color: Color(0xB3FFFFFF), // 70% white
    fontFamily: _fontFamily,
  );

  // ─── Conversation List ───────────────────────────────────────────────────
  static const TextStyle conversationName = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.neutral800,
    fontFamily: _fontFamily,
  );

  static const TextStyle conversationPreview = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: AppColors.neutral400,
    fontFamily: _fontFamily,
  );

  static const TextStyle conversationTime = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.2,
    color: AppColors.neutral300,
    fontFamily: _fontFamily,
  );
}

// ─── Extension for quick style variants ────────────────────────────────────
extension TextStyleX on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get regular => copyWith(fontWeight: FontWeight.w400);

  TextStyle get primary => copyWith(color: AppColors.primary);
  TextStyle get accent => copyWith(color: AppColors.accent);
  TextStyle get muted => copyWith(color: AppColors.neutral400);
  TextStyle get subtle => copyWith(color: AppColors.neutral300);
  TextStyle get danger => copyWith(color: AppColors.error);
  TextStyle get success => copyWith(color: AppColors.success);
  TextStyle get onDark => copyWith(color: AppColors.white);
  TextStyle get onDarkMuted => copyWith(color: AppColors.neutral500);
  TextStyle get onPrimary => copyWith(color: AppColors.white);

  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withSize(double size) => copyWith(fontSize: size);
}
