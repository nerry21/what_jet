import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/routing/app_routes.dart';
import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import '../../data/repositories/admin_auth_repository.dart';
import '../controllers/admin_auth_controller.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key, required this.repository});

  final AdminAuthRepository repository;

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage>
    with SingleTickerProviderStateMixin {
  late final AdminAuthController _controller;
  late final AnimationController _glowController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _hasNavigated = false;
  String? _focusedField;

  @override
  void initState() {
    super.initState();
    _controller = AdminAuthController(repository: widget.repository)
      ..addListener(_handleControllerChanged);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _emailFocusNode.addListener(() {
      setState(
        () =>
            _focusedField = _emailFocusNode.hasFocus ? 'email' : _focusedField,
      );
    });
    _passwordFocusNode.addListener(() {
      setState(
        () => _focusedField = _passwordFocusNode.hasFocus
            ? 'password'
            : _focusedField,
      );
    });

    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _glowController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final authenticatedUser = _controller.authenticatedUser;
    if (authenticatedUser == null || _hasNavigated || !mounted) {
      return;
    }

    _hasNavigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacementNamed(
        AppRoutes.adminOmnichannel,
        arguments: authenticatedUser,
      );
    });
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Email dan password wajib diisi.', isError: true);
      return;
    }

    final session = await _controller.login(email: email, password: password);
    if (!mounted || session == null) {
      return;
    }

    _showSnackBar('Login admin berhasil.');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.scaffoldBackground,
      ),
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Stack(
          children: [
            // ═══ AMBIENT GLOW BACKGROUND ═══
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) {
                return Positioned(
                  top: -60 + (_glowController.value * 20),
                  right: -40,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(
                            alpha: 0.08 + _glowController.value * 0.04,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              bottom: -80,
              left: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ═══ MAIN CONTENT ═══
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final isBusy =
                            _controller.isInitializing ||
                            _controller.isSubmitting;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // ═══ LOGO ═══
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary700,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.30,
                                    ),
                                    blurRadius: 32,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'W',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Title
                            Text(
                              'WhatsJet',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: AppColors.neutral800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Admin Console — Executive Access',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.neutral400,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 36),

                            // ═══ ERROR BANNER ═══
                            if (_controller.errorMessage != null)
                              Padding(
                                padding: EdgeInsets.only(bottom: 20),
                                child: _PremiumAuthBanner(
                                  message: _controller.errorMessage!,
                                  isOffline: _controller.isOffline,
                                  onRetry: isBusy ? null : _submit,
                                ),
                              ),

                            // ═══ EMAIL FIELD ═══
                            _PremiumTextField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              label: 'EMAIL',
                              hintText: 'admin@company.com',
                              keyboardType: TextInputType.emailAddress,
                              enabled: !isBusy,
                              isFocused: _focusedField == 'email',
                              onSubmitted: (_) =>
                                  _passwordFocusNode.requestFocus(),
                            ),
                            const SizedBox(height: 18),

                            // ═══ PASSWORD FIELD ═══
                            _PremiumTextField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              label: 'PASSWORD',
                              hintText: 'Masukkan password',
                              keyboardType: TextInputType.visiblePassword,
                              enabled: !isBusy,
                              obscureText: _obscurePassword,
                              isFocused: _focusedField == 'password',
                              onSubmitted: (_) => unawaited(_submit()),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.neutral400,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // ═══ SIGN IN BUTTON ═══
                            SizedBox(
                              width: double.infinity,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primary700,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.30,
                                      ),
                                      blurRadius: 24,
                                      offset: const Offset(0, 6),
                                    ),
                                    BoxShadow(
                                      color: const Color(0x40000000),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextButton(
                                  onPressed: isBusy ? null : _submit,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.white,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: isBusy
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.white,
                                          ),
                                        )
                                      : Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Footer
                            Text(
                              'v2.0 Premium · ${AppConfig.baseUrl.replaceAll('https://', '')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.neutral300,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM TEXT FIELD — Dark glass with animated focus glow
// ═══════════════════════════════════════════════════════════════════════════

class _PremiumTextField extends StatelessWidget {
  const _PremiumTextField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hintText,
    required this.keyboardType,
    required this.enabled,
    required this.isFocused,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hintText;
  final TextInputType keyboardType;
  final bool enabled;
  final bool isFocused;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: isFocused ? AppColors.primary : AppColors.neutral400,
          ),
          child: Text(label),
        ),
        const SizedBox(height: 8),

        // Input
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isFocused
                ? AppColors.primary.withValues(alpha: 0.04)
                : AppColors.surfaceTertiary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFocused
                  ? AppColors.primary.withValues(alpha: 0.40)
                  : AppColors.borderLight,
              width: isFocused ? 1.5 : 1.0,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            obscureText: obscureText,
            enabled: enabled,
            onSubmitted: onSubmitted,
            style: TextStyle(fontSize: 14, color: AppColors.neutral800),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: AppColors.neutral300),
              border: InputBorder.none,
              suffixIcon: suffixIcon,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM AUTH BANNER — Error/offline with dark glass
// ═══════════════════════════════════════════════════════════════════════════

class _PremiumAuthBanner extends StatelessWidget {
  const _PremiumAuthBanner({
    required this.message,
    required this.isOffline,
    this.onRetry,
  });

  final String message;
  final bool isOffline;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final color = isOffline ? AppColors.warning : AppColors.error;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, height: 1.4, color: color),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text('Retry', style: TextStyle(color: color)),
            ),
        ],
      ),
    );
  }
}
