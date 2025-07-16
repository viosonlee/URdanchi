
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/danchi.dart';
import '../services/api_service.dart';
import '../services/optimized_cached_tile_provider.dart';
import '../services/danchi_cache_service.dart';
import '../services/subscription_service.dart';
import '../services/map_type_service.dart';
import '../widgets/map_type_selector.dart';
import 'detail_screen.dart';

import 'new_rooms_screen.dart';
import 'settings_screen.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final _apiService = ApiService();
  final _danchiCacheService = DanchiCacheService();
  final _subscriptionService = SubscriptionService();
  final _mapTypeService = MapTypeService();
  List<DanchiMarker> _markers = [];
  final _mapEventSubject = PublishSubject<MapEvent>();

  LatLng _initialCenter = const LatLng(35.681, 139.767);
  double _initialZoom = 13.0;
  bool _mapInitialized = false;
  bool _hasNewRooms = false;
  Map<String, List<Room>> _newRoomsMap = {};
  Map<String, DanchiInfo> _danchiInfoMap = {};

  @override
  void initState() {
    super.initState();
    _loadMapState();
    _loadMapType();
    _checkForNewRooms();
    _mapEventSubject
        .listen((_) {
      _fetchMarkers(_mapController.camera.visibleBounds);
    });
  }

  Future<void> _loadMapState() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('map_lat');
    final lng = prefs.getDouble('map_lng');
    final zoom = prefs.getDouble('map_zoom');
    debugPrint('加载地图状态: lat=$lat, lng=$lng, zoom=$zoom');
    if (lat != null && lng != null && zoom != null) {
      setState(() {
        _initialCenter = LatLng(lat, lng);
        _initialZoom = zoom;
      });
      debugPrint('地图状态已加载: center=$_initialCenter, zoom=$_initialZoom');
    } else {
      debugPrint('未找到保存的地图状态，使用默认值');
    }
    setState(() {
      _mapInitialized = true;
    });
  }

  Future<void> _loadMapType() async {
    await _mapTypeService.initialize();
  }

  Future<void> _saveMapState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final center = _mapController.camera.center;
      final zoom = _mapController.camera.zoom;
      await prefs.setDouble('map_lat', center.latitude);
      await prefs.setDouble('map_lng', center.longitude);
      await prefs.setDouble('map_zoom', zoom);
      debugPrint('地图状态已保存: lat=${center.latitude}, lng=${center.longitude}, zoom=$zoom');
    } catch (e) {
      debugPrint('保存地图状态错误: $e');
    }
  }

  void _fetchMarkers(LatLngBounds? bounds) async {
    if (bounds == null) return;

    // Try to get cached markers first and display immediately
    final cachedMarkers = await _danchiCacheService.getCachedMapMarkers(
      bounds.northEast.latitude,
      bounds.northEast.longitude,
      bounds.southWest.latitude,
      bounds.southWest.longitude,
    );

    if (cachedMarkers != null) {
      if (mounted) {
        setState(() {
          _markers = cachedMarkers;
        });
      }
    }

    // Fetch fresh data from API in the background
    _fetchFreshMarkers(bounds);
    
    // Check for new rooms in subscribed danchi when map area changes
    _checkForNewRoomsInBackground();
  }

  Future<void> _fetchFreshMarkers(LatLngBounds bounds) async {
    try {
      final markers = await _apiService.getMapMarkers(
        bounds.northEast.latitude,
        bounds.northEast.longitude,
        bounds.southWest.latitude,
        bounds.southWest.longitude,
      );

      if (mounted) {
        setState(() {
          _markers = markers;
        });

        // Cache the fresh data
        await _danchiCacheService.cacheMapMarkers(
          bounds.northEast.latitude,
          bounds.northEast.longitude,
          bounds.southWest.latitude,
          bounds.southWest.longitude,
          markers,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToLoadMarkers(e.toString()))),
        );
      }
    }
  }

  Future<void> _checkForNewRooms() async {
    try {
      final newRoomsMap = await _subscriptionService.checkForNewRooms();
      
      if (newRoomsMap.isNotEmpty) {
        final danchiInfoMap = await _subscriptionService.getSubscribedDanchiInfo(
          newRoomsMap.keys.toList(),
        );

        if (mounted) {
          setState(() {
            _hasNewRooms = true;
            _newRoomsMap = newRoomsMap;
            _danchiInfoMap = danchiInfoMap;
          });
        }
      }
    } catch (e) {
      debugPrint('检查新房间错误: $e');
    }
  }

  /// Check for new rooms in background without blocking UI
  Future<void> _checkForNewRoomsInBackground() async {
    // Only check if we have subscriptions and haven't checked recently
    final subscribedIds = await _subscriptionService.getSubscribedDanchiIds();
    if (subscribedIds.isEmpty) return;
    
    final lastCheck = await _subscriptionService.getLastCheckTime();
    final now = DateTime.now();
    
    // Only check if last check was more than 5 minutes ago to avoid too frequent checks
    if (lastCheck != null && now.difference(lastCheck).inMinutes < 5) {
      return;
    }
    
    // Run check in background
    _checkForNewRooms();
  }

  void _showNewRoomsNotification() {
    if (!_hasNewRooms) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewRoomsScreen(
          newRoomsMap: _newRoomsMap,
          danchiInfoMap: _danchiInfoMap,
        ),
      ),
    ).then((_) {
      // Clear notification after viewing
      setState(() {
        _hasNewRooms = false;
        _newRoomsMap = {};
        _danchiInfoMap = {};
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_mapInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              onMapReady: () {
                _fetchMarkers(_mapController.camera.visibleBounds);
              },
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              onMapEvent: (mapEvent) {
                if (mapEvent is MapEventMoveEnd || mapEvent is MapEventFlingAnimationEnd) {
                  _mapEventSubject.add(mapEvent);
                  _saveMapState();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _mapTypeService.currentMapLayer.urlTemplate,
                userAgentPackageName: 'lee.vioson.danchi_map',
                tileProvider: OptimizedCachedTileProvider(
                  userAgentPackageName: 'lee.vioson.danchi_map',
                ),
              ),
              MarkerLayer(
                markers: _markers.map((marker) {
                  return Marker(
                    width: 80.0,
                    height: 80.0,
                    point: LatLng(marker.lat, marker.lng),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailScreen(danchiId: marker.id),
                          ),
                        );
                      },
                      child: Icon(
                        Icons.location_pin,
                        color: marker.roomCount > 0 ? Colors.red : Colors.grey,
                        size: 40.0,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          // 地图类型选择按钮
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.2 * 255).round()),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.layers,
                  color: Colors.black87,
                ),
                onPressed: () {
                  showMapTypeSelector(context, (MapType mapType) async {
                    await _mapTypeService.setMapType(mapType);
                  });
                },
              ),
            ),
          ),
          // Settings button
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.2 * 255).round()),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.black87),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
          // New rooms notification
          if (_hasNewRooms)
            Positioned(
              top: 120,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.3 * 255).round()),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notification_important,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.newRoomsAvailable,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_newRoomsMap.values.map((rooms) => rooms.length).fold(0, (sum, count) => sum + count)} ${AppLocalizations.of(context)!.newRoomsFound}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _showNewRoomsNotification,
                      icon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _hasNewRooms = false;
                        });
                      },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 缩放按钮
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 复位方向按钮
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.2 * 255).round()),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.navigation, color: Colors.black87),
                    onPressed: () {
                      _mapController.rotate(0);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // 放大按钮
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.2 * 255).round()),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.black87),
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      if (currentZoom < 18) {
                        _mapController.move(
                          _mapController.camera.center,
                          currentZoom + 1,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // 缩小按钮
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.2 * 255).round()),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.remove, color: Colors.black87),
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      if (currentZoom > 1) {
                        _mapController.move(
                          _mapController.camera.center,
                          currentZoom - 1,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapEventSubject.close();
    super.dispose();
  }
}
