import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class StatusStripShimmer extends StatelessWidget {
  const StatusStripShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: const Color(0xFFEAEAEA),
          highlightColor: const Color(0xFFF8F8F8),
          child: Column(
            children: <Widget>[
              Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 62,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
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
