import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _api = ApiClient();
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _venues = [];
  bool _loading = true;
  bool _tileError = false;
  LatLng _center = const LatLng(39.9042, 116.4074);

  // China-friendly tile providers (fallback chain)
  static const List<_TileProvider> _tileProviders = [
    // 1. 高德地图瓦片（国内可访问）
    _TileProvider(
      name: '高德地图',
      url: 'https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
    ),
    // 2. OpenStreetMap 中国大陆镜像（清华 TUNA）
    _TileProvider(
      name: 'OSM镜像',
      url: 'https://mirrors.tuna.tsinghua.edu.cn/osm/tiles/{z}/{x}/{y}.png',
    ),
    // 3. OpenStreetMap 官方 tiles（fallback）
    _TileProvider(
      name: 'OpenStreetMap',
      url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
  ];

  int _activeTileIndex = 0;

  String get _activeTileUrl => _tileProviders[_activeTileIndex].url;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition();
        if (pos != null) _center = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}
    _loadVenues();
  }

  void _retryTile() {
    setState(() {
      _tileError = false;
      _activeTileIndex = (_activeTileIndex + 1) % _tileProviders.length;
    });
  }

  Future<void> _loadVenues() async {
    try {
      final res = await _api.get('/api/venues', params: {
        'lat': _center.latitude.toString(),
        'lng': _center.longitude.toString(),
        'radius': '10', 'limit': '50',
      });
      if (res['success'] == true && mounted) {
        setState(() {
          _venues = (res['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tileProviders[_activeTileIndex].name),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () async {
              try {
                final pos = await Geolocator.getCurrentPosition();
                if (pos != null) {
                  setState(() => _center = LatLng(pos.latitude, pos.longitude));
                  _mapController.move(_center, 14);
                  _loadVenues();
                }
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('定位失败'), duration: Duration(seconds: 1)),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: '切换地图源',
            onPressed: _retryTile,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _center, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: _activeTileUrl,
                userAgentPackageName: 'com.duichai.duichai',
              ),
              if (_tileError)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('地图瓦片加载失败，点击右侧按钮切换地图源',
                                style: const TextStyle(fontSize: 13)),
                          ),
                          TextButton(
                            onPressed: _retryTile,
                            child: const Text('切换', style: TextStyle(color: AppTheme.primary)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              MarkerLayer(
                markers: _venues.map((v) {
                  final lat = (v['latitude'] as num?)?.toDouble() ?? 0;
                  final lng = (v['longitude'] as num?)?.toDouble() ?? 0;
                  return Marker(
                    point: LatLng(lat, lng),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/venue/detail', arguments: v['id']),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                        ),
                        child: const Icon(Icons.local_fire_department, color: Colors.white, size: 18),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          if (_venues.isNotEmpty)
            Positioned(
              left: 8, right: 8, bottom: 8,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  itemCount: _venues.length,
                  itemBuilder: (ctx, i) => _buildVenueCard(_venues[i]),
                ),
              ),
            ),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildVenueCard(Map<String, dynamic> venue) {
    final photos = (venue['photos'] as List?)?.cast<String>() ?? [];
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/venue/detail', arguments: venue['id']),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey.shade50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: Container(
                height: 60,
                color: Colors.grey.shade200,
                child: photos.isNotEmpty
                    ? Image.network(photos[0], fit: BoxFit.cover, width: double.infinity,
                        errorBuilder: (_, __, ___) => const Icon(Icons.sports_basketball, color: Colors.grey))
                    : const Icon(Icons.sports_basketball, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue['name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    const Icon(Icons.local_fire_department, size: 12, color: AppTheme.primary),
                    const SizedBox(width: 2),
                    Text('${venue['chaihuo_total'] ?? 0}', style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileProvider {
  final String name;
  final String url;
  const _TileProvider({required this.name, required this.url});
}
