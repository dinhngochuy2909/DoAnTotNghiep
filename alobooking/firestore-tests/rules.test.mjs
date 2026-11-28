// Kiểm thử luật bảo mật trên bộ mô phỏng Firestore (không đụng dữ liệu thật). Cần Java 21.
//   firebase emulators:exec --only firestore --project demo-alobooking "node --test firestore-tests/rules.test.mjs"
import { before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';

const HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const PROJECT = process.env.GCLOUD_PROJECT || 'demo-alobooking';
const ROOT = `projects/${PROJECT}/databases/(default)/documents`;
const BASE = `http://${HOST}/v1/${ROOT}`;

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
/** Token giả mà bộ mô phỏng chấp nhận, tương đương người dùng có mã `uid` đã đăng nhập. */
const token = (uid) => `${b64({ alg: 'none', typ: 'JWT' })}.${b64({
  sub: uid, user_id: uid, aud: PROJECT, iss: `https://securetoken.google.com/${PROJECT}`,
  iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 3600,
})}.`;

const value = (v) => (typeof v === 'boolean' ? { booleanValue: v }
  : Number.isInteger(v) ? { integerValue: String(v) }
    : typeof v === 'number' ? { doubleValue: v } : { stringValue: v });
const fields = (o) => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, value(v)]));

async function call(path, { as, method = 'GET', body } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (as) headers.Authorization = `Bearer ${as === 'seed' ? 'owner' : token(as)}`;
  const res = await fetch(path.startsWith('http') ? path : `${BASE}${path}`, { method, headers, body: body && JSON.stringify(body) });
  await res.arrayBuffer();
  return res.status;
}

const get = (path, as) => call(`/${path}`, { as });
const create = (collection, id, data, as) => call(`/${collection}?documentId=${id}`, { as, method: 'POST', body: { fields: fields(data) } });
const update = (path, data, as) => call(
  `/${path}?${Object.keys(data).map((k) => `updateMask.fieldPaths=${k}`).join('&')}`,
  { as, method: 'PATCH', body: { fields: fields(data) } });
const where = (field, op, v) => ({ fieldFilter: { field: { fieldPath: field }, op, value: value(v) } });
const query = (collection, filters, as) => call(`${BASE}:runQuery`, {
  as, method: 'POST', body: { structuredQuery: { from: [{ collectionId: collection }],
    where: filters.length === 1 ? filters[0] : { compositeFilter: { op: 'AND', filters } } } } });
/** Ghi nhiều tài liệu cùng lúc, như ứng dụng làm khi tạo đơn. */
const commit = (docs, as) => call(`${BASE}:commit`, {
  as, method: 'POST', body: { writes: docs.map(([path, data]) => ({
    update: { name: `${ROOT}/${path}`, fields: fields(data) }, currentDocument: { exists: false } })) } });

const allowed = async (promise, what) => assert.equal(await promise, 200, `phải được phép: ${what}`);
const denied = async (promise, what) => assert.equal(await promise, 403, `phải bị từ chối: ${what}`);

const booking = (id, userId, extra = {}) => ({
  id, userId, ownerId: 'chu1', venueId: 1, venueName: 'Sân A', field: 'Sân 1', date: '01/12/2026', time: '18:00 - 19:00',
  customer: 'Khách', phone: '0900000000', amount: '100.000đ', status: 'Chờ xác nhận', paymentMethod: 'VietQR',
  createdAt: '2026-11-28T10:00:00', ...extra,
});
const slot = (b) => ({ venueId: b.venueId, venueName: b.venueName, field: b.field, date: b.date, time: b.time,
  status: 'Đã đặt', paymentMethod: b.paymentMethod, createdAt: b.createdAt });
const payment = (b) => ({ id: `PAY-${b.id}`, bookingId: b.id, userId: b.userId, ownerId: b.ownerId, amount: b.amount, status: 'Đang xử lý', bankRef: '' });
/** Ba tài liệu ứng dụng ghi cho một đơn. */
const order = (b) => [[`bookings/${b.id}`, b], [`slots/${b.id}`, slot(b)], [`payments/PAY-${b.id}`, payment(b)]];

before(async () => {
  assert.ok(PROJECT.startsWith('demo-'), 'chỉ chạy trên dự án demo-*');
});

beforeEach(async () => {
  await call(`http://${HOST}/emulator/v1/${ROOT}`, { method: 'DELETE' });
  const seed = (path, data) => call(`/${path}`, { as: 'seed', method: 'PATCH', body: { fields: fields(data) } });
  for (const [id, role] of [['adm', 'admin'], ['chu1', 'owner'], ['chu2', 'owner'], ['khachA', 'customer'], ['khachB', 'customer'], ['may', 'webhook']]) {
    await seed(`users/${id}`, { role, fullName: id, email: `${id}@thu.vn`, phone: '09' });
  }
  await seed('venues/1', { id: 1, name: 'Sân A', ownerId: 'chu1', approvalStatus: 'approved', price: '80k - 100k/h' });
  await seed('venues/2', { id: 2, name: 'Sân B', ownerId: 'chu2', approvalStatus: 'approved', price: '80k - 100k/h' });
  const b = booking('BK-100001', 'khachA');
  for (const [path, data] of order(b)) await seed(path, data);
  await seed('notifications/N1', { userId: 'chu1', title: 'Đơn mới', message: 'x', isRead: false });
});

