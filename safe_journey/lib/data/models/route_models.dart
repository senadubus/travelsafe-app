class RouteOption {
  final String routeLabel;
  final List<int> pathNodes;
  final List<int> segmentIds;
  final double totalLengthM;
  final double totalRisk;
  final double totalCost;
  final List<List<double>> geometry;

  RouteOption({
    required this.routeLabel,
    required this.pathNodes,
    required this.segmentIds,
    required this.totalLengthM,
    required this.totalRisk,
    required this.totalCost,
    required this.geometry,
  });

  factory RouteOption.fromJson(Map<String, dynamic> json) {
    return RouteOption(
      routeLabel: json['route_label'] as String,
      pathNodes: List<int>.from(json['path_nodes'] as List),
      segmentIds: List<int>.from(json['segment_ids'] as List),
      totalLengthM: (json['total_length_m'] as num).toDouble(),
      totalRisk: (json['total_risk'] as num).toDouble(),
      totalCost: (json['total_cost'] as num).toDouble(),
      geometry: (json['geometry'] as List)
          .map(
            (point) => List<double>.from(
              (point as List).map((e) => (e as num).toDouble()),
            ),
          )
          .toList(),
    );
  }
}

class RouteResponse {
  final List<RouteOption> routes;

  RouteResponse({required this.routes});

  factory RouteResponse.fromJson(Map<String, dynamic> json) {
    return RouteResponse(
      routes: (json['routes'] as List)
          .map((e) => RouteOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
