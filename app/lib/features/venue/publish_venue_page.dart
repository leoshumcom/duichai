import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';

/// 场地发布页面
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
    if (files.isNotEmpty) {
      setState(() => _images.addAll(files));
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _videos.add(file));
    }
  }

  Future<void> _pickLocation() async {
    // TODO: 接入高德地图选点
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('地图选点功能待接入高德SDK')),
    );
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写场地名称')),
      );
      return;
    }
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择位置')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // 上传图片
      final photoUrls = <String>[];
      for (final img in _images) {
        final bytes = await img.readAsBytes();
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: img.name),
          'user_id': 'temp',
        });
        // TODO: 用实际 token 上传
        photoUrls.add('uploaded_${img.name}');
      }

      // 发布场地
      final res = await _api.post('/api/venues', data: {
        'name': _nameCtrl.text,
        'type': _selectedType,
        'latitude': _lat,
        'longitude': _lng,
        'address': _address,
        'description': _descCtrl.text,
        'photos': photoUrls,
        'is_free': _isFree,
        'price_info': _isFree ? null : _priceCtrl.text,
        'publisher_id': 'temp',
      });

      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('发布成功！获得100根柴火🔥')),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (res['duplicate_venue'] != null) {
          _showDuplicateWarning(res['duplicate_venue']);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? '发布失败')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('网络错误，请重试')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDuplicateWarning(dynamic duplicate) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('该场地已被发布'),
        content: Text('「${duplicate['name']}」已被其他用户发布过了。是否切换到补充模式？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('去补充')),
        ],
      ),
    );
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
              // 名称
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '场地名称', hintText: '例如：朝阳公园篮球场'),
              ),
              const SizedBox(height: 16),

              // 运动类型
              const Text('运动类型', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _types.map((t) => ChoiceChip(
                  label: Text(t),
                  selected: _selectedType == t,
                  selectedColor: AppTheme.primary.withOpacity(0.15),
                  onSelected: (v) => setState(() => _selectedType = t),
                )).toList(),
              ),
              const SizedBox(height: 16),

              // 定位
              const Text('位置', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: AppTheme.primary),
                  title: Text(_address ?? '点击选择位置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickLocation,
                ),
              ),
              const SizedBox(height: 16),

              // 图片
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

              // 视频
              const Text('视频（可选，30秒内）', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ..._videos.map((v) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Container(
                            width: 100, height: 100,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.play_circle_fill, size: 32),
                          ),
                          Positioned(
                            top: 4, right: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _videos.remove(v)),
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
                  if (_videos.length < 1)
                    GestureDetector(
                      onTap: _pickVideo,
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Icon(Icons.videocam, color: Colors.grey, size: 32),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // 收费/免费
              Row(
                children: [
                  const Text('费用：', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('免费'),
                    selected: _isFree,
                    selectedColor: Colors.green.shade50,
                    onSelected: (v) => setState(() => _isFree = true),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('收费'),
                    selected: !_isFree,
                    selectedColor: AppTheme.primary.withOpacity(0.15),
                    onSelected: (v) => setState(() => _isFree = false),
                  ),
                ],
              ),
              if (!_isFree) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '费用说明',
                    hintText: '例如：20元/小时',
                    prefixIcon: Icon(Icons.monetization_on_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 描述
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '场地描述（选填）',
                  hintText: '场地大小、设施情况、注意事项...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),

              // 提示
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
                        '首次发布场地可获得100根柴火🔥 如果场地已被发布过，将进入补充模式',
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
