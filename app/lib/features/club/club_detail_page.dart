import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_page.dart';

class ClubDetailPage extends StatefulWidget {
  final String clubId;
  const ClubDetailPage({super.key, required this.clubId});

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

class _ClubDetailPageState extends State<ClubDetailPage> with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  Map<String, dynamic>? _club;
  bool _loading = true;
  String? _error;
  int _memberPage = 1;
  bool _loadingMembers = false;

  // Chat
  List<dynamic> _messages = [];
  bool _loadingMessages = false;
  int _messagePage = 1;
  bool _hasMoreMessages = true;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showMentionPopup = false;
  List<Map<String, dynamic>> _clubMembers = [];

  late TabController _tabController;

  // Join requests
  List<Map<String, dynamic>> _joinRequests = [];
  bool _loadingJoinRequests = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadClub();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClub() async {
    try {
      final res = await _api.get('/api/clubs/${widget.clubId}', params: {
        'page': '$_memberPage', 'limit': '20',
      });
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _club = res['data'];
          _clubMembers = ((res['data']['members'] as List?)?.cast<Map<String, dynamic>>() ?? []);
          _loading = false;
        });
        _loadMessages();
      } else {
        setState(() { _error = res['error']; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _error = '加载失败'; _loading = false; });
    }
  }

  Future<void> _loadMoreMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final nextPage = _memberPage + 1;
      final res = await _api.get('/api/clubs/${widget.clubId}', params: {
        'page': nextPage.toString(), 'limit': '20',
      });
      if (res['success'] == true && res['data'] != null) {
        final existing = (_club!['members'] as List).cast<Map<String, dynamic>>();
        final newMembers = (res['data']['members'] as List).cast<Map<String, dynamic>>();
        setState(() {
          _club!['members'] = [...existing, ...newMembers];
          _club!['member_count'] = res['data']['member_count'] ?? _club!['member_count'];
          _memberPage = nextPage;
          _loadingMembers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  // ===== Join Request Methods =====
  Future<void> _applyJoinClub() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      return;
    }

    try {
      final res = await _api.post('/api/clubs/${widget.clubId}/join-request');
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('申请已提交，等待管理员审核')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? '申请失败')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络错误'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadJoinRequests() async {
    setState(() => _loadingJoinRequests = true);
    try {
      final res = await _api.get('/api/clubs/${widget.clubId}/join-requests');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _joinRequests = (res['data'] as List).cast<Map<String, dynamic>>();
          _loadingJoinRequests = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingJoinRequests = false);
    }
  }

  Future<void> _approveJoinRequest(String requestId) async {
    try {
      final res = await _api.post('/api/clubs/${widget.clubId}/join-request/$requestId/approve');
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已批准加入')),
          );
          _loadJoinRequests();
          _loadClub();
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectJoinRequest(String requestId) async {
    try {
      final res = await _api.post('/api/clubs/${widget.clubId}/join-request/$requestId/reject');
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已拒绝')),
          );
          _loadJoinRequests();
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ===== Chat Methods =====
  Future<void> _loadMessages() async {
    if (_loadingMessages) return;
    setState(() => _loadingMessages = true);
    try {
      final res = await _api.get('/api/clubs/${widget.clubId}/messages', params: {
        'page': '$_messagePage', 'limit': '20',
      });
      if (res['success'] == true && res['data'] != null) {
        final newMessages = res['data'] as List<dynamic>;
        final total = res['total'] as int? ?? 0;
        setState(() {
          // 如果第一页，替换；否则追加到开头（因为接口返回的是倒序翻页）
          if (_messagePage == 1) {
            _messages = newMessages;
          } else {
            _messages = [...newMessages, ..._messages];
          }
          _hasMoreMessages = _messages.length < total;
          _loadingMessages = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  Future<void> _sendMessage() async {
    final content = _msgCtrl.text.trim();
    if (content.isEmpty) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      return;
    }

    try {
      final res = await _api.post('/api/clubs/${widget.clubId}/messages', data: {
        'content': content,
      });
      if (res['success'] == true) {
        _msgCtrl.clear();
        setState(() => _showMentionPopup = false);
        // 刷新消息
        _messagePage = 1;
        await _loadMessages();
        // 滚动到底部
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发送失败'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onMsgTextChanged(String text) {
    // 检测是否输入了@
    final cursorPos = _msgCtrl.selection.baseOffset;
    if (cursorPos >= 0 && cursorPos <= text.length) {
      final beforeCursor = text.substring(0, cursorPos);
      final atIndex = beforeCursor.lastIndexOf('@');
      if (atIndex >= 0 && (atIndex == 0 || beforeCursor[atIndex - 1] == ' ')) {
        final query = beforeCursor.substring(atIndex + 1);
        setState(() {
          _showMentionPopup = true;
        });
      } else {
        setState(() {
          _showMentionPopup = false;
        });
      }
    }
  }

  void _insertMention(Map<String, dynamic> member) {
    final text = _msgCtrl.text;
    final cursorPos = _msgCtrl.selection.baseOffset;
    final beforeCursor = text.substring(0, cursorPos);
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex >= 0) {
      final afterCursor = text.substring(cursorPos);
      final newText = '${text.substring(0, atIndex)}@${member['nickname'] ?? ''}$afterCursor';
      _msgCtrl.text = newText;
      _msgCtrl.selection = TextSelection.collapsed(
        offset: atIndex + (member['nickname'] ?? '').length + 1,
      );
    }
    setState(() => _showMentionPopup = false);
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final dt = DateTime.parse(timeStr);
      return DateFormat('MM-dd HH:mm').format(dt);
    } catch (_) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('俱乐部')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _club == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('俱乐部')),
        body: Center(child: Text(_error ?? '不存在')),
      );
    }

    final c = _club!;
    final sportTypes = (c['sport_types'] as List?)?.cast<String>() ?? [];
    final members = (c['members'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totalMembers = c['member_count'] ?? members.length;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                  ),
                ),
                child: Center(
                  child: Text(
                    (c['name'] ?? 'C').toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 64, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primary,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: '俱乐部详情'),
                  Tab(text: '聊天'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildClubDetail(c, sportTypes, members, totalMembers),
            _buildChatTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildClubDetail(Map<String, dynamic> c, List<String> sportTypes, List<Map<String, dynamic>> members, int totalMembers) {
    final auth = context.watch<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c['name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              if (c['is_certified'] == true)
                _badge('已认证')
              else
                _badge('待认证'),
            ],
          ),
          if (c['slogan'] != null) ...[
            const SizedBox(height: 4),
            Text(c['slogan'], style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ],
          const SizedBox(height: 12),
          if (sportTypes.isNotEmpty)
            Wrap(
              spacing: 6, runSpacing: 6,
              children: sportTypes.map((s) => Chip(
                label: Text(s, style: const TextStyle(fontSize: 12)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
          const SizedBox(height: 16),
          if (c['description'] != null && (c['description'] as String).isNotEmpty) ...[
            Text(c['description'], style: const TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _statItem(Icons.people, '$totalMembers', '成员'),
                  const SizedBox(width: 32),
                  _statItem(Icons.local_fire_department, '${c['chaihuo_total'] ?? 0}', '柴火'),
                  const SizedBox(width: 32),
                  _statItem(Icons.sports, '${sportTypes.length}', '项目'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (members.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('成员 ($totalMembers)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (_loadingMembers)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                else if (members.length < totalMembers)
                  TextButton(
                    onPressed: _loadMoreMembers,
                    child: const Text('查看全部 >', style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...(members.length > 10 ? members.sublist(0, 10) : members).map((m) => ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: m['role'] == 'creator' ? AppTheme.primary : Colors.grey.shade300,
                child: Text(
                  (m['nickname'] ?? '?').toString().substring(0, 1),
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ),
              title: Text(m['nickname'] ?? '用户'),
              subtitle: m['role'] == 'creator'
                  ? const Text('创建者', style: TextStyle(fontSize: 12, color: AppTheme.primary))
                  : null,
              dense: true,
            )),
            if (members.length < totalMembers && members.length > 10)
              Center(
                child: TextButton.icon(
                  onPressed: _loadMoreMembers,
                  icon: const Icon(Icons.expand_more),
                  label: Text('展开 ${totalMembers - members.length} 位成员'),
                ),
              ),

          // 申请加入按钮（非成员显示）
          if (!members.any((m) => m['id'] == auth.user?['user_id'])) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _applyJoinClub,
                icon: const Icon(Icons.person_add),
                label: const Text('申请加入俱乐部'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],

          // 审核申请（仅创建者可见）
          if (c['creator_id'] == auth.user?['user_id']) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('📋 加入审核', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _loadJoinRequests,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('刷新', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            if (_loadingJoinRequests)
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ))
            else if (_joinRequests.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text('暂无待审核的申请', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  ),
                ),
              )
            else
              ..._joinRequests.map((req) {
                final reqStatus = req['status'] as String? ?? 'pending';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.primary.withOpacity(0.2),
                          child: Text(
                            (req['nickname'] ?? '?').toString().substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(req['nickname'] ?? '用户', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Email: ${req['email'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        if (reqStatus == 'pending')
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _approveJoinRequest(req['id']),
                                style: TextButton.styleFrom(foregroundColor: Colors.green),
                                child: const Text('通过', style: TextStyle(fontSize: 13)),
                              ),
                              TextButton(
                                onPressed: () => _rejectJoinRequest(req['id']),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('拒绝', style: TextStyle(fontSize: 13)),
                              ),
                            ],
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: reqStatus == 'approved' ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              reqStatus == 'approved' ? '已通过' : '已拒绝',
                              style: TextStyle(
                                fontSize: 12,
                                color: reqStatus == 'approved' ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    final auth = context.watch<AuthProvider>();
    final isMember = _clubMembers.any((m) => m['id'] == auth.user?['user_id']);

    return Column(
      children: [
        // 消息列表
        Expanded(
          child: _messages.isEmpty && _loadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('暂无消息，快来第一条发言吧！', style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length + (_hasMoreMessages ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i >= _messages.length) {
                          return Padding(
                            padding: const EdgeInsets.all(8),
                            child: Center(
                              child: TextButton(
                                onPressed: () { _messagePage++; _loadMessages(); },
                                child: const Text('加载更多'),
                              ),
                            ),
                          );
                        }
                        final msg = _messages[i] as Map<String, dynamic>;
                        final isMe = msg['user_id'] == auth.user?['user_id'];
                        return _buildMessageBubble(msg, isMe);
                      },
                    ),
        ),

        // @提及弹出列表
        if (_showMentionPopup && _clubMembers.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: ListView(
              shrinkWrap: true,
              children: _clubMembers.map((m) => ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.primary.withOpacity(0.2),
                  child: Text(
                    (m['nickname'] ?? '?').toString().substring(0, 1),
                    style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                  ),
                ),
                title: Text(m['nickname'] ?? '', style: const TextStyle(fontSize: 14)),
                onTap: () => _insertMention(m),
              )).toList(),
            ),
          ),

        // 成员不能发言的提示
        if (!auth.isLoggedIn || !isMember)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  auth.isLoggedIn ? '仅成员可在群内发言' : '请先登录再发言',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
          )
        else
          // 输入框
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: '输入消息... @ 提及',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: AppTheme.primary),
                      ),
                    ),
                    onChanged: _onMsgTextChanged,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  radius: 20,
                  child: IconButton(
                    icon: const Icon(Icons.send, size: 18, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withOpacity(0.2),
              backgroundImage: msg['avatar'] != null ? NetworkImage(msg['avatar']) : null,
              child: msg['avatar'] == null
                  ? Text(
                      (msg['nickname'] ?? '?').toString().substring(0, 1),
                      style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primary : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12).copyWith(
                  bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        msg['nickname'] ?? '用户',
                        style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : AppTheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  Text(
                    msg['content'] ?? '',
                    style: TextStyle(fontSize: 14, color: isMe ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(msg['created_at']),
                    style: TextStyle(fontSize: 10, color: isMe ? Colors.white60 : Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withOpacity(0.2),
              backgroundImage: msg['avatar'] != null ? NetworkImage(msg['avatar']) : null,
              child: msg['avatar'] == null
                  ? Text(
                      (msg['nickname'] ?? '?').toString().substring(0, 1),
                      style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text) {
    final bool certified = text == '已认证';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: certified ? Colors.blue.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(
        fontSize: 12,
        color: certified ? Colors.blue.shade700 : Colors.orange.shade700)),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}

/// TabBar固定在Sliver头部的委托
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
