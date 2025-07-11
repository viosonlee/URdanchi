import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/danchi.dart';

class ApiService {
  static const String _baseUrl = 'https://chintai.r6.ur-net.go.jp/chintai/api';

  // JSONのキーをダブルクォートで囲むためのヘルパー関数
  String _fixJson(String jsonString) {
    // キーをダブルクォートで囲む (例: id: -> "id":)
    String fixed = jsonString.replaceAllMapped(RegExp(r'([{,])\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:'), (match) {
      return '${match[1]}"${match[2]}":';
    });
    // JavaScriptのシングルクォートをダブルクォートに変換
    return fixed.replaceAll("'", '"');
  }

  Future<List<DanchiMarker>> getMapMarkers(double neLat, double neLng, double swLat, double swLng) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/bukken/search/map_marker/'),
      body: {
        'rent_low': '',
        'rent_high': '',
        'floorspace_low': '',
        'floorspace_high': '',
        'ne_lat': neLat.toString(),
        'ne_lng': neLng.toString(),
        'sw_lat': swLat.toString(),
        'sw_lng': swLng.toString(),
        'small': 'false',
      },
    );

    if (response.statusCode == 200) {
      final fixedJson = _fixJson(response.body);
      final List<dynamic> data = json.decode(fixedJson);
      return data.map((json) => DanchiMarker.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load map markers');
    }
  }

  Future<DanchiInfo> getDanchiInfo(String id) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/bukken/search/map_window/'),
      body: {
        'rent_low': '',
        'rent_high': '',
        'floorspace_low': '',
        'floorspace_high': '',
        'id': id,
      },
    );

    if (response.statusCode == 200) {
      final fixedJson = _fixJson(response.body);
      return DanchiInfo.fromJson(json.decode(fixedJson));
    } else {
      throw Exception('Failed to load danchi info');
    }
  }

  Future<List<Room>> getRoomList(String id, {String? lastId}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/room/list/'),
      body: {
        'rent_low': '',
        'rent_high': '',
        'floorspace_low': '',
        'floorspace_high': '',
        'mode': 'add',
        'id': id,
        'last_id': lastId ?? '000000000',
      },
    );

    if (response.statusCode == 200) {
      final fixedJson = _fixJson(response.body);
      final List<dynamic> data = json.decode(fixedJson);
      return data.map((json) => Room.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load room list');
    }
  }
}