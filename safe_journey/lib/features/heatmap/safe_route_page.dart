import 'package:flutter/material.dart';

// ─── constants ────────────────────────────────────────────────────────────────

const _kPrimary = Color(0xFF6B4FA0);
const _kOrange  = Color(0xFFE8761A);

// ─── page ─────────────────────────────────────────────────────────────────────

/// Safe Route page — UI only.
/// Wire up the "Find Safest Route" button once your routing backend is ready.
class SafeRoutePage extends StatefulWidget {
  const SafeRoutePage({super.key});

  @override
  State<SafeRoutePage> createState() => _SafeRoutePageState();
}

class _SafeRoutePageState extends State<SafeRoutePage> {
  final _fromCtrl = TextEditingController();
  final _toCtrl   = TextEditingController();

  bool _hasResult = false;
  bool _searching = false;

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  // Simulate a search (replace with real backend call when ready)
  Future<void> _findRoute() async {
    if (_fromCtrl.text.trim().isEmpty || _toCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both start and destination')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() { _searching = true; _hasResult = false; });
    // TODO: replace with real API call
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() { _searching = false; _hasResult = true; });
  }

  void _clearRoute() {
    setState(() { _hasResult = false; });
    _fromCtrl.clear();
    _toCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
                top: top + 12, left: 16, right: 16, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Safe Route',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const Spacer(),
                    if (_hasResult)
                      TextButton.icon(
                        onPressed: _clearRoute,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Find the safest path between two points',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),

                const SizedBox(height: 16),

                // ── From / To fields ─────────────────────────────────
                _RouteInputField(
                  controller: _fromCtrl,
                  hint: 'Start location',
                  icon: Icons.radio_button_checked,
                  iconColor: _kPrimary,
                  onClear: () => setState(() => _fromCtrl.clear()),
                ),
                const _RouteDivider(),
                _RouteInputField(
                  controller: _toCtrl,
                  hint: 'Destination',
                  icon: Icons.location_on,
                  iconColor: _kOrange,
                  onClear: () => setState(() => _toCtrl.clear()),
                ),

                const SizedBox(height: 14),

                // ── Find route button ────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _searching ? null : _findRoute,
                    icon: _searching
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.alt_route, size: 18),
                    label: Text(_searching
                        ? 'Finding safest route…'
                        : 'Find Safest Route'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Map area ──────────────────────────────────────────────────
          Expanded(
            child: _hasResult
                ? _RouteMapPreview(
                    from: _fromCtrl.text,
                    to:   _toCtrl.text,
                  )
                : _MapPlaceholder(isSearching: _searching),
          ),
        ],
      ),
    );
  }
}

// ─── Route input field ────────────────────────────────────────────────────────

class _RouteInputField extends StatelessWidget {
  const _RouteInputField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.onClear,
  });

  final TextEditingController controller;
  final String                hint;
  final IconData              icon;
  final Color                 iconColor;
  final VoidCallback          onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, v, __) => v.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon: Icon(Icons.clear, size: 16,
                            color: Colors.grey[400]),
                        onPressed: onClear,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteDivider extends StatelessWidget {
  const _RouteDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: Column(
      children: List.generate(
        3,
        (_) => Container(
          width: 2, height: 4, margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    ),
  );
}

// ─── Map placeholder ─────────────────────────────────────────────────────────

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.isSearching});
  final bool isSearching;

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFEEE8F4),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSearching ? Icons.alt_route : Icons.map_outlined,
            size: 56,
            color: _kPrimary.withOpacity(0.25),
          ),
          const SizedBox(height: 12),
          Text(
            isSearching
                ? 'Calculating safest route…'
                : 'Enter start and destination\nto preview the route',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kPrimary.withOpacity(0.45),
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Route result preview ─────────────────────────────────────────────────────

class _RouteMapPreview extends StatelessWidget {
  const _RouteMapPreview({required this.from, required this.to});
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map background (replace with GoogleMap widget when wired up)
        Container(
          color: const Color(0xFFE8E3F4),
          child: CustomPaint(
            painter: _DummyRoutePainter(),
            size: Size.infinite,
          ),
        ),

        // Route info card at bottom
        Positioned(
          left: 12, right: 12, bottom: 12,
          child: Material(
            color: Colors.white,
            elevation: 2,
            shadowColor: Colors.black12,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stat row
                  Row(
                    children: [
                      _RouteStat(
                        icon: Icons.shield_outlined,
                        label: 'Safety',
                        value: '87%',
                        color: Colors.green[600]!,
                      ),
                      const SizedBox(width: 16),
                      _RouteStat(
                        icon: Icons.timer_outlined,
                        label: 'Est. time',
                        value: '~14 min',
                        color: _kPrimary,
                      ),
                      const SizedBox(width: 16),
                      _RouteStat(
                        icon: Icons.straighten_outlined,
                        label: 'Distance',
                        value: '3.2 km',
                        color: Colors.grey[600]!,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // From → To summary
                  Row(
                    children: [
                      const Icon(Icons.radio_button_checked,
                          size: 14, color: _kPrimary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          from,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward,
                            size: 14, color: Colors.grey),
                      ),
                      const Icon(Icons.location_on,
                          size: 14, color: _kOrange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          to,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteStat extends StatelessWidget {
  const _RouteStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            )),
      ],
    ),
  );
}

// ─── Dummy route painter (placeholder visual) ─────────────────────────────────

class _DummyRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Light grid
    final gridPaint = Paint()
      ..color = _kPrimary.withOpacity(0.06)
      ..strokeWidth = 1;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Route line
    final routePaint = Paint()
      ..color = _kPrimary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.8)
      ..cubicTo(
        size.width * 0.2, size.height * 0.5,
        size.width * 0.5, size.height * 0.5,
        size.width * 0.5, size.height * 0.3,
      )
      ..cubicTo(
        size.width * 0.5, size.height * 0.15,
        size.width * 0.75, size.height * 0.15,
        size.width * 0.8, size.height * 0.15,
      );
    canvas.drawPath(path, routePaint);

    // Start dot
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.8),
      8,
      Paint()..color = _kPrimary,
    );
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.8),
      4,
      Paint()..color = Colors.white,
    );

    // End dot
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.15),
      8,
      Paint()..color = _kOrange,
    );
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.15),
      4,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
