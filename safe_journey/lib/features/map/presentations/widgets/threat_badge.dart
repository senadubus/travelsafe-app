import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum ThreatLevel { low, medium, high, unknown }

class ThreatBadge extends StatelessWidget {
  final ThreatLevel level;

  const ThreatBadge({
    super.key,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (level) {
      ThreatLevel.low => ('Low Risk', AppColors.safe),
      ThreatLevel.medium => ('Moderate', AppColors.medium),
      ThreatLevel.high => ('High Risk', AppColors.high),
      ThreatLevel.unknown => ('Scanning', AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
