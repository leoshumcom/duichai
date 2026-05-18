// 堆柴 Admin - Cloudflare Worker
export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === '/' || url.pathname === '/index.html') {
      return new Response(getHtml(), {
        headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-cache, no-store' },
      });
    }
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Access-Control-Max-Age': '86400' } });
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

function getHtml() {
  return `<!DOCTYPE html>
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
.section{background:#fff;border-radius:12px;padding:24px;margin-bottom:24px;box-shadow:0 2px 8px rgba(0,0,0,0.04)}
.section h3{font-size:16px;margin-bottom:16px}
input,select{padding:8px 12px;border:1px solid #ddd;border-radius:6px;font-size:14px;width:100%;max-width:300px}
button{padding:10px 20px;background:#FF6B35;color:#fff;border:none;border-radius:6px;cursor:pointer;font-size:14px}
button:hover{background:#e85a28}
button.secondary{background:#f0f0f0;color:#333;cursor:pointer}
.btn-sm{padding:6px 12px;font-size:13px}
.badge{display:inline-block;padding:2px 8px;border-radius:4px;font-size:12px}
.badge.green{background:#E8F5E9;color:#4CAF50}
.badge.red{background:#FFEBEE;color:#F44336}
.badge.orange{background:#FFF3E0;color:#FF9800}
.result{font-size:13px;margin-top:8px;padding:8px;border-radius:4px}
.result.success{background:#E8F5E9;color:#4CAF50}
.result.error{background:#FFEBEE;color:#F44336}
</style>
</head>
<body>
<div class="sidebar">
  <h2>🔥 堆柴</h2>
  <nav>
    <a href="#" class="active" onclick="showPage('dashboard')">📊 数据大盘</a>
    <a href="#" onclick="showPage('chaihuo')">🔥 柴火管理</a>
    <a href="#" onclick="showPage('users')">👤 用户管理</a>
    <a href="#" onclick="showPage('venues')">🏟 场地管理</a>
  </nav>
  <div style="position:absolute;bottom:24px;left:24px;right:24px">
    <button onclick="showLogin()" class="secondary" id="loginBtn" style="width:100%">🔑 管理员登录</button>
    <p id="loginStatus" style="font-size:12px;color:#666;margin-top:8px;text-align:center">未登录</p>
  </div>
</div>
<div class="main">

<div id="page-dashboard">
  <div class="header"><h1>📊 数据大盘</h1><span class="date" id="dateDisplay"></span></div>
  <div id="loginHint" style="text-align:center;padding:60px 20px;color:#999">
    <p>请先登录管理员账号</p>
    <button onclick="showLogin()" style="margin-top:16px">立即登录</button>
  </div>
  <div id="dashboardContent" style="display:none">
    <div class="kpi-grid">
      <div class="kpi-card primary"><div class="label">累计用户</div><div class="value" id="totalUsers">-</div></div>
      <div class="kpi-card"><div class="label">日活跃</div><div class="value" id="dau">-</div></div>
      <div class="kpi-card"><div class="label">场地</div><div class="value" id="totalVenues">-</div></div>
      <div class="kpi-card"><div class="label">俱乐部</div><div class="value" id="totalClubs">-</div></div>
      <div class="kpi-card"><div class="label">柴火总量</div><div class="value" id="totalChaihuo">-</div></div>
    </div>
    <div class="section">
      <h3>📋 待审核</h3>
      <table><thead><tr><th>类型</th><th>待处理</th></tr></thead>
      <tbody>
        <tr><td>🏟 新场地</td><td><span class="badge orange" id="pendingVenues">-</span></td></tr>
        <tr><td>👤 馆主认证</td><td><span class="badge orange" id="pendingOwners">-</span></td></tr>
        <tr><td>🔄 俱乐部认证</td><td><span class="badge orange" id="pendingClubs">-</span></td></tr>
        <tr><td>🚨 举报</td><td><span class="badge red" id="pendingReports">-</span></td></tr>
      </tbody></table>
    </div>
  </div>
</div>

<div id="page-chaihuo" style="display:none">
  <div class="header"><h1>🔥 柴火管理</h1></div>
  <div class="section">
    <h3>发放柴火</h3>
    <div style="display:flex;flex-direction:column;gap:12px;max-width:400px">
      <input type="text" id="grantEmail" placeholder="用户邮箱或UID" value="leoshum.com@gmail.com">
      <input type="number" id="grantAmount" placeholder="柴火数量" value="100">
      <button onclick="grantChaihuo()">发放柴火</button>
      <div id="grantResult"></div>
    </div>
  </div>
</div>

<div id="page-users" style="display:none">
  <div class="header"><h1>👤 用户管理</h1></div>
  <div class="section">
    <h3>用户列表</h3>
    <table><thead><tr><th>UID</th><th>邮箱</th><th>昵称</th><th>柴火</th><th>角色</th></tr></thead>
    <tbody id="userTable"></tbody></table>
  </div>
</div>

<div id="page-venues" style="display:none">
  <div class="header"><h1>🏟 场地管理</h1></div>
  <div class="section" id="venueSection"><p>加载中...</p></div>
</div>

</div>

<!-- Login Modal -->
<div id="loginModal" style="display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:999;align-items:center;justify-content:center">
  <div style="background:#fff;border-radius:12px;padding:32px;width:360px;max-width:90vw;box-shadow:0 8px 32px rgba(0,0,0,0.2)">
    <h3>🔑 管理员登录</h3>
    <div style="display:flex;flex-direction:column;gap:12px;margin-top:16px">
      <input type="email" id="loginEmail" placeholder="管理员邮箱" value="leoshum.com@gmail.com" style="padding:10px 12px">
      <input type="password" id="loginPassword" placeholder="管理员密码" style="padding:10px 12px">
      <button onclick="doLogin()" style="width:100%;padding:12px">登录</button>
      <div id="loginResult"></div>
      <button onclick="hideLogin()" style="background:transparent;color:#999;width:100%;padding:8px;border:none;cursor:pointer">取消</button>
    </div>
  </div>
</div>

<script>
(function(){
var API = location.origin;
var adminToken = localStorage.getItem('adminToken');
var adminEmail = localStorage.getItem('adminEmail');

function updateDate() {
  document.getElementById('dateDisplay').innerHTML = new Date().toLocaleDateString('zh-CN', {year:'numeric',month:'long',day:'numeric',hour:'2-digit',minute:'2-digit'});
}
updateDate();
setInterval(updateDate, 60000);

window.showLogin = function() {
  document.getElementById('loginModal').style.display = 'flex';
  document.getElementById('loginEmail').value = adminEmail || 'leoshum.com@gmail.com';
  document.getElementById('loginPassword').value = '';
  document.getElementById('loginResult').innerHTML = '';
};

window.hideLogin = function() {
  document.getElementById('loginModal').style.display = 'none';
};

function updateLoginUI() {
  var btn = document.getElementById('loginBtn');
  var st = document.getElementById('loginStatus');
  if (adminToken) {
    btn.innerHTML = '👤 ' + (adminEmail || '管理员');
    btn.style.background = '#4CAF50';
    btn.style.color = '#fff';
    st.innerHTML = '已登录';
    st.style.color = '#4CAF50';
  } else {
    btn.innerHTML = '🔑 管理员登录';
    btn.style.background = '';
    btn.style.color = '';
    st.innerHTML = '未登录';
    st.style.color = '#999';
  }
}

function apiCall(path, method, body) {
  var opts = {method: method || 'GET', headers: {'Content-Type': 'application/json'}};
  if (adminToken) opts.headers['Authorization'] = 'Bearer ' + adminToken;
  if (body) opts.body = JSON.stringify(body);
  return fetch(API + path, opts).then(function(r){ return r.json(); });
}

window.doLogin = function() {
  var email = document.getElementById('loginEmail').value.trim();
  var password = document.getElementById('loginPassword').value;
  var el = document.getElementById('loginResult');
  if (!email || !password) { el.innerHTML = '<div class="result error">请填写邮箱和密码</div>'; return; }
  el.innerHTML = '<div style="color:#999;font-size:13px">登录中...</div>';
  apiCall('/api/admin/login', 'POST', {email: email, password: password}).then(function(data) {
    if (data.success) {
      adminToken = data.data.token;
      adminEmail = email;
      localStorage.setItem('adminToken', adminToken);
      localStorage.setItem('adminEmail', adminEmail);
      el.innerHTML = '<div class="result success">✅ 登录成功！</div>';
      updateLoginUI();
      setTimeout(function(){ hideLogin(); showDashboard(); }, 600);
    } else {
      el.innerHTML = '<div class="result error">❌ ' + (data.error || '登录失败') + '</div>';
    }
  }).catch(function(){ el.innerHTML = '<div class="result error">网络错误</div>'; });
};

window.showPage = function(name) {
  var pages = document.querySelectorAll('.main > div[id^="page-"]');
  for (var i = 0; i < pages.length; i++) pages[i].style.display = 'none';
  document.getElementById('page-' + name).style.display = 'block';
  var links = document.querySelectorAll('.sidebar nav a');
  for (var i = 0; i < links.length; i++) links[i].classList.remove('active');
  var names = ['dashboard','chaihuo','users','venues'];
  var idx = names.indexOf(name);
  if (idx >= 0 && links[idx]) links[idx].classList.add('active');
  if (name === 'dashboard') showDashboard();
  if (name === 'users') loadUsers();
  if (name === 'venues') loadVenues();
};

function showDashboard() {
  document.getElementById('loginHint').style.display = adminToken ? 'none' : 'block';
  document.getElementById('dashboardContent').style.display = adminToken ? 'block' : 'none';
  if (!adminToken) return;
  apiCall('/api/admin/stats').then(function(data) {
    if (data.success && data.data) {
      document.getElementById('totalUsers').innerHTML = data.data.total_users;
      document.getElementById('dau').innerHTML = data.data.dau;
      document.getElementById('totalVenues').innerHTML = data.data.total_venues;
      document.getElementById('totalClubs').innerHTML = data.data.total_clubs;
      document.getElementById('totalChaihuo').innerHTML = data.data.total_chaihuo;
      var p = data.data.pending || {};
      document.getElementById('pendingVenues').innerHTML = p.venues || 0;
      document.getElementById('pendingOwners').innerHTML = p.owners || 0;
      document.getElementById('pendingClubs').innerHTML = p.clubs || 0;
      document.getElementById('pendingReports').innerHTML = p.reports || 0;
    }
  });
}

window.grantChaihuo = function() {
  var email = document.getElementById('grantEmail').value.trim();
  var amount = parseInt(document.getElementById('grantAmount').value);
  var el = document.getElementById('grantResult');
  if (!email || !amount || amount < 1) { el.innerHTML = '<div class="result error">请填写邮箱和有效的数量</div>'; return; }
  if (!adminToken) { showLogin(); return; }
  el.innerHTML = '<div style="color:#999;font-size:13px">处理中...</div>';
  apiCall('/api/admin/grant-chaihuo', 'POST', {email: email, amount: amount, reason: '管理员发放'}).then(function(data) {
    if (data.success) { el.innerHTML = '<div class="result success">✅ ' + data.data.email + ': ' + data.data.previous_balance + ' → ' + data.data.new_balance + ' (+' + data.data.amount + ')</div>'; }
    else { el.innerHTML = '<div class="result error">❌ ' + (data.error || '发放失败') + '</div>'; }
  }).catch(function(){ el.innerHTML = '<div class="result error">网络错误</div>'; });
};

function loadUsers() {
  if (!adminToken) return;
  apiCall('/api/admin/users').then(function(data) {
    var tb = document.getElementById('userTable');
    if (data.success && data.data && data.data.length > 0) {
      var h = '';
      for (var i = 0; i < data.data.length; i++) {
        var u = data.data[i];
        var cls = 'badge';
        if (u.role === 'admin' || u.role === 'super_admin') cls += ' green';
        else if (u.role === 'owner') cls += ' orange';
        h += '<tr><td>' + (u.uid || '-') + '</td><td>' + (u.email || '') + '</td><td>' + (u.nickname || '') + '</td><td>' + (u.chaihuo_balance || 0) + '</td><td><span class="' + cls + '">' + (u.role || 'user') + '</span></td></tr>';
      }
      tb.innerHTML = h;
    }
  });
}

function loadVenues() {
  if (!adminToken) return;
  apiCall('/api/admin/venues').then(function(data) {
    var el = document.getElementById('venueSection');
    if (data.success && data.data && data.data.length > 0) {
      var h = '<table><thead><tr><th>名称</th><th>类型</th><th>🔥</th><th>状态</th><th>操作</th></tr></thead><tbody>';
      for (var i = 0; i < data.data.length; i++) {
        var v = data.data[i];
        var cls = v.status === 'approved' ? 'badge green' : (v.status === 'pending' ? 'badge orange' : 'badge red');
        var txt = v.status === 'approved' ? '已通过' : (v.status === 'pending' ? '待审核' : v.status);
        h += '<tr><td>' + (v.name || '') + '</td><td>' + (v.type || '-') + '</td><td>' + (v.chaihuo_total || 0) + '</td><td><span class="' + cls + '">' + txt + '</span></td><td>' + (v.status === 'pending' ? '<button class="btn-sm" onclick="approveVenue('' + v.id + '')">通过</button>' : '') + '</td></tr>';
      }
      h += '</tbody></table>';
      el.innerHTML = h;
    }
  });
}

window.approveVenue = function(id) {
  if (!adminToken) return;
  apiCall('/api/admin/venues/' + id + '/approve', 'POST').then(function(d) { if (d.success) loadVenues(); });
};

updateLoginUI();
if (adminToken) showDashboard();
})();
</script>
</body>
</html>`;
}
