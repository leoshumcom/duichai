import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline, color: AppTheme.primary),
                  title: const Text('编辑资料'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    // 复用个人中心的编辑弹窗
                    final user = auth.user;
                    final nickCtrl = TextEditingController(text: user?['nickname'] ?? '');
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('编辑资料'),
                        content: TextField(controller: nickCtrl, decoration: const InputDecoration(labelText: '昵称')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('保存')),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined, color: AppTheme.primary),
                  title: const Text('通知设置'),
                  subtitle: const Text('已开启'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('通知开关功能开发中')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: AppTheme.primary),
                  title: const Text('隐私政策'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('隐私政策页面即将上线')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppTheme.primary),
                  title: const Text('关于堆柴'),
                  subtitle: const Text('v0.1.0'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: '堆柴',
                    applicationVersion: '0.1.0',
                    applicationLegalese: '众人拾柴火焰高',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await auth.logout();
                if (context.mounted) Navigator.pushReplacementNamed(context, '/home');
              },
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('退出登录'),
            ),
          ),
        ],
      ),
    );
  }
}
