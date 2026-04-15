import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import '../../../admin_auth/data/models/admin_user_model.dart';

class OmnichannelShellHeader extends StatelessWidget {
  const OmnichannelShellHeader({
    super.key,
    required this.currentUser,
    required this.isLoggingOut,
    required this.onLogout,
  });

  final AdminUserModel? currentUser;
  final bool isLoggingOut;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final adminInitial = _safeInitial(currentUser?.displayName, fallback: 'A');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.primary, AppColors.primary200],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 880;
          final identityCard = Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.24)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.24),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    adminInitial,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.surfacePrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _safeText(currentUser?.displayName, fallback: 'Admin'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.surfacePrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _safeText(currentUser?.roleLabel, fallback: 'Workspace'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xD9FFFFFF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          final logoutButton = OutlinedButton.icon(
            onPressed: isLoggingOut ? null : onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: Text(isLoggingOut ? 'Keluar...' : 'Logout'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.white,
              side: BorderSide(color: AppColors.white.withValues(alpha: 0.38)),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Admin Omnichannel',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.surfacePrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Inbox admin untuk membaca conversation lintas channel tanpa menyentuh flow customer live chat.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xE6FFFFFF),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: identityCard),
                const SizedBox(height: 12),
                logoutButton,
              ],
            );
          }

          return Row(
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Admin Omnichannel',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.surfacePrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Inbox admin untuk membaca conversation lintas channel tanpa menyentuh flow customer live chat.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xE6FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
              identityCard,
              const SizedBox(width: 12),
              logoutButton,
            ],
          );
        },
      ),
    );
  }
}

String _safeText(String? value, {required String fallback}) {
  final text = value?.trim();
  return (text == null || text.isEmpty) ? fallback : text;
}

String _safeInitial(String? value, {required String fallback}) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return fallback;
  }
  return text.characters.first.toUpperCase();
}