test('khách vãng lai chỉ đọc được dữ liệu công khai', async () => {
  await allowed(get('venues/1'), 'xem sân');
  await allowed(get('slots/BK-100001'), 'xem lịch bận');
  await denied(get('bookings/BK-100001'), 'đọc đơn (có tên, số điện thoại)');
  await denied(get('bookings'), 'liệt kê đơn');
  await denied(get('users/khachA'), 'đọc hồ sơ');
  await denied(get('users'), 'liệt kê người dùng');
  await denied(get('payments/PAY-BK-100001'), 'đọc phiếu thu');
  await denied(create('venues', '9', { name: 'x', ownerId: 'x', approvalStatus: 'approved' }), 'thêm sân');
  await denied(update('venues/1', { price: '1k - 1k/h' }), 'đổi giá sân');
  await denied(create('news', 'n1', { title: 'x' }), 'đăng tin');
  await denied(commit(order(booking('BK-100002', 'khachA'))), 'đặt sân khi chưa đăng nhập');
});

test('khách chỉ đọc được đơn của mình', async () => {
  await allowed(get('bookings/BK-100001', 'khachA'), 'đơn của mình');
  await denied(get('bookings/BK-100001', 'khachB'), 'đơn người khác');
  await denied(get('bookings', 'khachA'), 'liệt kê mọi đơn');
  await allowed(query('bookings', [where('userId', 'EQUAL', 'khachA')], 'khachA'), 'lọc đơn của mình');
  await denied(query('bookings', [where('userId', 'EQUAL', 'khachA')], 'khachB'), 'lọc đơn người khác');
  await allowed(query('payments', [where('userId', 'EQUAL', 'khachA')], 'khachA'), 'phiếu thu của mình');
});

test('đặt sân: chỉ cho chính mình, đúng chủ sân, đơn bắt đầu ở "Chờ xác nhận"', async () => {
  await allowed(commit(order(booking('BK-200001', 'khachB')), 'khachB'), 'đặt sân hợp lệ');
  await denied(commit(order(booking('BK-200002', 'khachA')), 'khachB'), 'đặt tên người khác');
  await denied(commit(order(booking('BK-200003', 'khachB', { status: 'Đã xác nhận' })), 'khachB'), 'tự tạo đơn đã xác nhận');
  await denied(commit(order(booking('BK-200004', 'khachB', { ownerId: 'khachB' })), 'khachB'), 'tự nhận là chủ sân của đơn');
  await denied(create('bookings', 'BK-200005', booking('BK-999999', 'khachB'), 'khachB'), 'trường id khác mã tài liệu');
  await denied(create('bookings', 'tuy-y', booking('tuy-y', 'khachB'), 'khachB'), 'mã đơn sai định dạng');
});

