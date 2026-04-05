class CrimePoint {
  final String crime;
  final String? description;
  final DateTime? crimeDate;
  final double lat;
  final double lng;
  final int? intensity;

  CrimePoint({
    required this.crime,
    required this.lat,
    required this.lng,
    this.description,
    this.crimeDate,
    this.intensity,
  });

  factory CrimePoint.fromJson(Map<String, dynamic> j) => CrimePoint(
        crime: (j['crime_type'] ?? j['crime'] ?? 'UNKNOWN').toString(),
        description: j['description']?.toString(),
        crimeDate: j['crime_date'] != null
            ? DateTime.tryParse(j['crime_date'].toString())
            : null,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        intensity:
            j['intensity'] == null ? null : (j['intensity'] as num).toInt(),
      );
}
