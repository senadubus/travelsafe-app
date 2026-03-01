import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiClient {
  final http.Client _client = http.Client();

  Future<Uint8List> getBytes(Uri uri) async {
    final res = await _client.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return res.bodyBytes;
  }
}

//import 'dart:convert';
//import 'package:http/http.dart' as http;

//class ApiClient {
//  final http.Client _client = http.Client();
//
//  Future<dynamic> getJson(Uri uri) async {
//    final res = await _client.get(uri);
//    if (res.statusCode < 200 || res.statusCode >= 300) {
//      throw Exception('HTTP ${res.statusCode}: ${res.body}');
//    }
//    return jsonDecode(res.body);
//  }
//}
