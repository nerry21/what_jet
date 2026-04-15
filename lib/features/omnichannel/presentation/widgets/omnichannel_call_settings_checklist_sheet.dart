import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';

class OmnichannelCallSettingsChecklistSheet extends StatelessWidget {
  final VoidCallback? onClose;

  const OmnichannelCallSettingsChecklistSheet({super.key, this.onClose});

  Widget _buildChecklistItem({
    required String title,
    required String description,
    required IconData icon,
    Color iconBg = AppColors.surfaceTertiary,
    Color iconColor = const Color(0xFFFFCF73),
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceTertiary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: AppRadii.borderRadiusMd,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutral800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.neutral600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceTertiary,
        borderRadius: AppRadii.borderRadiusPill,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.neutral600,
        ),
      ),
    );
  }

  void _close(BuildContext context) {
    Navigator.of(context).maybePop();
    onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 52,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.borderDefault,
                borderRadius: AppRadii.borderRadiusPill,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meta Call Settings Checklist',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.neutral800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Gunakan daftar ini untuk memastikan nomor WhatsApp Anda benar-benar siap memakai Calling API.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.neutral600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => _close(context),
                    borderRadius: AppRadii.borderRadiusPill,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTertiary,
                        borderRadius: AppRadii.borderRadiusPill,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.neutral600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildStepChip('1. Meta App'),
                        _buildStepChip('2. WhatsApp Account'),
                        _buildStepChip('3. Phone Number'),
                        _buildStepChip('4. Call Settings'),
                        _buildStepChip('5. Permission Flow'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildChecklistItem(
                      icon: Icons.apps_rounded,
                      title: 'Pastikan App Meta yang dipakai benar',
                      description:
                          'Gunakan App Meta yang memang terhubung ke WhatsApp Business Platform dan nomor yang sedang dipakai backend Anda.',
                    ),
                    _buildChecklistItem(
                      icon: Icons.business_center_rounded,
                      title: 'Pastikan WhatsApp Business Account sudah sesuai',
                      description:
                          'Nomor telepon yang dipakai backend harus berada di WhatsApp Business Account yang sama dengan token dan konfigurasi panggilan.',
                    ),
                    _buildChecklistItem(
                      icon: Icons.phone_android_rounded,
                      title: 'Periksa nomor WhatsApp yang aktif',
                      description:
                          'Cocokkan phone number ID di backend dengan nomor yang benar-benar Anda buka di pengaturan Meta.',
                    ),
                    _buildChecklistItem(
                      icon: Icons.settings_phone_rounded,
                      title: 'Aktifkan fitur Calling pada nomor',
                      description:
                          'Jika muncul pesan "Calling API not enabled", biasanya fitur call pada nomor tersebut belum diaktifkan di pengaturan Meta.',
                    ),
                    _buildChecklistItem(
                      icon: Icons.verified_user_rounded,
                      title: 'Cek token dan izin akses',
                      description:
                          'Pastikan access token yang dipakai backend masih valid dan memiliki izin yang sesuai untuk WhatsApp Business Platform.',
                    ),
                    _buildChecklistItem(
                      icon: Icons.mark_chat_read_rounded,
                      title: 'Cek alur permission user',
                      description:
                          'Business-initiated call biasanya memerlukan alur izin user terlebih dahulu. Pastikan backend tidak langsung mencoba memanggil tanpa permission yang valid.',
                    ),
                    _buildChecklistItem(
                      icon: Icons.receipt_long_rounded,
                      title: 'Lihat hasil readiness panel',
                      description:
                          'Gunakan panel readiness di dashboard untuk melihat apakah masalah ada pada backend config, Meta settings, atau nomor yang belum enable calling.',
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _close(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.surfaceTertiary,
                          foregroundColor: AppColors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadii.borderRadiusLg,
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text(
                          'Tutup',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
