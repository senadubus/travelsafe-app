// ============================================================
// SAYFA 3: OLASI SUÇ TAHMİNİ — AI Destekli Isı Haritası
// Google Maps + Tahmin Heatmap + Zaman / Bölge Filtresi
// ============================================================
// TODO: AI modelinden tahmin verilerini çek
// TODO: Saat dilimine göre heatmap'i güncelle
// TODO: Seçilen noktanın risk skorunu hesapla
// TODO: Tahmin güven aralığını göster
// ============================================================

import 'package:flutter/material.dart';

// --------------- VERİ MODELLERİ ---------------
class PredictionFilter {
  final TimeOfDay timeOfDay; // TODO: saat dilimi
  final String dayType; // "Hafta içi" / "Hafta sonu"
  final String season; // "İlkbahar" vb.

  PredictionFilter({
    required this.timeOfDay,
    required this.dayType,
    required this.season,
  });
}

class HotspotInfo {
  final String name; // TODO: backend'den / reverse geocoding
  final double riskScore; // 0-100
  final String crimeType;
  final String confidence; // "Yüksek Güven" vb.

  const HotspotInfo({
    required this.name,
    required this.riskScore,
    required this.crimeType,
    required this.confidence,
  });
}

// --------------- SAYFA ---------------
class CrimePredictionPage extends StatefulWidget {
  const CrimePredictionPage({super.key});

  @override
  State<CrimePredictionPage> createState() => _CrimePredictionPageState();
}

class _CrimePredictionPageState extends State<CrimePredictionPage>
    with TickerProviderStateMixin {
  // Filtre state
  double _timeSlider = 14; // 0-23 saat
  String _dayType = 'Hafta içi';
  String _selectedSeason = 'İlkbahar';
  bool _showPanel = true;
  bool _isLoading = false;

  // Seçili nokta
  HotspotInfo? _selectedHotspot;

  late AnimationController _panelAnim;
  late AnimationController _hotspotAnim;
  late AnimationController _chipAnim;

  final List<String> _dayTypes = ['Hafta içi', 'Hafta sonu'];
  final List<String> _seasons = ['İlkbahar', 'Yaz', 'Sonbahar', 'Kış'];

  // TODO: backend'den gelen tahmin noktaları
  final List<HotspotInfo> _hotspots = const [
    HotspotInfo(
        name: 'Merkez Kavşağı',
        riskScore: 87,
        crimeType: 'Hırsızlık',
        confidence: 'Yüksek Güven'),
    HotspotInfo(
        name: 'Pazar Alanı',
        riskScore: 74,
        crimeType: 'Dolandırıcılık',
        confidence: 'Orta Güven'),
    HotspotInfo(
        name: 'Otobüs Terminali',
        riskScore: 91,
        crimeType: 'Hırsızlık',
        confidence: 'Yüksek Güven'),
  ];

  @override
  void initState() {
    super.initState();
    _panelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _hotspotAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _chipAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // TODO: İlk yüklemede tahmin çek
    _runPrediction();
  }

  @override
  void dispose() {
    _panelAnim.dispose();
    _hotspotAnim.dispose();
    _chipAnim.dispose();
    super.dispose();
  }

  Future<void> _runPrediction() async {
    setState(() => _isLoading = true);

    // TODO: AI modelinden tahmin çek
    // final prediction = await predictionService.predict(
    //   hour: _timeSlider.toInt(),
    //   dayType: _dayType,
    //   season: _selectedSeason,
    // );
    // heatmapController.setData(prediction.heatmapPoints);

    await Future.delayed(const Duration(milliseconds: 1200)); // placeholder
    setState(() => _isLoading = false);
  }

  String get _formattedTime {
    final h = _timeSlider.toInt();
    return '${h.toString().padLeft(2, '0')}:00';
  }

  String get _timeLabel {
    final h = _timeSlider.toInt();
    if (h < 6) return 'Gece';
    if (h < 12) return 'Sabah';
    if (h < 17) return 'Öğleden Sonra';
    if (h < 21) return 'Akşam';
    return 'Gece';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ── 1. TAHMİN HARİTASI ─────────────────────────────
          Positioned.fill(
            child: _PredictionMapPlaceholder(
              timeValue: _timeSlider,
              hotspots: _hotspots,
              onHotspotTap: (h) {
                setState(() => _selectedHotspot = h);
                _hotspotAnim.forward(from: 0);
              },
            ),
          ),

          // ── 2. TOP BAR ──────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _PredictionTopBar(
                  timeLabel: _timeLabel,
                  formattedTime: _formattedTime,
                  isLoading: _isLoading,
                  onTogglePanel: () {
                    setState(() => _showPanel = !_showPanel);
                    if (_showPanel)
                      _panelAnim.forward();
                    else
                      _panelAnim.reverse();
                  },
                  panelOpen: _showPanel,
                ),

                // ── 3. FİLTRE PANELİ ────────────────────────
                SizeTransition(
                  sizeFactor: CurvedAnimation(
                    parent: _panelAnim,
                    curve: Curves.easeOutCubic,
                  ),
                  child: _PredictionFilterPanel(
                    timeSlider: _timeSlider,
                    dayType: _dayType,
                    selectedSeason: _selectedSeason,
                    dayTypes: _dayTypes,
                    seasons: _seasons,
                    timeLabel: _timeLabel,
                    formattedTime: _formattedTime,
                    onTimeChanged: (v) => setState(() => _timeSlider = v),
                    onDayTypeChanged: (v) => setState(() => _dayType = v),
                    onSeasonChanged: (v) => setState(() => _selectedSeason = v),
                    onApply: _runPrediction,
                  ),
                ),
              ],
            ),
          ),

          // ── 4. HOT SPOT BİLGİ KARTI ─────────────────────────
          if (_selectedHotspot != null)
            Positioned(
              bottom: 110,
              left: 16,
              right: 16,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _hotspotAnim,
                  curve: Curves.easeOutBack,
                )),
                child: FadeTransition(
                  opacity: _hotspotAnim,
                  child: _HotspotCard(
                    info: _selectedHotspot!,
                    onClose: () => setState(() => _selectedHotspot = null),
                  ),
                ),
              ),
            ),

          // ── 5. LEGEND + MODEL BİLGİSİ ───────────────────────
          Positioned(
            right: 16,
            bottom: 110,
            child: _selectedHotspot == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _ModelConfidenceChip(),
                      const SizedBox(height: 8),
                      _HeatmapLegend(),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // ── 6. ALT TOP NOKTALAR ──────────────────────────────
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _TopHotspotsBar(
              hotspots: _hotspots,
              onTap: (h) {
                setState(() => _selectedHotspot = h);
                _hotspotAnim.forward(from: 0);
              },
            ),
          ),

          // ── 7. LOADING ──────────────────────────────────────
          if (_isLoading)
            Positioned(
              top: 160,
              left: 0,
              right: 0,
              child: Center(child: _PredictionLoadingPill()),
            ),
        ],
      ),
    );
  }
}

