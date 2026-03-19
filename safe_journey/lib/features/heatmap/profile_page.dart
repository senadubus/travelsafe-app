import 'package:flutter/material.dart';

// ─── constants ────────────────────────────────────────────────────────────────

const _kPrimary = Color(0xFF6B4FA0);
const _kOrange  = Color(0xFFE8761A);

// ─── page ─────────────────────────────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Settings state
  bool _notificationsEnabled = true;
  bool _heatmapAutoRefresh   = true;
  bool _showIncidentMarkers  = true;
  String _defaultRadius      = '1 km';
  String _defaultCrimeType   = 'All';

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Profile header ────────────────────────────────────────────
          _ProfileHeader(topPad: top),

          const SizedBox(height: 16),

          // ── Settings sections ─────────────────────────────────────────
          _SectionCard(
            title: 'Map Settings',
            children: [
              _ToggleTile(
                icon: Icons.layers_outlined,
                label: 'Auto-refresh heatmap',
                subtitle: 'Reload when camera stops moving',
                value: _heatmapAutoRefresh,
                onChanged: (v) => setState(() => _heatmapAutoRefresh = v),
              ),
              _DividerLine(),
              _ToggleTile(
                icon: Icons.location_on_outlined,
                label: 'Show crime markers',
                subtitle: 'Display individual incident pins',
                value: _showIncidentMarkers,
                onChanged: (v) => setState(() => _showIncidentMarkers = v),
              ),
              _DividerLine(),
              _SelectTile(
                icon: Icons.radar_outlined,
                label: 'Default radius',
                value: _defaultRadius,
                options: const ['500 m', '1 km', '2 km', '5 km'],
                onChanged: (v) => setState(() => _defaultRadius = v),
              ),
              _DividerLine(),
              _SelectTile(
                icon: Icons.filter_list_outlined,
                label: 'Default crime type',
                value: _defaultCrimeType,
                options: const [
                  'All', 'Theft', 'Assault', 'Battery',
                  'Burglary', 'Robbery', 'Narcotics', 'Homicide',
                ],
                onChanged: (v) => setState(() => _defaultCrimeType = v),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _SectionCard(
            title: 'Notifications',
            children: [
              _ToggleTile(
                icon: Icons.notifications_outlined,
                label: 'Area alerts',
                subtitle: 'Get notified when crime activity is high nearby',
                value: _notificationsEnabled,
                onChanged: (v) => setState(() => _notificationsEnabled = v),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _SectionCard(
            title: 'About',
            children: [
              _InfoTile(
                icon: Icons.info_outline,
                label: 'App version',
                value: '1.0.0',
              ),
              _DividerLine(),
              _InfoTile(
                icon: Icons.storage_outlined,
                label: 'Data source',
                value: 'Chicago PD Open Data',
              ),
              _DividerLine(),
              _ActionTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy policy',
                onTap: () {/* TODO */},
              ),
              _DividerLine(),
              _ActionTile(
                icon: Icons.help_outline,
                label: 'Help & support',
                onTap: () {/* TODO */},
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Sign out ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () {/* TODO */},
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[400],
                side: BorderSide(color: Colors.red[200]!),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Profile header ───────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.topPad});
  final double topPad;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
          top: topPad + 16, left: 16, right: 16, bottom: 20),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 30,
            backgroundColor: _kPrimary.withOpacity(0.12),
            child: const Text(
              'U',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _kPrimary,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'user@travelsafe.app',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // Edit button
          IconButton(
            onPressed: () {/* TODO */},
            icon: Icon(Icons.edit_outlined, color: Colors.grey[500], size: 20),
          ),
        ],
      ),
    );
  }
}

// ─── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String        title;
  final List<Widget>  children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
          ),
          Material(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// ─── Tile types ───────────────────────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData         icon;
  final String           label;
  final String?          subtitle;
  final bool             value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[500]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E))),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(subtitle!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: _kPrimary,
        ),
      ],
    ),
  );
}

class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData           icon;
  final String             label;
  final String             value;
  final List<String>       options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => _showPicker(context),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF1A1A2E))),
          ),
          Text(value,
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
        ],
      ),
    ),
  );

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PickerSheet(
        title: label,
        options: options,
        selected: value,
        onSelected: (v) { Navigator.pop(context); onChanged(v); },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String   label;
  final String   value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[500]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF1A1A2E))),
        ),
        Text(value,
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF1A1A2E))),
          ),
          Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
        ],
      ),
    ),
  );
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 46,
    endIndent: 0,
    color: Colors.grey[100],
  );
}

// ─── Picker bottom sheet ──────────────────────────────────────────────────────

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String             title;
  final List<String>       options;
  final String             selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          ...options.map((opt) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(opt, style: const TextStyle(fontSize: 14)),
            trailing: opt == selected
                ? const Icon(Icons.check, color: _kPrimary, size: 18)
                : null,
            onTap: () => onSelected(opt),
          )),
        ],
      ),
    );
  }
}
