import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class SideActions extends StatelessWidget {
  final bool heatmapOn;
  final VoidCallback onRecenter;
  final VoidCallback onToggleHeatmap;

  const SideActions({
    super.key,
    required this.heatmapOn,
    required this.onRecenter,
    required this.onToggleHeatmap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionButton(
          icon: Icons.my_location_rounded,
          onTap: onRecenter,
          active: false,
        ),
        const SizedBox(height: 10),
        _ActionButton(
          icon: heatmapOn ? Icons.layers_rounded : Icons.layers_clear_rounded,
          onTap: onToggleHeatmap,
          active: heatmapOn,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? AppColors.accent.withOpacity(0.16)
          : AppColors.surface.withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: active ? AppColors.accent : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: active ? AppColors.accent : AppColors.textPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }
}
