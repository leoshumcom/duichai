import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_page.dart';
import 'package:provider/provider.dart';

class InvitePage extends StatefulWidget {
  const InvitePage({super.key});
  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  final _api = ApiClient();
  String _inviteCode = '';
  String _inviteLink = '';
  int _uid = 0;
  int _inviteCount = 0;
  List<Map<String, dynamic>> _invites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = context.read<AuthProvider>();
      final uid = auth.user?['uid'];
      setState(() => _uid = uid ?? 0);

      final res = await _api.get('/api/users/me/invites');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          // 邀请码 = UID数字
          final code = res['data']['invite_code'] ?? '';
          _inviteCode = code;
          _inviteLink = 'https://duichai.com/invite/${_uid}';
          _inviteCount = res['data']['count'] ?? 0;
          _invites = (res['data']['invites'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('邀请好友')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.person_add_alt_1, size: 48, color: AppTheme.primary),
                      const SizedBox(height: 12),
                      const Text('邀请好友加入堆柴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('每成功邀请一位好友，双方各获得10根柴火🔥',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('我的邀请码：', style: TextStyle(color: Colors.grey.shade600)),
                            SelectableText(_uid > 0 ? _uid.toString() : _inviteCode, style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary,
                              letterSpacing: 4,
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final code = _uid > 0 ? _uid.toString() : _inviteCode;
                            Share.share('一起来玩堆柴吧！发现身边的运动场地，众人拾柴火焰高🔥\n'
                                '我的邀请码: $code\n'
                                '注册时输入邀请码，双方各得10根柴火🔥\n'
                                '下载地址: https://duichai.com');
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('分享邀请码'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('已成功邀请 $_inviteCount 人', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_invites.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('还没有邀请记录\n快去分享你的邀请码吧', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                    ),
                  ),
                )
              else
                ..._invites.map((i) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: Text((i['invitee_name'] ?? '?').toString().substring(0, 1),
                          style: const TextStyle(color: AppTheme.primary)),
                    ),
                    title: Text(i['invitee_name'] ?? '好友'),
                    subtitle: Text('+${i['reward_chaihuo'] ?? 10}根柴火', style: const TextStyle(color: AppTheme.primary)),
                  ),
                )),
            ],
          ),
  );
}
