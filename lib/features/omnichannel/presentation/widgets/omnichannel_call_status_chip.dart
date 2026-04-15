import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/omnichannel_call_session_model.dart';
import '../utils/omnichannel_call_status_ui.dart';

class OmnichannelCallStatusChip extends StatelessWidget {
  const OmnichannelCallStatusChip({
    super.key,
    required this.session,
    this.compact = false,
  });

  final OmnichannelCallSessionModel? session;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = omnichannelCallStatusColor(session);
    final background = color.withValues(alpha: 0.12);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            omnichannelCallStatusIcon(session),
            size: compact ? 14 : 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            omnichannelCallPrimaryStatusText(session),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: session == null ? AppColors.neutral500 : color,
            ),
          ),
        ],
      ),
    );
  }
}
