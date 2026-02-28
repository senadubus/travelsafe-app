class HeatCluster {
  final double lat;
  final double lng;
  final int count;

  HeatCluster({
    required this.lat,
    required this.lng,
    required this.count,
  });

  factory HeatCluster.fromJson(Map<String, dynamic> j) => HeatCluster(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        count: (j['count'] as num).toInt(),
      );
}
