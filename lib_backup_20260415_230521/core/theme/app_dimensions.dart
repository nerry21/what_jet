// ============================================================================
// WhatsJet Premium Design System — Spacing, Radii & Shadows
// ============================================================================
// Replaces all 484 inline BoxDecoration/BorderRadius/BoxShadow declarations.
// Usage: AppSpacing.md, AppRadii.lg, AppShadows.card, etc.
// ============================================================================

import 'package:flutter/material.dart';

import 'app_colors.dart';

// ─── Spacing ───────────────────────────────────────────────────────────────
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double massive = 48;
  static const double giant = 64;

  // Quick EdgeInsets
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);
  static const EdgeInsets paddingXxl = EdgeInsets.all(xxl);

  static const EdgeInsets paddingHorizontalMd =
      EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHorizontalLg =
      EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingHorizontalXl =
      EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets paddingVerticalSm =
      EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVerticalMd =
      EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVerticalLg =
      EdgeInsets.symmetric(vertical: lg);

  // SizedBox gaps
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
  static const SizedBox gapXxl = SizedBox(width: xxl, height: xxl);

  // Vertical-only gaps (most common in Column layouts)
  static const SizedBox verticalXs = SizedBox(height: xs);
  static const SizedBox verticalSm = SizedBox(height: sm);
  static const SizedBox verticalMd = SizedBox(height: md);
  static const SizedBox verticalLg = SizedBox(height: lg);
  static const SizedBox verticalXl = SizedBox(height: xl);
  static const SizedBox verticalXxl = SizedBox(height: xxl);
  static const SizedBox verticalXxxl = SizedBox(height: xxxl);

  // Horizontal-only gaps
  static const SizedBox horizontalXs = SizedBox(width: xs);
  static const SizedBox horizontalSm = SizedBox(width: sm);
  static const SizedBox horizontalMd = SizedBox(width: md);
  static const SizedBox horizontalLg = SizedBox(width: lg);
  static const SizedBox horizontalXl = SizedBox(width: xl);
}

// ─── Border Radii ──────────────────────────────────────────────────────────
class AppRadii {
  const AppRadii._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 28;
  static const double pill = 999;

  // BorderRadius helpers
  static final BorderRadius borderRadiusXs = BorderRadius.circular(xs);
  static final BorderRadius borderRadiusSm = BorderRadius.circular(sm);
  static final BorderRadius borderRadiusMd = BorderRadius.circular(md);
  static final BorderRadius borderRadiusLg = BorderRadius.circular(lg);
  static final BorderRadius borderRadiusXl = BorderRadius.circular(xl);
  static final BorderRadius borderRadiusXxl = BorderRadius.circular(xxl);
  static final BorderRadius borderRadiusXxxl = BorderRadius.circular(xxxl);
  static final BorderRadius borderRadiusPill = BorderRadius.circular(pill);

  // Top-only radii (for headers, top cards)
  static final BorderRadius topLg = BorderRadius.vertical(
    top: Radius.circular(lg),
  );
  static final BorderRadius topXl = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static final BorderRadius topXxl = BorderRadius.vertical(
    top: Radius.circular(xxl),
  );

  // Bottom-only radii (for bottom sheets)
  static final BorderRadius bottomLg = BorderRadius.vertical(
    bottom: Radius.circular(lg),
  );
  static final BorderRadius bottomXl = BorderRadius.vertical(
    bottom: Radius.circular(xl),
  );
}

// ─── Shadows ───────────────────────────────────────────────────────────────
class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> none = [];

  static const List<BoxShadow> xs = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 40,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 60,
      offset: Offset(0, 20),
    ),
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  /// Primary glow for elevated buttons and focused inputs.
  static const List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: AppColors.primaryGlow,
      blurRadius: 24,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Accent glow for purple elements.
  static const List<BoxShadow> accentGlow = [
    BoxShadow(
      color: AppColors.accentGlow,
      blurRadius: 24,
      offset: Offset(0, 4),
    ),
  ];

  /// Success glow for online indicators.
  static const List<BoxShadow> successGlow = [
    BoxShadow(
      color: AppColors.successGlow,
      blurRadius: 8,
    ),
  ];

  /// Card shadow (main surface elevation).
  static const List<BoxShadow> card = md;

  /// Pane shadow (dashboard panes).
  static const List<BoxShadow> pane = lg;

  /// Input focus shadow.
  static List<BoxShadow> inputFocus = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.08),
      blurRadius: 0,
      spreadRadius: 3,
    ),
  ];
}
