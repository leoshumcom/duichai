import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'features/auth/auth_page.dart';
import 'features/profile/profile_page.dart';
import 'features/venue/publish_venue_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => ApiClient()),
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<ApiClient>()),
        ),
      ],
      child: const DuichaiApp(),
    ),
  );
}

class DuichaiApp extends StatelessWidget {
  const DuichaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '堆柴',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      initialRoute: '/home',
      routes: {
        '/home': (ctx) => const MainScreen(),
        '/login': (ctx) => const LoginPage(),
        '/register': (ctx) => const RegisterPage(),
        '/publish': (ctx) => const PublishVenuePage(),
      },
    );
  }
}

/// 主页面（底部导航）
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DiscoverPage(),
    const VenueMapPage(),
    const ClubsPageSimple(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '发现'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '地图'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: '俱乐部'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}

/// 发现页
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _api = ApiClient();
  List<dynamic> _venues = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  Future<void> _loadVenues() async {
    try {
      final res = await _api.get('/api/venues', params: {'sort': 'chaihuo', 'limit': '20'});
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _venues = res['data'] as List<dynamic>;
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('堆柴'),
        actions: [
          if (!auth.isLoggedIn)
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('登录'),
            )
          else
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
            ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 搜索
                    TextField(
                      decoration: InputDecoration(
                        hintText: '搜索场地、俱乐部...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: const Icon(Icons.tune),
                      ),
                      onTap: () {},
                    ),
                    const SizedBox(height: 20),

                    // 分类标签
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildTag('🔥 推荐', true),
                          _buildTag('🏀 篮球', false),
                          _buildTag('⚽ 足球', false),
                          _buildTag('🏸 羽毛球', false),
                          _buildTag('🎾 网球', false),
                          _buildTag('🏃 跑步', false),
                          _buildTag('🛹 滑板', false),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 热门标题
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🔥 热门场地',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        TextButton(onPressed: () {}, child: const Text('查看全部 >')),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // 场地列表
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_venues.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stadium_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('还没有场地，来发布第一个吧！',
                          style: TextStyle(color: Colors.grey.shade500)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/publish'),
                        icon: const Icon(Icons.add),
                        label: const Text('发布场地'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildVenueCard(context, _venues[i]),
                  childCount: _venues.length,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/publish'),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('发布场地', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildTag(String label, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isActive,
        selectedColor: AppTheme.primary.withOpacity(0.15),
        labelStyle: TextStyle(
          color: isActive ? AppTheme.primary : Colors.grey.shade600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildVenueCard(BuildContext context, dynamic venue) {
    final v = venue as Map<String, dynamic>;
    final photos = (v['photos'] as List?)?.cast<String>() ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 缩略图
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey.shade200,
                    child: photos.isNotEmpty
                        ? Image.network(photos[0], fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.sports_basketball, color: Colors.grey))
                        : const Icon(Icons.sports_basketball, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v['name'] ?? '',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${v['address'] ?? '未知位置'} · ${v['type'] ?? ''}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: AppTheme.primary, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${v['chaihuo_total'] ?? 0}',
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          if (v['is_free'] == 1 || v['is_free'] == true) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('免费', style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== 占位页面 =====

class VenueMapPage extends StatelessWidget {
  const VenueMapPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('地图找场')),
    body: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text('地图模块开发中'),],
    )),
  );
}

class ClubsPageSimple extends StatelessWidget {
  const ClubsPageSimple({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('俱乐部')),
    body: const Center(child: Text('俱乐部模块开发中')),
  );
}
