import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import 'package:shimmer/shimmer.dart';

class StatusStripShimmer extends StatelessWidget {
  const StatusStripShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: AppColors.borderDefault,
          highlightColor: AppColors.surfaceTertiary,
          child: Column(
            children: <Widget>[
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 62,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadii.borderRadiusPill,
                ),
              ),
            ],
          ),
        ),
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemCount: 5,
      ),
    );
  }
}
