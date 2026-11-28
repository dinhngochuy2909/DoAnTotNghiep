// Máy nhận thông báo tiền về từ SePay (Cloudflare Worker).
// Khi có tiền vào đúng tài khoản, đúng mã đơn và đủ số tiền: đơn chuyển sang "Đã xác nhận",
// phiếu thu chuyển sang "Thành công". Ứng dụng đang mở hộp QR sẽ thấy và báo đặt sân thành công.
//
// Biến môi trường (đặt bằng `wrangler secret put`, KHÔNG ghi vào mã vì kho mã công khai):
//   ACCOUNT_NUMBER      số tài khoản nhận tiền đã liên kết SePay
//   SEPAY_HMAC_SECRET   khóa ký HMAC-SHA256 của webhook (nên dùng)
//   SEPAY_API_KEY       hoặc khóa kiểu "Authorization: Apikey ..."
//   FIRESTORE_PROJECT   mã dự án Firebase (khai trong wrangler.toml)

const PENDING = 'Chờ xác nhận';
const CONFIRMED = 'Đã xác nhận';
const PAID = 'Thành công';
const MAX_SKEW_SECONDS = 300;

export default {
  async fetch(request, env) {
    return handle(request, env, (url, init) => fetch(url, init), () => Date.now());
  },
};

// SePay chỉ coi là thành công khi nhận HTTP 200 và đúng nội dung {"success": true}
const ok = () => json({ success: true }, 200);
const json = (body, status) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

export async function handle(request, env, http, now) {
  if (request.method !== 'POST') return json({ success: false }, 405);
  if (!env.ACCOUNT_NUMBER || !(env.SEPAY_HMAC_SECRET || env.SEPAY_API_KEY)) {
    console.error('Chưa cấu hình ACCOUNT_NUMBER và khóa xác thực: từ chối mọi yêu cầu');
    return json({ success: false }, 500);
  }

  const raw = await request.text();
  if (!(await authentic(request, raw, env, now))) return json({ success: false }, 401);

  let data;
  try {
    data = JSON.parse(raw);
  } catch {
    return json({ success: false }, 400);
  }

  // Không phải tiền vào đúng tài khoản thì bỏ qua (vẫn trả thành công để SePay không gửi lại)
  if (data.transferType !== 'in' || String(data.accountNumber) !== String(env.ACCOUNT_NUMBER)) return ok();

  const code = bookingCode(`${data.code ?? ''} ${data.content ?? ''}`);
  if (!code) {
    console.log('Giao dịch không có mã đơn', data.id);
    return ok();
  }

  try {
    const store = firestore(env.FIRESTORE_PROJECT, http);
    const bookings = await store.bookingsOfCode(code);
    const pending = bookings.filter((b) => b.status === PENDING);
    if (pending.length === 0) {
      console.log('Không có đơn đang chờ cho mã', code, '(đã xác nhận trước đó hoặc đã hủy)');
      return ok();
    }

    const total = pending.reduce((sum, b) => sum + money(b.amount), 0);
    const paid = Number(data.transferAmount) || 0;
    if (total <= 0 || paid < total) {
      console.log('Chuyển thiếu tiền cho mã', code, '- cần', total, 'nhận', paid);
      return ok();
    }

    const reference = String(data.referenceCode || `SePay-${data.id}`);
    for (const b of pending) {
      // Phiếu thu trước, đơn sau: nếu lỗi giữa chừng thì đơn vẫn "Chờ xác nhận" và lần gửi lại làm tiếp được
      for (const p of await store.paymentsOfBooking(b.id)) {
        if (String(p.status).toLowerCase().includes('xử lý')) await store.update('payments', p.docId, { status: PAID, bankRef: reference });
      }
      await store.update('bookings', b.docId, { status: CONFIRMED });
    }
    console.log('Đã xác nhận', pending.map((b) => b.id).join(', '));
    return ok();
  } catch (error) {
    console.error('Lỗi khi cập nhật đơn', code, String(error));
    return json({ success: false }, 500);
  }
}

/** "MBVCB.1.BK123456.CT tu ..." -> "BK-123456". Ứng dụng đặt nội dung chuyển khoản là mã đơn bỏ gạch nối. */
export function bookingCode(text) {
  const m = /BK[\s-]?(\d{6})(?!\d)/i.exec(text || '');
  return m ? `BK-${m[1]}` : null;
}

/** "200.000 đ" -> 200000 */
export function money(text) {
  return Number(String(text ?? '').replace(/[^0-9]/g, '')) || 0;
}

async function authentic(request, raw, env, now) {
  if (env.SEPAY_HMAC_SECRET) {
    const signature = request.headers.get('X-SePay-Signature') || '';
    const timestamp = request.headers.get('X-SePay-Timestamp') || '';
    if (!/^\d+$/.test(timestamp) || Math.abs(now() / 1000 - Number(timestamp)) > MAX_SKEW_SECONDS) return false;
    return same(signature, `sha256=${await hmacHex(env.SEPAY_HMAC_SECRET, `${timestamp}.${raw}`)}`);
  }
  return same(request.headers.get('Authorization') || '', `Apikey ${env.SEPAY_API_KEY}`);
}

export async function hmacHex(secret, message) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const mac = await crypto.subtle.sign('HMAC', key, enc.encode(message));
  return [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** So sánh không phụ thuộc vị trí ký tự sai đầu tiên. */
function same(a, b) {
  let diff = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) diff |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
  return diff === 0;
}

function firestore(project, http) {
  const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;

  async function query(structuredQuery) {
    const res = await http(`${base}:runQuery`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ structuredQuery }),
    });
    if (!res.ok) throw new Error(`runQuery ${res.status}`);
    return (await res.json())
      .filter((row) => row.document)
      .map((row) => {
        const out = { docId: row.document.name.split('/').pop() };
        for (const [k, v] of Object.entries(row.document.fields || {})) out[k] = v.stringValue;
        return out;
      });
  }

  const where = (field, op, value) => ({ fieldFilter: { field: { fieldPath: field }, op, value: { stringValue: value } } });

  return {
    /** Đơn có mã đúng bằng `code`, hoặc `code-1`, `code-2`... (đặt nhiều sân thanh toán một lần). */
    async bookingsOfCode(code) {
      const rows = await query({
        from: [{ collectionId: 'bookings' }],
        where: {
          compositeFilter: {
            op: 'AND',
            filters: [where('id', 'GREATER_THAN_OR_EQUAL', code), where('id', 'LESS_THAN_OR_EQUAL', `${code}`)],
          },
        },
      });
      return rows.filter((b) => b.id === code || String(b.id).startsWith(`${code}-`));
    },
    paymentsOfBooking(bookingId) {
      return query({ from: [{ collectionId: 'payments' }], where: where('bookingId', 'EQUAL', bookingId) });
    },
    async update(collection, docId, values) {
      const mask = Object.keys(values).map((k) => `updateMask.fieldPaths=${k}`).join('&');
      const fields = Object.fromEntries(Object.entries(values).map(([k, v]) => [k, { stringValue: v }]));
      const res = await http(`${base}/${collection}/${encodeURIComponent(docId)}?${mask}&currentDocument.exists=true`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fields }),
      });
      if (!res.ok) throw new Error(`update ${collection} ${res.status}`);
    },
  };
}
