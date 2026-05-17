import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _api = ApiClient();
  late AMapController _mapController;
  List<Map<String, dynamic>> _venues = [];
  bool _loading = true;
  LatLng _center = const LatLng(39.9042, 116.4074);
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
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
        final venues = (res['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _venues = venues;
          _loading = false;
          _markers = venues.map((v) {
            final lat = (v['latitude'] as num?)?.toDouble() ?? 0;
            final lng = (v['longitude'] as num?)?.toDouble() ?? 0;
            return Marker(
              position: LatLng(lat, lng),
              icon: BitmapDescriptor.defaultMarker,
              infoWindowEnable: true,
              infoWindow: InfoWindow(title: v['name'] ?? '', snippet: '🔥 ${v['chaihuo_total'] ?? 0}'),
              onTap: (id) {
                Navigator.pushNamed(context, '/venue/detail', arguments: v['id']);
              },
            );
          }).toSet();
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
        title: const Text('地图'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () async {
              try {
                final pos = await Geolocator.getCurrentPosition();
                if (pos != null) {
                  final latLng = LatLng(pos.latitude, pos.longitude);
                  setState(() => _center = latLng);
                  _mapController.moveCamera(CameraUpdate.newLatLngZoom(latLng, 14));
                  _loadVenues();
                }
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('定位失败'), duration: Duration(seconds: 1)),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          AMapWidget(
            apiKey: AMapApiKey(
              androidKey: AppConfig.amapApiKey,
              iosKey: AppConfig.amapIosKey,
            ),
            privacyStatement: const AMapPrivacyStatement(
              hasContains: true,
              hasShow: true,
              hasAgree: true,
            ),
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 14,
            ),
            myLocationStyleOptions: const MyLocationStyleOptions(
              true,
              circleFillColor: Colors.lightBlue,
              circleStrokeColor: Colors.blue,
              circleStrokeWidth: 2,
            ),
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;
            },
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
