// ============================================================
// MAIN — TravelSafe App Shell  (4 sekme + logo)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'page1_heatmap.dart';
// import 'page2_route_planner.dart';
// import 'page3_crime_prediction.dart';
// import 'page4_profile.dart';
// import 'logo_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF1A1A2E),
  ));
  runApp(const TravelSafeApp());
}

class TravelSafeApp extends StatelessWidget {
  const TravelSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TravelSafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7B3FA0),
          secondary: Color(0xFFE8631A),
          surface: Color(0xFF1A1A2E),
        ),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      home: const AppShell(),
    );
  }
}

// ── ANA SHELL ─────────────────────────────────────────────────
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  // TODO: Gerçek sayfalarla değiştir:
  // HeatmapHomePage(), RoutePlannerPage(), CrimePredictionPage(), ProfilePage()
  final List<Widget> _pages = const [
    _PlaceholderPage(
        title: 'Isı Haritası',
        icon: Icons.map_rounded,
        file: 'page1_heatmap.dart'),
    _PlaceholderPage(
        title: 'Güvenli Rota',
        icon: Icons.route_rounded,
        file: 'page2_route_planner.dart'),
    _PlaceholderPage(
        title: 'Suç Tahmini',
        icon: Icons.psychology_rounded,
        file: 'page3_crime_prediction.dart'),
    _PlaceholderPage(
        title: 'Profil',
        icon: Icons.person_rounded,
        file: 'page4_profile.dart'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _TravelSafeNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── BOTTOM NAV ────────────────────────────────────────────────
// Sol 2 sekme | Ortada Logo | Sağ 2 sekme
class _TravelSafeNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _TravelSafeNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: const Color(0xFF13132A),
        border: Border(
            top: BorderSide(color: const Color(0xFF7B3FA0).withOpacity(0.18))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 24,
              offset: const Offset(0, -6))
        ],
      ),
      child: Row(
        children: [
          // Sol 2
          _NavTab(
              icon: Icons.map_rounded,
              label: 'Harita',
              index: 0,
              current: currentIndex,
              onTap: onTap),
          _NavTab(
              icon: Icons.route_rounded,
              label: 'Rota',
              index: 1,
              current: currentIndex,
              onTap: onTap),

          // ── LOGO (ortada, tıklanabilir) ──
          Expanded(
            child: GestureDetector(
              onTap: () => onTap(0),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TravelSafeLogoVector(size: 30, withText: false),
                  SizedBox(height: 3),
                  Text(
                    'TravelSafe',
                    style: TextStyle(
                        fontSize: 8,
                        color: Colors.white30,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
          ),

          // Sağ 2
          _NavTab(
              icon: Icons.psychology_rounded,
              label: 'Tahmin',
              index: 2,
              current: currentIndex,
              onTap: onTap),
          _NavTab(
              icon: Icons.person_rounded,
              label: 'Profil',
              index: 3,
              current: currentIndex,
              onTap: onTap),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, current;
  final ValueChanged<int> onTap;
  const _NavTab(
      {required this.icon,
      required this.label,
      required this.index,
      required this.current,
      required this.onTap});

  bool get _sel => index == current;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _sel
                    ? const Color(0xFF7B3FA0).withOpacity(0.2)
                    : Colors.transparent,
              ),
              child: Icon(icon,
                  size: _sel ? 22 : 20,
                  color: _sel ? const Color(0xFFBB86FC) : Colors.white24),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: _sel ? FontWeight.w700 : FontWeight.normal,
                color: _sel ? const Color(0xFFBB86FC) : Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── LOGO WIDGET (logo_widget.dart'a taşı) ─────────────────────
class TravelSafeLogoVector extends StatelessWidget {
  final double size;
  final bool withText;
  const TravelSafeLogoVector({super.key, this.size = 40, this.withText = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: _CompassPainter())),
        if (withText) ...[
          const SizedBox(width: 8),
          RichText(
              text: TextSpan(children: [
            TextSpan(
                text: 'Travel',
                style: TextStyle(
                    color: const Color(0xFF7B3FA0),
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w800)),
            TextSpan(
                text: 'Safe',
                style: TextStyle(
                    color: const Color(0xFFE8631A),
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w800)),
          ])),
        ],
      ],
    );
  }
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    canvas.drawCircle(
        Offset(cx, cy),
        r * 0.9,
        Paint()
          ..color = const Color(0xFF7B3FA0).withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.08);
    _a(canvas, cx, cy, cx, cy - r * 0.82, cx - r * 0.2, cy - r * 0.08,
        cx + r * 0.2, cy - r * 0.08, const Color(0xFF7B3FA0));
    _a(canvas, cx, cy, cx, cy + r * 0.82, cx + r * 0.2, cy + r * 0.08,
        cx - r * 0.2, cy + r * 0.08, const Color(0xFF9B59C0));
    _a(canvas, cx, cy, cx + r * 0.82, cy, cx + r * 0.08, cy - r * 0.2,
        cx + r * 0.08, cy + r * 0.2, const Color(0xFFE8631A));
    _a(canvas, cx, cy, cx - r * 0.82, cy, cx - r * 0.08, cy + r * 0.2,
        cx - r * 0.08, cy - r * 0.2, const Color(0xFFFF8C42));
    canvas.drawCircle(Offset(cx, cy), r * 0.13, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(cx, cy),
        r * 0.13,
        Paint()
          ..color = const Color(0xFF7B3FA0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.04);
    canvas.drawCircle(
        Offset(cx, cy), r * 0.05, Paint()..color = const Color(0xFFE8631A));
  }

  void _a(Canvas c, double cx, double cy, double tx, double ty, double lx,
      double ly, double rx, double ry, Color col) {
    c.drawPath(
        Path()
          ..moveTo(tx, ty)
          ..lineTo(lx, ly)
          ..lineTo(cx, cy)
          ..lineTo(rx, ry)
          ..close(),
        Paint()..color = col);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── PLACEHOLDER ───────────────────────────────────────────────
class _PlaceholderPage extends StatelessWidget {
  final String title, file;
  final IconData icon;
  const _PlaceholderPage(
      {required this.title, required this.icon, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TravelSafeLogoVector(size: 72, withText: true),
            const SizedBox(height: 32),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [Color(0xFF7B3FA0), Color(0xFFE8631A)]),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(file,
                style: const TextStyle(color: Colors.white30, fontSize: 12)),
            const SizedBox(height: 4),
            const Text('import edince placeholder\'ı kaldır',
                style: TextStyle(color: Colors.white10, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
