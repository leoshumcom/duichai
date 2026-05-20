import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_page.dart';
import 'my_tips_page.dart';
import 'badges_page.dart';
import 'invite_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _levelInfo;
  bool _levelInfoLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadLevelInfo();
  }

  Future<void> _loadLevelInfo() async {
    try {
      final api = ApiClient();
      final res = await api.get('/api/users/me/level-info');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _levelInfo = res['data'] as Map<String, dynamic>;
          _levelInfoLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _levelInfoLoaded = true);
    }
  }

  Future<void> _showEditProfileDialog(BuildContext context, AuthProvider auth) async {
    final user = auth.user;
    final nickCtrl = TextEditingController(text: user?['nickname'] ?? '');
    final phoneCtrl = TextEditingController(text: user?['phone'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑资料'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nickCtrl, decoration: const InputDecoration(labelText: '昵称')),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '手机号')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        final api = ApiClient();
        final data = <String, dynamic>{};
        if (nickCtrl.text.isNotEmpty) data['nickname'] = nickCtrl.text.trim();
        if (phoneCtrl.text.isNotEmpty) data['phone'] = phoneCtrl.text.trim();
        await api.post('/api/users/me/profile', data: data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('资料更新成功')));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新失败'), backgroundColor: Colors.red));
        }
      }
    }
  }

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
            // ---- 用户信息卡片 ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _showAvatarPicker(context, auth),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: AppTheme.primary,
                            backgroundImage: user?['avatar'] != null ? NetworkImage(user!['avatar']) : null,
                            child: user?['avatar'] == null
                                ? Text((user?['nickname'] ?? '?').toString().substring(0, 1).toUpperCase(),
                                    style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 昵称
                          Text(user?['nickname'] ?? '',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          // 邮箱 (Flexible 防止溢出)
                          Row(
                            children: [
                              Flexible(
                                child: Text(user?['email'] ?? '',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showEditProfileDialog(context, auth),
                                child: Icon(Icons.edit, size: 14, color: AppTheme.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // LV + UID + 角色（横排，可滚动）
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: [
                              _buildBadge('Lv.${user?['level'] ?? 1}'),
                              if (user?['uid'] != null) ...[
                                const SizedBox(width: 6),
                                _buildBadge('UID ${user!['uid']}',
                                    bg: AppTheme.primary.withOpacity(0.1), fg: AppTheme.primary),
                              ],
                              if (user?['role'] == 'owner') ...[
                                const SizedBox(width: 6),
                                _buildBadge('馆主', bg: AppTheme.primary.withOpacity(0.1), fg: AppTheme.primary),
                              ],
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            // ---- 扫脸认证按钮 ----
            Card(
              child: ListTile(
                leading: Icon(Icons.face_retouching_natural, color: AppTheme.primary),
                title: Text(user?['face_authed'] == true ? '✅ 已扫脸认证' : '扫脸认证'),
                subtitle: user?['face_authed'] == true
                    ? Text('性别: ${user?['face_gender'] == 'female' ? '女' : '男'}', style: const TextStyle(fontSize: 12))
                    : const Text('使用摄像头/相册进行人脸认证', style: TextStyle(fontSize: 12)),
                trailing: user?['face_authed'] == true
                    ? Icon(Icons.check_circle, color: Colors.green.shade400)
                    : const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => _showFaceAuthDialog(context, auth, user),
              ),
            ),

            const SizedBox(height: 16),

            // ---- 柴火 + 升级进度卡片 ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 24)),
                              const SizedBox(height: 4),
                              Text('${user?['chaihuo_balance'] ?? 0}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text('柴火余额', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 24)),
                              const SizedBox(height: 4),
                              if (_levelInfo != null && _levelInfo!['current_chaihuo'] != null)
                                Text('${_levelInfo!['current_chaihuo']}',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
                              else
                                Text('${user?['chaihuo_balance'] ?? 0}',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text('柴火值', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // 升级进度条
                    if (_levelInfo != null) ...[
                      const SizedBox(height: 16),
                      _buildLevelProgress(_levelInfo!, user?['level'] ?? 1),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ---- 菜单项 ----
            _menuItem(Icons.local_fire_department, '我的添柴', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTipsPage()));
            }),
            _menuItem(Icons.stadium_outlined, '我发布的场地', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyVenuesPage()));
            }),
            _menuItem(Icons.groups_outlined, '我的俱乐部', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyClubsPage()));
            }),
            _menuItem(Icons.star_outline, '我的勋章', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesPage()));
            }),
            _menuItem(Icons.person_add_alt_1, '邀请好友', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InvitePage()));
            }),
            _menuItem(Icons.settings_outlined, '设置', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
            }),

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
      ),
    );
  }

  Widget _buildLevelProgress(Map<String, dynamic> info, int currentLevel) {
    final isMax = info['is_max_level'] == true;
    final progress = (info['progress_pct'] as num?)?.toDouble() ?? 0;
    final currentChaihuo = (info['current_chaihuo'] as num?)?.toInt() ?? 0;
    final nextMin = (info['next_min_chaihuo'] as num?)?.toInt() ?? 0;
    final curMin = (info['current_level'] as num?)?.toInt() == 1 ? 0 : null; // not used directly

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(info['current_name'] ?? 'Lv.$currentLevel',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(
              isMax ? '已达最高等级 🎉' : '下一级: ${info['next_name'] ?? ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (progress / 100.0).clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isMax
              ? '已累计获得 $currentChaihuo 🔥'
              : '还需 ${nextMin - currentChaihuo} 柴火升级至 ${info['next_name'] ?? ''}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Future<void> _showAvatarPicker(BuildContext context, AuthProvider auth) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (file == null) return;

    try {
      final bytes = await file.readAsBytes();
      final fileName = 'avatar_${auth.user!['user_id']}.jpg';
      final dio = Dio(BaseOptions(baseUrl: 'https://api.duichai.com'));
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
        'user_id': auth.user!['user_id'],
      });
      final uploadRes = await dio.post('/api/upload', data: formData);

      if (uploadRes.data['success'] == true) {
        final avatarUrl = uploadRes.data['data']['url'] as String;
        final api = ApiClient();
        await api.post('/api/users/me/avatar', data: {'avatar_url': avatarUrl});
        // 强制刷新用户数据
        await auth.refreshUser();
        // 如果 refreshUser 没有返回头像，手动设置
        if (auth.user?['avatar'] == null || (auth.user?['avatar'] as String).isEmpty) {
          auth.user?['avatar'] = avatarUrl;
          auth.notifyListeners();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('头像更新成功')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('上传失败，请重试'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('头像上传失败，请检查网络'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showFaceAuthDialog(BuildContext context, AuthProvider auth, Map<String, dynamic>? user) async {
    if (user?['face_authed'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('您已完成扫脸认证')),
      );
      return;
    }

    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('扫脸认证'),
        content: const Text('请选择拍照或从相册选择一张正脸照片'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ImageSource.camera), child: const Text('拍照')),
          TextButton(onPressed: () => Navigator.pop(ctx, ImageSource.gallery), child: const Text('相册')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
    if (source == null) return;

    final file = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
    if (file == null) return;

    try {
      // 展示加载中
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final bytes = await file.readAsBytes();
      String binary = '';
      bytes.forEach((byte) { binary += String.fromCharCode(byte); });
      final imageBase64 = base64Encode(bytes);

      // 上传到 /api/face/detect 检测
      final api = ApiClient();
      final detectRes = await api.post('/api/face/detect', data: {
        'image_base64': imageBase64,
      });

      // 关闭加载对话框
      if (mounted) Navigator.pop(context);

      if (detectRes['success'] == true && detectRes['data'] != null) {
        final faceData = detectRes['data'] as Map<String, dynamic>;
        final gender = faceData['gender'] as String? ?? 'male';
        final age = faceData['age'] as int? ?? 0;
        final genderDisplay = gender == 'female' ? '女' : '男';
        final frameDisplay = gender == 'female' ? '🎀 头像框' : '⭐ 头像框';

        // 确认对话框
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('扫脸结果'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('性别: $genderDisplay'),
                Text('年龄: ${age}岁'),
                const SizedBox(height: 8),
                Text('将分配: $frameDisplay', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认认证')),
            ],
          ),
        );

        if (confirmed == true) {
          // 调用 /api/face/auth 完成认证注册
          final authRes = await api.post('/api/face/auth', data: {
            'image_base64': imageBase64,
          });

          if (authRes['success'] == true) {
            await auth.refreshUser();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('扫脸认证成功！')),
              );
              setState(() {});
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(authRes['error'] ?? '认证失败'), backgroundColor: Colors.red),
              );
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(detectRes['error'] ?? '未检测到人脸'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭可能还在的加载框
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('扫脸认证失败，请检查网络'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildBadge(String text, {Color? bg, Color? fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg ?? AppTheme.primary, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 12, color: fg ?? Colors.white)),
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

/// 我发布的场地页面
class MyVenuesPage extends StatefulWidget {
  const MyVenuesPage({super.key});

  @override
  State<MyVenuesPage> createState() => _MyVenuesPageState();
}

class _MyVenuesPageState extends State<MyVenuesPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _venues = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  Future<void> _loadVenues() async {
    try {
      final res = await _api.get('/api/users/me/venues');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _venues = (res['data'] as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我发布的场地')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _venues.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stadium_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('还没有发布场地', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _venues.length,
                  itemBuilder: (ctx, i) {
                    final v = _venues[i];
                    final photos = (v['photos'] as List?)?.cast<String>() ?? [];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 60, height: 60, color: Colors.grey.shade200,
                            child: photos.isNotEmpty
                                ? Image.network(photos[0], fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.sports_basketball))
                                : const Icon(Icons.sports_basketball, color: Colors.grey),
                          ),
                        ),
                        title: Text(v['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v['address'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: AppTheme.primary, size: 14),
                                const SizedBox(width: 2),
                                Text('${v['chaihuo_total'] ?? 0}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: v['status'] == 'approved' ? Colors.green.shade50 : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    v['status'] == 'approved' ? '已发布' : (v['status'] == 'pending' ? '审核中' : v['status'] ?? ''),
                                    style: TextStyle(fontSize: 11, color: v['status'] == 'approved' ? Colors.green : Colors.orange, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () => Navigator.pushNamed(context, '/venue/detail', arguments: v['id']),
                      ),
                    );
                  },
                ),
    );
  }
}

/// 我的俱乐部页面
class MyClubsPage extends StatefulWidget {
  const MyClubsPage({super.key});

  @override
  State<MyClubsPage> createState() => _MyClubsPageState();
}

class _MyClubsPageState extends State<MyClubsPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _clubs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  Future<void> _loadClubs() async {
    try {
      final res = await _api.get('/api/users/me/clubs');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _clubs = (res['data'] as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的俱乐部')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _clubs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('还没有加入俱乐部', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _clubs.length,
                  itemBuilder: (ctx, i) {
                    final c = _clubs[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withOpacity(0.2),
                          child: Text((c['name'] ?? '?').toString().substring(0, 1),
                              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                        ),
                        title: Row(
                          children: [
                            Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (c['role'] != null) ...[const SizedBox(width: 6), Text('(${c['role']})', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))],
                          ],
                        ),
                        subtitle: Text('${c['member_count'] ?? 1} 人 · 🔥${c['chaihuo_total'] ?? 0}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () => Navigator.pushNamed(context, '/club/detail', arguments: c['id']),
                      ),
                    );
                  },
                ),
    );
  }
}
