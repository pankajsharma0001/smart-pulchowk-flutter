import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/models/event.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';

class EventStatusBadge extends StatelessWidget {
  final ClubEvent event;
  final bool isCompact;

  const EventStatusBadge({
    super.key,
    required this.event,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = _getStatusInfo();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 10,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: status.color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.label.toUpperCase(),
            style: AppTextStyles.overline.copyWith(
              color: status.color,
              fontSize: isCompact ? 8 : 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo() {
    if (event.isCancelled) {
      return _StatusInfo(label: 'Cancelled', color: AppColors.error);
    }
    if (event.isCompleted) {
      return _StatusInfo(label: 'Completed', color: AppColors.textMuted);
    }
    if (event.isOngoing) {
      return _StatusInfo(label: 'Ongoing', color: AppColors.success);
    }
    if (event.isUpcoming) {
      return _StatusInfo(label: 'Upcoming', color: AppColors.primary);
    }
    return _StatusInfo(label: event.status, color: AppColors.primary);
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  _StatusInfo({required this.label, required this.color});
}
