import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_page.dart';

/// 场地详情页
class VenueDetailPage extends StatefulWidget {
  final String venueId;
  const VenueDetailPage({super.key, required this.venueId});

  @override
  State<VenueDetailPage> createState() => _VenueDetailPageState();
}

class _VenueDetailPageState extends State<VenueDetailPage> {
  final _api = ApiClient();
  final _tipCtrl = TextEditingController();
  Map<String, dynamic>? _venue;
  bool _loading = true;
  int _tipAmount = 10;

  @override
  void initState() {
    super.initState();
    _loadVenue();
  }

  @override
  void dispose() {
    _tipCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVenue() async {
    try {
      final res = await _api.get('/api/venues/${widget.venueId}');
      if (res['success'] == true && mounted) {
        setState(() { _venue = res['data']; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _tipVenue() async {
    final tipAmount = _tipAmount;
    if (tipAmount <= 0) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录再添柴')),
        );
      }
      return;
    }

    try {
      await _api.post('/api/venues/tip', data: {
        'venue_id': widget.venueId,
        'user_id': auth.user!['user_id'],
        'amount': tipAmount,
        'content': _tipCtrl.text.isNotEmpty ? _tipCtrl.text : null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('添柴成功！🔥')),
        );
        _loadVenue();
        _tipCtrl.clear();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('添柴失败，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('场地详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_venue == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('场地详情')),
        body: const Center(child: Text('场地不存在')),
      );
    }

    final v = _venue!;
    final photos = (v['photos'] as List?)?.cast<String>() ?? [];
    final topTippers = (v['top_tippers'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 头部
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: photos.isNotEmpty
                  ? Image.network(photos[0], fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200,
                        child: const Center(child: Icon(Icons.sports_basketball, size: 64, color: Colors.grey))))
                  : Container(color: Colors.grey.shade200,
                      child: const Center(child: Icon(Icons.sports_basketball, size: 64, color: Colors.grey))),
            ),
          ),

          // 内容
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名称+柴火
                  Row(
                    children: [
                      Expanded(
                        child: Text(v['name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department, color: AppTheme.primary, size: 18),
                            const SizedBox(width: 4),
                            Text('${v['chaihuo_total'] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(v['address'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      const Spacer(),
                      Text(v['type'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 描述
                  if (v['description'] != null && (v['description'] as String).isNotEmpty) ...[
                    Text(v['description'], style: const TextStyle(fontSize: 14, height: 1.5)),
                    const SizedBox(height: 16),
                  ],

                  // 更多图片
                  if (photos.length > 1) ...[
                    const Text('更多照片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length - 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(photos[i + 1], width: 120, height: 120, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 120, height: 120, color: Colors.grey.shade200)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 添柴榜
                  if (topTippers.isNotEmpty) ...[
                    const Text('🏆 添柴榜', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...topTippers.asMap().entries.map((entry) {
                      final tipper = entry.value;
                      final rank = entry.key + 1;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: rank == 1 ? AppTheme.primary : Colors.grey.shade300,
                          child: Text('$rank', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(tipper['nickname'] ?? '用户'),
                        trailing: Text('${tipper['total_chaihuo']}🔥', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // 添柴按钮
                  const Text('🔥 添柴', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [1, 10, 50, 100, 500].map((amount) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('$amount'),
                          selected: _tipAmount == amount,
                          selectedColor: AppTheme.primary.withOpacity(0.15),
                          onSelected: (v) => setState(() => _tipAmount = amount),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tipCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: '写句支持的话（选填）...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _tipVenue,
                      icon: const Icon(Icons.local_fire_department),
                      label: Text('添柴 $_tipAmount 根 🔥'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
