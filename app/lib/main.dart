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
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  Future<void> _loadVenues() async {
    try {
      final params = <String, String>{'sort': _sort, 'limit': '20'};
      if (_selectedType.isNotEmpty) params['type'] = _selectedType;
      if (_city != '全国') params['city'] = _city;
      if (_searchQuery.isNotEmpty) params['q'] = _searchQuery;
      final res = await _api.get('/api/venues', params: params);
      if (res['success'] == true && res['data'] != null) {
        setState(() { _venues = res['data'] as List<dynamic>; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== 城市选择器：省-市二级联动 =====
  static const Map<String, List<String>> _chinaCities = {
    '北京市': ['北京'],
    '天津市': ['天津'],
    '上海市': ['上海'],
    '重庆市': ['重庆'],
    '河北省': ['石家庄', '唐山', '秦皇岛', '邯郸', '保定', '张家口', '承德', '沧州', '廊坊', '衡水'],
    '山西省': ['太原', '大同', '阳泉', '长治', '晋城', '朔州', '晋中', '运城', '忻州', '临汾', '吕梁'],
    '内蒙古': ['呼和浩特', '包头', '乌海', '赤峰', '通辽', '鄂尔多斯', '呼伦贝尔', '巴彦淖尔', '乌兰察布'],
    '辽宁省': ['沈阳', '大连', '鞍山', '抚顺', '本溪', '丹东', '锦州', '营口', '阜新', '辽阳', '盘锦', '铁岭', '朝阳', '葫芦岛'],
    '吉林省': ['长春', '吉林', '四平', '辽源', '通化', '白山', '松原', '白城', '延边'],
    '黑龙江省': ['哈尔滨', '齐齐哈尔', '鸡西', '鹤岗', '双鸭山', '大庆', '伊春', '佳木斯', '七台河', '牡丹江', '黑河', '绥化'],
    '江苏省': ['南京', '无锡', '徐州', '常州', '苏州', '南通', '连云港', '淮安', '盐城', '扬州', '镇江', '泰州', '宿迁'],
    '浙江省': ['杭州', '宁波', '温州', '嘉兴', '湖州', '绍兴', '金华', '衢州', '舟山', '台州', '丽水'],
    '安徽省': ['合肥', '芜湖', '蚌埠', '淮南', '马鞍山', '淮北', '铜陵', '安庆', '黄山', '滁州', '阜阳', '宿州', '六安', '亳州', '池州', '宣城'],
    '福建省': ['福州', '厦门', '莆田', '三明', '泉州', '漳州', '南平', '龙岩', '宁德'],
    '江西省': ['南昌', '景德镇', '萍乡', '九江', '新余', '鹰潭', '赣州', '吉安', '宜春', '抚州', '上饶'],
    '山东省': ['济南', '青岛', '淄博', '枣庄', '东营', '烟台', '潍坊', '济宁', '泰安', '威海', '日照', '临沂', '德州', '聊城', '滨州', '菏泽'],
    '河南省': ['郑州', '开封', '洛阳', '平顶山', '安阳', '鹤壁', '新乡', '焦作', '濮阳', '许昌', '漯河', '三门峡', '南阳', '商丘', '信阳', '周口', '驻马店'],
    '湖北省': ['武汉', '黄石', '十堰', '宜昌', '襄阳', '鄂州', '荆门', '孝感', '荆州', '黄冈', '咸宁', '随州', '恩施'],
    '湖南省': ['长沙', '株洲', '湘潭', '衡阳', '邵阳', '岳阳', '常德', '张家界', '益阳', '郴州', '永州', '怀化', '娄底', '湘西'],
    '广东省': ['广州', '深圳', '珠海', '汕头', '佛山', '韶关', '湛江', '肇庆', '江门', '茂名', '惠州', '梅州', '汕尾', '河源', '阳江', '清远', '东莞', '中山', '潮州', '揭阳', '云浮'],
    '广西壮族自治区': ['南宁', '柳州', '桂林', '梧州', '北海', '防城港', '钦州', '贵港', '玉林', '百色', '贺州', '河池', '来宾', '崇左'],
    '海南省': ['海口', '三亚', '三沙', '儋州'],
    '四川省': ['成都', '自贡', '攀枝花', '泸州', '德阳', '绵阳', '广元', '遂宁', '内江', '乐山', '南充', '眉山', '宜宾', '广安', '达州', '雅安', '巴中', '资阳'],
    '贵州省': ['贵阳', '六盘水', '遵义', '安顺', '毕节', '铜仁', '黔西南', '黔东南', '黔南'],
    '云南省': ['昆明', '曲靖', '玉溪', '保山', '昭通', '丽江', '普洱', '临沧', '楚雄', '红河', '文山', '西双版纳', '大理', '德宏', '怒江', '迪庆'],
    '西藏自治区': ['拉萨', '日喀则', '昌都', '林芝', '山南', '那曲', '阿里'],
    '陕西省': ['西安', '铜川', '宝鸡', '咸阳', '渭南', '延安', '汉中', '榆林', '安康', '商洛'],
    '甘肃省': ['兰州', '嘉峪关', '金昌', '白银', '天水', '武威', '张掖', '平凉', '酒泉', '庆阳', '定西', '陇南', '临夏', '甘南'],
    '青海省': ['西宁', '海东', '海北', '黄南', '海南', '果洛', '玉树', '海西'],
    '宁夏回族自治区': ['银川', '石嘴山', '吴忠', '固原', '中卫'],
    '新疆维吾尔自治区': ['乌鲁木齐', '克拉玛依', '吐鲁番', '哈密', '昌吉', '博尔塔拉', '巴音郭楞', '阿克苏', '克孜勒苏', '喀什', '和田', '伊犁', '塔城', '阿勒泰'],
    '香港特别行政区': ['香港'],
    '澳门特别行政区': ['澳门'],
    '台湾省': ['台北', '新北', '桃园', '台中', '台南', '高雄', '基隆', '新竹', '嘉义'],
  };

  /// 返回用户选择的城市名，若取消则返回null（调用方自行判断）
  Future<String?> _showCityPicker(BuildContext context) async {
    String? selectedProvince;
    final provinces = ['全国', ..._chinaCities.keys];

    // Step 1: 选择省份
    selectedProvince = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择省份'),
        children: provinces.map((p) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, p),
          child: Text(p, style: TextStyle(
            fontSize: 16,
            color: p == _city || _chinaCities[p]?.contains(_city) == true ? AppTheme.primary : null,
            fontWeight: p == _city || _chinaCities[p]?.contains(_city) == true ? FontWeight.bold : null,
          )),
        )).toList(),
      ),
    );
    if (selectedProvince == null) return null; // 取消
    if (selectedProvince == '全国') return '全国';

    // Step 2: 选择城市
    final cities = _chinaCities[selectedProvince] ?? [];
    if (cities.length == 1) {
      // 直辖市直接返回
      return cities[0];
    }

    final selectedCity = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('选择城市 - $selectedProvince'),
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
    return selectedCity;
  }

  void _showFilterDialog(BuildContext context) {
    String tempType = _selectedType;
    String tempSort = _sort;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
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
                      controller: _searchCtrl,
                      onChanged: (v) {
                        setState(() => _searchQuery = v);
                        _loadVenues();
                      },
                      decoration: InputDecoration(
                        hintText: '搜索场地、俱乐部...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                  _loadVenues();
                                },
                              ),
                            IconButton(
                              icon: Icon(Icons.tune, size: 22, color: _selectedType.isNotEmpty ? AppTheme.primary : null),
                              onPressed: () => _showFilterDialog(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: ['🔥 推荐', '🏀 篮球', '⚽ 足球', '🏸 羽毛球', '🎾 网球', '🏃 跑步'].map((t) {
                          final tag = t.substring(2);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(t, style: const TextStyle(fontSize: 13)),
                              selected: _selectedType == tag || (t == '🔥 推荐' && _selectedType.isEmpty),
                              selectedColor: AppTheme.primary.withOpacity(0.15),
                              onSelected: (_) {
                                setState(() {
                                  _selectedType = t == '🔥 推荐' ? '' : tag;
                                });
                                _loadVenues();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final result = await _showCityPicker(context);
                        if (result != null && result != _city) {
                          debugPrint('city filter: $_city -> $result');
                          setState(() { _city = result; });
                          _loadVenues();
                        }
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


