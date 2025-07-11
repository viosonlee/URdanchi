import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/danchi.dart';
import '../services/api_service.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final _apiService = ApiService();
  List<DanchiMarker> _markers = [];
  final _mapEventSubject = PublishSubject<MapEvent>();

  LatLng _initialCenter = const LatLng(35.681, 139.767);
  double _initialZoom = 13.0;

  @override
  void initState() {
    super.initState();
    _loadMapState();
    _mapEventSubject
        .debounceTime(const Duration(seconds: 1))
        .listen((_) {
      _fetchMarkers(_mapController.camera.visibleBounds);
    });
  }

  Future<void> _loadMapState() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('map_lat');
    final lng = prefs.getDouble('map_lng');
    final zoom = prefs.getDouble('map_zoom');
    if (lat != null && lng != null && zoom != null) {
      setState(() {
        _initialCenter = LatLng(lat, lng);
        _initialZoom = zoom;
      });
    }
  }

  Future<void> _saveMapState() async {
    final prefs = await SharedPreferences.getInstance();
    final center = _mapController.camera.center;
    final zoom = _mapController.camera.zoom;
    await prefs.setDouble('map_lat', center.latitude);
    await prefs.setDouble('map_lng', center.longitude);
    await prefs.setDouble('map_zoom', zoom);
  }

  void _fetchMarkers(LatLngBounds? bounds) async {
    if (bounds == null) return;

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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load markers: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UR住宅地图'),
      ),
      body: FlutterMap(
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
              _saveMapState(); // 保存地图状态
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.danchi_map_app',
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
    );
  }

  @override
  void dispose() {
    _mapEventSubject.close();
    super.dispose();
  }
}