test('đặt nhiều sân một mã, không ai chen được đơn vào mã của người khác', async () => {
  const one = booking('BK-300001-1', 'khachA');
  const two = booking('BK-300001-2', 'khachA', { field: 'Sân 2' });
  await allowed(commit([...order(one), ...order(two)], 'khachA'), 'hai sân cùng mã');
  await denied(commit(order(booking('BK-300001-3', 'khachB')), 'khachB'), 'chen vào mã nhiều sân của người khác');
  await denied(commit(order(booking('BK-100001-1', 'khachB')), 'khachB'), 'chen vào mã một sân của người khác');
});

test('khách không tự xác nhận, tự hủy hay sửa tiền; không đụng phiếu thu', async () => {
  await denied(update('bookings/BK-100001', { status: 'Đã xác nhận' }, 'khachA'), 'tự xác nhận');
  await denied(update('bookings/BK-100001', { status: 'Đã hủy' }, 'khachA'), 'tự hủy');
  await denied(update('bookings/BK-100001', { amount: '1.000đ' }, 'khachA'), 'sửa tiền');
  await denied(update('payments/PAY-BK-100001', { status: 'Thành công' }, 'khachA'), 'tự đánh dấu đã trả tiền');
  await denied(update('slots/BK-100001', { status: 'Đã hủy' }, 'khachA'), 'giải phóng ô giờ');
  await denied(create('slots', 'BK-400001', slot(booking('BK-400001', 'khachA')), 'khachA'), 'chiếm ô giờ không có đơn');
  await denied(create('slots', 'BK-100001', { ...slot(booking('BK-100001', 'khachA')), phone: '09' }, 'khachA'), 'ghi thông tin cá nhân vào lịch công khai');
});

test('chủ sân xử lý đơn sân mình, không thấy đơn sân khác', async () => {
  await allowed(query('bookings', [where('ownerId', 'EQUAL', 'chu1')], 'chu1'), 'đơn sân mình');
  await denied(query('bookings', [where('ownerId', 'EQUAL', 'chu1')], 'chu2'), 'đơn sân người khác');
  await denied(update('bookings/BK-100001', { status: 'Đã xác nhận' }, 'chu2'), 'xác nhận đơn sân khác');
  await denied(update('bookings/BK-100001', { amount: '1đ' }, 'chu1'), 'sửa tiền');
  await allowed(update('bookings/BK-100001', { status: 'Đã hủy' }, 'chu1'), 'hủy đơn sân mình');
  await allowed(update('slots/BK-100001', { status: 'Đã hủy' }, 'chu1'), 'giải phóng ô giờ sân mình');
  await allowed(update('payments/PAY-BK-100001', { status: 'Thành công' }, 'chu1'), 'đối soát phiếu thu');
  await denied(get('users', 'chu1'), 'liệt kê người dùng');
});

test('máy nhận webhook chỉ xác nhận được đơn đang chờ', async () => {
  const range = [where('id', 'GREATER_THAN_OR_EQUAL', 'BK-100001'), where('id', 'LESS_THAN_OR_EQUAL', 'BK-100001')];
  await allowed(query('bookings', range, 'may'), 'tìm đơn theo mã');
  await allowed(query('payments', [where('bookingId', 'EQUAL', 'BK-100001')], 'may'), 'tìm phiếu thu');
  await denied(update('bookings/BK-100001', { status: 'Đã hủy' }, 'may'), 'hủy đơn');
  await denied(update('bookings/BK-100001', { amount: '1đ' }, 'may'), 'sửa tiền');
  await denied(get('users/khachA', 'may'), 'đọc hồ sơ khách');
  await denied(update('venues/1', { price: '1k - 1k/h' }, 'may'), 'sửa sân');
  await allowed(update('payments/PAY-BK-100001', { status: 'Thành công', bankRef: 'FT1' }, 'may'), 'ghi nhận tiền về');
  await allowed(update('bookings/BK-100001', { status: 'Đã xác nhận' }, 'may'), 'xác nhận đơn');
  await denied(update('bookings/BK-100001', { status: 'Đã xác nhận', note: 'x' }, 'may'), 'thêm trường');
});

