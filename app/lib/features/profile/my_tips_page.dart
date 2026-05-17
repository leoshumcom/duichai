import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';

class MyTipsPage extends StatefulWidget {
  const MyTipsPage({super.key});
  @override
  State<MyTipsPage> createState() => _MyTipsPageState();
}

class _MyTipsPageState extends State<MyTipsPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _tips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _api.get('/api/users/me/tips').then((res) {
      if (mounted) setState(() {
        if (res['success'] == true) _tips = (res['data'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    }).catchError((_) { if (mounted) setState(() => _loading = false); });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('我的添柴')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _tips.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_fire_department, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('还没有添过柴', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('去喜欢的场地添一把🔥', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _tips.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final t = _tips[i];
                  final photos = (t['venue_photos'] as List?)?.cast<String>() ?? [];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 48, height: 48, color: Colors.grey.shade100,
                        child: photos.isNotEmpty
                            ? Image.network(photos[0], fit: BoxFit.cover)
                            : const Icon(Icons.stadium_outlined, color: Colors.grey),
                      ),
                    ),
                    title: Text(t['venue_name'] ?? '场地', style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${t['description'] ?? '添柴'} · ${_formatDate(t['created_at'])}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('🔥 ${t['amount'] ?? 0}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
  );

  String _formatDate(String? dt) {
    if (dt == null) return '';
    try {
      return dt.substring(0, 10);
    } catch (_) {
      return dt;
    }
  }
}
