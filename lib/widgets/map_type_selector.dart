import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/map_type_service.dart';

class MapTypeSelector extends StatefulWidget {
  final Function(MapType) onMapTypeChanged;

  const MapTypeSelector({
    super.key,
    required this.onMapTypeChanged,
  });

  @override
  State<MapTypeSelector> createState() => _MapTypeSelectorState();
}

class _MapTypeSelectorState extends State<MapTypeSelector> {
  final MapTypeService _mapTypeService = MapTypeService();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.layers, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.mapTypeSelector,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
          
          // 地图类型列表
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: MapTypeService.mapLayers.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey.shade200,
            ),
            itemBuilder: (context, index) {
              final layer = MapTypeService.mapLayers[index];
              final isSelected = layer.type == _mapTypeService.currentMapType;
              
              return InkWell(
                onTap: () {
                  _mapTypeService.setMapType(layer.type);
                  widget.onMapTypeChanged(layer.type);
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 地图类型图标
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Colors.blue.shade100 
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected 
                              ? Border.all(color: Colors.blue.shade300, width: 2)
                              : null,
                        ),
                        child: Icon(
                          _getIconForMapType(layer.type),
                          color: isSelected 
                              ? Colors.blue.shade700 
                              : Colors.grey.shade600,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // 地图类型信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getLocalizedName(context, layer),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                                color: isSelected 
                                    ? Colors.blue.shade700 
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getLocalizedDescription(context, layer),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      // 选中指示器
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getIconForMapType(MapType type) {
    switch (type) {
      case MapType.standard:
        return Icons.map;
      case MapType.satellite:
        return Icons.satellite_alt;
      case MapType.hybrid:
        return Icons.layers;
      case MapType.terrain:
        return Icons.terrain;
      case MapType.transport:
        return Icons.directions_transit;
    }
  }

  String _getLocalizedName(BuildContext context, MapLayerConfig layer) {
    final localizations = AppLocalizations.of(context)!;
    switch (layer.type) {
      case MapType.standard:
        return localizations.mapTypeStandard;
      case MapType.satellite:
        return localizations.mapTypeSatellite;
      case MapType.hybrid:
        return localizations.mapTypeHybrid;
      case MapType.terrain:
        return localizations.mapTypeTerrain;
      case MapType.transport:
        return localizations.mapTypeTransport;
    }
  }

  String _getLocalizedDescription(BuildContext context, MapLayerConfig layer) {
    final localizations = AppLocalizations.of(context)!;
    switch (layer.type) {
      case MapType.standard:
        return localizations.mapTypeStandardDesc;
      case MapType.satellite:
        return localizations.mapTypeSatelliteDesc;
      case MapType.hybrid:
        return localizations.mapTypeHybridDesc;
      case MapType.terrain:
        return localizations.mapTypeTerrainDesc;
      case MapType.transport:
        return localizations.mapTypeTransportDesc;
    }
  }
}

// 显示地图类型选择器的辅助函数
void showMapTypeSelector(BuildContext context, Function(MapType) onMapTypeChanged) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      margin: const EdgeInsets.all(16),
      child: MapTypeSelector(onMapTypeChanged: onMapTypeChanged),
    ),
  );
}