import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class BottomBar extends StatelessWidget {
  final String selectedCrimeType;
  final int selectedDays;
  final bool filterOpen;
  final VoidCallback onToggleFilter;

  const BottomBar({
    super.key,
    required this.selectedCrimeType,
    required this.selectedDays,
    required this.filterOpen,
    required this.onToggleFilter,
  });

  String get _summary {
    final type = selectedCrimeType == 'ALL' ? 'All crimes' : selectedCrimeType;
    return '$type • $selectedDays days';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.90),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.tune_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _summary,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onToggleFilter,
                  style: TextButton.styleFrom(
                    backgroundColor: filterOpen
                        ? AppColors.primary.withOpacity(0.16)
                        : AppColors.accent,
                    foregroundColor:
                        filterOpen ? AppColors.primarySoft : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(filterOpen ? 'Close' : 'Filters'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
