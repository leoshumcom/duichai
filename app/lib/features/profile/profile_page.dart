import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('登录后查看更多', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                icon: const Icon(Icons.login),
                label: const Text('登录 / 注册'),
              ),
            ],
          ),
        ),
      );
    }

    final user = auth.user;
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppTheme.primary,
                      child: Text(
                        (user?['nickname'] ?? '?').toString().substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?['nickname'] ?? '',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(user?['email'] ?? '',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(children: [
                            _buildBadge('Lv.${user?['level'] ?? 1}'),
                            const SizedBox(width: 8),
                            if (user?['role'] == 'owner')
                              _buildBadge('馆主', bg: AppTheme.primary.withOpacity(0.1), fg: AppTheme.primary),
                          ]),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _statItem('🔥', '${user?['chaihuo_balance'] ?? 0}', '柴火余额'),
                    const SizedBox(width: 32),
                    _statItem('📈', 'Lv.${user?['level'] ?? 1}', '用户等级'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _menuItem(Icons.local_fire_department, '我的添柴', () {}),
            _menuItem(Icons.stadium_outlined, '我发布的场地', () {}),
            _menuItem(Icons.groups_outlined, '我的俱乐部', () {}),
            _menuItem(Icons.star_outline, '我的勋章', () {}),
            _menuItem(Icons.person_add_alt_1, '邀请好友', () {}),
            _menuItem(Icons.settings_outlined, '设置', () {}),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () { auth.logout(); Navigator.pushReplacementNamed(context, '/home'); },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('退出登录'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, {Color? bg, Color? fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg ?? AppTheme.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: fg ?? Colors.white)),
    );
  }

  Widget _statItem(String icon, String value, String label) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
