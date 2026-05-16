import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

/// 认证状态管理
class AuthProvider extends ChangeNotifier {
  final ApiClient _api;
  String? _token;
  Map<String, dynamic>? _user;

  AuthProvider(this._api);

  bool get isLoggedIn => _token != null;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;

  Future<Map<String, dynamic>> register(String email, String password, String nickname) async {
    final res = await _api.post('/api/auth/register', data: {
      'email': email,
      'password': password,
      'nickname': nickname,
    });
    return res;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _api.post('/api/auth/login', data: {
      'email': email,
      'password': password,
    });
    if (res['success'] == true && res['data'] != null) {
      _token = res['data']['token'];
      _user = res['data'];
      _api.setToken(_token!);
      notifyListeners();
    }
    return res;
  }

  void logout() {
    _token = null;
    _user = null;
    _api.clearToken();
    notifyListeners();
  }
}

/// 登录页面
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _pwdCtrl.text.isEmpty) {
      setState(() => _error = '请填写邮箱和密码');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final res = await auth.login(_emailCtrl.text.trim(), _pwdCtrl.text);

      if (res['success'] == true) {
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() => _error = res['error'] ?? '登录失败');
      }
    } catch (e) {
      setState(() => _error = '网络错误，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 80),
              // Logo
              Text(
                '堆柴',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: 4,
                ),
              ),
              const Text(
                '众人拾柴火焰高',
                style: TextStyle(fontSize: 14, color: AppTheme.warmBrown),
              ),
              const SizedBox(height: 60),

              // 邮箱输入
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: '邮箱',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // 密码输入
              TextField(
                controller: _pwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('忘记密码？', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: 24),

              // 登录按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('登录'),
                ),
              ),
              const SizedBox(height: 16),

              // 注册入口
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('还没有账号？', style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: const Text('立即注册'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 注册页面
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _nickCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_emailCtrl.text.isEmpty || _pwdCtrl.text.isEmpty || _nickCtrl.text.isEmpty) {
      setState(() => _error = '请填写邮箱、密码和昵称');
      return;
    }
    if (_pwdCtrl.text.length < 6) {
      setState(() => _error = '密码至少6位');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final auth = context.read<AuthProvider>();
      final res = await auth.register(
        _emailCtrl.text.trim(),
        _pwdCtrl.text,
        _nickCtrl.text.trim(),
      );

      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('注册成功，请登录')),
          );
          Navigator.pop(context);
        }
      } else {
        setState(() => _error = res['error'] ?? '注册失败');
      }
    } catch (e) {
      setState(() => _error = '网络错误，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '邮箱', prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nickCtrl,
                decoration: const InputDecoration(labelText: '昵称', prefixIcon: Icon(Icons.person_outlined)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '手机号（选填）', prefixIcon: Icon(Icons.phone_outlined)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock_outlined)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('注册'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
