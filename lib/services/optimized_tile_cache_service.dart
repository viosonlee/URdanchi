import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'connectivity_service.dart';

class CachedTile {
  final Uint8List tileData;
  final DateTime timestamp;

  CachedTile({required this.tileData, required this.timestamp});

  bool get isExpired {
    return DateTime.now().difference(timestamp) > OptimizedTileCacheService.tileCacheExpiry;
  }
}

class OptimizedTileCacheService {
  static final OptimizedTileCacheService _instance = OptimizedTileCacheService._internal();
  factory OptimizedTileCacheService() => _instance;
  OptimizedTileCacheService._internal();

  final Map<String, CachedTile> _memoryCache = {};
  final ConnectivityService _connectivityService = ConnectivityService();

  static const int maxMemoryCacheSize = 100;
  static const int maxDiskCacheSizeMB = 1024;
  static const Duration tileCacheExpiry = Duration(days: 90);

  late Directory _cacheDir;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/map_tiles_optimized');
      if (!await _cacheDir.exists()) {
        await _cacheDir.create(recursive: true);
      }
      await _enforceDiskCacheLimit();
      await _connectivityService.initialize();
      _initialized = true;
    } catch (e) {
      debugPrint('初始化优化缓存目录错误: $e');
    }
  }

  String _generateCacheKey(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }


  Future<CachedTile?> getTile(String url) async {
    if (!_initialized) await initialize();
    final cacheKey = _generateCacheKey(url);

    if (_memoryCache.containsKey(cacheKey)) {
      final tile = _memoryCache[cacheKey]!;
      _promoteInMemoryCache(cacheKey, tile);
      return tile;
    }

    final file = File('${_cacheDir.path}/$cacheKey');
    if (await file.exists()) {
      try {
        final tileData = await file.readAsBytes();
        final stat = await file.stat();
        final cachedTile = CachedTile(tileData: tileData, timestamp: stat.modified);
        _addToMemoryCache(cacheKey, cachedTile);
        return cachedTile;
      } catch (e) {
        debugPrint('从磁盘读取瓦片错误: $e');
      }
    }
    return null;
  }

  Future<Uint8List?> downloadAndCacheTile(String url, {Map<String, String>? headers}) async {
    final networkStatus = _connectivityService.currentStatus;
    
    switch (networkStatus) {
      case NetworkStatus.offline:
        return null;
      
      case NetworkStatus.metered:
        final cachedTile = await getTile(url);
        if (cachedTile != null) {
          return cachedTile.tileData;
        }
        break;
      
      case NetworkStatus.unmetered:
      case NetworkStatus.unknown:
        break;
    }

    try {
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        await cacheTile(url, response.bodyBytes);
        return response.bodyBytes;
      } else {
        debugPrint('下载瓦片失败: ${response.statusCode} for $url');
      }
    } catch (e) {
      debugPrint('下载瓦片错误 $url: $e');
    }
    return null;
  }

  Future<TileLoadResult> loadTileWithStrategy(String url, {Map<String, String>? headers}) async {
    final networkStatus = _connectivityService.currentStatus;
    final cachedTile = await getTile(url);

    switch (networkStatus) {
      case NetworkStatus.offline:
        if (cachedTile != null) {
          return TileLoadResult(
            tileData: cachedTile.tileData,
            source: TileSource.cache,
            isExpired: cachedTile.isExpired,
          );
        }
        return TileLoadResult(tileData: null, source: TileSource.none, isExpired: false);

      case NetworkStatus.metered:
        if (cachedTile != null) {
          return TileLoadResult(
            tileData: cachedTile.tileData,
            source: TileSource.cache,
            isExpired: cachedTile.isExpired,
          );
        }
        final networkData = await downloadAndCacheTile(url, headers: headers);
        return TileLoadResult(
          tileData: networkData,
          source: networkData != null ? TileSource.network : TileSource.none,
          isExpired: false,
        );

      case NetworkStatus.unmetered:
      case NetworkStatus.unknown:
        if (cachedTile != null) {
          _backgroundRefreshTile(url, headers);
          return TileLoadResult(
            tileData: cachedTile.tileData,
            source: TileSource.cache,
            isExpired: cachedTile.isExpired,
          );
        }
        final networkData = await downloadAndCacheTile(url, headers: headers);
        return TileLoadResult(
          tileData: networkData,
          source: networkData != null ? TileSource.network : TileSource.none,
          isExpired: false,
        );
    }
  }

  Future<void> _backgroundRefreshTile(String url, Map<String, String>? headers) async {
    try {
      await Future.delayed(const Duration(milliseconds: 50));
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        await cacheTile(url, response.bodyBytes);
      }
    } catch (e) {
      debugPrint('后台刷新瓦片失败 $url: $e');
    }
  }

  Future<void> cacheTile(String url, Uint8List tileData) async {
    if (!_initialized) await initialize();
    final cacheKey = _generateCacheKey(url);
    final cachedTile = CachedTile(tileData: tileData, timestamp: DateTime.now());

    _addToMemoryCache(cacheKey, cachedTile);

    try {
      final file = File('${_cacheDir.path}/$cacheKey');
      await file.writeAsBytes(tileData);
    } catch (e) {
      debugPrint('保存瓦片到磁盘错误: $e');
    }
  }

  void _addToMemoryCache(String cacheKey, CachedTile cachedTile) {
    if (_memoryCache.length >= maxMemoryCacheSize) {
      _removeOldestFromMemoryCache();
    }
    _memoryCache[cacheKey] = cachedTile;
  }

  void _promoteInMemoryCache(String cacheKey, CachedTile cachedTile) {
    _memoryCache.remove(cacheKey);
    _memoryCache[cacheKey] = cachedTile;
  }

  void _removeOldestFromMemoryCache() {
    if (_memoryCache.isEmpty) return;
    final oldestKey = _memoryCache.keys.first;
    _memoryCache.remove(oldestKey);
  }

  Future<void> _enforceDiskCacheLimit() async {
    try {
      final files = await _cacheDir.list().toList();
      int totalSize = 0;
      final fileInfos = <Map<String, dynamic>>[];

      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
          fileInfos.add({'file': file, 'size': stat.size, 'modified': stat.modified});
        }
      }

      final maxSizeBytes = maxDiskCacheSizeMB * 1024 * 1024;
      if (totalSize > maxSizeBytes) {
        fileInfos.sort((a, b) => (a['modified'] as DateTime).compareTo(b['modified'] as DateTime));
        int removedSize = 0;
        for (final fileInfo in fileInfos) {
          if (totalSize - removedSize <= maxSizeBytes) break;
          try {
            await (fileInfo['file'] as File).delete();
            removedSize += fileInfo['size'] as int;
          } catch (e) {
            debugPrint('删除过期瓦片 ${(fileInfo['file'] as File).path} 错误: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('强制执行磁盘缓存限制错误: $e');
    }
  }

  Future<void> clearCache() async {
    if (!_initialized) await initialize();
    _memoryCache.clear();
    try {
      if (await _cacheDir.exists()) {
        await _cacheDir.delete(recursive: true);
        await _cacheDir.create(recursive: true);
      }
    } catch (e) {
      debugPrint('清除缓存错误: $e');
    }
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    if (!_initialized) await initialize();
    final stats = <String, dynamic>{};
    stats['memoryCacheCount'] = _memoryCache.length;
    stats['memoryCacheMaxSize'] = maxMemoryCacheSize;

    int diskCacheCount = 0;
    int diskCacheSize = 0;
    try {
      final files = await _cacheDir.list().toList();
      for (final file in files) {
        if (file is File) {
          diskCacheCount++;
          diskCacheSize += (await file.stat()).size;
        }
      }
    } catch (e) {
      debugPrint('获取缓存统计错误: $e');
    }
    stats['diskCacheCount'] = diskCacheCount;
    stats['diskCacheSizeMB'] = (diskCacheSize / (1024 * 1024)).toStringAsFixed(2);
    stats['diskCacheMaxSizeMB'] = maxDiskCacheSizeMB;
    stats['networkStatus'] = _connectivityService.currentStatus.name;
    return stats;
  }
}

class TileLoadResult {
  final Uint8List? tileData;
  final TileSource source;
  final bool isExpired;

  TileLoadResult({
    required this.tileData,
    required this.source,
    required this.isExpired,
  });
}

enum TileSource {
  cache,    // 来自缓存
  network,  // 来自网络
  none,     // 无数据
}