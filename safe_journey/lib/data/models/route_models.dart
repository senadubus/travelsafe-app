class UIRouteResponse {
  final String message;
  final int? startNode;
  final int? endNode;
  final List<UIRouteOption> routes;
  final String mode;

  UIRouteResponse({
    required this.message,
    required this.startNode,
    required this.endNode,
    required this.routes,
    required this.mode,
  });

  factory UIRouteResponse.fromJson(Map<String, dynamic> json) {
    final rawRoutes = json['routes'];

    return UIRouteResponse(
      message: json['message']?.toString() ?? '',
      startNode: (json['start_node'] as num?)?.toInt(),
      endNode: (json['end_node'] as num?)?.toInt(),
      routes: rawRoutes is List
          ? rawRoutes
              .where((e) => e is Map)
              .map(
                (e) => UIRouteOption.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : [],
      mode: json['mode']?.toString() ?? 'car',
    );
  }
}

class UIRouteOption {
  final int routeId;
  final String routeLabel;
  final double totalLengthM;
  final double totalRisk;
  final double totalCost;
  final String riskLevel;
  final String colorHex;
  final List<int> segments;
  final List<List<double>> geometry;

  UIRouteOption({
    required this.routeId,
    required this.routeLabel,
    required this.totalLengthM,
    required this.totalRisk,
    required this.totalCost,
    required this.riskLevel,
    required this.colorHex,
    required this.segments,
    required this.geometry,
  });

  factory UIRouteOption.fromJson(Map<String, dynamic> json) {
    final rawSegments = json['segments'];
    final rawGeometry = json['geometry'];

    return UIRouteOption(
      routeId: (json['route_id'] as num?)?.toInt() ?? 0,
      routeLabel: json['route_label']?.toString() ?? 'Rota',
      totalLengthM: (json['total_length_m'] as num?)?.toDouble() ?? 0.0,
      totalRisk: (json['total_risk'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0.0,
      riskLevel: json['risk_level']?.toString() ?? 'Bilinmiyor',
      colorHex: json['color']?.toString() ?? '#9E9E9E',
      segments: rawSegments is List
          ? rawSegments.whereType<num>().map((e) => e.toInt()).toList()
          : [],
      geometry: rawGeometry is List
          ? rawGeometry
              .where((p) => p is List && p.length >= 2)
              .map(
                (p) => [
                  (p[0] as num).toDouble(),
                  (p[1] as num).toDouble(),
                ],
              )
              .toList()
          : [],
    );
  }
}
