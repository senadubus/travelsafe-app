import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiClient {
  final http.Client _client = http.Client();

  Future<Uint8List> getBytes(Uri uri) async {
    final res = await _client.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Uint8List(0);
    }
    return res.bodyBytes;
  }

  Future<dynamic> getJson(Uri uri) async {
    final res = await _client.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<dynamic> postJson(
    Uri uri, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body ?? {}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    return jsonDecode(res.body);
  }

  void dispose() {
    _client.close();
  }
}
