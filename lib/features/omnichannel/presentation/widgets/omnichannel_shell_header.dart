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
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.primary.withValues(alpha: 0.95),
            AppColors.primary700,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 880;

          // Admin identity card
          final identityCard = Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    adminInitial,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
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
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _safeText(currentUser?.roleLabel, fallback: 'Workspace'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.white.withValues(alpha: 0.70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          final logoutButton = Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.25),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              onPressed: isLoggingOut ? null : onLogout,
              icon: Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.white.withValues(alpha: 0.80),
              ),
              label: Text(
                isLoggingOut ? 'Keluar...' : 'Logout',
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.80),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'WhatsJet Admin',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Omnichannel inbox — lintas channel tanpa mengganggu flow customer.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.white.withValues(alpha: 0.70),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'WhatsJet Admin',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Omnichannel inbox — lintas channel tanpa mengganggu flow customer.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.white.withValues(alpha: 0.70),
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
