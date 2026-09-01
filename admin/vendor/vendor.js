/* لوحة البائع — موبايل first، حالة مركزية، قراءة/إجراءات عبر API */
'use strict';
const API = location.origin + '/mp-api/api/v1';
let token = localStorage.getItem('sm_vendor_token') || null;
let vendor = null;
let wallet = null;

const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

async function api(path, { method = 'GET', body } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = 'Bearer ' + token;
  const res = await fetch(API + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  let json = null; try { json = await res.json(); } catch {}
  if (res.status === 401) { token = null; localStorage.removeItem('sm_vendor_token'); renderLogin(); throw new Error('انتهت الجلسة'); }
  if (!res.ok) throw new Error((json && json.message) || 'HTTP ' + res.status);
  return json.data !== undefined ? json.data : json;
}
function toast(m) { const t = $('#toast'); t.textContent = m; t.classList.add('show'); setTimeout(() => t.classList.remove('show'), 2400); }
function fmtDT(iso) { return new Date(iso).toLocaleString('ar', { weekday: 'short', hour: '2-digit', minute: '2-digit', day: 'numeric', month: 'short' }); }
function badge(s) { return `<span class="badge ${esc(s)}">${esc(s === 'PENDING' ? 'قيد الانتظار' : s === 'CONFIRMED' ? 'مؤكد' : s === 'COMPLETED' ? 'مكتمل' : s === 'CANCELLED' ? 'ملغى' : s === 'REJECTED' ? 'مرفوض' : s === 'EXPIRED' ? 'منتهي' : s)}</span>`; }

function renderLogin() {
  setTimeout(() => { const go = document.querySelector('#login-go'); if (go) go.onclick = doLogin; });
  document.body.innerHTML = `<div style="max-width:380px;margin:70px auto 0;padding:0 16px">
   <div style="background:#fff;border:1px solid var(--bd);border-radius:12px;padding:24px">
    <h2 style="margin-bottom:16px">دخول البائع</h2>
    <input id="em" placeholder="البريد" style="width:100%;padding:11px 14px;margin-bottom:10px;border:1px solid var(--bd);border-radius:8px;font:inherit">
    <input id="pw" type="password" placeholder="كلمة المرور" style="width:100%;padding:11px 14px;margin-bottom:14px;border:1px solid var(--bd);border-radius:8px;font:inherit">
    <button class="btn" id="login-go" style="width:100%">دخول</button>
    <p id="err" style="color:var(--er);margin-top:10px;font-size:13px"></p></div></div>`;
}
async function doLogin() {
  try {
    const res = await fetch(API + '/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: $('#em').value.trim(), password: $('#pw').value }) });
    const j = await res.json();
    if (!res.ok) throw new Error(j.message || 'فشل');
    if (j.data.user.role !== 'VENDOR' && j.data.user.role !== 'ADMIN') throw new Error('هذا الحساب ليس بائعاً');
    token = j.data.accessToken; localStorage.setItem('sm_vendor_token', token);
    location.reload();
  } catch (e) { $('#err').textContent = e.message; }
}

async function loadVendor() {
  const me = await api('/vendors/me/profile');
  vendor = me;
  $('#vendor-name').textContent = me.name;
  $('#vendor-status').textContent = me.status === 'APPROVED' ? '✓ معتمد' : me.status;
}

async function loadBookings() {
  const d = await api('/bookings/vendor/queue?limit=50');
  const rows = d || [];
  const pending = rows.filter((r) => r.status === 'PENDING');
  const bn = $('#pending-banner');
  if (pending.length) { bn.classList.remove('hidden'); $('#pending-num').textContent = pending.length; }
  else bn.classList.add('hidden');

  const todayStr = new Date().toDateString();
  const todays = rows.filter((r) => new Date(r.startsAt).toDateString() === todayStr);
  $('#today-list').innerHTML = todays.length ? todays.map((r) => `
    <div class="bcard">
      <div class="time">${esc(fmtDT(r.startsAt))}</div>
      <div class="name">${esc(r.bookingRef)}</div>
      <div class="cust">${esc(r.customer?.profile?.firstName || '')} ${esc(r.customer?.profile?.lastName || '')}</div>
      <div class="foot">${badge(r.status)}<span style="font-weight:700">${esc(r.totalPrice + ' ' + r.currency)}</span></div>
    </div>`).join('')
    : `<div class="empty" style="width:100%">لا حجوزات اليوم — قدم خدماتك وس تظهر هنا.</div>`;

  $('#requests-list').innerHTML = pending.length ? pending.map((r) => `
    <div class="bcard" style="margin-bottom:10px">
      <div class="time">${esc(fmtDT(r.startsAt))}</div>
      <div class="name">${esc(r.bookingRef)} — ${esc(r.customer?.profile?.firstName || 'عميل')}</div>
      <div class="foot">${badge(r.status)}
        <div class="acts">
          <button class="btn" onclick="decide('${r.id}','CONFIRMED')">قبول</button>
          <button class="btn ghost" onclick="decide('${r.id}','REJECTED')">رفض</button>
        </div></div>
    </div>`).join('')
    : '<div class="empty">لا طلبات معلقة حالياً — كل شيء تحت السيطرة.</div>';
}

async function decide(id, decision) {
  try {
    await api(`/bookings/${id}/${decision === 'CONFIRMED' ? 'confirm' : 'reject'}`, { method: 'PATCH', body: {} });
    toast(decision === 'CONFIRMED' ? 'تم القبول وإشعار العميل' : 'تم الرفض');
    await loadBookings();
  } catch (e) { toast(e.message); }
}

async function loadWallet() {
  try {
    const d = await api('/wallet');
    wallet = d.wallet;
    const sales = d.transactions.filter((t) => t.type === 'SALE').reduce((a, t) => a + t.amount, 0);
    $('#wallet-balance').textContent = `${wallet.balance} ${wallet.currency}`;
    $('#wallet-balance2').textContent = `${wallet.balance} ${wallet.currency}`;
    $('#total-sales').textContent = `${sales} ${wallet.currency}`;
    $('#tx-list').innerHTML = d.transactions.length ? d.transactions.map((t) => `
      <div class="rev" style="margin-bottom:8px;display:flex;justify-content:space-between;align-items:center">
        <span>${esc(t.type)}<br><span style="color:var(--mu);font-size:11px">${esc(new Date(t.createdAt).toLocaleDateString('ar'))}</span></span>
        <b style="color:${t.type === 'SALE' ? 'var(--ok)' : 'var(--er)'}">${t.type === 'SALE' ? '+' : '-'}${esc(String(t.amount))}</b>
      </div>`).join('') : '<div class="empty">لا حركات بعد</div>';
  } catch (e) {
    $('#wallet-balance').textContent = '—';
    $('#tx-list').innerHTML = `<div class="empty">${esc(e.message)}</div>`;
  }
}

async function requestPayout() {
  try {
    const bal = wallet?.balance ?? 0;
    await api('/wallet/payouts', { method: 'POST', body: { amount: bal, note: 'سحب من اللوحة' } });
    toast('تم إرسال طلب السحب للإدارة');
  } catch (e) { toast(e.message); }
}

async function loadServices() {
  const rows = await api('/services/mine');
  $('#services-list').innerHTML = rows.length ? rows.map((s) => `
    <div class="rev" style="margin-bottom:8px">
      <div class="r1"><b>${esc(s.name)}</b><b style="color:var(--p)">${esc(s.price + ' ' + s.currency)}</b></div>
      <p>${esc(s.description || 'بدون وصف')} — ${badge(s.isActive ? 'CONFIRMED' : 'EXPIRED')}</p>
    </div>`).join('') : '<div class="empty">لا خدمات بعد — أضف خدمتك الأولى عبر الـ API</div>';
}

function showSection(v) {
  ['today', 'requests', 'wallet', 'services'].forEach((s) => {
    const el = $('#sec-' + s); if (el) el.style.display = s === v ? 'block' : 'none';
  });
  document.querySelectorAll('#bottomnav a').forEach((a) => a.classList.toggle('active', a.dataset.v === v || (v === 'today' && a.dataset.v === 'today')));
  window.scrollTo(0, 0);
}

document.querySelectorAll('#bottomnav a').forEach((a) => {
  a.addEventListener('click', (e) => { e.preventDefault(); showSection(a.dataset.v); });
});

(async function init() {
  if (!token) { renderLogin(); return; }
  try {
    await loadVendor();
    await Promise.all([loadBookings(), loadWallet(), loadServices()]);
  } catch (e) { toast(e.message); }
})();
