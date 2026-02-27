// ============================================================
// SAYFA 2: ROTA BELİRLEME — En Güvenli 3 Rota
// Başlangıç / Bitiş + Google Maps + 3 Rota Kartı
// ============================================================
// TODO: Kullanıcıdan alınan konumları backend'e gönder
// TODO: Backend'den gelen 3 rotayı Polyline olarak haritada çiz
// TODO: Her rotanın güvenlik skorunu, süresini, mesafesini göster
// TODO: GoogleMap controller ile kamerayı rotaya fit et
// ============================================================

import 'package:flutter/material.dart';

// --------------- VERİ MODELLERİ ---------------
class RouteResult {
  final String label; // "En Güvenli", "Dengeli", "En Hızlı"
  final double safetyScore; // TODO: backend'den gelecek 0-100
  final int durationMin; // TODO: backend'den gelecek
  final double distanceKm; // TODO: backend'den gelecek
  final List<dynamic> polylinePoints; // TODO: LatLng listesi
  final Color color;

  const RouteResult({
    required this.label,
    required this.safetyScore,
    required this.durationMin,
    required this.distanceKm,
    required this.polylinePoints,
    required this.color,
  });
}

// --------------- SAYFA ---------------
class RoutePlannerPage extends StatefulWidget {
  const RoutePlannerPage({super.key});

  @override
  State<RoutePlannerPage> createState() => _RoutePlannerPageState();
}

class _RoutePlannerPageState extends State<RoutePlannerPage>
    with TickerProviderStateMixin {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  bool _showResults = false;
  bool _isSearching = false;
  int _selectedRoute = 0;

  late AnimationController _resultsAnim;
  late AnimationController _mapAnim;

  // TODO: Backend'den gelecek, şimdilik placeholder
  final List<RouteResult> _routes = const [
    RouteResult(
      label: 'En Güvenli',
      safetyScore: 94,
      durationMin: 48,
      distanceKm: 33.2,
      polylinePoints: [], // TODO: LatLng listesi
      color: Color(0xFF4CAF50),
    ),
    RouteResult(
      label: 'Dengeli',
      safetyScore: 81,
      durationMin: 38,
      distanceKm: 28.7,
      polylinePoints: [], // TODO: LatLng listesi
      color: Color(0xFFFF9800),
    ),
    RouteResult(
      label: 'En Hızlı',
      safetyScore: 67,
      durationMin: 29,
      distanceKm: 25.1,
      polylinePoints: [], // TODO: LatLng listesi
      color: Color(0xFFFF5722),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _resultsAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _mapAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _resultsAnim.dispose();
    _mapAnim.dispose();
    super.dispose();
  }

  Future<void> _findRoutes() async {
    if (_fromController.text.isEmpty || _toController.text.isEmpty) {
      _showSnack('Başlangıç ve bitiş noktasını girin');
      return;
    }
    setState(() => _isSearching = true);

    // TODO: Backend'e istek at
    // final results = await routeService.getSafeRoutes(
    //   from: _fromController.text,
    //   to: _toController.text,
    // );

    await Future.delayed(const Duration(seconds: 2)); // placeholder

    setState(() {
      _isSearching = false;
      _showResults = true;
    });
    _resultsAnim.forward();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.purple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ── 1. HARİTA ──────────────────────────────────────
          Positioned.fill(
            child: FadeTransition(
              opacity: _mapAnim,
              child: _RouteMapPlaceholder(
                showRoutes: _showResults,
                selectedIndex: _selectedRoute,
                routes: _routes,
              ),
            ),
          ),

          // ── 2. GİRİŞ ALANI (üst) ───────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: _InputCard(
                fromController: _fromController,
                toController: _toController,
                isSearching: _isSearching,
                onSearch: _findRoutes,
                onSwap: () {
                  final tmp = _fromController.text;
                  _fromController.text = _toController.text;
                  _toController.text = tmp;
                },
              ),
            ),
          ),

          // ── 3. SONUÇ KARTI (alt) ────────────────────────────
          if (_showResults)
            Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _resultsAnim,
                  curve: Curves.easeOutCubic,
                )),
                child: _RouteResultsSheet(
                  routes: _routes,
                  selectedIndex: _selectedRoute,
                  onSelect: (i) => setState(() => _selectedRoute = i),
                  onConfirm: () {
                    // TODO: seçilen rotayı başlat / navigasyona geç
                  },
                ),
              ),
            ),

          // ── 4. LOADING ──────────────────────────────────────
          if (_isSearching)
            Container(
              color: Colors.black38,
              child: Center(child: _SearchingIndicator()),
            ),
        ],
      ),
    );
  }
}

