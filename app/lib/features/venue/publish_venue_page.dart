import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_page.dart';

class PublishVenuePage extends StatefulWidget {
  const PublishVenuePage({super.key});

  @override
  State<PublishVenuePage> createState() => _PublishVenuePageState();
}

class _PublishVenuePageState extends State<PublishVenuePage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _api = ApiClient();

  String _selectedType = '篮球';
  bool _isFree = true;
  double? _lat, _lng;
  String? _address;
  List<XFile> _images = [];
  List<XFile> _videos = [];
  bool _loading = false;

  final _types = ['篮球', '足球', '羽毛球', '网球', '乒乓球', '跑步', '游泳', '滑板', '瑜伽', '健身', '其他'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isNotEmpty) setState(() => _images.addAll(files));
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file != null) setState(() => _videos.add(file));
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写场地名称')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      await _api.post('/api/venues', data: {
        'name': _nameCtrl.text,
        'type': _selectedType,
        'latitude': _lat ?? 39.9,
        'longitude': _lng ?? 116.4,
        'address': _address,
        'description': _descCtrl.text,
        'is_free': _isFree,
        'publisher_id': auth.isLoggedIn ? auth.user!['user_id'] : 'temp',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发布成功！获得100根柴火')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发布失败')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发布场地'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('发布', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '场地名称', hintText: '例如：朝阳公园篮球场'),
              ),
              const SizedBox(height: 16),
              const Text('运动类型', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _types.map((t) => ChoiceChip(
                  label: Text(t),
                  selected: _selectedType == t,
                  selectedColor: AppTheme.primary.withOpacity(0.15),
                  onSelected: (v) => setState(() => _selectedType = t),
                )).toList(),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: AppTheme.primary),
                  title: Text(_address ?? '点击获取当前位置'),
                  subtitle: _lat != null ? Text('${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_lat == null)
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              final perm = await Geolocator.requestPermission();
                              if (perm == LocationPermission.denied) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('需要位置权限')));
                                return;
                              }
                              final pos = await Geolocator.getCurrentPosition();
                              if (mounted) {
                                setState(() {
                                  _lat = pos.latitude;
                                  _lng = pos.longitude;
                                  _address = '位置已获取';
                                });
                              }
                            } catch (e) {
                              if (mounted) {
                                // 定位失败，弹出地址输入框
                                final addr = await showDialog<String>(
                                  context: context,
                                  builder: (ctx) {
                                    final ctrl = TextEditingController();
                                    return AlertDialog(
                                      title: const Text('输入地址/位置'),
                                      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '例如：朝阳区国贸CBD'), maxLines: 2),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                                        TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('确认')),
                                      ],
                                    );
                                  },
                                );
                                if (addr != null && addr.isNotEmpty && mounted) {
                                  setState(() { _address = addr; });
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text('定位', style: TextStyle(fontSize: 13)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: () {
                          setState(() {
                            _lat = null;
                            _lng = null;
                            _address = null;
                          });
                        },
                      ),
                    ],
                  ),
                  onTap: () async {
                    // 弹出地址输入框供用户手动输入
                    final addrCtrl = TextEditingController(text: _address ?? '');
                    final latCtrl = TextEditingController(text: _lat?.toStringAsFixed(6) ?? '');
                    final lngCtrl = TextEditingController(text: _lng?.toStringAsFixed(6) ?? '');
                    final result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('编辑位置'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: '地址描述', hintText: '场地地址或描述'), maxLines: 2),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: TextField(controller: latCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '纬度（选填）', hintText: '如: 39.9'))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: lngCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '经度（选填）', hintText: '如: 116.4'))),
                            ]),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, {
                            'lat': double.tryParse(latCtrl.text),
                            'lng': double.tryParse(lngCtrl.text),
                            'address': addrCtrl.text.trim(),
                          }), child: const Text('确认')),
                        ],
                      ),
                    );
                    if (result != null && mounted) {
                      setState(() {
                        final parsedLat = result['lat'] as double?;
                        final parsedLng = result['lng'] as double?;
                        if (parsedLat != null) _lat = parsedLat;
                        if (parsedLng != null) _lng = parsedLng;
                        if ((result['address'] as String?)?.isNotEmpty == true) _address = result['address'] as String;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text('照片（最多9张）', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._images.map((img) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            Image.file(File(img.path), width: 100, height: 100, fit: BoxFit.cover),
                            Positioned(
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => _images.remove(img)),
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                    if (_images.length < 9)
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Icon(Icons.add_photo_alternate, color: Colors.grey, size: 32),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('费用：', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(width: 12),
                  ChoiceChip(label: const Text('免费'), selected: _isFree,
                      selectedColor: Colors.green.shade50,
                      onSelected: (v) => setState(() => _isFree = true)),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('收费'), selected: !_isFree,
                      selectedColor: AppTheme.primary.withOpacity(0.15),
                      onSelected: (v) => setState(() => _isFree = false)),
                ],
              ),
              if (!_isFree) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '费用说明', hintText: '20元/小时'),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '场地描述（选填）', hintText: '场地大小、设施情况...'),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '首次发布场地可获得100根柴火！如果场地已被发布过，将进入补充模式',
                        style: TextStyle(fontSize: 12, color: AppTheme.warmBrown),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
