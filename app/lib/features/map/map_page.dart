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
  bool _mapError = false;
  LatLng _center = const LatLng(39.9042, 116.4074);

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
        title: const Text('Map'),
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
                  const SnackBar(content: Text('Location failed'), duration: Duration(seconds: 1)),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _center, initialZoom: 14),
            children: [
              // 多层图源: OSM主站 -> OSM德国镜像 -> 备用
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                fallbackUrl: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.duichai.duichai',
                maxZoom: 18,
                errorImage: const AssetImage('assets/images/tile_error.png'),
              ),
              // 额外备用图源
              TileLayer(
                urlTemplate: 'https://basemap.nationalmap.gov/arcgis/rest/services/USGSTopo/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.duichai.duichai',
                maxZoom: 16,
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
          // 地图加载错误提示
          if (_mapError)
            Positioned(
              top: 16, left: 16, right: 16,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('地图瓦片加载失败，已切换到备用图源',
                          style: TextStyle(fontSize: 13, color: Colors.black87)),
                      ),
                    ],
                  ),
                ),
              ),
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
