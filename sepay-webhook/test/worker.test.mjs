// Chạy: node --test test/   (không cần mạng, không đụng cơ sở dữ liệu thật)
import test from 'node:test';
import assert from 'node:assert/strict';
import { handle, bookingCode, money, hmacHex } from '../src/worker.js';

const ACCOUNT = '0000000000';
const NOW = 1_800_000_000_000;
const env = { ACCOUNT_NUMBER: ACCOUNT, SEPAY_HMAC_SECRET: 'khoa-thu', FIRESTORE_PROJECT: 'du-an-thu' };

const doc = (collection, docId, values) => ({
  document: {
    name: `projects/p/databases/(default)/documents/${collection}/${docId}`,
    fields: Object.fromEntries(Object.entries(values).map(([k, v]) => [k, { stringValue: v }])),
  },
});

/** Firestore giả giữ dữ liệu trong bộ nhớ và ghi lại mọi lần sửa. */
function fakeStore({ bookings = [], payments = [], failPatch = false } = {}) {
  const writes = [];
  const http = async (url, init) => {
    if (url.endsWith(':runQuery')) {
      const q = JSON.parse(init.body).structuredQuery;
      const name = q.from[0].collectionId;
      let rows = name === 'bookings' ? bookings : payments;
      if (name === 'payments') rows = rows.filter((p) => p.bookingId === q.where.fieldFilter.value.stringValue);
      return new Response(JSON.stringify(rows.map((r) => doc(name, r.docId ?? r.id, r))), { status: 200 });
    }
    if (failPatch) return new Response('{}', { status: 503 });
    const [path] = url.split('?');
    const fields = Object.fromEntries(Object.entries(JSON.parse(init.body).fields).map(([k, v]) => [k, v.stringValue]));
    writes.push({ doc: path.split('/documents/')[1], ...fields });
    return new Response('{}', { status: 200 });
  };
  return { http, writes };
}

const transfer = (over = {}) => ({
  id: 1, gateway: 'MBBank', accountNumber: ACCOUNT, code: null, content: 'BK123456', transferType: 'in',
  transferAmount: 200000, referenceCode: 'FT999', ...over,
});

async function post(body, { headers, store, settings = env } = {}) {
  const raw = JSON.stringify(body);
  const ts = String(NOW / 1000);
  const signed = { 'X-SePay-Timestamp': ts, 'X-SePay-Signature': `sha256=${await hmacHex('khoa-thu', `${ts}.${raw}`)}` };
  const request = new Request('https://x/', { method: 'POST', body: raw, headers: headers ?? signed });
  const res = await handle(request, settings, store.http, () => NOW);
  return { status: res.status, body: await res.json() };
}

const pendingOne = () => ({
  bookings: [{ id: 'BK-123456', status: 'Chờ xác nhận', amount: '200.000 đ' }],
  payments: [{ docId: 'PAY-1', bookingId: 'BK-123456', status: 'Đang xử lý' }],
});

test('tiền đủ, đúng mã: xác nhận đơn và phiếu thu, trả đúng {"success": true}', async () => {
  const store = fakeStore(pendingOne());
  const r = await post(transfer(), { store });
  assert.deepEqual(r, { status: 200, body: { success: true } });
  assert.deepEqual(store.writes, [
    { doc: 'payments/PAY-1', status: 'Thành công', bankRef: 'FT999' },
    { doc: 'bookings/BK-123456', status: 'Đã xác nhận' },
  ]);
});

test('đặt nhiều sân cùng một mã: phải đủ tổng tiền mới xác nhận tất cả', async () => {
  const data = {
    bookings: [
      { id: 'BK-123456-1', status: 'Chờ xác nhận', amount: '200.000 đ' },
      { id: 'BK-123456-2', status: 'Chờ xác nhận', amount: '100.000 đ' },
      { id: 'BK-1234567', status: 'Chờ xác nhận', amount: '100.000 đ' }, // mã khác, không được đụng
    ],
  };
  const short = fakeStore(data);
  await post(transfer({ transferAmount: 200000 }), { store: short });
  assert.equal(short.writes.length, 0);

  const full = fakeStore(data);
  await post(transfer({ transferAmount: 300000 }), { store: full });
  assert.deepEqual(full.writes.map((w) => w.doc), ['bookings/BK-123456-1', 'bookings/BK-123456-2']);
});

test('chuyển thiếu, sai tài khoản, tiền ra, không có mã, đơn đã hủy: không sửa gì nhưng vẫn trả thành công', async () => {
  const cases = [
    transfer({ transferAmount: 199999 }),
    transfer({ accountNumber: '111' }),
    transfer({ transferType: 'out' }),
    transfer({ content: 'chuyen tien an trua' }),
  ];
  for (const body of cases) {
    const store = fakeStore(pendingOne());
    const r = await post(body, { store });
    assert.equal(r.status, 200);
    assert.equal(store.writes.length, 0, JSON.stringify(body));
  }
  const cancelled = fakeStore({ bookings: [{ id: 'BK-123456', status: 'Đã hủy', amount: '200.000 đ' }] });
  await post(transfer(), { store: cancelled });
  assert.equal(cancelled.writes.length, 0);
});

test('SePay gửi lại giao dịch đã xử lý thì không ghi lần nữa', async () => {
  const store = fakeStore({ bookings: [{ id: 'BK-123456', status: 'Đã xác nhận', amount: '200.000 đ' }] });
  const r = await post(transfer(), { store });
  assert.equal(r.status, 200);
  assert.equal(store.writes.length, 0);
});

test('không có chữ ký, chữ ký sai hoặc quá cũ thì bị từ chối', async () => {
  const body = transfer();
  const raw = JSON.stringify(body);
  const old = String(NOW / 1000 - 4000);
  const bad = [
    {},
    { 'X-SePay-Timestamp': String(NOW / 1000), 'X-SePay-Signature': 'sha256=00' },
    { 'X-SePay-Timestamp': old, 'X-SePay-Signature': `sha256=${await hmacHex('khoa-thu', `${old}.${raw}`)}` },
    { Authorization: 'Apikey doan-mo' },
  ];
  for (const headers of bad) {
    const store = fakeStore(pendingOne());
    const r = await post(body, { headers, store });
    assert.equal(r.status, 401, JSON.stringify(headers));
    assert.equal(store.writes.length, 0);
  }
});

test('xác thực kiểu API Key; chưa cấu hình khóa thì từ chối tất cả', async () => {
  const store = fakeStore(pendingOne());
  const settings = { ACCOUNT_NUMBER: ACCOUNT, SEPAY_API_KEY: 'abc', FIRESTORE_PROJECT: 'x' };
  assert.equal((await post(transfer(), { headers: { Authorization: 'Apikey abc' }, store, settings })).status, 200);
  assert.equal(store.writes.length, 2);
  assert.equal((await post(transfer(), { headers: { Authorization: 'Apikey abc' }, store, settings: { ACCOUNT_NUMBER: ACCOUNT } })).status, 500);
});

test('ghi cơ sở dữ liệu lỗi thì trả 500 để SePay gửi lại', async () => {
  const store = fakeStore({ ...pendingOne(), failPatch: true });
  assert.equal((await post(transfer(), { store })).status, 500);
});

test('đọc mã đơn và số tiền', () => {
  assert.equal(bookingCode('MBVCB.88.BK123456.CT tu 0123'), 'BK-123456');
  assert.equal(bookingCode('bk 123456 thanh toan'), 'BK-123456');
  assert.equal(bookingCode('BK1234567'), null);
  assert.equal(bookingCode('xin chao'), null);
  assert.equal(money('1.200.000 đ'), 1200000);
});
