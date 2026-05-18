import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_page.dart';

/// 俱乐部列表页
class ClubsPage extends StatefulWidget {
  const ClubsPage({super.key});

  @override
  State<ClubsPage> createState() => _ClubsPageState();
}

class _ClubsPageState extends State<ClubsPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _clubs = [];
  bool _loading = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClubs() async {
    try {
      final params = <String, String>{};
      if (_searchQuery.isNotEmpty) params['q'] = _searchQuery;
      final res = await _api.get('/api/clubs', params: params);
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _clubs = (res['data'] as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('俱乐部')),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _loadClubs();
              },
              decoration: InputDecoration(
                hintText: '搜索俱乐部...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          _loadClubs();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _clubs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.groups, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('还没有俱乐部', style: TextStyle(color: Colors.grey.shade500)),
                            const SizedBox(height: 8),
                            Text('创建一个俱乐部，约上球友一起运动', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, '/club/create'),
                              icon: const Icon(Icons.add),
                              label: const Text('创建俱乐部'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _clubs.length,
                        itemBuilder: (ctx, i) => _buildClubCard(_clubs[i]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/club/create'),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('创建俱乐部', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildClubCard(Map<String, dynamic> club) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, '/club/detail', arguments: club['id'] ?? ''),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primary.withOpacity(0.2),
                child: Text(
                  (club['name'] ?? '?').toString().substring(0, 1),
                  style: const TextStyle(fontSize: 24, color: AppTheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(club['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        if (club['is_certified'] == true) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: Colors.blue, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(club['description'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 13), maxLines: 1),
                  ],
                ),
              ),
              Column(
                children: [
                  const Icon(Icons.people, color: AppTheme.primary, size: 20),
                  Text('${club['member_count'] ?? 1}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 创建俱乐部页面
class CreateClubPage extends StatefulWidget {
  const CreateClubPage({super.key});

  @override
  State<CreateClubPage> createState() => _CreateClubPageState();
}

class _CreateClubPageState extends State<CreateClubPage> {
  final _nameCtrl = TextEditingController();
  final _sloganCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  List<String> _sports = [];
  bool _loading = false;
  final _api = ApiClient();

  final _allSports = ['篮球', '足球', '羽毛球', '网球', '乒乓球', '跑步', '游泳', '滑板', '瑜伽', '健身', '骑行', '徒步'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sloganCtrl.dispose();
    _descCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写俱乐部名称')),
      );
      return;
    }
    if (_sports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择至少一个运动项目')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final auth = context.read<AuthProvider>();
      if (!auth.isLoggedIn) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先登录')),
          );
        }
        setState(() => _loading = false);
        return;
      }

      final res = await _api.post('/api/clubs', data: {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.isNotEmpty ? _descCtrl.text.trim() : null,
        'slogan': _sloganCtrl.text.isNotEmpty ? _sloganCtrl.text.trim() : null,
        'sport_types': _sports,
        'contact': _contactCtrl.text.isNotEmpty ? _contactCtrl.text.trim() : null,
        'creator_id': auth.user!['user_id'],
      });

      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('俱乐部创建成功！获得50根启动柴火🔥')),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? '创建失败，请重试')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('创建失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建俱乐部')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '俱乐部名称', hintText: '例如：朝阳篮球俱乐部'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _sloganCtrl,
                decoration: const InputDecoration(labelText: '俱乐部口号（选填）', hintText: '热血青春，球场见！'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '俱乐部介绍（选填）', alignLabelWithHint: true),
              ),
              const SizedBox(height: 16),

              const Text('运动项目', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _allSports.map((s) => FilterChip(
                  label: Text(s),
                  selected: _sports.contains(s),
                  selectedColor: AppTheme.primary.withOpacity(0.15),
                  onSelected: (v) {
                    setState(() {
                      v ? _sports.add(s) : _sports.remove(s);
                    });
                  },
                )).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contactCtrl,
                decoration: const InputDecoration(
                  labelText: '联系方式（选填）',
                  hintText: '微信/手机号',
                  prefixIcon: Icon(Icons.contact_phone_outlined),
                ),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.local_fire_department, color: AppTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '创建俱乐部即可获得50根柴火启动资金！俱乐部满10人/50人/100人可获得对应勋章。',
                        style: TextStyle(fontSize: 12, color: AppTheme.warmBrown),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _create,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('创建俱乐部，获得50根柴火🔥'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
