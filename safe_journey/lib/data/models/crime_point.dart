class CrimePoint {
  final String crime;
  final double lat;
  final double lng;
  final int? intensity;

  CrimePoint({
    required this.crime,
    required this.lat,
    required this.lng,
    this.intensity,
  });

  factory CrimePoint.fromJson(Map<String, dynamic> j) => CrimePoint(
        crime: (j['crime'] ?? 'UNKNOWN').toString(),
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        intensity:
            j['intensity'] == null ? null : (j['intensity'] as num).toInt(),
      );
}
