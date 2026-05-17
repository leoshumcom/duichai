import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';

class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});
  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _allBadges = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _api.get('/api/users/me/badges').then((res) {
      if (mounted && res['success'] == true && res['data'] != null) {
        setState(() {
          _allBadges = (res['data']['all'] as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    }).catchError((_) { if (mounted) setState(() => _loading = false); });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('我的勋章')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _allBadges.isEmpty
            ? const Center(child: Text('暂无勋章'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _allBadges.length,
                itemBuilder: (ctx, i) {
                  final b = _allBadges[i];
                  final earned = b['earned'] == true;
                  return Card(
                    child: ListTile(
                      leading: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: earned ? AppTheme.primary : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            _iconForBadge(b['id'] ?? ''),
                            color: Colors.white, size: 24,
                          ),
                        ),
                      ),
                      title: Text(b['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: earned ? Colors.black : Colors.grey)),
                      subtitle: Text(b['description'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      trailing: earned
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                          : Icon(Icons.lock_outline, color: Colors.grey.shade300, size: 20),
                    ),
                  );
                },
              ),
  );

  IconData _iconForBadge(String id) {
    switch (id) {
      case 'pioneer': return Icons.explore;
      case 'venue_100': return Icons.stadium;
      case 'chaihuo_10000': return Icons.local_fire_department;
      case 'top_tipper': return Icons.emoji_events;
      case 'social': return Icons.people;
      case 'auditor': return Icons.verified;
      case 'supplement': return Icons.edit_note;
      default: return Icons.star;
    }
  }
}
