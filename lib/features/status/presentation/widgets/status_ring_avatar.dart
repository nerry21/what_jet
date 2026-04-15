import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';

class StatusRingAvatar extends StatelessWidget {
  const StatusRingAvatar({
    super.key,
    required this.label,
    required this.hasUnviewed,
    this.imageUrl,
    this.size = 74,
  });

  final String label;
  final bool hasUnviewed;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ringColor = hasUnviewed ? AppColors.primary : AppColors.neutral400;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: <Color>[ringColor, ringColor.withValues(alpha: 0.75)],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceSecondary,
            ),
            padding: EdgeInsets.all(3),
            child: CircleAvatar(
              backgroundColor: AppColors.surfaceTertiary,
              backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
                  ? NetworkImage(imageUrl!)
                  : null,
              child: imageUrl == null || imageUrl!.isEmpty
                  ? Text(
                      label.isNotEmpty ? label[0].toUpperCase() : 'A',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: size + 12,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
