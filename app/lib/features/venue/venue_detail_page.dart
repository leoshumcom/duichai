import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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

class _VenueDetailPageState extends State<VenueDetailPage> with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  final _tipCtrl = TextEditingController();
  Map<String, dynamic>? _venue;
  bool _loading = true;
  int _tipAmount = 10;

  // Reviews
  List<dynamic> _reviews = [];
  bool _loadingReviews = false;
  int _reviewPage = 1;
  bool _hasMoreReviews = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVenue();
    _loadReviews();
  }

  @override
  void dispose() {
    _tipCtrl.dispose();
    _tabController.dispose();
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

  Future<void> _loadReviews() async {
    if (_loadingReviews || !_hasMoreReviews) return;
    setState(() => _loadingReviews = true);
    try {
      final res = await _api.get('/api/venues/${widget.venueId}/reviews', params: {
        'page': '$_reviewPage', 'limit': '20',
      });
      if (res['success'] == true && res['data'] != null) {
        final newReviews = res['data'] as List<dynamic>;
        final total = res['total'] as int? ?? 0;
        setState(() {
          _reviews.addAll(newReviews);
          _hasMoreReviews = _reviews.length < total;
          _loadingReviews = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
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
        _loadReviews(); // 刷新评价
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

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final dt = DateTime.parse(timeStr);
      return DateFormat('MM-dd HH:mm').format(dt);
    } catch (_) {
      return timeStr;
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 240,
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
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primary,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: '场地详情'),
                  Tab(text: '评价'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: 场地详情 + 添柴
            _buildDetailTab(v, photos, topTippers),
            // Tab 2: 评价列表
            _buildReviewsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTab(Map<String, dynamic> v, List<String> photos, List<Map<String, dynamic>> topTippers) {
    return SingleChildScrollView(
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
    );
  }

  Widget _buildReviewsTab() {
    if (_reviews.isEmpty && _loadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('暂无评价', style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text('添柴时可带上评价', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length + (_hasMoreReviews ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _reviews.length) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: _loadingReviews
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: () { _reviewPage++; _loadReviews(); },
                      child: const Text('加载更多'),
                    ),
            ),
          );
        }
        final r = _reviews[i] as Map<String, dynamic>;
        final rPhotos = (r['photos'] as List?)?.cast<String>() ?? [];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primary.withOpacity(0.2),
                      backgroundImage: r['avatar'] != null ? NetworkImage(r['avatar']) : null,
                      child: r['avatar'] == null
                          ? Text(
                              (r['nickname'] ?? '?').toString().substring(0, 1),
                              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(r['nickname'] ?? '用户', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              if (r['uid'] != null) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text('#${r['uid']}', style: const TextStyle(fontSize: 10, color: AppTheme.primary)),
                                ),
                              ],
                            ],
                          ),
                          Text(_formatTime(r['created_at']), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 2),
                          Text('${r['chaihuo_amount'] ?? 0}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (r['content'] != null && (r['content'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(r['content'], style: const TextStyle(fontSize: 14, height: 1.4)),
                ],
                if (rPhotos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: rPhotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, pi) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(rPhotos[pi], width: 80, height: 80, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: Colors.grey.shade200)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// TabBar固定在Sliver头部的委托
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
