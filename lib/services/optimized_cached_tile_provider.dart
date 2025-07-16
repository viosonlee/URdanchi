import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'optimized_tile_cache_service.dart';
import 'connectivity_service.dart';

class OptimizedCachedTileProvider extends TileProvider {
  final OptimizedTileCacheService _cacheService = OptimizedTileCacheService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final String? userAgentPackageName;
  
  @override
  final Map<String, String> headers;

  OptimizedCachedTileProvider({
    this.userAgentPackageName,
    Map<String, String>? headers,
  }) : headers = Map<String, String>.from(headers ?? {});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final urlTemplate = options.urlTemplate ?? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    final url = _buildTileUrl(urlTemplate, coordinates);
    
    return OptimizedCachedNetworkImage(
      url: url,
      headers: _buildHeaders(),
      cacheService: _cacheService,
      connectivityService: _connectivityService,
    );
  }

  String _buildTileUrl(String template, TileCoordinates coordinates) {
    return template
        .replaceAll('{z}', coordinates.z.toString())
        .replaceAll('{x}', coordinates.x.toString())
        .replaceAll('{y}', coordinates.y.toString());
  }

  Map<String, String> _buildHeaders() {
    final requestHeaders = Map<String, String>.from(headers);
    if (userAgentPackageName != null) {
      requestHeaders['User-Agent'] = userAgentPackageName!;
    }
    return requestHeaders;
  }
}

class OptimizedCachedNetworkImage extends ImageProvider<OptimizedCachedNetworkImage> {
  final String url;
  final Map<String, String> headers;
  final OptimizedTileCacheService cacheService;
  final ConnectivityService connectivityService;

  const OptimizedCachedNetworkImage({
    required this.url,
    required this.headers,
    required this.cacheService,
    required this.connectivityService,
  });

  @override
  Future<OptimizedCachedNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<OptimizedCachedNetworkImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(OptimizedCachedNetworkImage key, ImageDecoderCallback decode) {
    final chunkEvents = StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: 1.0,
      debugLabel: url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<OptimizedCachedNetworkImage>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    OptimizedCachedNetworkImage key,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
  ) async {
    try {
      assert(key == this);

      final result = await cacheService.loadTileWithStrategy(url, headers: headers);
      
      if (result.tileData != null) {
        final buffer = await ui.ImmutableBuffer.fromUint8List(result.tileData!);
        return decode(buffer);
      } else {
        throw Exception('无法加载瓦片: $url');
      }
    } catch (e) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    } finally {
      chunkEvents.close();
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is OptimizedCachedNetworkImage && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => '${runtimeType.toString()}("$url")';
}