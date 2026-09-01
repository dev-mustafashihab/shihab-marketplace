/* لوحة الإدارة — vanilla SPA. حالة مركزية + routes + جداول. */
'use strict';

const API = location.origin + '/mp-api/api/v1';
let state = { token: sessionStorage.getItem('sm_admin_token') || null, route: 'dashboard', cache: {} };

/* ---------- API helper ---------- */
async function api(path, { method = 'GET', body } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (state.token) headers.Authorization = 'Bearer ' + state.token;
  const res = await fetch(API + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  let json = null;
  try { json = await res.json(); } catch { json = null; }
  if (res.status === 401 && state.token) { logout(); throw new Error('انتهت الجلسة، سجّل الدخول من جديد'); }
  if (!res.ok) throw new Error((json && json.message) || ('HTTP ' + res.status));
  return json;
}

/* ---------- utilities ---------- */
const $ = (sel) => document.querySelector(sel);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
function toast(msg, kind = '') {
  const el = document.createElement('div');
  el.className = 'toast ' + kind; el.textContent = msg;
  $('#toast-root').appendChild(el);
  setTimeout(() => el.remove(), 3200);
}
function badge(status) { return `<span class="badge ${esc(status)}">${esc(status)}</span>`; }
function confirmDialog(title, text, confirmLabel = 'تأكيد') {
  return new Promise((resolve) => {
    const root = $('#dialog-root');
    root.innerHTML = `<div class="dialog-overlay"><div class="dialog">
      <h3>${esc(title)}</h3><p>${esc(text)}</p>
      <div class="actions"><button class="btn danger" id="dlg-ok">${esc(confirmLabel)}</button>
      <button class="btn ghost" id="dlg-cancel">إلغاء</button></div></div></div>`;
    $('#dlg-ok').onclick = () => { root.innerHTML = ''; resolve(true); };
    $('#dlg-cancel').onclick = () => { root.innerHTML = ''; resolve(false); };
  });
}
function drawer(html) {
  const root = $('#drawer-root');
  root.innerHTML = `<div class="drawer-overlay" id="drawer-overlay"></div><div class="drawer">${html}</div>`;
  $('#drawer-overlay').onclick = closeDrawer;
}
function closeDrawer() { $('#drawer-root').innerHTML = ''; }
function loginScreen() {
  $('#content').innerHTML = `<div class="card" style="max-width:420px;margin:60px auto;padding:26px">
    <h3 style="margin-bottom:14px">دخول لوحة الإدارة</h3>
    <input id="li-email" class="search-input" style="width:100%;margin-bottom:10px" placeholder="البريد">
    <input id="li-pass" type="password" class="search-input" style="width:100%;margin-bottom:14px" placeholder="كلمة المرور">
    <button class="btn" id="li-go" style="width:100%">تسجيل الدخول</button>
    <p id="li-err" style="color:var(--error);margin-top:10px"></p></div>`;
  $('#li-go').onclick = async () => {
    try {
      const res = await fetch(API + '/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: $('#li-email').value.trim(), password: $('#li-pass').value }) });
      const json = await res.json();
      if (!res.ok) throw new Error(json.message || 'فشل الدخول');
      if (json.data.user.role !== 'ADMIN') throw new Error('هذا الحساب ليس مدير منصة');
      state.token = json.data.accessToken;
      sessionStorage.setItem('sm_admin_token', state.token);
      toast('مرحباً', 'success'); route();
    } catch (e) { $('#li-err').textContent = e.message; }
  };
}
function logout() { state.token = null; sessionStorage.removeItem('sm_admin_token'); route(); }

/* ---------- table renderer ---------- */
function renderTable({ columns, rows, rowId, actions, bulk, empty }) {
  if (!rows || !rows.length) return `<div class="state-empty">${esc(empty || 'لا توجد بيانات بعد')}</div>`;
  const head = `<tr>${bulk ? '<th style="width:34px"><input type="checkbox" id="chk-all"></th>' : ''}${columns.map((c) => `<th>${esc(c.label)}</th>`).join('')}${actions ? '<th></th>' : ''}</tr>`;
  const body = rows.map((r, idx) => `<tr data-id="${esc(rowId(r))}">
    ${bulk ? '<td><input type="checkbox" class="chk-row" data-id="' + esc(rowId(r)) + '"></td>' : ''}
    ${columns.map((c) => `<td>${c.render ? c.render(r) : esc(c.field ? r[c.field] : '')}</td>`).join('')}
    ${actions ? '<td style="white-space:nowrap"></td>' : ''}</tr>`).join('');
  return `<div class="card"><table><thead>${head}</thead><tbody>${body}</tbody></table></div>`;
}

/* ---------- pages ---------- */
const pages = {
  async dashboard() {
    $('#page-title').textContent = 'لوحة التحكم';
    $('#content').innerHTML = '<div class="kpis">' + [1, 2, 3, 4].map(() => '<div class="kpi"><div class="label skeleton" style="height:12px"></div><div class="value skeleton" style="height:26px;margin-top:8px"></div></div>').join('') + '</div>';
    const [users, vendorsP, bookings, orders] = await Promise.all([
      api('/users?limit=1'), api('/vendors/admin/queue/PENDING?limit=1'), api('/bookings/mine?limit=1'), api('/orders/vendor/queue?limit=1'),
    ]);
    const usersTotal = users.meta?.total ?? '—';
    const pendingVendors = Array.isArray(vendorsP) ? vendorsP[0] : (vendorsP.meta?.total ?? 0);
    const bookingsTotal = bookings.meta?.total ?? '—';
    const ordersTotal = orders.meta?.total ?? '—';
    $('#content').innerHTML = `<div class="kpis">
      <div class="kpi"><div class="label">المستخدمون</div><div class="value">${esc(usersTotal)}</div></div>
      <div class="kpi"><div class="label">بائعون بانتظار التحقق</div><div class="value">${esc(pendingVendors)}</div><div class="sub">يتطلب إجراء</div></div>
      <div class="kpi"><div class="label">الحجوزات</div><div class="value">${esc(bookingsTotal)}</div></div>
      <div class="kpi"><div class="label">الطلبات</div><div class="value">${esc(ordersTotal)}</div></div>
    </div>
    <div class="card" style="padding:18px"><h3 style="margin-bottom:8px">اختصارات</h3>
      <button class="btn ghost" onclick="location.hash='#vendors-queue'">مراجعة البائعين المعلقين</button>
      <button class="btn ghost" onclick="location.hash='#payments'">الدفعات المعلقة</button></div>`;
  },

  async 'vendors-queue'() {
    $('#page-title').textContent = 'طابور التحقق';
    $('#content').innerHTML = '<div class="skeleton" style="height:200px"></div>';
    const res = await api('/vendors/admin/queue/PENDING?limit=50');
    const raw = res.data;
    const rows = Array.isArray(raw) && raw.length === 2 && typeof raw[0] === 'number' ? raw[1] : raw;
    const tableHtml = renderTable({
      columns: [
        { label: 'البائع', field: 'name' },
        { label: 'التصنيف', render: (r) => esc(r.category?.nameAr || '—') },
        { label: 'المالك', render: (r) => esc(r.owner?.email || '—') },
        { label: 'الحالة', render: (r) => badge(r.status) },
      ],
      rows, rowId: (r) => r.id,
      empty: 'لا يوجد بائعون في الطابور',
    });
    $('#content').innerHTML = tableHtml;
    const tbody = $('#content').querySelector('tbody');
    if (!tbody) return; // empty state — لا جدول
    tbody.addEventListener('click', async (e) => {
      const tr = e.target.closest('tr'); if (!tr) return;
      const id = tr.dataset.id;
      const row = rows.find((r) => r.id === id);
      drawer(`<h3>${esc(row.name)}</h3>
        <div class="row"><span class="k">الوصف</span><span>${esc(row.description || '—')}</span></div>
        <div class="row"><span class="k">التصنيف</span><span>${esc(row.category?.nameAr || '—')}</span></div>
        <div class="row"><span class="k">المالك</span><span>${esc(row.owner?.email || '—')}</span></div>
        <div class="row"><span class="k">الهاتف</span><span>${esc(row.phone || '—')}</span></div>
        <div class="row"><span class="k">العنوان</span><span>${esc(row.address || '—')}</span></div>
        <div class="actions">
          <button class="btn" id="ap">اعتماد</button>
          <button class="btn danger" id="rj">رفض</button>
          <button class="btn ghost" id="cl">إغلاق</button></div>`);
      $('#cl').onclick = closeDrawer;
      $('#ap').onclick = async () => {
        if (await confirmDialog('اعتماد البائع', 'سيصبح البائع ظاهراً في البحث العام.', 'اعتماد')) {
          await api('/vendors/' + id, { method: 'PATCH', body: { status: 'APPROVED' } });
          toast('تم الاعتماد', 'success'); closeDrawer(); route();
        }
      };
      $('#rj').onclick = async () => {
        if (await confirmDialog('رفض البائع', 'سيتم رفض طلب الانضمام.', 'رفض')) {
          await api('/vendors/' + id, { method: 'PATCH', body: { status: 'REJECTED', rejectionReason: 'بيانات غير مكتملة' } });
          toast('تم الرفض'); closeDrawer(); route();
        }
      };
    });
  },

  async payments() {
    $('#page-title').textContent = 'الدفعات';
    $('#content').innerHTML = '<div class="skeleton" style="height:200px"></div>';
    const res = await api('/payments?limit=50');
    const raw = res.data;
    const rows = Array.isArray(raw) && raw.length === 2 && typeof raw[0] === 'number' ? raw[1] : raw;
    $('#content').innerHTML = renderTable({
      columns: [
        { label: 'المعرّف', render: (r) => `<span class="mono">${esc(r.id.slice(0, 8))}</span>` },
        { label: 'المزود', field: 'provider' },
        { label: 'المبلغ', render: (r) => esc(r.amount + ' ' + r.currency) },
        { label: 'الحالة', render: (r) => badge(r.status) },
        { label: 'التاريخ', render: (r) => esc(new Date(r.createdAt).toLocaleString('ar')) },
      ],
      rows, rowId: (r) => r.id,
      empty: 'لا توجد دفعات',
    });
    $('#content').querySelector('tbody').addEventListener('click', async (e) => {
      const tr = e.target.closest('tr'); if (!tr) return;
      const id = tr.dataset.id;
      const row = rows.find((r) => r.id === id);
      if (row.status !== 'PENDING') { toast('الدفعة معالجة مسبقاً'); return; }
      if (await confirmDialog('تأكيد الدفعة', 'سيتم تأكيد استلام التحويل وتحديث الحجز/الطلب والمحفظة.', 'تأكيد الدفع')) {
        await api('/payments/' + id + '/confirm', { method: 'PATCH' });
        toast('تم التأكيد وأثره على المحفظة', 'success'); route();
      }
    });
  },

  async bookings() {
    $('#page-title').textContent = 'الحجوزات';
    $('#content').innerHTML = '<div class="skeleton" style="height:200px"></div>';
    const res = await api('/orders/vendor/queue?limit=50');
    const rows = res.data || [];
    $('#content').innerHTML = renderTable({
      columns: [
        { label: 'المرجع', render: (r) => `<span class="mono">${esc(r.orderRef)}</span>` },
        { label: 'البائع', render: (r) => esc(r.vendor?.name || '—') },
        { label: 'الإجمالي', render: (r) => esc(r.total + ' ' + r.currency) },
        { label: 'الحالة', render: (r) => badge(r.status) },
      ],
      rows, rowId: (r) => r.id, empty: 'لا توجد طلبات',
    });
  },

  async settings() {
    $('#page-title').textContent = 'الإعدادات المالية';
    const res = await api('/settings/financial');
    const s = res && res.data ? res.data : res;
    $('#content').innerHTML = `<div class="card" style="max-width:520px;padding:20px">
      <h3 style="margin-bottom:14px">نسبة العمولة</h3>
      <div style="display:flex;gap:10px;align-items:center">
        <input id="st-comm" type="number" min="0" max="50" value="${esc(s.commissionPercent)}" class="search-input" style="width:110px">
        <span>%</span>
        <button class="btn" id="st-save">حفظ</button></div>
      <p class="muted" style="margin-top:10px">تُطبَّق النسبة على الدفعات الجديدة لحظة تأكيدها.</p></div>`;
    $('#st-save').onclick = async () => {
      await api('/settings/financial', { method: 'PATCH', body: { commissionPercent: Number($('#st-comm').value) } });
      toast('تم الحفظ', 'success');
    };
  },
};

/* ---------- nav & router ---------- */
const NAV = [
  { section: 'عام' },
  { id: 'dashboard', label: 'لوحة التحكم' },
  { section: 'إدارة' },
  { id: 'vendors-queue', label: 'التحقق من البائعين' },
  { id: 'payments', label: 'الدفعات' },
  { id: 'bookings', label: 'الطلبات' },
  { section: 'النظام' },
  { id: 'settings', label: 'الإعدادات المالية' },
];

function renderNav() {
  $('#nav').innerHTML = NAV.map((n) => n.section
    ? `<div class="nav-section">${esc(n.section)}</div>`
    : `<div class="nav-item ${state.route === n.id ? 'active' : ''}" data-route="${n.id}">${esc(n.label)}</div>`).join('');
  $('#nav').querySelectorAll('.nav-item').forEach((el) => {
    el.onclick = () => { location.hash = '#' + el.dataset.route; };
  });
}

async function route() {
  renderNav();
  if (!state.token) { $('#page-title').textContent = 'لوحة إدارة المنصة'; return loginScreen(); }
  const page = pages[state.route] || pages.dashboard;
  try { await page(); } catch (e) {
    $('#content').innerHTML = `<div class="state-error">${esc(e.message)}<br><button class="btn ghost" onclick="route()" style="margin-top:10px">إعادة المحاولة</button></div>`;
  }
}

/* ---------- API health dot ---------- */
async function pingApi() {
  try { await fetch(API + '/health'); $('#api-status').classList.add('online'); }
  catch { $('#api-status').classList.remove('online'); }
}

window.addEventListener('hashchange', () => {
  const h = location.hash.replace('#', '');
  if (h && h !== state.route) { state.route = h; route(); }
});

pingApi(); setInterval(pingApi, 15000);
if (location.hash) state.route = location.hash.replace('#', '') || 'dashboard';
route();
