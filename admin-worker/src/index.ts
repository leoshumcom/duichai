// 堆柴 Admin - Cloudflare Worker
// Serves the admin panel HTML (full dashboard) and proxies API requests
export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === '/' || url.pathname === '/index.html') {
      return new Response(getHtml(), {
        headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-cache, no-store, must-revalidate' },
      });
    }
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Access-Control-Max-Age': '86400' },
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
.kpi-card .change{font-size:12px;color:#4CAF50;margin-top:4px}
.section{background:#fff;border-radius:12px;padding:24px;margin-bottom:24px;box-shadow:0 2px 8px rgba(0,0,0,0.04)}
.section h3{font-size:16px;margin-bottom:16px;color:#333}
table{width:100%;border-collapse:collapse;font-size:14px}
th{text-align:left;padding:12px 8px;color:#999;font-weight:500;border-bottom:2px solid #f0f0f0}
td{padding:12px 8px;border-bottom:1px solid #f5f5f5}
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
.logout-btn{position:absolute;bottom:24px;left:24px;right:24px}
.logout-btn button{width:100%;font-size:13px}
@media(max-width:768px){.sidebar{width:0;overflow:hidden}.main{margin-left:0}}
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
  <div class="logout-btn">
    <button onclick="showLogin()" class="secondary" id="loginBtn">🔑 管理员登录</button>
    <p id="loginStatus" style="font-size:12px;color:#666;margin-top:8px;text-align:center">未登录</p>
  </div>
</div>
<div class="main">

<div id="page-dashboard">
  <div class="header">
    <h1>📊 数据大盘</h1>
    <span class="date" id="dateDisplay"></span>
  </div>
  <div id="loginHint" style="text-align:center;padding:60px 20px;color:#999">
    <p style="font-size:18px;margin-bottom:12px">请先登录管理员账号</p>
    <button onclick="showLogin()">立即登录</button>
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
      <div><label style="font-size:13px;color:#666;display:block;margin-bottom:4px">用户邮箱/UID</label>
        <input type="text" id="grantEmail" placeholder="用户邮箱或UID" value="leoshum.com@gmail.com"></div>
      <div><label style="font-size:13px;color:#666;display:block;margin-bottom:4px">柴火数量</label>
        <input type="number" id="grantAmount" placeholder="柴火数量" value="100"></div>
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

<div id="loginModal" style="display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:999;align-items:center;justify-content:center">
  <div style="background:#fff;border-radius:12px;padding:32px;width:360px;max-width:90vw;box-shadow:0 8px 32px rgba(0,0,0,0.2)">
    <h3 style="margin-bottom:20px;font-size:20px;color:#1A1A1A">🔑 管理员登录</h3>
    <div style="display:flex;flex-direction:column;gap:12px">
      <input type="email" id="loginEmail" placeholder="管理员邮箱" value="leoshum.com@gmail.com" style="max-width:100%;padding:10px 12px">
      <input type="password" id="loginPassword" placeholder="管理员密码" style="max-width:100%;padding:10px 12px">
      <button onclick="doLogin()" style="width:100%;padding:12px">登录</button>
      <div id="loginResult"></div>
      <button onclick="hideLogin()" style="background:transparent;color:#999;width:100%;padding:8px;border:none;cursor:pointer">取消</button>
    </div>
  </div>
</div>

<script>
var API = location.origin;
var adminToken = localStorage.getItem('adminToken');
var adminEmail = localStorage.getItem('adminEmail');

function updateDate() {
  document.getElementById('dateDisplay').textContent = new Date().toLocaleDateString('zh-CN', { year:'numeric', month:'long', day:'numeric', hour:'2-digit', minute:'2-digit' });
}
updateDate();
setInterval(updateDate, 60000);

function showLogin() {
  document.getElementById('loginModal').style.display = 'flex';
  document.getElementById('loginEmail').value = adminEmail || 'leoshum.com@gmail.com';
  document.getElementById('loginPassword').value = '';
  document.getElementById('loginResult').innerHTML = '';
}
function hideLogin() {
  document.getElementById('loginModal').style.display = 'none';
}
function updateUI() {
  var btn = document.getElementById('loginBtn');
  var st = document.getElementById('loginStatus');
  if (adminToken) {
    btn.textContent = '\u{1F464} ' + (adminEmail || '\u{7BA1}\u{7406}\u{5458}');
    btn.style.background = '#4CAF50';
    btn.style.color = '#fff';
    st.innerHTML = '\u{5DF2}\u{767B}\u{5F55}';
    st.style.color = '#4CAF50';
  } else {
    btn.innerHTML = '\u{1F511} \u{7BA1}\u{7406}\u{5458}\u{767B}\u{5F55}';
    btn.style.background = '';
    btn.style.color = '';
    st.innerHTML = '\u{672A}\u{767B}\u{5F55}';
    st.style.color = '#999';
  }
}

function apiCall(path, method, body) {
  var opts = { method: method || 'GET', headers: { 'Content-Type': 'application/json' }};
  if (adminToken) opts.headers['Authorization'] = 'Bearer ' + adminToken;
  if (body) opts.body = JSON.stringify(body);
  return fetch(API + path, opts).then(function(r) { return r.json(); });
}

function doLogin() {
  var email = document.getElementById('loginEmail').value.trim();
  var password = document.getElementById('loginPassword').value;
  var el = document.getElementById('loginResult');
  if (!email || !password) { el.innerHTML = '<div class="result error">\u{8BF7}\u{586B}\u{5199}\u{90AE}\u{7BB1}\u{548C}\u{5BC6}\u{7801}</div>'; return; }
  el.innerHTML = '<div style="color:#999;font-size:13px">\u{6B63}\u{5728}\u{767B}\u{5F55}...</div>';
  apiCall('/api/admin/login', 'POST', { email: email, password: password }).then(function(data) {
    if (data.success) {
      adminToken = data.data.token;
      adminEmail = email;
      localStorage.setItem('adminToken', adminToken);
      localStorage.setItem('adminEmail', adminEmail);
      el.innerHTML = '<div class="result success">\u{2705} \u{767B}\u{5F55}\u{6210}\u{529F}\u{FF01}</div>';
      updateUI();
      setTimeout(hideLogin, 800);
      showDashboard();
    } else {
      el.innerHTML = '<div class="result error">\u{274C} ' + (data.error || '\u{767B}\u{5F55}\u{5931}\u{8D25}') + '</div>';
    }
  }).catch(function() {
    el.innerHTML = '<div class="result error">\u{7F51}\u{7EDC}\u{9519}\u{8BEF}</div>';
  });
}

function showPage(name) {
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
}

function showDashboard() {
  document.getElementById('loginHint').style.display = adminToken ? 'none' : 'block';
  document.getElementById('dashboardContent').style.display = adminToken ? 'block' : 'none';
  if (!adminToken) return;
  apiCall('/api/admin/stats').then(function(data) {
    if (data.success && data.data) {
      document.getElementById('totalUsers').textContent = data.data.total_users;
      document.getElementById('dau').textContent = data.data.dau;
      document.getElementById('totalVenues').textContent = data.data.total_venues;
      document.getElementById('totalClubs').textContent = data.data.total_clubs;
      document.getElementById('totalChaihuo').textContent = data.data.total_chaihuo;
      var p = data.data.pending || {};
      document.getElementById('pendingVenues').textContent = p.venues || 0;
      document.getElementById('pendingOwners').textContent = p.owners || 0;
      document.getElementById('pendingClubs').textContent = p.clubs || 0;
      document.getElementById('pendingReports').textContent = p.reports || 0;
    }
  });
}

function grantChaihuo() {
  var email = document.getElementById('grantEmail').value.trim();
  var amount = parseInt(document.getElementById('grantAmount').value);
  var el = document.getElementById('grantResult');
  if (!email || !amount || amount < 1) { el.innerHTML = '<div class="result error">\u{8BF7}\u{586B}\u{5199}\u{6709}\u{6548}\u{7684}\u{90AE}\u{7BB1}\u{548C}\u{6570}\u{91CF}</div>'; return; }
  if (!adminToken) { showLogin(); return; }
  el.innerHTML = '<div style="color:#999;font-size:13px">\u{5904}\u{7406}\u{4E2D}...</div>';
  apiCall('/api/admin/grant-chaihuo', 'POST', { email: email, amount: amount, reason: '\u{7BA1}\u{7406}\u{5458}\u{53D1}\u{653E}' }).then(function(data) {
    if (data.success) {
      el.innerHTML = '<div class="result success">\u{2705} ' + data.data.email + ': ' + data.data.previous_balance + ' \u{2192} ' + data.data.new_balance + ' (+' + data.data.amount + ')</div>';
    } else {
      el.innerHTML = '<div class="result error">\u{274C} ' + (data.error || '\u{53D1}\u{653E}\u{5931}\u{8D25}') + '</div>';
    }
  }).catch(function() {
    el.innerHTML = '<div class="result error">\u{7F51}\u{7EDC}\u{9519}\u{8BEF}</div>';
  });
}

function loadUsers() {
  if (!adminToken) return;
  apiCall('/api/admin/users').then(function(data) {
    var tb = document.getElementById('userTable');
    if (data.success && data.data && data.data.length > 0) {
      var html = '';
      for (var i = 0; i < data.data.length; i++) {
        var u = data.data[i];
        var roleBadge = 'badge';
        if (u.role === 'admin' || u.role === 'super_admin') roleBadge += ' green';
        else if (u.role === 'owner') roleBadge += ' orange';
        html += '<tr><td><code>' + (u.uid || '-') + '</code></td><td>' + (u.email || '') + '</td><td>' + (u.nickname || '') + '</td><td>' + (u.chaihuo_balance || 0) + ' \u{1F525}</td><td><span class="' + roleBadge + '">' + (u.role || 'user') + '</span></td></tr>';
      }
      tb.innerHTML = html;
    } else {
      tb.innerHTML = '<tr><td colspan="5" style="text-align:center;color:#999">\u{6682}\u{65E0}\u{7528}\u{6237}\u{6570}\u{636E}</td></tr>';
    }
  });
}

function loadVenues() {
  if (!adminToken) return;
  apiCall('/api/admin/venues').then(function(data) {
    var el = document.getElementById('venueSection');
    if (data.success && data.data && data.data.length > 0) {
      var html = '<table><thead><tr><th>\u{573A}\u{5730}\u{540D}</th><th>\u{7C7B}\u{578B}</th><th>\u{5730}\u{5740}</th><th>\u{1F525}</th><th>\u{72B6}\u{6001}</th><th>\u{64CD}\u{4F5C}</th></tr></thead><tbody>';
      for (var i = 0; i < data.data.length; i++) {
        var v = data.data[i];
        var statusBadge = v.status === 'approved' ? 'badge green' : (v.status === 'pending' ? 'badge orange' : 'badge red');
        var statusText = v.status === 'approved' ? '\u{5DF2}\u{901A}\u{8FC7}' : (v.status === 'pending' ? '\u{5F85}\u{5BA1}\u{6838}' : v.status);
        html += '<tr><td>' + (v.name || '') + '</td><td>' + (v.type || '-') + '</td><td style="font-size:12px;max-width:200px;overflow:hidden;text-overflow:ellipsis">' + (v.address || '-') + '</td><td>' + (v.chaihuo_total || 0) + '</td><td><span class="' + statusBadge + '">' + statusText + '</span></td><td>';
        if (v.status === 'pending') html += '<button class="btn-sm" onclick="approveVenue('' + v.id + '')">\u{901A}\u{8FC7}</button>';
        html += '</td></tr>';
      }
      html += '</tbody></table>';
      el.innerHTML = html;
    } else {
      el.innerHTML = '<p style="color:#999">\u{6682}\u{65E0}\u{573A}\u{5730}\u{6570}\u{636E}</p>';
    }
  });
}

function approveVenue(venueId) {
  if (!adminToken) return;
  apiCall('/api/admin/venues/' + venueId + '/approve', 'POST').then(function(data) {
    if (data.success) loadVenues();
  });
}

updateUI();
if (adminToken) { showDashboard(); }
</script>
</body>
</html>`;
}
