import 'package:flutter/material.dart';

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
    final ringColor = hasUnviewed
        ? const Color(0xFF25D366)
        : const Color(0xFFBDBDBD);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: <Color>[ringColor, ringColor.withValues(alpha: 0.75)],
            ),
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(3),
            child: CircleAvatar(
              backgroundColor: const Color(0xFFE8F5E9),
              backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
                  ? NetworkImage(imageUrl!)
                  : null,
              child: imageUrl == null || imageUrl!.isEmpty
                  ? Text(
                      label.isNotEmpty ? label[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B5E20),
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
