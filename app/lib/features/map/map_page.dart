import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';

/// 地图找场页面（集成高德地图）
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _api = Dio(BaseOptions(baseUrl: 'https://restapi.amap.com/v3'));
  List<Map<String, dynamic>> _venues = [];
  bool _loading = true;
  double _lat = 39.9042; // 默认北京
  double _lng = 116.4074;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      // TODO: 通过高德定位SDK获取真实位置
      // 目前使用默认位置，后续接入 amap_flutter_location
    }
    _searchNearby();
  }

  Future<void> _searchNearby() async {
    try {
      final res = await _api.get('/place/around', queryParameters: {
        'key': 'f073e6e3b08e43d4a8383ba702bd7bab'
        'location': '$_lng,$_lat',
        'radius': '5000',
        'types': '运动场馆|体育休闲',
        'offset': '20',
        'extensions': 'base',
      });
      if (res.data['status'] == '1' && mounted) {
        final pois = (res.data['pois'] as List?) ?? [];
        setState(() {
          _venues = pois.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地图找场'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _searchNearby,
            tooltip: '刷新附近场地',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 地图占位（待接入高德MapWidget）
          Container(
            color: Colors.grey.shade100,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('高德地图容器', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    '此处将嵌入高德地图 MapWidget\n需配置 AMAP_API_KEY',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          // 底部场地列表
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)],
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _venues.isEmpty
                      ? const Center(child: Text('附近暂无场地'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _venues.length,
                          itemBuilder: (ctx, i) => _buildNearbyItem(_venues[i]),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyItem(Map<String, dynamic> poi) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.stadium_outlined, color: AppTheme.primary, size: 20),
      ),
      title: Text(poi['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(
        '${poi['distance'] ?? ''}m · ${poi['type'] ?? ''}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
      trailing: const Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 20),
      onTap: () {
        // 点击跳转到场地详情或提示可以发布
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${poi['name']}」尚未被收录，去发布？')),
        );
      },
    );
  }
}

/// 地图选点组件（发布场地时使用）
class LocationPicker extends StatefulWidget {
  final Function(double lat, double lng, String address) onPicked;

  const LocationPicker({super.key, required this.onPicked});

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          // TODO: 弹出高德地图选点页面
          // 模拟选点
          final result = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('选择位置'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('地图选点界面\n（需接入高德地图选点SDK）',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                ElevatedButton(
                  onPressed: () {
                    // 模拟返回坐标
                    Navigator.pop(ctx, {
                      'lat': 39.9042,
                      'lng': 116.4074,
                      'address': '北京市朝阳区示例地址',
                    });
                  },
                  child: const Text('确认位置'),
                ),
              ],
            ),
          );

          if (result != null) {
            widget.onPicked(
              result['lat'] as double,
              result['lng'] as double,
              result['address'] as String,
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: AppTheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('选择位置', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('在地图上标记场地位置', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
