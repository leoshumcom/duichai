import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';

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
  int _memberPage = 1;
  bool _loadingMembers = false;

  @override
  void initState() {
    super.initState();
    _loadClub();
  }

  Future<void> _loadClub() async {
    try {
      final res = await _api.get('/api/clubs/${widget.clubId}', params: {
        'page': _memberPage.toString(), 'limit': '20',
      });
      if (res['success'] == true && res['data'] != null) {
        setState(() { _club = res['data']; _loading = false; });
      } else {
        setState(() { _error = res['error']; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'load failed'; _loading = false; });
    }
  }

  Future<void> _loadMoreMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final nextPage = _memberPage + 1;
      final res = await _api.get('/api/clubs/${widget.clubId}', params: {
        'page': nextPage.toString(), 'limit': '20',
      });
      if (res['success'] == true && res['data'] != null) {
        final existing = (_club!['members'] as List).cast<Map<String, dynamic>>();
        final newMembers = (res['data']['members'] as List).cast<Map<String, dynamic>>();
        setState(() {
          _club!['members'] = [...existing, ...newMembers];
          _club!['member_count'] = res['data']['member_count'] ?? _club!['member_count'];
          _memberPage = nextPage;
          _loadingMembers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Club')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _club == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Club')),
        body: Center(child: Text(_error ?? 'Not found')),
      );
    }

    final c = _club!;
    final sportTypes = (c['sport_types'] as List?)?.cast<String>() ?? [];
    final members = (c['members'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totalMembers = c['member_count'] ?? members.length;

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
                    (c['name'] ?? 'C').toString().substring(0, 1).toUpperCase(),
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
                        _badge('Certified')
                      else
                        _badge('Pending'),
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _statItem(Icons.people, '${totalMembers}', 'Members'),
                          const SizedBox(width: 32),
                          _statItem(Icons.local_fire_department, '${c['chaihuo_total'] ?? 0}', 'Chaihuo'),
                          const SizedBox(width: 32),
                          _statItem(Icons.sports, '${sportTypes.length}', 'Sports'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Members section
                  if (members.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Members ($totalMembers)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        if (_loadingMembers)
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        else if (members.length < totalMembers)
                          TextButton(
                            onPressed: _loadMoreMembers,
                            child: const Text('Show all >', style: TextStyle(fontSize: 13)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...(members.length > 10 ? members.sublist(0, 10) : members).map((m) => ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: m['role'] == 'creator' ? AppTheme.primary : Colors.grey.shade300,
                        child: Text(
                          (m['nickname'] ?? '?').toString().substring(0, 1),
                          style: const TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ),
                      title: Text(m['nickname'] ?? 'User'),
                      subtitle: m['role'] == 'creator'
                          ? const Text('Creator', style: TextStyle(fontSize: 12, color: AppTheme.primary))
                          : null,
                      dense: true,
                    )),
                    if (members.length < totalMembers && members.length > 10)
                      Center(
                        child: TextButton.icon(
                          onPressed: _loadMoreMembers,
                          icon: const Icon(Icons.expand_more),
                          label: Text('Show ${totalMembers - members.length} more'),
                        ),
                      ),
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

  Widget _badge(String text) {
    final bool certified = text == 'Certified';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: certified ? Colors.blue.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(
        fontSize: 12,
        color: certified ? Colors.blue.shade700 : Colors.orange.shade700)),
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

