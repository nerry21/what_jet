import 'dart:async';

import 'package:flutter/material.dart';

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

class _AdminLoginPageState extends State<AdminLoginPage> {
  late final AdminAuthController _controller;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AdminAuthController(repository: widget.repository)
      ..addListener(_handleControllerChanged);

    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.scaffoldBackground,
              AppColors.borderLight,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final isBusy =
                      _controller.isInitializing || _controller.isSubmitting;

                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: AppRadii.borderRadiusXxl,
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 32,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: <Color>[
                                  AppColors.primary,
                                  AppColors.primary200,
                                ],
                              ),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Admin Omnichannel',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Masuk sebagai admin untuk membuka inbox omnichannel di web atau desktop.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Color(0xE6FFFFFF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                if (_controller.errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _AdminAuthBanner(
                                      message: _controller.errorMessage!,
                                      isOffline: _controller.isOffline,
                                      onRetry: isBusy ? null : _submit,
                                    ),
                                  ),
                                const _FieldLabel(text: 'Email'),
                                _AdminInput(
                                  controller: _emailController,
                                  hintText: 'admin@whatjet.com',
                                  keyboardType: TextInputType.emailAddress,
                                  enabled: !isBusy,
                                  onSubmitted: (_) =>
                                      _passwordFocusNode.requestFocus(),
                                ),
                                const SizedBox(height: 16),
                                const _FieldLabel(text: 'Password'),
                                _AdminInput(
                                  controller: _passwordController,
                                  hintText: 'Masukkan password',
                                  keyboardType: TextInputType.visiblePassword,
                                  focusNode: _passwordFocusNode,
                                  enabled: !isBusy,
                                  obscureText: _obscurePassword,
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
                                      color: AppColors.neutral500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: <Color>[
                                          AppColors.primary,
                                          AppColors.primary200,
                                        ],
                                      ),
                                      borderRadius: AppRadii.borderRadiusMd,
                                      boxShadow: const <BoxShadow>[
                                        BoxShadow(
                                          color: Color(0x3300A884),
                                          blurRadius: 12,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: TextButton(
                                      onPressed: isBusy ? null : _submit,
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: AppRadii.borderRadiusMd,
                                        ),
                                      ),
                                      child: Text(
                                        isBusy ? 'Memproses...' : 'Login Admin',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SelectableText(
                                  'API Base URL: ${AppConfig.baseUrl}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.neutral300,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
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
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }
}

class _AdminAuthBanner extends StatelessWidget {
  const _AdminAuthBanner({
    required this.message,
    required this.isOffline,
    this.onRetry,
  });

  final String message;
  final bool isOffline;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isOffline
        ? const Color(0xFF9A6700)
        : AppColors.error;
    final backgroundColor = isOffline
        ? const Color(0xFFFFF4E5)
        : AppColors.error.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadii.borderRadiusMd,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: foregroundColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: foregroundColor,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    );
  }
}

class _AdminInput extends StatelessWidget {
  const _AdminInput({
    required this.controller,
    required this.hintText,
    required this.keyboardType,
    required this.enabled,
    this.focusNode,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final bool enabled;
  final FocusNode? focusNode;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: AppRadii.borderRadiusLg,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        enabled: enabled,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppColors.neutral300),
          border: InputBorder.none,
          suffixIcon: suffixIcon,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
