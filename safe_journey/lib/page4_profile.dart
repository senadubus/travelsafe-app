// ============================================================
// SAYFA 4: PROFİL SAYFASI
// ============================================================
// TODO: Kullanıcı bilgilerini auth servisinden çek
// TODO: İstatistikleri backend'den al
// TODO: Ayarları SharedPreferences'a kaydet
// ============================================================

import 'package:flutter/material.dart';
// import 'logo_widget.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  // TODO: Backend / auth'dan çek
  final String _name = 'Kullanıcı Adı';
  final String _email = 'kullanici@email.com';
  final String _memberSince = 'Ocak 2024';
  final int _totalRoutes = 0;
  final int _avgSafety = 0;
  final int _totalKm = 0;
  final int _savedPlaces = 0;

  bool _notifEnabled = true;
  bool _locationShare = false;
  bool _darkMode = true;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650))
      ..forward();
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildStatsBar()),
              SliverToBoxAdapter(child: _buildRecentActivity()),
              SliverToBoxAdapter(child: _buildSectionLabel('Tercihler')),
              SliverToBoxAdapter(child: _buildPreferences()),
              SliverToBoxAdapter(child: _buildSectionLabel('Hesap')),
              SliverToBoxAdapter(child: _buildAccountMenu()),
              SliverToBoxAdapter(child: _buildLogout()),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B69), Color(0xFF1A1A2E)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst satır: Logo + başlık + düzenle
              Row(
                children: [
                  const TravelSafeLogoVector(size: 34, withText: false),
                  const SizedBox(width: 10),
                  const Text(
                    'Profilim',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {/* TODO: düzenleme sayfası */},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.purpleL.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.purpleL.withOpacity(0.35)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.edit_rounded,
                              color: AppColors.purpleL, size: 13),
                          SizedBox(width: 5),
                          Text('Düzenle',
                              style: TextStyle(
                                  color: AppColors.purpleL,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Avatar + bilgiler
              Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 74, height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF7B3FA0), Color(0xFFE8631A)],
                          ),
                          border: Border.all(color: Colors.white12, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF7B3FA0).withOpacity(0.4),
                                blurRadius: 18,
                                offset: const Offset(0, 6))
                          ],
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: Colors.white, size: 36),
                        // TODO: Gerçek fotoğraf için:
                        // child: ClipOval(child: Image.network(photoUrl, fit: BoxFit.cover)),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {/* TODO: galeri / kamera aç */},
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFE8631A),
                              border: Border.all(color: AppColors.bg, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(_email,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                color: Colors.white24, size: 11),
                            const SizedBox(width: 4),
                            Text('Üye: $_memberSince',
                                style: const TextStyle(
                                    color: Colors.white24, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Rozet
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.green.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.green.withOpacity(0.15)),
                      child: const Icon(Icons.verified_rounded,
                          color: AppColors.green, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Güvenli Yolcu Rozeti',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          Text('Tüm rotalar güvenle tamamlandı',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(
                      _avgSafety == 0 ? '—' : '$_avgSafety',
                      style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 24,
                          fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.04)),
          top: BorderSide(color: Colors.white.withOpacity(0.04)),
        ),
      ),
      child: Row(
        children: [
          _StatCell(
              value: '$_totalRoutes', label: 'Rota', color: AppColors.purpleL),
          Container(width: 1, height: 36, color: Colors.white10),
          _StatCell(
              value: _avgSafety == 0 ? '—' : '$_avgSafety',
              label: 'Ort. Güvenlik',
              color: AppColors.green),
          Container(width: 1, height: 36, color: Colors.white10),
          _StatCell(
              value: _totalKm == 0 ? '—' : '${_totalKm}km',
              label: 'Toplam',
              color: const Color(0xFFE8631A)),
          Container(width: 1, height: 36, color: Colors.white10),
          _StatCell(
              value: '$_savedPlaces',
              label: 'Kayıtlı',
              color: const Color(0xFF00BCD4)),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    // TODO: Backend'den son rotaları çek
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Son Rotalar',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const Spacer(),
              GestureDetector(
                onTap: () {/* TODO: Geçmiş sayfası */},
                child: const Text('Tümü →',
                    style: TextStyle(color: AppColors.purpleL, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // TODO: Placeholder — backend'den gelince liste ile doldur
          _ActivityRow(from: '—', to: '—', score: 0, time: '—'),
          const SizedBox(height: 8),
          _ActivityRow(from: '—', to: '—', score: 0, time: '—'),
        ],
      ),
    );
  }

  Widget _buildPreferences() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          _ToggleTile(
              icon: Icons.notifications_rounded,
              color: AppColors.purpleL,
              title: 'Güvenlik Bildirimleri',
              subtitle: 'Tehlikeli bölge ve kaza uyarıları',
              value: _notifEnabled,
              onChanged: (v) => setState(() => _notifEnabled = v)),
          const SizedBox(height: 8),
          _ToggleTile(
              icon: Icons.share_location_rounded,
              color: const Color(0xFFE8631A),
              title: 'Konum Paylaşımı',
              subtitle: 'Güvendiğin kişilerle paylaş',
              value: _locationShare,
              onChanged: (v) => setState(() => _locationShare = v)),
          const SizedBox(height: 8),
          _ToggleTile(
              icon: Icons.dark_mode_rounded,
              color: const Color(0xFF00BCD4),
              title: 'Karanlık Mod',
              subtitle: 'Gece teması aktif',
              value: _darkMode,
              onChanged: (v) => setState(() => _darkMode = v)),
        ],
      ),
    );
  }

  Widget _buildAccountMenu() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          _MenuTile(
              icon: Icons.people_alt_rounded,
              color: AppColors.green,
              title: 'Acil Kişiler',
              subtitle: 'Güvendiğin kişileri yönet',
              onTap: () {}),
          const SizedBox(height: 8),
          _MenuTile(
              icon: Icons.directions_car_rounded,
              color: const Color(0xFFE8631A),
              title: 'Araç Profilim',
              subtitle: 'Araç bilgilerini düzenle',
              onTap: () {}),
          const SizedBox(height: 8),
          _MenuTile(
              icon: Icons.history_rounded,
              color: AppColors.purpleL,
              title: 'Seyahat Geçmişi',
              subtitle: 'Tüm rotaları görüntüle',
              onTap: () {}),
          const SizedBox(height: 8),
          _MenuTile(
              icon: Icons.privacy_tip_rounded,
              color: const Color(0xFF00BCD4),
              title: 'Gizlilik',
              subtitle: 'Veri paylaşım ayarları',
              onTap: () {}),
          const SizedBox(height: 8),
          _MenuTile(
              icon: Icons.help_outline_rounded,
              color: Colors.white38,
              title: 'Yardım & Destek',
              subtitle: 'SSS ve iletişim',
              onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildLogout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: GestureDetector(
        onTap: () {/* TODO: auth çıkış */},
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.red.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: AppColors.red, size: 18),
              SizedBox(width: 8),
              Text('Çıkış Yap',
                  style: TextStyle(
                      color: AppColors.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: Colors.white30,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      ),
    );
  }
}