// ── GİRİŞ KARTI ──────────────────────────────────────────────
class _InputCard extends StatelessWidget {
  final TextEditingController fromController;
  final TextEditingController toController;
  final bool isSearching;
  final VoidCallback onSearch;
  final VoidCallback onSwap;

  const _InputCard({
    required this.fromController,
    required this.toController,
    required this.isSearching,
    required this.onSearch,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.purple.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 30,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [AppColors.purple, AppColors.orange]),
                ),
                child: const Icon(Icons.shield_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Güvenli Rota Bul',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Nereden
          _LocationField(
            controller: fromController,
            hint: 'Nereden?',
            icon: Icons.my_location_rounded,
            dotColor: AppColors.green,
          ),

          // Swap
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 18),
                Container(width: 2, height: 20, color: Colors.white12),
                const Spacer(),
                GestureDetector(
                  onTap: onSwap,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface2,
                      border:
                          Border.all(color: AppColors.purple.withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.swap_vert_rounded,
                        color: AppColors.purpleL, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Nereye
          _LocationField(
            controller: toController,
            hint: 'Nereye?',
            icon: Icons.location_on_rounded,
            dotColor: AppColors.orange,
          ),

          const SizedBox(height: 14),

          // Bul butonu
          SizedBox(
            width: double.infinity,
            height: 48,
            child: _GradientButton(
              label: isSearching ? 'Hesaplanıyor...' : 'En Güvenli 3 Rota Bul',
              icon: Icons.route_rounded,
              onTap: isSearching ? () {} : onSearch,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color dotColor;

  const _LocationField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dotColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: dotColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ROTA SONUÇLARI SAYFASI ────────────────────────────────────
class _RouteResultsSheet extends StatelessWidget {
  final List<RouteResult> routes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onConfirm;

  const _RouteResultsSheet({
    required this.routes,
    required this.selectedIndex,
    required this.onSelect,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.purple.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: AppColors.purple.withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, -10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              const Text(
                '3 Güvenli Rota Bulundu',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.green.withOpacity(0.4)),
                ),
                child: const Text(
                  '✓ Analiz tamamlandı',
                  style: TextStyle(color: AppColors.green, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Rota kartları
          ...routes.asMap().entries.map((e) {
            final i = e.key;
            final route = e.value;
            final isSelected = i == selectedIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? route.color.withOpacity(0.12)
                        : AppColors.surface2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? route.color.withOpacity(0.6)
                          : Colors.white10,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Renk göstergesi
                      Container(
                        width: 4,
                        height: 48,
                        decoration: BoxDecoration(
                          color: route.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Bilgiler
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  route.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                if (i == 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.purple,
                                          AppColors.orange
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Önerilen',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${route.durationMin} dk  •  ${route.distanceKm} km',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      // Güvenlik skoru
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${route.safetyScore.toInt()}',
                            style: TextStyle(
                              color: route.color,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          Text(
                            'güvenlik',
                            style: TextStyle(
                                color: route.color.withOpacity(0.7),
                                fontSize: 10),
                          ),
                        ],
                      ),

                      // Seçim işareti
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? route.color : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? route.color : Colors.white24,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 4),

          // Başlat butonu
          SizedBox(
            width: double.infinity,
            height: 50,
            child: _GradientButton(
              label: 'Navigasyonu Başlat',
              icon: Icons.navigation_rounded,
              onTap: onConfirm,
            ),
          ),
        ],
      ),
    );
  }
}

// ── ROTA HARİTA PLACEHOLDER ───────────────────────────────────
class _RouteMapPlaceholder extends StatelessWidget {
  final bool showRoutes;
  final int selectedIndex;
  final List<RouteResult> routes;

  const _RouteMapPlaceholder({
    required this.showRoutes,
    required this.selectedIndex,
    required this.routes,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: GoogleMap widget buraya gelecek
    // Polyline'lar routes[i].polylinePoints kullanılarak çizilecek
    // Seçilen rota (selectedIndex) daha kalın/parlak gösterilecek
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2332), Color(0xFF0D1B2A)],
        ),
      ),
      child: CustomPaint(
        painter: _RouteMapPainter(
          showRoutes: showRoutes,
          selectedIndex: selectedIndex,
          routeColors: routes.map((r) => r.color).toList(),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  final bool showRoutes;
  final int selectedIndex;
  final List<Color> routeColors;

  _RouteMapPainter({
    required this.showRoutes,
    required this.selectedIndex,
    required this.routeColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Harita arka planı
    final road = Paint()
      ..color = const Color(0xFF1E3040)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;

    for (double y = 0.2; y < 1; y += 0.2) {
      canvas.drawLine(Offset(0, size.height * y),
          Offset(size.width, size.height * y), road);
    }
    for (double x = 0.2; x < 1; x += 0.22) {
      canvas.drawLine(
          Offset(size.width * x, 0), Offset(size.width * x, size.height), road);
    }

    if (!showRoutes) return;

    // TODO: Gerçek polyline koordinatları ile değiştirilecek
    // Placeholder rota çizgileri
    final routePaths = [
      _buildPath1(size),
      _buildPath2(size),
      _buildPath3(size),
    ];

    for (int i = 0; i < routePaths.length; i++) {
      final isSelected = i == selectedIndex;
      final paint = Paint()
        ..color = routeColors[i].withOpacity(isSelected ? 0.95 : 0.3)
        ..strokeWidth = isSelected ? 5 : 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (isSelected) {
        final glowPaint = Paint()
          ..color = routeColors[i].withOpacity(0.25)
          ..strokeWidth = 14
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(routePaths[i], glowPaint);
      }
      canvas.drawPath(routePaths[i], paint);
    }

    // Başlangıç & bitiş noktaları
    _drawPin(
        canvas, Offset(size.width * 0.15, size.height * 0.25), AppColors.green);
    _drawPin(canvas, Offset(size.width * 0.82, size.height * 0.72),
        AppColors.orange);
  }

  Path _buildPath1(Size s) {
    return Path()
      ..moveTo(s.width * 0.15, s.height * 0.25)
      ..lineTo(s.width * 0.2, s.height * 0.25)
      ..lineTo(s.width * 0.2, s.height * 0.6)
      ..lineTo(s.width * 0.6, s.height * 0.6)
      ..lineTo(s.width * 0.6, s.height * 0.72)
      ..lineTo(s.width * 0.82, s.height * 0.72);
  }

  Path _buildPath2(Size s) {
    return Path()
      ..moveTo(s.width * 0.15, s.height * 0.25)
      ..lineTo(s.width * 0.42, s.height * 0.25)
      ..lineTo(s.width * 0.42, s.height * 0.4)
      ..lineTo(s.width * 0.6, s.height * 0.4)
      ..lineTo(s.width * 0.6, s.height * 0.72)
      ..lineTo(s.width * 0.82, s.height * 0.72);
  }

  Path _buildPath3(Size s) {
    return Path()
      ..moveTo(s.width * 0.15, s.height * 0.25)
      ..lineTo(s.width * 0.42, s.height * 0.25)
      ..lineTo(s.width * 0.42, s.height * 0.6)
      ..lineTo(s.width * 0.82, s.height * 0.6)
      ..lineTo(s.width * 0.82, s.height * 0.72);
  }

  void _drawPin(Canvas canvas, Offset center, Color color) {
    final fill = Paint()..color = color;
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 8, fill);
    canvas.drawCircle(center, 8, border);
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter old) =>
      old.showRoutes != showRoutes || old.selectedIndex != selectedIndex;
}

// ── SEARCHING ─────────────────────────────────────────────────
class _SearchingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.purple.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: AppColors.purple.withOpacity(0.3), blurRadius: 30)
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.purple, strokeWidth: 2.5),
          SizedBox(height: 14),
          Text(
            'Güvenli rotalar\nhesaplanıyor...',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// Renk sabitlerini tekrar tanımlıyoruz (her dosya bağımsız)
class AppColors {
  static const bg = Color(0xFF0F0F1E);
  static const surface = Color(0xFF1A1A2E);
  static const surface2 = Color(0xFF252538);
  static const purple = Color(0xFF9C27B0);
  static const purpleL = Color(0xFFBB86FC);
  static const orange = Color(0xFFFF7043);
  static const green = Color(0xFF4CAF50);
  static const red = Color(0xFFFF5722);
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GradientButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.purple, AppColors.orange]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: AppColors.purple.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
