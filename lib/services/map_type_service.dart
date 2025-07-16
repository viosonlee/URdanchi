import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MapType {
  standard,      // 标准地图
  satellite,     // 卫星地图
  hybrid,        // 混合地图
  terrain,       // 地形地图
  transport,     // 交通地图
}

class MapLayerConfig {
  final MapType type;
  final String name;
  final String nameKey; // 本地化键
  final String urlTemplate;
  final String description;
  final String descriptionKey; // 本地化键
  final int maxZoom;
  final String attribution;

  const MapLayerConfig({
    required this.type,
    required this.name,
    required this.nameKey,
    required this.urlTemplate,
    required this.description,
    required this.descriptionKey,
    this.maxZoom = 19,
    required this.attribution,
  });
}

class MapTypeService {
  static final MapTypeService _instance = MapTypeService._internal();
  factory MapTypeService() => _instance;
  MapTypeService._internal();

  static const String _mapTypeKey = 'selected_map_type';
  MapType _currentMapType = MapType.standard;

  // 地图类型配置
  static const List<MapLayerConfig> mapLayers = [
    MapLayerConfig(
      type: MapType.standard,
      name: 'Standard',
      nameKey: 'mapTypeStandard',
      urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
      description: 'Google standard roadmap',
      descriptionKey: 'mapTypeStandardDesc',
      attribution: '© Google',
    ),
    MapLayerConfig(
      type: MapType.satellite,
      name: 'Satellite',
      nameKey: 'mapTypeSatellite',
      urlTemplate: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
      description: 'Google satellite imagery',
      descriptionKey: 'mapTypeSatelliteDesc',
      attribution: '© Google',
    ),
    MapLayerConfig(
      type: MapType.hybrid,
      name: 'Hybrid',
      nameKey: 'mapTypeHybrid',
      urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
      description: 'Google satellite with road overlays',
      descriptionKey: 'mapTypeHybridDesc',
      attribution: '© Google',
    ),
    MapLayerConfig(
      type: MapType.terrain,
      name: 'Terrain',
      nameKey: 'mapTypeTerrain',
      urlTemplate: 'https://mt1.google.com/vt/lyrs=p&x={x}&y={y}&z={z}',
      description: 'Google terrain maps with elevation',
      descriptionKey: 'mapTypeTerrainDesc',
      attribution: '© Google',
    ),
    MapLayerConfig(
      type: MapType.transport,
      name: 'Transport',
      nameKey: 'mapTypeTransport',
      urlTemplate: 'https://tile.memomaps.de/tilegen/{z}/{x}/{y}.png',
      description: 'Transport and public transit focused map',
      descriptionKey: 'mapTypeTransportDesc',
      attribution: '© OpenStreetMap contributors, © MeMoMaps',
    ),
  ];

  MapType get currentMapType => _currentMapType;

  MapLayerConfig get currentMapLayer {
    return mapLayers.firstWhere(
      (layer) => layer.type == _currentMapType,
      orElse: () => mapLayers.first,
    );
  }

  /// 初始化，从本地存储加载当前地图类型
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final typeIndex = prefs.getInt(_mapTypeKey) ?? 0;
      if (typeIndex >= 0 && typeIndex < MapType.values.length) {
        _currentMapType = MapType.values[typeIndex];
      }
    } catch (e) {
      debugPrint('加载地图类型错误: $e');
    }
  }

  /// 切换地图类型
  Future<void> setMapType(MapType type) async {
    if (_currentMapType != type) {
      _currentMapType = type;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_mapTypeKey, type.index);
      } catch (e) {
        debugPrint('保存地图类型错误: $e');
      }
    }
  }

  /// 获取下一个地图类型（用于快速切换）
  MapType getNextMapType() {
    final currentIndex = _currentMapType.index;
    final nextIndex = (currentIndex + 1) % MapType.values.length;
    return MapType.values[nextIndex];
  }

  /// 根据类型获取配置
  static MapLayerConfig? getConfigForType(MapType type) {
    try {
      return mapLayers.firstWhere((layer) => layer.type == type);
    } catch (e) {
      return null;
    }
  }
}