// ── BİLEŞENLER ───────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatCell(
      {required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white30, fontSize: 10)),
        ]),
      );
}

class _ActivityRow extends StatelessWidget {
  final String from, to, time;
  final int score;
  const _ActivityRow(
      {required this.from,
      required this.to,
      required this.score,
      required this.time});
  @override
  Widget build(BuildContext context) {
    final c = score >= 80
        ? AppColors.green
        : score >= 60
            ? const Color(0xFFFF9800)
            : score == 0
                ? Colors.white24
                : AppColors.red;
    return Row(
      children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: const Color(0xFF7B3FA0).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.route_rounded,
                color: AppColors.purpleL, size: 18)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$from  →  $to',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          Text(time,
              style: const TextStyle(color: Colors.white30, fontSize: 10)),
        ])),
        Text(score == 0 ? '—' : '$score',
            style:
                TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ])),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.purpleL,
              activeTrackColor: AppColors.purple.withOpacity(0.35),
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: Colors.white12),
        ]),
      );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  const _MenuTile(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                ])),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white12, size: 20),
          ]),
        ),
      );
}

// ── RENKLER ───────────────────────────────────────────────────
class AppColors {
  static const bg = Color(0xFF0F0F1E);
  static const surface = Color(0xFF1A1A2E);
  static const purple = Color(0xFF7B3FA0);
  static const purpleL = Color(0xFFBB86FC);
  static const orange = Color(0xFFE8631A);
  static const green = Color(0xFF4CAF50);
  static const red = Color(0xFFFF5722);
}

// ── LOGO (logo_widget.dart import edilene kadar burada) ───────
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
