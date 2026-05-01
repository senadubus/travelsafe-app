import 'package:flutter/material.dart';

import 'package:safe_journey/data/models/crime_point.dart';

const _kPrimary = Color(0xFF6B4FA0);
const _kOrange = Color(0xFFE8761A);

// ── Intensity helpers ────────────────────────────────────────────────────────

Color intensityColor(int? intensity) {
  if (intensity == null || intensity <= 1) return Colors.green[600]!;
  if (intensity <= 3) return Colors.orange[700]!;
  return Colors.red[600]!;
}

String intensityLabel(int? intensity) {
  if (intensity == null || intensity <= 1) return 'Low';
  if (intensity <= 3) return 'Medium';
  return 'High';
}

// ── CrimeListCard (CrimePointsPage'deki _CrimeCard) ─────────────────────────

class CrimeListCard extends StatelessWidget {
  const CrimeListCard({super.key, required this.point});
  final CrimePoint point;

  @override
  Widget build(BuildContext context) {
    final color = intensityColor(point.intensity);
    final level = intensityLabel(point.intensity);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_crimeIcon(point.crime), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _toTitleCase(point.crime),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${point.lat.toStringAsFixed(4)}, '
                    '${point.lng.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                level,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _crimeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('theft') ||
        t.contains('burglary') ||
        t.contains('robbery')) {
      return Icons.money_off_rounded;
    }
    if (t.contains('assault') || t.contains('battery')) {
      return Icons.personal_injury_outlined;
    }
    if (t.contains('narcotics')) return Icons.medication_outlined;
    if (t.contains('homicide')) return Icons.gpp_bad_outlined;
    return Icons.report_outlined;
  }

  String _toTitleCase(String s) =>
      s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ── CrimeDetailCard (HeatmapPage marker popup) ───────────────────────────────

class CrimeDetailCard extends StatelessWidget {
  const CrimeDetailCard({
    super.key,
    required this.crime,
    required this.onClose,
  });

  final CrimePoint crime;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final date = crime.crimeDate != null
        ? '${crime.crimeDate!.day.toString().padLeft(2, '0')}/'
            '${crime.crimeDate!.month.toString().padLeft(2, '0')}/'
            '${crime.crimeDate!.year}'
        : 'Unknown date';

    final time = crime.crimeDate != null
        ? '${crime.crimeDate!.hour.toString().padLeft(2, '0')}:'
            '${crime.crimeDate!.minute.toString().padLeft(2, '0')}'
        : '--:--';

    final description =
        (crime.description != null && crime.description!.trim().isNotEmpty)
            ? crime.description!.trim()
            : 'No additional description available.';

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _kOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: _kOrange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          crime.crime,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F1F1F),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Incident details',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 18, color: Colors.black54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DetailPill(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: date,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DetailPill(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value: time,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE9E9EF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Color(0xFF2D2D2D),
                      ),
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
}

// ── DetailPill ────────────────────────────────────────────────────────────────

class DetailPill extends StatelessWidget {
  const DetailPill({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9E9EF)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _kPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
