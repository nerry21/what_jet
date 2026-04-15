import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';

class SegmentedStatusRingAvatar extends StatelessWidget {
  const SegmentedStatusRingAvatar({
    super.key,
    required this.label,
    required this.totalSegments,
    required this.viewedSegments,
    required this.heroTag,
    this.imageUrl,
    this.size = 74,
  });

  final String label;
  final int totalSegments;
  final int viewedSegments;
  final String heroTag;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final segments = totalSegments <= 0 ? 1 : totalSegments;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Hero(
          tag: heroTag,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _SegmentedRingPainter(
                  totalSegments: segments,
                  viewedSegments: viewedSegments.clamp(0, segments),
                ),
                child: Padding(
                  padding: EdgeInsets.all(6),
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
              ),
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

class _SegmentedRingPainter extends CustomPainter {
  _SegmentedRingPainter({
    required this.totalSegments,
    required this.viewedSegments,
  });

  final int totalSegments;
  final int viewedSegments;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 4.0;
    const gapRadians = 0.10;

    final rect = Offset.zero & size;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const fullSweep = 6.283185307179586;
    final segmentSweep = (fullSweep / totalSegments) - gapRadians;

    var startAngle = -1.5707963267948966;

    for (var i = 0; i < totalSegments; i++) {
      final isViewed = i < viewedSegments;
      basePaint.color = isViewed ? AppColors.neutral400 : AppColors.primary;

      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        startAngle,
        segmentSweep,
        false,
        basePaint,
      );

      startAngle += segmentSweep + gapRadians;
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedRingPainter oldDelegate) {
    return oldDelegate.totalSegments != totalSegments ||
        oldDelegate.viewedSegments != viewedSegments;
  }
}
