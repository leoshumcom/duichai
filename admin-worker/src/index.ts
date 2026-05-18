// 堆柴 Admin - Cloudflare Worker
// Serves the admin panel HTML (embedded) and proxies API requests

const INDEX_HTML = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>堆柴管理后台</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"PingFang SC",sans-serif;background:#FFF8F0;color:#1A1A1A}
.sidebar{position:fixed;left:0;top:0;width:240px;height:100vh;background:#1A1A1A;color:#fff;padding:24px}
.sidebar h2{font-size:24px;color:#FF6B35;margin-bottom:32px}
.sidebar nav a{display:block;padding:12px 16px;color:#999;text-decoration:none;border-radius:8px;margin-bottom:4px;font-size:14px;cursor:pointer}
.sidebar nav a:hover,.sidebar nav a.active{background:#FF6B35;color:#fff}
.main{margin-left:240px;padding:24px}
.header{display:flex;justify-content:space-between;align-items:center;margin-bottom:32px}
.header h1{font-size:24px}
.header .date{color:#999;font-size:14px}
.kpi-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px;margin-bottom:32px}
.kpi-card{background:#fff;border-radius:12px;padding:20px;box-shadow:0 2px 8px rgba(0,0,0,0.04)}
.kpi-card .label{font-size:13px;color:#999;margin-bottom:8px}
.kpi-card .value{font-size:32px;font-weight:700;color:#1A1A1A}
.kpi-card.primary .value{color:#FF6B35}
.kpi-card .change{font-size:12px;color:#4CAF50;margin-top:4px}
.section{background:#fff;border-radius:12px;padding:24px;margin-bottom:24px;box-shadow:0 2px 8px rgba(0,0,0,0.04)}
.section h3{font-size:16px;margin-bottom:16px;color:#333}
table{width:100%;border-collapse:collapse;font-size:14px}
th{text-align:left;padding:12px 8px;color:#999;font-weight:500;border-bottom:2px solid #f0f0f0}
td{padding:12px 8px;border-bottom:1px solid #f5f5f5}
input,select{padding:8px 12px;border:1px solid #ddd;border-radius:6px;font-size:14px;width:100%;max-width:300px}
button{padding:10px 20px;background:#FF6B35;color:#fff;border:none;border-radius:6px;cursor:pointer;font-size:14px}
button:hover{background:#e85a28}
button.secondary{background:#f0f0f0;color:#333}
.btn-sm{padding:6px 12px;font-size:13px}
.btn-danger{background:#F44336}
.btn-danger:hover{background:#d32f2f}
.apikey-input{font-family:monospace;font-size:12px;color:#666}
.badge{display:inline-block;padding:2px 8px;border-radius:4px;font-size:12px}
.badge.green{background:#E8F5E9;color:#4CAF50}
.badge.red{background:#FFEBEE;color:#F44336}
.badge.orange{background:#FFF3E0;color:#FF9800}
.result{font-size:13px;margin-top:8px;padding:8px;border-radius:4px}
.result.success{background:#E8F5E9;color:#4CAF50}
.result.error{background:#FFEBEE;color:#F44336}
.login-notice{text-align:center;padding:32px}
.login-notice p{color:#999;margin-bottom:16px}
@media(max-width:768px){.sidebar{width:0;overflow:hidden}.main{margin-left:0}}
</style>
</head>
<body>
<div id="appContent" style="display:none">
<div class="sidebar">
  <h2>🔥 堆柴</h2>
  <nav>
    <a href="#" class="active" onclick="showPage('dashboard')">📊 数据大盘</a>
    <a href="#" onclick="showPage('chaihuo')">🔥 柴火管理</a>
    <a href="#" onclick="showPage('users')">👤 用户管理</a>
    <a href="#" onclick="showPage('venues')">🏟 场地管理</a>
    <a href="#" onclick="showPage('owners')">👤 馆主认证</a>
    <a href="#" onclick="showPage('clubs')">🔄 俱乐部管理</a>
  </nav>
  <div style="position:absolute;bottom:24px;left:24px;right:24px">
    <button onclick="doLogout()" style="width:100%;font-size:13px" class="secondary" id="loginBtn">🔑 管理员登录</button>
    <p id="loginStatus" style="font-size:12px;color:#666;margin-top:8px;text-align:center">未登录</p>
  </div>
</div>
<div class="main">

<!-- Dashboard -->
<div id="page-dashboard">
  <div class="header">
    <h1>📊 数据大盘</h1>
    <span class="date" id="dateDisplay"></span>
  </div>
  <div class="kpi-grid">
    <div class="kpi-card primary">
      <div class="label">累计用户</div>
      <div class="value" id="totalUsers">-</div>
    </div>
    <div class="kpi-card">
      <div class="label">日活跃</div>
      <div class="value" id="dau">-</div>
    </div>
    <div class="kpi-card">
      <div class="label">场地</div>
      <div class="value" id="totalVenues">-</div>
    </div>
    <div class="kpi-card">
      <div class="label">俱乐部</div>
      <div class="value" id="totalClubs">-</div>
    </div>
    <div class="kpi-card">
      <div class="label">柴火总量</div>
      <div class="value" id="totalChaihuo">-</div>
    </div>
  </div>
  <div class="section">
    <h3>📋 待审核</h3>
    <table>
      <thead><tr><th>类型</th><th>待处理</th></tr></thead>
      <tbody>
        <tr><td>🏟 新场地</td><td><span class="badge orange" id="pendingVenues">-</span></td></tr>
        <tr><td>👤 馆主认证</td><td><span class="badge orange" id="pendingOwners">-</span></td></tr>
        <tr><td>🔄 俱乐部认证</td><td><span class="badge orange" id="pendingClubs">-</span></td></tr>
        <tr><td>🚨 举报</td><td><span class="badge red" id="pendingReports">-</span></td></tr>
      </tbody>
    </table>
  </div>
</div>

<!-- Chaihuo Management -->
<div id="page-chaihuo" style="display:none">
  <div class="header"><h1>🔥 柴火管理</h1></div>
  <div class="section">
    <h3>发放柴火</h3>
    <div style="display:flex;flex-direction:column;gap:12px;max-width:400px">
      <div>
        <label style="font-size:13px;color:#666;display:block;margin-bottom:4px">用户邮箱</label>
        <input type="email" id="grantEmail" placeholder="用户邮箱" value="leoshum.com@gmail.com">
      </div>
      <div>
        <label style="font-size:13px;color:#666;display:block;margin-bottom:4px">柴火数量</label>
        <input type="number" id="grantAmount" placeholder="柴火数量" value="100">
      </div>
      <div>
        <label style="font-size:13px;color:#666;display:block;margin-bottom:4px">发放原因（选填）</label>
        <input type="text" id="grantReason" placeholder="发放原因" value="管理员发放">
      </div>
      <button onclick="grantChaihuo()">发放柴火</button>
      <div id="grantResult"></div>
    </div>
  </div>
  <div class="section">
    <h3>管理员信息</h3>
    <p>管理员密码: <code>Qq141516@</code></p>
    <p style="margin-top:8px;color:#999;font-size:13px">登录方式: 点击左侧底部「管理员登录」按钮，输入邮箱和管理员密码</p>
  </div>
</div>

<!-- Users -->
<div id="page-users" style="display:none">
  <div class="header"><h1>👤 用户管理</h1></div>
  <div class="section">
    <h3>用户列表</h3>
    <table>
      <thead><tr><th>邮箱</th><th>昵称</th><th>柴火</th><th>角色</th></tr></thead>
      <tbody id="userTable"></tbody>
    </table>
  </div>
</div>

<!-- Venues -->
<div id="page-venues" style="display:none">
  <div class="header"><h1>🏟 场地管理</h1></div>
  <div class="section" id="venueSection"><p>加载中...</p></div>
</div>

<!-- Owner Certification -->
<div id="page-owners" style="display:none">
  <div class="header"><h1>👤 馆主认证申请</h1></div>
  <div class="section" id="ownerSection">
    <div style="margin-bottom:16px">
      <button class="btn-sm" onclick="refreshOwners('pending')" style="margin-right:8px">待审核</button>
      <button class="btn-sm secondary" onclick="refreshOwners('approved')" style="margin-right:8px">已通过</button>
      <button class="btn-sm secondary" onclick="refreshOwners('rejected')">已拒绝</button>
    </div>
    <table><thead><tr><th>用户</th><th>手机</th><th>营业执照</th><th>身份证</th><th>提交时间</th><th>操作</th></tr></thead><tbody id="ownerTable"><tr><td colspan="6" style="text-align:center;color:#999">加载中...</td></tr></tbody></table>
  </div>
</div>

<!-- Club Management -->
<div id="page-clubs" style="display:none">
  <div class="header"><h1>🔄 俱乐部管理</h1></div>
  <div class="section">
    <h3>俱乐部列表</h3>
    <table><thead><tr><th>名称</th><th>创建者</th><th>成员数</th><th>柴火</th><th>认证</th><th>状态</th></tr></thead><tbody id="clubTable"><tr><td colspan="6" style="text-align:center;color:#999">加载中...</td></tr></tbody></table>
  </div>
  <div class="section">
    <h3>俱乐部认证申请</h3>
    <table><thead><tr><th>俱乐部</th><th>申请人</th><th>提交时间</th><th>操作</th></tr></thead><tbody id="clubCertTable"><tr><td colspan="4" style="text-align:center;color:#999">加载中...</td></tr></tbody></table>
  </div>
</div>
</div>
</div>

<!-- Login Modal Dialog -->
<div id="loginModalOverlay" style="display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:999;align-items:center;justify-content:center">
  <div style="background:#fff;border-radius:12px;padding:32px;width:360px;max-width:90vw;box-shadow:0 8px 32px rgba(0,0,0,0.2)">
    <h3 style="margin-bottom:20px;font-size:20px;color:#1A1A1A">🔑 管理员登录</h3>
    <div style="display:flex;flex-direction:column;gap:12px">
      <input type="email" id="loginModalEmail" placeholder="管理员邮箱" value="leoshum.com@gmail.com" style="max-width:100%;padding:10px 12px">
      <input type="password" id="loginModalPassword" placeholder="管理员密码" style="max-width:100%;padding:10px 12px">
      <button onclick="doLogin()" style="width:100%;padding:12px">登录</button>
      <div id="loginModalResult"></div>
      <button onclick="closeLoginModal()" style="background:transparent;color:#999;width:100%;padding:8px">取消</button>
    </div>
  </div>
</div>

<script>
let adminToken = localStorage.getItem('adminToken');
let adminEmail = localStorage.getItem('adminEmail');
let adminNickname = localStorage.getItem('adminNickname') || '管理员';

function updateDate() {
  const now = new Date();
  document.getElementById('dateDisplay').textContent = now.toLocaleDateString('zh-CN', { year:'numeric', month:'long', day:'numeric', hour:'2-digit', minute:'2-digit' });
}
updateDate();
setInterval(updateDate, 60000);

function updateLoginUI() {
  const btn = document.getElementById('loginBtn');
  const status = document.getElementById('loginStatus');
  const appContent = document.getElementById('appContent');
  if (adminToken) {
    btn.textContent = '🚪 退出登录 (' + adminNickname + ')';
    btn.style.background = '#f44336';
    btn.style.color = '#fff';
    status.textContent = '已登录';
    status.style.color = '#4CAF50';
    appContent.style.display = 'block';
  } else {
    btn.textContent = '🔑 管理员登录';
    btn.style.background = '#f0f0f0';
    btn.style.color = '#333';
    btn.onclick = showLoginModal;
    status.textContent = '未登录';
    status.style.color = '#999';
    appContent.style.display = 'none';
  }
}

function doLogout() {
  adminToken = null;
  adminEmail = null;
  adminNickname = null;
  localStorage.removeItem('adminToken');
  localStorage.removeItem('adminEmail');
  localStorage.removeItem('adminNickname');
  updateLoginUI();
  showLoginModal();
}

function showLoginModal() {
  document.getElementById('loginModalOverlay').style.display = 'flex';
  document.getElementById('loginModalEmail').value = adminEmail || 'leoshum.com@gmail.com';
  document.getElementById('loginModalPassword').value = '';
  document.getElementById('loginModalResult').innerHTML = '';
}

function closeLoginModal() {
  document.getElementById('loginModalOverlay').style.display = 'none';
}

function showPage(name) {
  document.querySelectorAll('.main > div[id^="page-"]').forEach(el => el.style.display = 'none');
  document.getElementById('page-' + name).style.display = 'block';
  document.querySelectorAll('.sidebar nav a').forEach(a => a.classList.remove('active'));
  document.querySelector(\`.sidebar nav a[onclick*="'\${name}'"]\`).classList.add('active');
  if (name === 'dashboard') refreshDashboard();
  if (name === 'users') refreshUsers();
  if (name === 'venues') refreshVenues();
  if (name === 'owners') refreshOwners('pending');
  if (name === 'clubs') { refreshClubList(); refreshClubCerts(); }
}

async function api(path, method = 'GET', body = null) {
  const opts = { method, headers: { 'Content-Type': 'application/json' }};
  if (adminToken) opts.headers['Authorization'] = 'Bearer ' + adminToken;
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch('https://api.duichai.com' + path, opts);
  return res.json();
}

async function doLogin() {
  const email = document.getElementById('loginModalEmail').value.trim();
  const password = document.getElementById('loginModalPassword').value;
  const resultEl = document.getElementById('loginModalResult');

  if (!email || !password) {
    resultEl.innerHTML = '<div class="result error">请填写邮箱和密码</div>';
    return;
  }

  resultEl.innerHTML = '<div style="color:#999;font-size:13px">正在登录...</div>';

  const res = await api('/api/admin/login', 'POST', { email, password });
  if (res.success) {
    adminToken = res.data.token;
    adminEmail = email;
    adminNickname = res.data.nickname || '管理员';
    localStorage.setItem('adminToken', adminToken);
    localStorage.setItem('adminEmail', adminEmail);
    localStorage.setItem('adminNickname', adminNickname);
    updateLoginUI();
    resultEl.innerHTML = '<div class="result success">✅ 登录成功！</div>';
    setTimeout(closeLoginModal, 1000);
    refreshDashboard();
  } else {
    resultEl.innerHTML = '<div class="result error">❌ ' + (res.error || '登录失败') + '</div>';
  }
}

async function refreshDashboard() {
  if (!adminToken) { return; }
  const res = await api('/api/admin/stats');
  if (res.success && res.data) {
    document.getElementById('totalUsers').textContent = res.data.total_users;
    document.getElementById('dau').textContent = res.data.dau;
    document.getElementById('totalVenues').textContent = res.data.total_venues;
    document.getElementById('totalClubs').textContent = res.data.total_clubs;
    document.getElementById('totalChaihuo').textContent = res.data.total_chaihuo;
    document.getElementById('pendingVenues').textContent = res.data.pending.venues;
    document.getElementById('pendingOwners').textContent = res.data.pending.owners;
    document.getElementById('pendingClubs').textContent = res.data.pending.clubs;
    document.getElementById('pendingReports').textContent = res.data.pending.reports;
  }
}

async function grantChaihuo() {
  const email = document.getElementById('grantEmail').value.trim();
  const amount = parseInt(document.getElementById('grantAmount').value);
  const reason = document.getElementById('grantReason').value || '管理员发放';
  const el = document.getElementById('grantResult');

  if (!email || !amount || amount < 1) {
    el.innerHTML = '<div class="result error">请填写邮箱和有效的数量</div>';
    return;
  }

  if (!adminToken) {
    showLoginModal();
    return;
  }

  el.innerHTML = '<div style="color:#999;font-size:13px">处理中...</div>';

  const res = await api('/api/admin/grant-chaihuo', 'POST', { email, amount, reason });
  if (res.success) {
    el.innerHTML = '<div class="result success">✅ ' + res.data.email + ': ' + res.data.previous_balance + ' → ' + res.data.new_balance + ' (+' + res.data.amount + ')</div>';
  } else {
    el.innerHTML = '<div class="result error">❌ ' + (res.error || '发放失败') + '</div>';
  }
}

async function refreshUsers() {
  if (!adminToken) { showLoginModal(); return; }
  const tb = document.getElementById('userTable');
  tb.innerHTML = '<tr><td colspan="4" style="text-align:center;color:#999">加载中...</td></tr>';
  const res = await api('/api/admin/users');
  if (res.success && res.data) {
    tb.innerHTML = res.data.map(u => {
      const roleBadge = u.role === 'admin' || u.role === 'super_admin'
        ? '<span class="badge green">admin</span>'
        : u.role === 'owner'
        ? '<span class="badge orange">owner</span>'
        : '<span class="badge">user</span>';
      const uidStr = u.uid ? \`<span style="color:#999;font-size:12px">#\${u.uid}</span>\` : '';
      return '<tr><td>' + u.email + ' ' + uidStr + '</td><td>' + u.nickname + '</td><td>' + (u.chaihuo_balance || 0) + '🔥</td><td>' + roleBadge + '</td></tr>';
    }).join('');
  } else {
    tb.innerHTML = '<tr><td colspan="4" style="text-align:center;color:#999">加载失败</td></tr>';
  }
}

async function refreshVenues() {
  if (!adminToken) { showLoginModal(); return; }
  const el = document.getElementById('venueSection');
  el.innerHTML = '<p style="color:#999">加载中...</p>';
  const res = await api('/api/admin/venues');
  if (res.success && res.data) {
    let html = '<h3>场地列表</h3><table><thead><tr><th>名称</th><th>类型</th><th>柴火</th><th>发布者</th><th>状态</th><th>操作</th></tr></thead><tbody>';
    html += res.data.map(v => {
      const statusBadge = v.status === 'approved' ? '<span class="badge green">已审核</span>'
        : v.status === 'pending' ? '<span class="badge orange">待审核</span>'
        : '<span class="badge red">' + v.status + '</span>';
      const approveBtn = v.status === 'pending'
        ? '<button class="btn-sm" onclick="approveVenue(\\'' + v.id + '\\')" style="margin-right:4px">通过</button>'
        : '';
      const deleteBtn = v.status !== 'deleted'
        ? '<button class="btn-sm btn-danger" onclick="deleteVenue(\\'' + v.id + '\\')">删除</button>'
        : '-';
      return '<tr><td>' + v.name + '</td><td>' + v.type + '</td><td>' + (v.chaihuo_total || 0) + '</td><td>' + (v.publisher_name || '-') + '</td><td>' + statusBadge + '</td><td>' + approveBtn + deleteBtn + '</td></tr>';
    }).join('');
    html += '</tbody></table>';
    el.innerHTML = html;
  } else {
    el.innerHTML = '<p style="color:red">加载失败</p>';
  }
}

async function approveVenue(venueId) {
  const res = await api('/api/admin/venues/' + venueId + '/approve', 'POST');
  if (res.success) {
    refreshVenues();
  } else {
    alert('操作失败: ' + (res.error || ''));
  }
}

async function deleteVenue(venueId) {
  if (!confirm('确认删除该场地？将扣除发布者110根柴火（100惩罚+10管理费）')) return;
  const res = await api('/api/admin/venues/' + venueId + '/delete', 'POST');
  if (res.success) {
    alert('已删除：' + (res.message || ''));
    refreshVenues();
  } else {
    alert('操作失败: ' + (res.error || ''));
  }
}

// ===== Owner Certification =====
let _ownerStatus = 'pending';
async function refreshOwners(status) {
  if (!adminToken) { showLoginModal(); return; }
  _ownerStatus = status || 'pending';
  // Update button styles
  document.querySelectorAll('#ownerSection .btn-sm').forEach(b => {
    b.className = 'btn-sm' + (b.textContent.includes({pending:'待审核',approved:'已通过',rejected:'已拒绝'}[_ownerStatus]) ? '' : ' secondary');
  });
  // Fix: simpler button toggle
  document.querySelectorAll('#ownerSection .btn-sm').forEach(b => b.classList.add('secondary'));
  const tb = document.getElementById('ownerTable');
  tb.innerHTML = '<tr><td colspan="6" style="text-align:center;color:#999">加载中...</td></tr>';
  const res = await api('/api/admin/owner-applications?status=' + _ownerStatus);
  if (res.success && res.data) {
    if (res.data.length === 0) {
      tb.innerHTML = '<tr><td colspan="6" style="text-align:center;color:#999">暂无数据</td></tr>';
      return;
    }
    tb.innerHTML = res.data.map(a => {
      const actions = a.status === 'pending'
        ? '<button class="btn-sm" onclick="approveOwner(\\'' + a.id + '\\')" style="margin-right:4px">通过</button><button class="btn-sm btn-danger" onclick="rejectOwner(\\'' + a.id + '\\')">拒绝</button>'
        : a.status === 'approved' ? '<span style="color:#4CAF50">✅ 已通过</span>' : '<span style="color:#F44336">❌ ' + (a.reject_reason || '已拒绝') + '</span>';
      return '<tr><td>' + (a.nickname || '-') + '<br><small style="color:#999">' + (a.email || '') + '</small></td>'
        + '<td>' + (a.contact_phone || a.user_phone || '-') + '</td>'
        + '<td><a href="' + a.business_license + '" target="_blank">查看</a></td>'
        + '<td><a href="' + a.id_card_front + '" target="_blank">正面</a> | <a href="' + a.id_card_back + '" target="_blank">反面</a></td>'
        + '<td>' + (a.created_at || '-') + '</td>'
        + '<td>' + actions + '</td></tr>';
    }).join('');
  } else {
    tb.innerHTML = '<tr><td colspan="6" style="text-align:center;color:#999">加载失败</td></tr>';
  }
}

async function approveOwner(appId) {
  const res = await api('/api/admin/owner-applications/' + appId + '/approve', 'POST');
  if (res.success) {
    alert('✅ 馆主认证通过');
    refreshOwners(_ownerStatus);
  } else {
    alert('操作失败: ' + (res.error || ''));
  }
}

async function rejectOwner(appId) {
  const reason = prompt('请输入拒绝原因：', '资料不符合要求');
  if (reason === null) return;
  const res = await api('/api/admin/owner-applications/' + appId + '/reject', 'POST', { reject_reason: reason });
  if (res.success) {
    alert('已拒绝');
    refreshOwners(_ownerStatus);
  } else {
    alert('操作失败: ' + (res.error || ''));
  }
}

// ===== Club Management =====
async function refreshClubList() {
  if (!adminToken) { showLoginModal(); return; }
  const tb = document.getElementById('clubTable');
  tb.innerHTML = '<tr><td colspan="6" style="text-align:center;color:#999">加载中...</td></tr>';
  const res = await api('/api/admin/clubs');
  if (res.success && res.data) {
    if (res.data.length === 0) {
      tb.innerHTML = '<tr><td colspan="6" style="text-align:center;color:#999">暂无俱乐部</td></tr>';
      return;
    }
    tb.innerHTML = res.data.map(c => {
      const certBadge = c.is_certified ? '<span class="badge green">已认证</span>' : '<span class="badge orange">未认证</span>';
      const statusBadge = c.status === 'active' ? '<span class="badge green">正常</span>' : '<span class="badge red">' + c.status + '</span>';
      return '<tr><td>' + c.name + '</td><td>' + (c.creator_name || '-') + '</td><td>' + (c.member_count || 1) + '</td><td>' + (c.chaihuo_total || 0) + '</td><td>' + certBadge + '</td><td>' + statusBadge + '</td></tr>';
    }).join('');
  } else {
    tb.innerHTML = '<tr><td colspan="6" style="text-align:center;color:#999">加载失败</td></tr>';
  }
}

async function refreshClubCerts() {
  if (!adminToken) { showLoginModal(); return; }
  const tb = document.getElementById('clubCertTable');
  tb.innerHTML = '<tr><td colspan="4" style="text-align:center;color:#999">加载中...</td></tr>';
  const res = await api('/api/admin/club-certifications');
  if (res.success && res.data) {
    if (res.data.length === 0) {
      tb.innerHTML = '<tr><td colspan="4" style="text-align:center;color:#999">暂无待审核认证</td></tr>';
      return;
    }
    tb.innerHTML = res.data.map(c => {
      return '<tr><td>' + (c.club_name || '-') + '</td>'
        + '<td>' + (c.applicant_name || '-') + '<br><small style="color:#999">' + (c.applicant_email || '') + '</small></td>'
        + '<td>' + (c.created_at || '-') + '</td>'
        + '<td><button class="btn-sm" onclick="approveClubCert(\\'' + c.id + '\\')" style="margin-right:4px">通过</button><button class="btn-sm btn-danger" onclick="rejectClubCert(\\'' + c.id + '\\')">拒绝</button></td></tr>';
    }).join('');
  } else {
    tb.innerHTML = '<tr><td colspan="4" style="text-align:center;color:#999">加载失败</td></tr>';
  }
}

async function approveClubCert(certId) {
  const res = await api('/api/admin/club-certifications/' + certId + '/approve', 'POST');
  if (res.success) {
    alert('✅ 认证通过');
    refreshClubCerts();
    refreshClubList();
  } else {
    alert('操作失败: ' + (res.error || ''));
  }
}

async function rejectClubCert(certId) {
  const reason = prompt('请输入拒绝原因：', '资料不符');
  if (reason === null) return;
  const res = await api('/api/admin/club-certifications/' + certId + '/reject', 'POST', { reject_reason: reason });
  if (res.success) {
    alert('已拒绝');
    refreshClubCerts();
  } else {
    alert('操作失败: ' + (res.error || ''));
  }
}

// Init
updateLoginUI();
if (adminToken) {
  refreshDashboard();
}
</script>
</body>
</html>
`;

export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === '/' || url.pathname === '/index.html') {
      return new Response(INDEX_HTML, {
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
      });
    }
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          'Access-Control-Max-Age': '86400',
        },
      });
    }
    if (url.pathname.startsWith('/api/')) {
      const apiUrl = 'https://api.duichai.com' + url.pathname + url.search;
      const apiRequest = new Request(apiUrl, { method: request.method, headers: request.headers, body: request.body });
      const response = await fetch(apiRequest);
      const h = new Headers(response.headers);
      h.set('Access-Control-Allow-Origin', '*');
      return new Response(response.body, { status: response.status, statusText: response.statusText, headers: h });
    }
    return new Response('Not Found', { status: 404 });
  },
};
