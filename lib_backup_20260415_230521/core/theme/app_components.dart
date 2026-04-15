// ============================================================================
// WhatsJet Premium Design System — Reusable Components
// ============================================================================
// Drop-in replacements for OmnichannelPaneCard, OmnichannelSectionCard,
// OmnichannelEmptyState, buttons, inputs, badges, avatars, etc.
// All components use design tokens and include micro-animations.
// ============================================================================

import 'package:flutter/material.dart';

import 'app_animations.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';

// ─── Premium Card Surface ──────────────────────────────────────────────────
/// Replaces [OmnichannelPaneCard] with premium elevation and border.
class WjCard extends StatelessWidget {
  const WjCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.paddingXl,
    this.shadow = AppShadows.card,
    this.radius,
    this.color,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow> shadow;
  final BorderRadius? radius;
  final Color? color;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppColors.surfacePrimary,
        borderRadius: radius ?? AppRadii.borderRadiusXxl,
        border: border ?? Border.all(color: AppColors.borderLight),
        boxShadow: shadow,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

// ─── Dark Glass Surface ────────────────────────────────────────────────────
/// Premium dark surface with ambient glow effect.
class WjDarkSurface extends StatelessWidget {
  const WjDarkSurface({
    super.key,
    required this.child,
    this.padding = AppSpacing.paddingXl,
    this.radius,
    this.showGlow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? radius;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.darkSurfaceGradient,
        borderRadius: radius ?? AppRadii.borderRadiusXl,
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.06),
        ),
      ),
      child: ClipRRect(
        borderRadius: radius ?? AppRadii.borderRadiusXl,
        child: Stack(
          children: [
            if (showGlow) ...[
              Positioned(
                top: -40,
                right: -40,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

// ─── Section Card ──────────────────────────────────────────────────────────
/// Replaces [OmnichannelSectionCard] with consistent token usage.
class WjSectionCard extends StatelessWidget {
  const WjSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: AppColors.surfaceTertiary.withValues(alpha: 0.7),
        borderRadius: AppRadii.borderRadiusXl,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: AppTypography.label),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          AppSpacing.verticalMd,
          child,
        ],
      ),
    );
  }
}

// ─── Primary Button ────────────────────────────────────────────────────────
/// Gradient primary button with press animation and glow.
class WjPrimaryButton extends StatelessWidget {
  const WjPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = AppPressable(
      onTap: isLoading ? null : onPressed,
      enabled: onPressed != null && !isLoading,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        width: expanded ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 0 : AppSpacing.xxl,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          gradient: onPressed != null && !isLoading
              ? AppColors.primaryGradient
              : null,
          color: onPressed == null || isLoading ? AppColors.neutral200 : null,
          borderRadius: AppRadii.borderRadiusMd,
          boxShadow: onPressed != null && !isLoading
              ? AppShadows.primaryGlow
              : AppShadows.none,
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white.withValues(alpha: 0.8),
                ),
              ),
              AppSpacing.horizontalSm,
            ] else if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.white),
              AppSpacing.horizontalSm,
            ],
            Text(
              isLoading ? 'Memproses...' : label,
              style: AppTypography.bodyBold.onPrimary,
            ),
          ],
        ),
      ),
    );

    return button;
  }
}

// ─── Outline Button ────────────────────────────────────────────────────────
class WjOutlineButton extends StatelessWidget {
  const WjOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.neutral600;
    return AppPressable(
      onTap: onPressed,
      enabled: onPressed != null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: AppRadii.borderRadiusMd,
          border: Border.all(color: c.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: c),
              AppSpacing.horizontalSm,
            ],
            Text(label, style: AppTypography.bodyMedium.withColor(c)),
          ],
        ),
      ),
    );
  }
}

// ─── Text Input ────────────────────────────────────────────────────────────
/// Premium text field with animated focus state, label, and error.
class WjTextField extends StatefulWidget {
  const WjTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.focusNode,
    this.enabled = true,
    this.suffixIcon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final bool enabled;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  State<WjTextField> createState() => _WjTextFieldState();
}

class _WjTextFieldState extends State<WjTextField> {
  late final FocusNode _focus;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _hasFocus = _focus.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          AnimatedDefaultTextStyle(
            duration: AppDurations.fast,
            style: AppTypography.label.copyWith(
              color: hasError
                  ? AppColors.error
                  : _hasFocus
                      ? AppColors.primary600
                      : AppColors.neutral400,
            ),
            child: Text(widget.label!),
          ),
          AppSpacing.verticalXs,
        ],
        AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          decoration: BoxDecoration(
            color: hasError
                ? AppColors.error.withValues(alpha: 0.04)
                : _hasFocus
                    ? AppColors.primary.withValues(alpha: 0.04)
                    : AppColors.neutral50,
            borderRadius: AppRadii.borderRadiusMd,
            border: Border.all(
              color: hasError
                  ? AppColors.error.withValues(alpha: 0.4)
                  : _hasFocus
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.borderLight,
              width: _hasFocus || hasError ? 1.5 : 1,
            ),
            boxShadow: _hasFocus && !hasError
                ? AppShadows.inputFocus
                : AppShadows.none,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            enabled: widget.enabled,
            onSubmitted: widget.onSubmitted,
            style: AppTypography.body,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppTypography.body.subtle,
              border: InputBorder.none,
              suffixIcon: widget.suffixIcon,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          AppSpacing.verticalXs,
          Text(widget.errorText!, style: AppTypography.micro.danger),
        ],
      ],
    );
  }
}

