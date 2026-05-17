import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'features/auth/auth_page.dart';
import 'features/profile/profile_page.dart';
import 'features/venue/publish_venue_page.dart';
import 'features/venue/venue_detail_page.dart';
import 'features/club/club_page.dart';
import 'features/club/club_detail_page.dart';
import 'features/map/map_page.dart';
import 'features/profile/notifications_page.dart';
import 'features/payment/recharge_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  final auth = AuthProvider(api);
  // 启动时恢复登录状态
  await auth.init();
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
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
        '/venue/detail': (ctx) => VenueDetailPage(
          venueId: ModalRoute.of(ctx)!.settings.arguments as String,
        ),
        '/venue/list': (ctx) => const DiscoverPage(),
        '/club/create': (ctx) => const CreateClubPage(),
        '/club/detail': (ctx) => ClubDetailPage(
          clubId: ModalRoute.of(ctx)!.settings.arguments as String,
        ),
        '/recharge': (ctx) => const RechargePage(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DiscoverPage(),
    const MapPage(),
    const ClubsPage(),
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

// ===== Discover Page =====
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _api = ApiClient();
  List<dynamic> _venues = [];
  bool _loading = true;
  String _city = '全国';
  String _selectedType = '';
  String _sort = 'chaihuo';

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  Future<void> _loadVenues() async {
    try {
      final params = <String, String>{'sort': _sort, 'limit': '20'};
      if (_selectedType.isNotEmpty) params['type'] = _selectedType;
      final res = await _api.get('/api/venues', params: params);
      if (res['success'] == true && res['data'] != null) {
        setState(() { _venues = res['data'] as List<dynamic>; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showFilterDialog(BuildContext context) {
    String tempType = _selectedType;
    String tempSort = _sort;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('筛选', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('运动类型', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: ['', '篮球', '足球', '羽毛球', '网球', '乒乓球', '跑步', '游泳', '滑板', '健身', '其他'].map((t) => ChoiceChip(
                  label: Text(t.isEmpty ? '全部' : t, style: const TextStyle(fontSize: 13)),
                  selected: tempType == t,
                  onSelected: (v) => setSheetState(() => tempType = v ? t : ''),
                )).toList(),
              ),
              const SizedBox(height: 16),
              const Text('排序', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [['chaihuo', '🔥 柴火最多'], ['newest', '🆕 最新发布'], ['distance', '📍 距离最近']].map((opt) => ChoiceChip(
                  label: Text(opt[1]),
                  selected: tempSort == opt[0],
                  onSelected: (v) => setSheetState(() => tempSort = opt[0]),
                )).toList(),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () {
                  Navigator.pop(ctx);
                  setState(() { _selectedType = tempType; _sort = tempSort; });
                  _loadVenues();
                }, child: const Text('确定'))),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('堆柴'),
        actions: [
          if (!auth.isLoggedIn)
            TextButton(onPressed: () => Navigator.pushNamed(context, '/login'), child: const Text('登录'))
          else
            IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
            }),
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
                    TextField(
                      decoration: InputDecoration(
                        hintText: '搜索场地、俱乐部...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.tune, color: _selectedType.isNotEmpty ? AppTheme.primary : null),
                          onPressed: () => _showFilterDialog(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: ['🔥 推荐', '🏀 篮球', '⚽ 足球', '🏸 羽毛球', '🎾 网球', '🏃 跑步'].map((t) =>
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(t, style: const TextStyle(fontSize: 13)),
                              selected: false,
                              selectedColor: AppTheme.primary.withOpacity(0.15),
                              onSelected: (_) {},
                            ),
                          )
                        ).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final cities = ['全国', '北京', '上海', '广州', '深圳', '杭州', '成都', '武汉', '南京', '重庆', '西安'];
                        final result = await showDialog<String>(
                          context: context,
                          builder: (ctx) => SimpleDialog(
                            title: const Text('选择城市'),
                            children: cities.map((c) => SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, c),
                              child: Text(c, style: TextStyle(
                                fontSize: 16,
                                color: c == _city ? AppTheme.primary : null,
                                fontWeight: c == _city ? FontWeight.bold : null,
                              )),
                            )).toList(),
                          ),
                        );
                        if (result != null) setState(() { _city = result; });
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(_city, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🔥 热门场地', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        TextButton(onPressed: () => Navigator.pushNamed(context, '/venue/list'), child: const Text('查看全部 >')),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_venues.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stadium_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('还没有场地，来发布第一个吧！', style: TextStyle(color: Colors.grey.shade500)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/publish'),
                        icon: const Icon(Icons.add), label: const Text('发布场地'),
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

  Widget _buildVenueCard(BuildContext context, dynamic venue) {
    final v = venue as Map<String, dynamic>;
    final photos = (v['photos'] as List?)?.cast<String>() ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pushNamed(context, '/venue/detail', arguments: v['id']),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 80, height: 80, color: Colors.grey.shade200,
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
                      Text(v['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('${v['address'] ?? ''} · ${v['type'] ?? ''}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.local_fire_department, color: AppTheme.primary, size: 16),
                        const SizedBox(width: 4),
                        Text('${v['chaihuo_total'] ?? 0}',
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                      ]),
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


