import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';

/// 俱乐部详情页
class ClubDetailPage extends StatefulWidget {
  final String clubId;
  const ClubDetailPage({super.key, required this.clubId});

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

class _ClubDetailPageState extends State<ClubDetailPage> {
  final _api = ApiClient();
  Map<String, dynamic>? _club;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClub();
  }

  Future<void> _loadClub() async {
    try {
      final res = await _api.get('/api/clubs/${widget.clubId}');
      if (res['success'] == true && res['data'] != null) {
        setState(() { _club = res['data']; _loading = false; });
      } else {
        setState(() { _error = res['error']; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _error = '加载失败'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('俱乐部详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _club == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('俱乐部详情')),
        body: Center(child: Text(_error ?? '俱乐部不存在')),
      );
    }

    final c = _club!;
    final sportTypes = (c['sport_types'] as List?)?.cast<String>() ?? [];
    final members = (c['members'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                  ),
                ),
                child: Center(
                  child: Text(
                    (c['name'] ?? '俱乐部').toString().substring(0, 1),
                    style: const TextStyle(fontSize: 64, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(c['name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      if (c['is_certified'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('已认证', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('待审核', style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
                        ),
                    ],
                  ),
                  if (c['slogan'] != null) ...[
                    const SizedBox(height: 4),
                    Text(c['slogan'], style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  ],
                  const SizedBox(height: 12),
                  if (sportTypes.isNotEmpty)
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: sportTypes.map((s) => Chip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                    ),
                  const SizedBox(height: 16),
                  if (c['description'] != null && (c['description'] as String).isNotEmpty) ...[
                    Text(c['description'], style: const TextStyle(fontSize: 14, height: 1.5)),
                    const SizedBox(height: 16),
                  ],
                  // 统计信息
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _statItem(Icons.people, '${c['member_count'] ?? 0}', '成员'),
                          const SizedBox(width: 32),
                          _statItem(Icons.local_fire_department, '${c['chaihuo_total'] ?? 0}', '柴火'),
                          const SizedBox(width: 32),
                          _statItem(Icons.sports, '${sportTypes.length}', '项目'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 成员列表
                  if (members.isNotEmpty) ...[
                    const Text('成员', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...members.map((m) => ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: m['role'] == 'creator' ? AppTheme.primary : Colors.grey.shade300,
                        child: Text(
                          (m['nickname'] ?? '?').toString().substring(0, 1),
                          style: const TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ),
                      title: Text(m['nickname'] ?? '用户'),
                      subtitle: m['role'] == 'creator' ? const Text('创建者', style: TextStyle(fontSize: 12)) : null,
                      dense: true,
                    )),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