// ── TOP BAR ──────────────────────────────────────────────────
class _PredictionTopBar extends StatelessWidget {
  final String timeLabel;
  final String formattedTime;
  final bool isLoading;
  final VoidCallback onTogglePanel;
  final bool panelOpen;

  const _PredictionTopBar({
    required this.timeLabel,
    required this.formattedTime,
    required this.isLoading,
    required this.onTogglePanel,
    required this.panelOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 24)
        ],
      ),
      child: Row(
        children: [
          // AI ikonu
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF9C27B0), Color(0xFF00BCD4)],
              ),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF00BCD4).withOpacity(0.3),
                    blurRadius: 10)
              ],
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suç Tahmin Modeli',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
                ),
                Row(
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: Color(0xFF00BCD4)),
                      )
                    else
                      const Icon(Icons.circle,
                          color: Color(0xFF00BCD4), size: 8),
                    const SizedBox(width: 5),
                    Text(
                      isLoading
                          ? 'Tahmin hesaplanıyor...'
                          : '$timeLabel  •  $formattedTime',
                      style: TextStyle(
                          color: const Color(0xFF00BCD4).withOpacity(0.8),
                          fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTogglePanel,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: panelOpen
                    ? const LinearGradient(
                        colors: [AppColors.purple, Color(0xFF00BCD4)])
                    : null,
                color: panelOpen ? null : AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: panelOpen
                      ? Colors.transparent
                      : const Color(0xFF00BCD4).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    panelOpen ? Icons.close_rounded : Icons.access_time_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    panelOpen ? 'Kapat' : 'Zaman',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── FİLTRE PANELİ ────────────────────────────────────────────
class _PredictionFilterPanel extends StatelessWidget {
  final double timeSlider;
  final String dayType;
  final String selectedSeason;
  final List<String> dayTypes;
  final List<String> seasons;
  final String timeLabel;
  final String formattedTime;
  final ValueChanged<double> onTimeChanged;
  final ValueChanged<String> onDayTypeChanged;
  final ValueChanged<String> onSeasonChanged;
  final VoidCallback onApply;

  const _PredictionFilterPanel({
    required this.timeSlider,
    required this.dayType,
    required this.selectedSeason,
    required this.dayTypes,
    required this.seasons,
    required this.timeLabel,
    required this.formattedTime,
    required this.onTimeChanged,
    required this.onDayTypeChanged,
    required this.onSeasonChanged,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 20)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Saat Slider ──
          Row(
            children: [
              const _FilterLabel('Saat Dilimi'),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF00BCD4).withOpacity(0.4)),
                ),
                child: Text(
                  '$formattedTime  •  $timeLabel',
                  style: const TextStyle(
                      color: Color(0xFF00BCD4),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00BCD4),
              inactiveTrackColor: AppColors.surface2,
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF00BCD4).withOpacity(0.15),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: timeSlider,
              min: 0,
              max: 23,
              divisions: 23,
              onChanged: onTimeChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              '00:00',
              '06:00',
              '12:00',
              '18:00',
              '23:00',
            ]
                .map((t) => Text(t,
                    style: const TextStyle(color: Colors.white24, fontSize: 9)))
                .toList(),
          ),

          const SizedBox(height: 14),

          // ── Gün Tipi ──
          const _FilterLabel('Gün Tipi'),
          const SizedBox(height: 8),
          Row(
            children: dayTypes.map((dt) {
              final sel = dt == dayType;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onDayTypeChanged(dt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: sel
                            ? const LinearGradient(
                                colors: [AppColors.purple, Color(0xFF00BCD4)])
                            : null,
                        color: sel ? null : AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel ? Colors.transparent : Colors.white10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        dt,
                        style: TextStyle(
                          color: sel ? Colors.white : Colors.white38,
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // ── Mevsim ──
          const _FilterLabel('Mevsim'),
          const SizedBox(height: 8),
          Row(
            children: seasons.map((s) {
              final sel = s == selectedSeason;
              final icons = {
                'İlkbahar': '🌸',
                'Yaz': '☀️',
                'Sonbahar': '🍂',
                'Kış': '❄️'
              };
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onSeasonChanged(s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF00BCD4).withOpacity(0.2)
                            : AppColors.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? const Color(0xFF00BCD4) : Colors.white10,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(icons[s]!, style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 3),
                          Text(
                            s,
                            style: TextStyle(
                              color: sel
                                  ? const Color(0xFF00BCD4)
                                  : Colors.white38,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: GestureDetector(
              onTap: onApply,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.purple, Color(0xFF00BCD4)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.purple.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.psychology_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Tahmini Güncelle',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── HOT SPOT BİLGİ KARTI ─────────────────────────────────────
class _HotspotCard extends StatelessWidget {
  final HotspotInfo info;
  final VoidCallback onClose;

  const _HotspotCard({required this.info, required this.onClose});

  Color get _riskColor {
    if (info.riskScore >= 80) return AppColors.red;
    if (info.riskScore >= 60) return AppColors.orange;
    return AppColors.green;
  }

  String get _riskLabel {
    if (info.riskScore >= 80) return 'Yüksek Risk';
    if (info.riskScore >= 60) return 'Orta Risk';
    return 'Düşük Risk';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _riskColor.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
              color: _riskColor.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _riskColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.location_on_rounded,
                    color: _riskColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                    Text(info.crimeType,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded,
                    color: Colors.white38, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Risk Skoru',
                        style: TextStyle(color: Colors.white38, fontSize: 10)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${info.riskScore.toInt()}',
                          style: TextStyle(
                            color: _riskColor,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Text(' / 100',
                            style: TextStyle(
                                color: _riskColor.withOpacity(0.5),
                                fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Progress bar
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: info.riskScore / 100,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _riskColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _riskColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _riskColor.withOpacity(0.4)),
                    ),
                    child: Text(_riskLabel,
                        style: TextStyle(
                            color: _riskColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BCD4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF00BCD4).withOpacity(0.3)),
                    ),
                    child: Text(info.confidence,
                        style: const TextStyle(
                            color: Color(0xFF00BCD4), fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── EN RİSKLİ NOKTALAR BAR ───────────────────────────────────
class _TopHotspotsBar extends StatelessWidget {
  final List<HotspotInfo> hotspots;
  final ValueChanged<HotspotInfo> onTap;

  const _TopHotspotsBar({required this.hotspots, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'En Riskli Noktalar',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: hotspots.map((h) {
              final color =
                  h.riskScore >= 80 ? AppColors.red : AppColors.orange;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(h),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${h.riskScore.toInt()}',
                          style: TextStyle(
                              color: color,
                              fontSize: 18,
                              fontWeight: FontWeight.w900),
                        ),
                        Text(
                          h.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── MODEL GÜVENİ ─────────────────────────────────────────────
class _ModelConfidenceChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.psychology_rounded, color: Color(0xFF00BCD4), size: 14),
          SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Güven',
                  style: TextStyle(color: Colors.white38, fontSize: 9)),
              Text('% 89',
                  style: TextStyle(
                      color: Color(0xFF00BCD4),
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── LEGEND ───────────────────────────────────────────────────
class _HeatmapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Text('Tahmin Yoğunluğu',
              style: TextStyle(color: Colors.white38, fontSize: 9)),
          const SizedBox(height: 6),
          Container(
            width: 90,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4CAF50),
                  Color(0xFFFF9800),
                  Color(0xFFFF5722)
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Az', style: TextStyle(color: Colors.white24, fontSize: 8)),
              Text('Fazla',
                  style: TextStyle(color: Colors.white24, fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── HARİTA PLACEHOLDER ───────────────────────────────────────
class _PredictionMapPlaceholder extends StatelessWidget {
  final double timeValue;
  final List<HotspotInfo> hotspots;
  final ValueChanged<HotspotInfo> onHotspotTap;

  const _PredictionMapPlaceholder({
    required this.timeValue,
    required this.hotspots,
    required this.onHotspotTap,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: GoogleMap widget + HeatmapLayer buraya gelecek
    // Gece-gündüz durumuna göre harita stili değiştirilebilir:
    // timeValue < 6 || timeValue >= 20 → dark map style
    final isNight = timeValue < 6 || timeValue >= 20;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isNight
              ? [const Color(0xFF0A0F1A), const Color(0xFF060D18)]
              : [const Color(0xFF1A2332), const Color(0xFF0D1B2A)],
        ),
      ),
      child: CustomPaint(
        painter: _PredictionMapPainter(
          timeValue: timeValue,
          hotspotPositions: [
            Offset(0.35, 0.42),
            Offset(0.62, 0.55),
            Offset(0.48, 0.68),
          ],
          hotspotScores: hotspots.map((h) => h.riskScore).toList(),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _PredictionMapPainter extends CustomPainter {
  final double timeValue;
  final List<Offset> hotspotPositions;
  final List<double> hotspotScores;

  _PredictionMapPainter({
    required this.timeValue,
    required this.hotspotPositions,
    required this.hotspotScores,
  });

  @override
  void paint(Canvas canvas, Size size) {
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

    // Heatmap noktaları
    for (int i = 0; i < hotspotPositions.length; i++) {
      final pos = Offset(
        size.width * hotspotPositions[i].dx,
        size.height * hotspotPositions[i].dy,
      );
      final score = i < hotspotScores.length ? hotspotScores[i] : 70.0;
      final intensity = score / 100;

      final color = Color.lerp(
        const Color(0xFF4CAF50),
        const Color(0xFFFF5722),
        intensity,
      )!;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(0.55), color.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: pos, radius: 90));

      canvas.drawCircle(pos, 90, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PredictionMapPainter old) =>
      old.timeValue != timeValue;
}

// ── LOADING ──────────────────────────────────────────────────
class _PredictionLoadingPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF00BCD4).withOpacity(0.2), blurRadius: 20)
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF00BCD4)),
          ),
          SizedBox(width: 10),
          Text('AI modeli çalışıyor...',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── KÜÇÜK YARDIMCILAR ─────────────────────────────────────────
class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

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