// ─── Avatar ────────────────────────────────────────────────────────────────
/// Channel-aware gradient avatar with online indicator.
class WjAvatar extends StatelessWidget {
  const WjAvatar({
    super.key,
    required this.initial,
    this.size = 40,
    this.channel = 'whatsapp',
    this.showOnline = false,
    this.imageUrl,
  });

  final String initial;
  final double size;
  final String channel;
  final bool showOnline;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final borderWidth = size * 0.06;
    return SizedBox(
      width: size + (showOnline ? 4 : 0),
      height: size + (showOnline ? 4 : 0),
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: AppColors.channelAvatarGradient(channel),
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            alignment: Alignment.center,
            child: imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(size * 0.28),
                    child: Image.network(
                      imageUrl!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                    ),
                  )
                : Text(
                    initial.isNotEmpty ? initial[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: size * 0.38,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
          ),
          if (showOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: AppColors.onlineIndicator,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surfacePrimary,
                    width: borderWidth,
                  ),
                  boxShadow: AppShadows.successGlow,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Status Badge ──────────────────────────────────────────────────────────
/// Pill-shaped badge for status, channels, and counts.
class WjBadge extends StatelessWidget {
  const WjBadge({
    super.key,
    required this.label,
    this.color,
    this.showDot = false,
    this.filled = false,
  });

  final String label;
  final Color? color;
  final bool showDot;
  final bool filled;

  /// Preset: unread count badge (filled emerald).
  factory WjBadge.unread(int count) {
    return WjBadge(
      label: count > 99 ? '99+' : count.toString(),
      color: AppColors.primary,
      filled: true,
    );
  }

  /// Preset: channel badge.
  factory WjBadge.channel(String channel) {
    return WjBadge(
      label: _channelLabel(channel),
      color: AppColors.channelColor(channel),
      showDot: true,
    );
  }

  /// Preset: status badge.
  factory WjBadge.status(String status) {
    return WjBadge(
      label: status[0].toUpperCase() + status.substring(1),
      color: AppColors.statusColor(status),
      showDot: true,
    );
  }

  static String _channelLabel(String ch) {
    return switch (ch) {
      'whatsapp' || 'wa' => 'WhatsApp',
      'mobile_live_chat' || 'chat' => 'Live Chat',
      'telegram' => 'Telegram',
      'instagram' => 'Instagram',
      'facebook' => 'Facebook',
      'email' => 'Email',
      _ => ch,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.neutral400;

    if (filled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        constraints: const BoxConstraints(minWidth: 20),
        decoration: BoxDecoration(
          color: c,
          borderRadius: AppRadii.borderRadiusPill,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.micro.onPrimary.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: AppRadii.borderRadiusPill,
        border: Border.all(color: c.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            AppSpacing.horizontalXs,
          ],
          Text(
            label,
            style: AppTypography.micro.copyWith(
              color: c,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Inline Banner ─────────────────────────────────────────────────────────
/// Replaces OmnichannelInlineBanner with animated enter and semantic colors.
class WjBanner extends StatelessWidget {
  const WjBanner({
    super.key,
    required this.message,
    this.type = WjBannerType.error,
    this.onRetry,
    this.onDismiss,
  });

  final String message;
  final WjBannerType type;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final (bgColor, fgColor, icon) = switch (type) {
      WjBannerType.error => (
          AppColors.error50,
          AppColors.error,
          Icons.error_outline_rounded,
        ),
      WjBannerType.warning => (
          AppColors.warning50,
          AppColors.warning800,
          Icons.warning_amber_rounded,
        ),
      WjBannerType.success => (
          AppColors.success50,
          AppColors.success800,
          Icons.check_circle_outline_rounded,
        ),
      WjBannerType.info => (
          AppColors.info50,
          AppColors.info800,
          Icons.info_outline_rounded,
        ),
    };

    return AppFadeSlideIn(
      child: Container(
        width: double.infinity,
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppRadii.borderRadiusMd,
        ),
        child: Row(
          children: [
            Icon(icon, color: fgColor, size: 20),
            AppSpacing.horizontalMd,
            Expanded(
              child: Text(
                message,
                style: AppTypography.caption.copyWith(
                  color: fgColor,
                  height: 1.4,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: AppTypography.caption.bold.copyWith(color: fgColor),
                ),
              ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                icon: Icon(Icons.close, size: 16, color: fgColor),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
          ],
        ),
      ),
    );
  }
}

enum WjBannerType { error, warning, success, info }

// ─── Empty State ───────────────────────────────────────────────────────────
/// Replaces OmnichannelEmptyState with entrance animation.
class WjEmptyState extends StatelessWidget {
  const WjEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppFadeSlideIn(
        child: Padding(
          padding: AppSpacing.paddingXxl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppScaleIn(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: AppColors.primary),
                ),
              ),
              AppSpacing.verticalLg,
              Text(title, style: AppTypography.h2, textAlign: TextAlign.center),
              AppSpacing.verticalSm,
              Text(
                message,
                style: AppTypography.body.muted,
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                AppSpacing.verticalXxl,
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Skeleton Loading Block ────────────────────────────────────────────────
/// Replaces OmnichannelSkeletonBlock with shimmer animation.
class WjSkeleton extends StatelessWidget {
  const WjSkeleton({
    super.key,
    this.height = 14,
    this.width,
    this.radius,
    this.circle = false,
  });

  final double height;
  final double? width;
  final double? radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        width: circle ? height : width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: circle
              ? null
              : BorderRadius.circular(radius ?? AppRadii.sm),
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }
}
