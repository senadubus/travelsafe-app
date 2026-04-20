import 'package:flutter/foundation.dart';
import 'package:safe_journey/core/constants.dart';

import '../../core/api_client.dart';
import '../models/route_models.dart';

class RouteService {
  final ApiClient apiClient;

  RouteService({required this.apiClient});

  static const String _baseUrl = '${Env.baseUrl}/api';
  // Gerçek cihazda bunu bilgisayar IP'n ile değiştir:
  // http://192.168.1.xxx:8000/api

  Future<RouteResponse> getAlternativeRoutes({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    double distanceWeight = 1.0,
    double riskWeight = 2.0,
    double penaltyFactor = 500.0,
  }) async {
    final uri = Uri.parse('$_baseUrl/routes/alternatives');

    final json = await apiClient.postJson(
      uri,
      body: {
        'start_lat': startLat,
        'start_lng': startLng,
        'end_lat': endLat,
        'end_lng': endLng,
        'distance_weight': distanceWeight,
        'risk_weight': riskWeight,
        'penalty_factor': penaltyFactor,
      },
    );

    if (json is! Map<String, dynamic>) {
      throw Exception('Beklenmeyen API cevabı');
    }

    return RouteResponse.fromJson(json);
  }

  Future<void> debugHealthCheck() async {
    debugPrint('RouteService hazır');
  }
}