test('hồ sơ: tự đăng ký chỉ là khách hàng, không tự nâng quyền', async () => {
  await allowed(create('users', 'moi', { role: 'customer', fullName: 'Mới' }, 'moi'), 'đăng ký');
  await denied(create('users', 'gian', { role: 'admin' }, 'gian'), 'đăng ký làm admin');
  await denied(create('users', 'gian', { role: 'customer', password: 'x' }, 'gian'), 'lưu mật khẩu trong Firestore');
  await denied(create('users', 'nguoikhac', { role: 'customer' }, 'gian'), 'tạo hồ sơ cho người khác');
  await denied(update('users/khachA', { role: 'admin' }, 'khachA'), 'tự nâng quyền');
  await allowed(update('users/khachA', { phone: '0911' }, 'khachA'), 'sửa số điện thoại');
  await denied(update('users/khachB', { phone: '0911' }, 'khachA'), 'sửa hồ sơ người khác');
  await allowed(get('users', 'adm'), 'quản trị viên xem người dùng');
});

test('sân: chủ sân đăng thì chờ duyệt, không tự duyệt, không đổi chủ', async () => {
  const venue = { id: 3, name: 'Sân C', ownerId: 'chu1', approvalStatus: 'pending' };
  await allowed(create('venues', '3', venue, 'chu1'), 'đăng sân chờ duyệt');
  await denied(create('venues', '4', { ...venue, id: 4, approvalStatus: 'approved' }, 'chu1'), 'đăng sân đã duyệt sẵn');
  await denied(create('venues', '5', { ...venue, id: 5 }, 'khachA'), 'khách đăng sân');
  await denied(update('venues/3', { approvalStatus: 'approved' }, 'chu1'), 'tự duyệt');
  await denied(update('venues/3', { ownerId: 'chu2' }, 'chu1'), 'đổi chủ');
  await denied(update('venues/2', { price: '1k - 1k/h' }, 'chu1'), 'sửa sân người khác');
  await allowed(update('venues/3', { approvalStatus: 'approved' }, 'adm'), 'quản trị viên duyệt');
});

test('đánh giá, tin tức, thông báo', async () => {
  await allowed(create('reviews', 'r1', { userId: 'khachA', venueId: 1, stars: 5, comment: 'ok' }, 'khachA'), 'viết đánh giá');
  await denied(create('reviews', 'r2', { userId: 'khachB', venueId: 1, stars: 5, comment: '' }, 'khachA'), 'giả danh');
  await denied(create('reviews', 'r3', { userId: 'khachA', venueId: 1, stars: 9, comment: '' }, 'khachA'), 'số sao ngoài 1-5');
  await denied(create('news', 'n1', { title: 'x' }, 'chu1'), 'chủ sân đăng tin');
  await allowed(create('news', 'n1', { title: 'x' }, 'adm'), 'quản trị viên đăng tin');
  await allowed(get('notifications/N1', 'chu1'), 'đọc thông báo của mình');
  await denied(get('notifications/N1', 'khachA'), 'đọc thông báo người khác');
  await allowed(update('notifications/N1', { isRead: true }, 'chu1'), 'đánh dấu đã đọc');
  await allowed(create('notifications', 'N2', { userId: 'chu1', title: 'Đơn', message: 'm', isRead: false }, 'khachA'), 'báo đơn mới');
});

test('quản trị viên xem được toàn bộ', async () => {
  await allowed(get('bookings', 'adm'), 'mọi đơn');
  await allowed(get('payments', 'adm'), 'mọi phiếu thu');
  await denied(get('collectionKhac/x', 'adm'), 'collection không khai báo');
});
