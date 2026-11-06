import 'package:flutter/material.dart';

const _kPrimary = Color(0xFF6B4FA0);

class MapFab extends StatelessWidget {
  const MapFab({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip = '',
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? _kPrimary : Colors.white,
        elevation: 2,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 20,
              color: active ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}
