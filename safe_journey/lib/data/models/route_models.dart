class UIRouteResponse {
  final String message;
  final int? startNode;
  final int? endNode;
  final List<UIRouteOption> routes;

  UIRouteResponse({
    required this.message,
    required this.startNode,
    required this.endNode,
    required this.routes,
  });

  factory UIRouteResponse.fromJson(Map<String, dynamic> json) {
    return UIRouteResponse(
      message: json['message'] as String? ?? '',
      startNode: (json['start_node'] as num?)?.toInt(),
      endNode: (json['end_node'] as num?)?.toInt(),
      routes: ((json['routes'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => UIRouteOption.fromJson(e))
          .toList(),
    );
  }
}

class UIRouteOption {
  final int routeId;
  final double totalLengthM;
  final List<int> segments;
  final List<List<double>> geometry;

  UIRouteOption({
    required this.routeId,
    required this.totalLengthM,
    required this.segments,
    required this.geometry,
  });

  factory UIRouteOption.fromJson(Map<String, dynamic> json) {
    return UIRouteOption(
      routeId: json['route_id'] as int? ?? 0,
      totalLengthM: (json['total_length_m'] as num?)?.toDouble() ?? 0.0,
      segments: ((json['segments'] as List?) ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      geometry: ((json['geometry'] as List?) ?? [])
          .map(
            (point) => ((point as List?) ?? [])
                .map((e) => (e as num).toDouble())
                .toList(),
          )
          .toList(),
    );
  }
}
