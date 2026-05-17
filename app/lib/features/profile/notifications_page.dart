import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  int _unreadCount = 0;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.get('/api/users/me/notifications', params: {
        'page': _page.toString(), 'limit': '20'
      });
      if (res['success'] == true && res['data'] != null) {
        final items = (res['data'] as List).cast<Map<String, dynamic>>();
        setState(() {
          _notifications.addAll(items);
          _unreadCount = res['unread_count'] ?? 0;
          _hasMore = items.length >= 20;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    await _api.post('/api/users/me/notifications/read', data: {});
    setState(() {
      for (var n in _notifications) { n['is_read'] = 1; }
      _unreadCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('通知'),
      actions: [
        if (_unreadCount > 0)
          TextButton(onPressed: _markAllRead, child: const Text('全部已读')),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _notifications.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('暂无通知', style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _notifications.length + (_hasMore ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i >= _notifications.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  final n = _notifications[i];
                  final isRead = n['is_read'] == 1;
                  return Card(
                    color: isRead ? null : AppTheme.primary.withOpacity(0.03),
                    child: ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: isRead ? Colors.grey.shade100 : AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_iconForType(n['type'] ?? ''),
                            color: isRead ? Colors.grey : AppTheme.primary, size: 20),
                      ),
                      title: Text(n['title'] ?? '', style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                        fontSize: 14,
                      )),
                      subtitle: n['body'] != null
                          ? Text(n['body'], style: TextStyle(fontSize: 12, color: Colors.grey.shade500), maxLines: 2)
                          : null,
                      trailing: Text(_formatDate(n['created_at']),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    ),
                  );
                },
              ),
  );

  IconData _iconForType(String type) {
    switch (type) {
      case 'tip': return Icons.local_fire_department;
      case 'venue': return Icons.stadium;
      case 'club': return Icons.groups;
      case 'system': return Icons.info_outline;
      default: return Icons.notifications;
    }
  }

  String _formatDate(String? dt) {
    if (dt == null) return '';
    try { return dt.substring(0, 16).replaceAll('T', ' '); } catch (_) { return dt!; }
  }
}
