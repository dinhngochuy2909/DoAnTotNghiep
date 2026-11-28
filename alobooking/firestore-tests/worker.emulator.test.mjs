// Máy nhận webhook chạy với bộ mô phỏng Firebase: đăng nhập tài khoản riêng và xác nhận đơn dưới luật bảo mật thật.
//   firebase emulators:exec --only firestore,auth --project demo-alobooking "node --test firestore-tests/worker.emulator.test.mjs"
import test from 'node:test';
import assert from 'node:assert/strict';
import { handle, hmacHex } from '../../sepay-webhook/src/worker.js';

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-alobooking';
const STORE = `http://${process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080'}`;
const AUTH = `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099'}`;
const BASE = `${STORE}/v1/projects/${PROJECT}/databases/(default)/documents`;
const SECRET = 'khoa-thu';

const value = (v) => (Number.isInteger(v) ? { integerValue: String(v) } : { stringValue: v });
const seed = async (path, data) => {
  const res = await fetch(`${BASE}/${path}`, {
    method: 'PATCH', headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, value(v)])) }),
  });
  assert.equal(res.status, 200);
};
const status = async (path) => (await (await fetch(`${BASE}/${path}`, { headers: { Authorization: 'Bearer owner' } })).json())
  .fields.status.stringValue;

/** Máy nhận gọi địa chỉ thật của Google: đổi sang bộ mô phỏng. */
const http = (url, init) => fetch(url
  .replace('https://firestore.googleapis.com', STORE)
  .replace('https://identitytoolkit.googleapis.com', `${AUTH}/identitytoolkit.googleapis.com`), init);

async function notify(env, amount, code) {
  const raw = JSON.stringify({ id: 1, accountNumber: env.ACCOUNT_NUMBER, content: code, transferType: 'in', transferAmount: amount, referenceCode: 'FT1' });
  const ts = String(Math.floor(Date.now() / 1000));
  const request = new Request('https://x/', { method: 'POST', body: raw,
    headers: { 'X-SePay-Timestamp': ts, 'X-SePay-Signature': `sha256=${await hmacHex(SECRET, `${ts}.${raw}`)}` } });
  return (await handle(request, env, http, () => Date.now())).status;
}

test('máy nhận xác nhận đơn bằng tài khoản riêng; không có tài khoản thì luật chặn', async () => {
  assert.ok(PROJECT.startsWith('demo-'));
  await fetch(`${STORE}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: 'DELETE' });
  await fetch(`${AUTH}/emulator/v1/projects/${PROJECT}/accounts`, { method: 'DELETE' });
  const signUp = await (await fetch(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=k`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'may@thu.vn', password: 'matkhau-may', returnSecureToken: true }),
  })).json();
  await seed(`users/${signUp.localId}`, { role: 'webhook' });
  await seed('venues/7', { name: 'Sân', price: '80k - 100k/h' });
  await seed('bookings/BK-555555', { id: 'BK-555555', status: 'Chờ xác nhận', amount: '80.000đ', venueId: 7, time: '10:00 - 11:00', userId: 'u', ownerId: 'o' });
  await seed('payments/PAY-555555', { bookingId: 'BK-555555', status: 'Đang xử lý', userId: 'u', ownerId: 'o' });
  const env = { ACCOUNT_NUMBER: '000', SEPAY_HMAC_SECRET: SECRET, FIRESTORE_PROJECT: PROJECT, FIREBASE_API_KEY: 'k' };

  assert.equal(await notify(env, 80000, 'BK555555'), 500, 'không đăng nhập thì bị luật chặn, SePay sẽ gửi lại');
  assert.equal(await status('bookings/BK-555555'), 'Chờ xác nhận');

  assert.equal(await notify({ ...env, BOT_EMAIL: 'may@thu.vn', BOT_PASSWORD: 'matkhau-may' }, 80000, 'BK555555'), 200);
  assert.equal(await status('bookings/BK-555555'), 'Đã xác nhận');
  assert.equal(await status('payments/PAY-555555'), 'Thành công');
});
