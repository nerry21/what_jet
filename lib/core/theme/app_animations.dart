// ============================================================================
// WhatsJet Premium Design System — Animations
// ============================================================================
// Centralized motion system: durations, curves, transitions, and reusable
// animated wrapper widgets for premium micro-interactions.
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

// ─── Duration Tokens ───────────────────────────────────────────────────────
class AppDurations {
  const AppDurations._();

  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 450);
  static const Duration slower = Duration(milliseconds: 600);
  static const Duration dramatic = Duration(milliseconds: 800);

  // Stagger delays for list items
  static Duration stagger(int index, {int maxMs = 400}) {
    return Duration(milliseconds: (index * 50).clamp(0, maxMs));
  }
}

// ─── Curve Tokens ──────────────────────────────────────────────────────────
class AppCurves {
  const AppCurves._();

  /// Default ease for most transitions.
  static const Curve standard = Curves.easeOutCubic;

  /// Snappy enter (elements appearing).
  static const Curve enter = Curves.easeOutQuart;

  /// Smooth exit (elements disappearing).
  static const Curve exit = Curves.easeInCubic;

  /// Bouncy overshoot (buttons, badges, toasts).
  static const Curve bounce = Curves.elasticOut;

  /// Gentle spring for drag releases.
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Decelerate (scrolling, fling-based).
  static const Curve decelerate = Curves.decelerate;

  /// Emphasized ease for hero transitions.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
}

// ─── Page Transitions ──────────────────────────────────────────────────────
class AppPageTransitions {
  const AppPageTransitions._();

  /// Fade + slide up transition (iOS-style modern).
  static Route<T> fadeSlideUp<T>(Widget page, {RouteSettings? settings}) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: AppDurations.normal,
      reverseTransitionDuration: AppDurations.fast,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppCurves.enter,
          reverseCurve: AppCurves.exit,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Scale + fade transition (for modals / overlays).
  static Route<T> scaleFade<T>(Widget page, {RouteSettings? settings}) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: AppDurations.normal,
      reverseTransitionDuration: AppDurations.fast,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppCurves.enter,
          reverseCurve: AppCurves.exit,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Shared axis horizontal (for tab-like navigation).
  static Route<T> sharedAxisX<T>(Widget page, {RouteSettings? settings}) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: AppDurations.normal,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppCurves.emphasized,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.15, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

// ─── Animated Wrapper Widgets ──────────────────────────────────────────────

/// Fade-in + slide-up on first build. Perfect for list items and cards.
///
/// ```dart
/// AppFadeSlideIn(
///   delay: AppDurations.stagger(index),
///   child: ConversationCard(...),
/// )
/// ```
class AppFadeSlideIn extends StatefulWidget {
  const AppFadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
    this.offset = const Offset(0, 16),
    this.curve = AppCurves.enter,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;
  final Curve curve;

  @override
  State<AppFadeSlideIn> createState() => _AppFadeSlideInState();
}

class _AppFadeSlideInState extends State<AppFadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final curved = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _position = Tween<Offset>(begin: widget.offset, end: Offset.zero)
        .animate(curved);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(offset: _position.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Scale-in with a subtle bounce. Perfect for badges, FABs, toasts.
///
/// ```dart
/// AppScaleIn(
///   child: UnreadBadge(count: 3),
/// )
/// ```
class AppScaleIn extends StatefulWidget {
  const AppScaleIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.curve = AppCurves.spring,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  @override
  State<AppScaleIn> createState() => _AppScaleInState();
}

class _AppScaleInState extends State<AppScaleIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

/// Tap feedback: scale-down on press, release with spring bounce.
///
/// ```dart
/// AppPressable(
///   onTap: () => print('tapped'),
///   child: MyButton(),
/// )
/// ```
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.96,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final bool enabled;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
      reverseDuration: const Duration(milliseconds: 350),
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppCurves.standard,
        reverseCurve: AppCurves.spring,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.enabled) _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.enabled ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Shimmer loading effect. Replaces the shimmer package dependency.
///
/// ```dart
/// AppShimmer(
///   child: Container(height: 14, color: Colors.white),
/// )
/// ```
class AppShimmer extends StatefulWidget {
  const AppShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  final Widget child;
  final Duration duration;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.5, -0.3),
              end: const Alignment(1.5, 0.3),
              colors: const [
                Color(0xFFECEAE6),
                Color(0xFFF5F4F2),
                Color(0xFFECEAE6),
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Animated counter — number ticks up/down with spring animation.
///
/// ```dart
/// AppAnimatedCounter(
///   value: unreadCount,
///   style: AppTypography.caption.bold.primary,
/// )
/// ```
class AppAnimatedCounter extends StatelessWidget {
  const AppAnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = AppDurations.normal,
    this.curve = AppCurves.enter,
  });

  final int value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, animValue, _) {
        return Text(
          animValue.round().toString(),
          style: style,
        );
      },
    );
  }
}

/// Pulsing dot for online/active indicators.
///
/// ```dart
/// AppPulsingDot(color: AppColors.success, size: 8)
/// ```
class AppPulsingDot extends StatefulWidget {
  const AppPulsingDot({
    super.key,
    this.color = const Color(0xFF22C55E),
    this.size = 8,
    this.pulseScale = 2.2,
  });

  final Color color;
  final double size;
  final double pulseScale;

  @override
  State<AppPulsingDot> createState() => _AppPulsingDotState();
}

class _AppPulsingDotState extends State<AppPulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * widget.pulseScale,
      height: widget.size * widget.pulseScale,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _PulsingDotPainter(
              color: widget.color,
              dotSize: widget.size,
              pulseScale: widget.pulseScale,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _PulsingDotPainter extends CustomPainter {
  _PulsingDotPainter({
    required this.color,
    required this.dotSize,
    required this.pulseScale,
    required this.progress,
  });

  final Color color;
  final double dotSize;
  final double pulseScale;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Pulsing ring
    final ringRadius = (dotSize / 2) + (dotSize / 2) * (pulseScale - 1) * progress;
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.3 * (1 - progress))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, ringRadius, ringPaint);

    // Solid dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, dotSize / 2, dotPaint);
  }

  @override
  bool shouldRepaint(_PulsingDotPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Typing indicator (3 bouncing dots).
///
/// ```dart
/// AppTypingIndicator(color: AppColors.neutral300)
/// ```
class AppTypingIndicator extends StatefulWidget {
  const AppTypingIndicator({
    super.key,
    this.color = const Color(0xFFB5B3AD),
    this.dotSize = 6,
  });

  final Color color;
  final double dotSize;

  @override
  State<AppTypingIndicator> createState() => _AppTypingIndicatorState();
}

class _AppTypingIndicatorState extends State<AppTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value + i * 0.2) % 1.0;
            final bounce = math.sin(phase * math.pi);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.dotSize * 0.3),
              child: Transform.translate(
                offset: Offset(0, -bounce * widget.dotSize * 0.6),
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.4 + bounce * 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Staggered list animation wrapper — animates children one by one.
///
/// ```dart
/// AppStaggeredList(
///   children: conversations.map((c) => ConversationCard(c)).toList(),
/// )
/// ```
class AppStaggeredList extends StatelessWidget {
  const AppStaggeredList({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.itemDuration = const Duration(milliseconds: 400),
  });

  final List<Widget> children;
  final Duration staggerDelay;
  final Duration itemDuration;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++)
          AppFadeSlideIn(
            duration: itemDuration,
            delay: Duration(
              milliseconds: staggerDelay.inMilliseconds * i,
            ),
            child: children[i],
          ),
      ],
    );
  }
}
