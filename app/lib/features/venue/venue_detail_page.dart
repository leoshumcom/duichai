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

  // Match-making
  List<Map<String, dynamic>> _matches = [];
  bool _loadingMatches = false;
  final _matchTimeCtrl = TextEditingController();
  final _matchNotesCtrl = TextEditingController();
  int _matchMaxPlayers = 4;
  DateTime _selectedMatchDate = DateTime.now().add(const Duration(hours: 2));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadVenue();
    _loadReviews();
    _loadMatches();
  }

  @override
  void dispose() {
    _tipCtrl.dispose();
    _tabController.dispose();
    _matchTimeCtrl.dispose();
    _matchNotesCtrl.dispose();
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

  Future<void> _loadMatches() async {
    if (_loadingMatches) return;
    setState(() => _loadingMatches = true);
    try {
      final res = await _api.get('/api/venues/${widget.venueId}/matches');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _matches = (res['data'] as List).cast<Map<String, dynamic>>();
          _loadingMatches = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMatches = false);
    }
  }

  Future<void> _createMatch() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
      }
      return;
    }

    try {
      final res = await _api.post('/api/venues/${widget.venueId}/match', data: {
        'match_time': _selectedMatchDate.toIso8601String(),
        'max_players': _matchMaxPlayers,
        'notes': _matchNotesCtrl.text.isNotEmpty ? _matchNotesCtrl.text : null,
      });
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('约球创建成功！')),
          );
          _matchNotesCtrl.clear();
          _loadMatches();
          // 切到约球tab
          _tabController.animateTo(2);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? '创建失败')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络错误'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _joinMatch(String matchId) async {
    try {
      final res = await _api.post('/api/match/$matchId/join');
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已加入约球')),
          );
          _loadMatches();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? '加入失败')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络错误'), backgroundColor: Colors.red),
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
                  Tab(text: '约球'),
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
            // Tab 3: 约球
            _buildMatchesTab(),
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
          // 申请成为馆主按钮（仅非馆主用户可见）
          const Divider(),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showOwnerApplyDialog(context),
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('申请成为馆主'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showOwnerApplyDialog(BuildContext context) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      return;
    }

    final licCtrl = TextEditingController();
    final idFrontCtrl = TextEditingController();
    final idBackCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final wechatCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('申请成为馆主'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('请上传以下资料（支持图片URL或OSS链接）', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(controller: licCtrl, decoration: const InputDecoration(labelText: '营业执照图片URL', hintText: '请上传营业执照图片后粘贴链接')),
                const SizedBox(height: 12),
                TextField(controller: idFrontCtrl, decoration: const InputDecoration(labelText: '身份证正面URL', hintText: '请上传身份证正面图片后粘贴链接')),
                const SizedBox(height: 12),
                TextField(controller: idBackCtrl, decoration: const InputDecoration(labelText: '身份证反面URL', hintText: '请上传身份证反面图片后粘贴链接')),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '联系电话', hintText: '手机号'), keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                TextField(controller: wechatCtrl, decoration: const InputDecoration(labelText: '微信（选填）', hintText: '微信号')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: submitting ? null : () async {
                if (licCtrl.text.isEmpty || idFrontCtrl.text.isEmpty || idBackCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写必填信息'), backgroundColor: Colors.red),
                  );
                  return;
                }
                setDialogState(() => submitting = true);
                try {
                  final api = ApiClient();
                  final res = await api.post('/api/venues/owner-apply', data: {
                    'business_license': licCtrl.text.trim(),
                    'id_card_front': idFrontCtrl.text.trim(),
                    'id_card_back': idBackCtrl.text.trim(),
                    'contact_phone': phoneCtrl.text.trim(),
                    'contact_wechat': wechatCtrl.text.isNotEmpty ? wechatCtrl.text.trim() : null,
                  });
                  if (res['success'] == true) {
                    Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('申请已提交，等待管理员审核')),
                      );
                    }
                  } else {
                    setDialogState(() => submitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res['error'] ?? '提交失败'), backgroundColor: Colors.red),
                    );
                  }
                } catch (_) {
                  setDialogState(() => submitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('网络错误'), backgroundColor: Colors.red),
                  );
                }
              },
              child: submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('提交申请'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchesTab() {
    return Column(
      children: [
        // 创建约球按钮
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showCreateMatchDialog(context),
              icon: const Icon(Icons.sports_esports),
              label: const Text('发起约球'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        // 约球列表
        Expanded(
          child: _loadingMatches
              ? const Center(child: CircularProgressIndicator())
              : _matches.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sports_esports_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('暂无约球', style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('发起约球，一起运动吧！', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _matches.length,
                      itemBuilder: (ctx, i) {
                        final m = _matches[i];
                        final matchTime = m['match_time'] ?? '';
                        final status = m['status'] ?? 'open';
                        final isFull = status == 'full';
                        final canJoin = status == 'open' && !isFull;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppTheme.primary.withOpacity(0.2),
                                      child: Text(
                                        (m['creator_name'] ?? '?').toString().substring(0, 1),
                                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(m['creator_name'] ?? '用户', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isFull ? Colors.orange.shade50 : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isFull ? '已满' : '招募中',
                                        style: TextStyle(fontSize: 12, color: isFull ? Colors.orange : Colors.green, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(children: [
                                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(_formatTime(matchTime), style: TextStyle(color: Colors.grey.shade600)),
                                  const Spacer(),
                                  const Icon(Icons.people, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text('${m['current_players'] ?? 0}/${m['max_players'] ?? 0}', style: TextStyle(color: Colors.grey.shade600)),
                                ]),
                                if (m['notes'] != null && (m['notes'] as String).isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(m['notes'], style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                                ],
                                if (canJoin) ...[
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: () => _joinMatch(m['id']),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                      ),
                                      child: const Text('加入', style: TextStyle(fontSize: 13)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showCreateMatchDialog(BuildContext context) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录创建约球')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text('发起约球', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
                const Text('时间', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: _selectedMatchDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (date != null) {
                            final time = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(_selectedMatchDate),
                            );
                            if (time != null) {
                              setSheetState(() {
                                _selectedMatchDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                              });
                            }
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          DateFormat('MM-dd HH:mm').format(_selectedMatchDate),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('人数上限', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [2, 4, 6, 10, 20].map((n) => ChoiceChip(
                    label: Text('$n 人'),
                    selected: _matchMaxPlayers == n,
                    selectedColor: AppTheme.primary.withOpacity(0.15),
                    onSelected: (_) => setSheetState(() => _matchMaxPlayers = n),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('备注（选填）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _matchNotesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: '说点什么...自带球/新手友好/水平要求',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _createMatch();
                    },
                    child: const Text('发布约球'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
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
