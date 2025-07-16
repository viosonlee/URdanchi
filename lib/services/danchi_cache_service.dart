import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../models/danchi.dart';

class DanchiCacheService {
  static final DanchiCacheService _instance = DanchiCacheService._internal();
  factory DanchiCacheService() => _instance;
  DanchiCacheService._internal();

  late Directory _cacheDir;
  bool _initialized = false;

  // Cache configuration
  static const Duration markerCacheExpiry = Duration(hours: 2); // Marker cache for 2 hours
  static const Duration roomCacheExpiry = Duration(hours: 6); // Room cache for 6 hours

  /// Initialize the cache service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/danchi_cache');
      
      if (!await _cacheDir.exists()) {
        await _cacheDir.create(recursive: true);
      }
      
      _initialized = true;
    } catch (e) {
      debugPrint('初始化团地缓存失败: $e');
    }
  }

  /// Cache map markers with bounds
  Future<void> cacheMapMarkers(
    double neLat, double neLng, double swLat, double swLng,
    List<DanchiMarker> markers,
  ) async {
    if (!_initialized) await initialize();
    
    try {
      final boundsKey = '${neLat}_${neLng}_${swLat}_$swLng';
      final file = File('${_cacheDir.path}/markers_$boundsKey.json');
      
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'bounds': {'neLat': neLat, 'neLng': neLng, 'swLat': swLat, 'swLng': swLng},
        'markers': markers.map((marker) => marker.toJson()).toList(),
      };
      
      await file.writeAsString(jsonEncode(cacheData));
    } catch (e) {
          debugPrint('缓存地图标记错误: $e');
    }
  }

  /// Get cached map markers
  Future<List<DanchiMarker>?> getCachedMapMarkers(
    double neLat, double neLng, double swLat, double swLng,
  ) async {
    if (!_initialized) await initialize();
    
    try {
      final boundsKey = '${neLat}_${neLng}_${swLat}_$swLng';
      final file = File('${_cacheDir.path}/markers_$boundsKey.json');
      
      if (!await file.exists()) return null;
      
      final content = await file.readAsString();
      final data = jsonDecode(content);
      
      final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
      if (DateTime.now().difference(timestamp) > markerCacheExpiry) {
        await file.delete();
        return null;
      }
      
      final markersJson = data['markers'] as List;
      return markersJson.map((json) => DanchiMarker.fromJson(json)).toList();
    } catch (e) {
      debugPrint('获取缓存地图标记错误: $e');
      return null;
    }
  }

  /// Cache danchi detailed info
  Future<void> cacheDanchiInfo(String danchiId, DanchiInfo info) async {
    if (!_initialized) await initialize();
    
    try {
      final file = File('${_cacheDir.path}/danchi_$danchiId.json');
      
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'info': info.toJson(),
      };
      
      await file.writeAsString(jsonEncode(cacheData));
    } catch (e) {
      debugPrint('缓存团地信息错误: $e');
    }
  }

  /// Get cached danchi info
  Future<DanchiInfo?> getCachedDanchiInfo(String danchiId) async {
    if (!_initialized) await initialize();
    
    try {
      final file = File('${_cacheDir.path}/danchi_$danchiId.json');
      
      if (!await file.exists()) return null;
      
      final content = await file.readAsString();
      final data = jsonDecode(content);
      
      final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
      if (DateTime.now().difference(timestamp) > markerCacheExpiry) {
        await file.delete();
        return null;
      }
      
      return DanchiInfo.fromJson(data['info']);
    } catch (e) {
      debugPrint('读取缓存团地信息错误: $e');
      return null;
    }
  }

  /// Cache room list for a danchi
  Future<void> cacheRoomList(String danchiId, List<Room> rooms) async {
    if (!_initialized) await initialize();
    
    try {
      final file = File('${_cacheDir.path}/rooms_$danchiId.json');
      
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'rooms': rooms.map((room) => room.toJson()).toList(),
      };
      
      await file.writeAsString(jsonEncode(cacheData));
    } catch (e) {
      debugPrint('缓存房间列表错误: $e');
    }
  }

  /// Get cached room list
  Future<List<Room>?> getCachedRoomList(String danchiId) async {
    if (!_initialized) await initialize();
    
    try {
      final file = File('${_cacheDir.path}/rooms_$danchiId.json');
      
      if (!await file.exists()) return null;
      
      final content = await file.readAsString();
      final data = jsonDecode(content);
      
      final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
      if (DateTime.now().difference(timestamp) > roomCacheExpiry) {
        await file.delete();
        return null;
      }
      
      final roomsJson = data['rooms'] as List;
      return roomsJson.map((json) => Room.fromJson(json)).toList();
    } catch (e) {
      debugPrint('获取缓存房间列表错误: $e');
      return null;
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    if (!_initialized) await initialize();
    
    try {
      if (await _cacheDir.exists()) {
        await _cacheDir.delete(recursive: true);
        await _cacheDir.create(recursive: true);
      }
    } catch (e) {
      debugPrint('清除缓存错误: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    if (!_initialized) await initialize();
    
    final stats = <String, dynamic>{};
    
    try {
      final files = await _cacheDir.list().toList();
      int totalFiles = 0;
      int totalSize = 0;
      int markerFiles = 0;
      int roomFiles = 0;
      int danchiFiles = 0;
      
      for (final file in files) {
        if (file is File) {
          totalFiles++;
          final stat = await file.stat();
          totalSize += stat.size;
          
          final fileName = file.uri.pathSegments.last;
          if (fileName.startsWith('markers_')) {
            markerFiles++;
          } else if (fileName.startsWith('rooms_')) {
            roomFiles++;
          } else if (fileName.startsWith('danchi_')) {
            danchiFiles++;
          }
        }
      }
      
      stats['totalFiles'] = totalFiles;
      stats['totalSizeMB'] = (totalSize / (1024 * 1024)).toStringAsFixed(2);
      stats['markerCacheFiles'] = markerFiles;
      stats['roomCacheFiles'] = roomFiles;
      stats['danchiInfoFiles'] = danchiFiles;
    } catch (e) {
      debugPrint('获取缓存统计错误: $e');
    }
    
    return stats;
  }
}