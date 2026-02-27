import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final http.Client _client;
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<dynamic> getJson(Uri uri) async {
    final res = await _client.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body);
  }
}
