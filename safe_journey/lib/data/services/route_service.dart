import 'package:flutter/foundation.dart';
import 'package:safe_journey/core/constants.dart';

import '../../core/api_client.dart';
import '../models/route_models.dart';

class RouteService {
  final ApiClient apiClient;

  RouteService({required this.apiClient});

  static const String _baseUrl = '${Env.baseUrl}/api';

  Future<UIRouteResponse> sendUiRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required String mode,
  }) async {
    final uri = Uri.parse('$_baseUrl/uiroute');

    final responseJson = await apiClient.postJson(
      uri,
      body: {
        'start_lat': startLat,
        'start_lng': startLng,
        'end_lat': endLat,
        'end_lng': endLng,
        'mode': mode,
      },
    );

    debugPrint('UIROUTE RAW RESPONSE: $responseJson');

    if (responseJson == null) {
      return UIRouteResponse(
        message: 'Backend returned null response',
        startNode: null,
        endNode: null,
        routes: [],
        mode: '',
      );
    }

    if (responseJson is Map<String, dynamic>) {
      return UIRouteResponse.fromJson(responseJson);
    }

    if (responseJson is Map) {
      return UIRouteResponse.fromJson(
        Map<String, dynamic>.from(responseJson),
      );
    }

    return UIRouteResponse(
      message: 'Unexpected response type: ${responseJson.runtimeType}',
      startNode: null,
      endNode: null,
      routes: [],
      mode: '',
    );
  }

  Future<void> debugHealthCheck() async {
    debugPrint('RouteService ready');
  }
}
