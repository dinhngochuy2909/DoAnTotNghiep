# -*- coding: utf-8 -*-
"""Chuyển dữ liệu đang có sang Firebase Authentication trước khi khóa luật Firestore.

Chạy trong thư mục alobooking, KHI LUẬT FIRESTORE CÒN MỞ. Mặc định chỉ xem trước; thêm --apply để ghi.

  python tool/migrate_to_auth.py backup              sao lưu các collection ra migration_backup/
  python tool/migrate_to_auth.py accounts --apply    tạo tài khoản đăng nhập (giữ mật khẩu cũ), tài khoản chủ sân và máy nhận
  python tool/migrate_to_auth.py data --apply        thêm mã chủ sân/mã sân vào đơn, phiếu thu; tạo lịch bận công khai
  python tool/migrate_to_auth.py strip --apply       xóa trường mật khẩu khỏi Firestore (sau khi đã đăng nhập thử được)

Thêm --emulator để chạy thử với bộ mô phỏng (dự án demo-alobooking).
Thư mục migration_backup/ chứa mật khẩu băm và mật khẩu mới: không commit, không gửi cho ai.
"""
import base64
import datetime
import hashlib
import json
import os
import re
import secrets
import subprocess
import sys
import urllib.request

sys.stdout.reconfigure(encoding='utf-8')

EMULATOR = '--emulator' in sys.argv
APPLY = '--apply' in sys.argv
PROJECT = 'demo-alobooking' if EMULATOR else 'alobooking-b2484'
HOST = 'http://127.0.0.1:8080' if EMULATOR else 'https://firestore.googleapis.com'
DOCS = f'projects/{PROJECT}/databases/(default)/documents'
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'migration_backup')

# Tài khoản cần tạo thêm: chủ của các sân mẫu, và tài khoản riêng của máy nhận webhook.
EXTRA = [
    ('owner_chuan_01', 'chusan@alobooking.com', 'owner', 'Trần Văn Chủ Sân'),
    ('sepay_bot', 'sepay-bot@alobooking.com', 'webhook', 'Máy nhận SePay'),
]


def request(method, url, body=None):
    headers = {'User-Agent': 'alobooking-migration/1.0', 'Content-Type': 'application/json'}
    if EMULATOR:
        headers['Authorization'] = 'Bearer owner'
    data = None if body is None else json.dumps(body).encode('utf-8')
    with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers, method=method), timeout=60) as r:
        return json.load(r)


def docs(collection):
    out, token = [], None
    while True:
        page = request('GET', f'{HOST}/v1/{DOCS}/{collection}?pageSize=300' + (f'&pageToken={token}' if token else ''))
        out += page.get('documents', [])
        token = page.get('nextPageToken')
        if not token:
            return out


def get(doc, key, default=''):
    value = doc.get('fields', {}).get(key, {})
    return value.get('stringValue', value.get('integerValue', default))


def doc_id(doc):
    return doc['name'].split('/')[-1]


def fields(**values):
    return {k: ({'integerValue': str(v)} if isinstance(v, int) else {'stringValue': v}) for k, v in values.items()}


def write(path, values, mask=None):
    """Một lệnh ghi của documents:commit; có `mask` thì chỉ đổi các trường đó."""
    out = {'update': {'name': f'{DOCS}/{path}', 'fields': values}}
    if mask is not None:
        out['updateMask'] = {'fieldPaths': mask}
    return out


def commit(writes):
    for i in range(0, len(writes), 400):
        request('POST', f'{HOST}/v1/{DOCS}:commit', {'writes': writes[i:i + 400]})


def b64(raw):
    return base64.b64encode(raw).decode('ascii')


def hashed(password, salt=None):
    """Cặp (passwordHash, salt) cho `auth:import` SHA256 một vòng, salt đứng trước: sha256("salt:matkhau")."""
    salt = salt or base64.urlsafe_b64encode(secrets.token_bytes(16)).decode('ascii')
    return b64(hashlib.sha256(f'{salt}:{password}'.encode('utf-8')).digest()), b64(f'{salt}:'.encode('utf-8'))


def import_record(user):
    """Bản ghi import giữ nguyên mật khẩu của một hồ sơ cũ; None nếu hồ sơ không đăng nhập được."""
    stored, email = get(user, 'password'), get(user, 'email').strip().lower()
    if not stored or not re.fullmatch(r'[^@\s]+@[^@\s]+\.[^@\s]+', email):
        return None
    if stored.startswith('sha256$'):
        _, salt, digest = stored.split('$')
        password_hash, salt_b64 = b64(bytes.fromhex(digest)), b64(f'{salt}:'.encode('utf-8'))
    else:  # định dạng cũ nhất: base64 hai lần
        password_hash, salt_b64 = hashed(base64.b64decode(base64.b64decode(stored)).decode('utf-8'))
    return {'localId': doc_id(user), 'email': email, 'passwordHash': password_hash, 'salt': salt_b64}


def backup():
    folder = os.path.join(OUT, datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
    os.makedirs(folder, exist_ok=True)
    for collection in ['users', 'venues', 'bookings', 'payments', 'notifications', 'reviews', 'news']:
        found = docs(collection)
        with open(os.path.join(folder, collection + '.json'), 'w', encoding='utf-8') as f:
            json.dump(found, f, ensure_ascii=False)
        print(f'{collection}: {len(found)} tài liệu')
    print('đã sao lưu vào', folder)


def import_accounts(records, path):
    """Nạp tài khoản vào Firebase Authentication, giữ nguyên mật khẩu băm."""
    if EMULATOR:  # `firebase auth:import` không đi qua bộ mô phỏng nên gọi thẳng API của nó
        result = request('POST', f'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts:batchCreate',
                         {'hashAlgorithm': 'SHA256', 'rounds': 1, 'passwordHashOrder': 'SALT_AND_PASSWORD', 'users': records})
        assert not result.get('error'), result
        return
    command = (f'firebase auth:import "{os.path.relpath(path)}" --hash-algo=SHA256 --rounds=1 '
               f'--hash-input-order=SALT_FIRST --project {PROJECT} --non-interactive')
    subprocess.run(command, shell=True, check=True, stdin=subprocess.DEVNULL)


VERIFIED = os.path.join(OUT, 'da_kiem_mat_khau.txt')


def web_api_key():
    key = os.environ.get('FIREBASE_API_KEY', '')
    path = os.path.join(os.path.dirname(OUT), 'dart_defines.json')
    if not key and os.path.exists(path):
        with open(path, encoding='utf-8-sig') as f:
            key = json.load(f).get('FIREBASE_API_KEY', '')
    assert key, 'thiếu FIREBASE_API_KEY (biến môi trường hoặc dart_defines.json)'
    return key


def probe():
    """Một hồ sơ giả theo đúng kiểu cũ, để kiểm rằng mật khẩu cũ vẫn đăng nhập được sau khi nạp."""
    password = secrets.token_urlsafe(12)
    salt = base64.urlsafe_b64encode(secrets.token_bytes(16)).decode('ascii')
    stored = f'sha256${salt}$' + hashlib.sha256(f'{salt}:{password}'.encode('utf-8')).hexdigest()
    email = f'kiem-thu-{secrets.token_hex(4)}@alobooking.com'
    user = {'name': f'{DOCS}/users/kiem_thu_{secrets.token_hex(4)}', 'fields': fields(email=email, password=stored)}
    return import_record(user), email, password


def verify_probe(email, password):
    """Đăng nhập tài khoản thử bằng mật khẩu "cũ" rồi xóa nó đi."""
    key = web_api_key()
    base = 'https://identitytoolkit.googleapis.com/v1/accounts'
    token = request('POST', f'{base}:signInWithPassword?key={key}',
                    {'email': email, 'password': password, 'returnSecureToken': True})['idToken']
    request('POST', f'{base}:delete?key={key}', {'idToken': token})
    with open(VERIFIED, 'w', encoding='utf-8') as f:
        f.write(datetime.datetime.now().isoformat())
    print('đã kiểm: mật khẩu cũ đăng nhập được (tài khoản thử đã xóa)')


def accounts():
    users = docs('users')
    existing = {doc_id(u) for u in users}
    records = [r for r in (import_record(u) for u in users) if r]
    print(f'{len(records)} tài khoản giữ nguyên mật khẩu, {len(users) - len(records)} hồ sơ không có đăng nhập')
    created, profiles = [], []
    for uid, email, role, name in EXTRA:
        if uid in existing:
            print(f'{uid}: đã có hồ sơ, bỏ qua')
            continue
        password = secrets.token_urlsafe(12)
        password_hash, salt = hashed(password)
        records.append({'localId': uid, 'email': email, 'passwordHash': password_hash, 'salt': salt})
        profiles.append(write(f'users/{uid}', fields(fullName=name, email=email, phone='', role=role,
                                                       createdAt=datetime.datetime.now().isoformat())))
        created.append((role, email, password))
    print('tạo thêm:', ', '.join(email for _, email, _ in created) or 'không')
    if not APPLY:
        print('(xem trước; thêm --apply để ghi)')
        return
    os.makedirs(OUT, exist_ok=True)
    test_record = None
    if not EMULATOR:  # bộ mô phỏng không kiểm được mật khẩu băm nên chỉ thử trên Firebase thật
        web_api_key()  # dừng sớm nếu chưa có khóa
        test_record, test_email, test_password = probe()
        records.append(test_record)
    path = os.path.join(OUT, 'auth_import.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump({'users': records}, f)
    if created:
        with open(os.path.join(OUT, 'tai_khoan_moi.txt'), 'a', encoding='utf-8') as f:
            for role, email, password in created:
                f.write(f'{role}\t{email}\t{password}\n')
        print('mật khẩu mới ghi ở migration_backup/tai_khoan_moi.txt')
    import_accounts(records, path)
    if test_record:
        verify_probe(test_email, test_password)
    commit(profiles)
    print('đã tạo tài khoản')


def data():
    venues = docs('venues')
    by_name = {}
    for v in venues:
        by_name.setdefault(get(v, 'name').strip().lower(), []).append(v)
    digits = lambda s: re.sub(r'\D', '', s)
    phones = {digits(get(u, 'phone')): doc_id(u) for u in docs('users') if get(u, 'password') and digits(get(u, 'phone'))}
    writes, links, unmatched = [], {}, 0
    for b in docs('bookings'):
        matches = by_name.get(get(b, 'venueName').strip().lower(), [])
        venue = matches[0] if len(matches) == 1 else None
        unmatched += venue is None
        owner = (get(venue, 'ownerId') if venue else '') or 'admin_super_01'
        venue_id = int(get(venue, 'id')) if venue else 0
        user = get(b, 'userId') or phones.get(digits(get(b, 'phone')), '')
        links[doc_id(b)] = (user, owner)
        values = fields(ownerId=owner, venueId=venue_id, **({'userId': user} if user else {}))
        writes.append(write(f'bookings/{doc_id(b)}', values, list(values)))
        status = 'Đã hủy' if 'hủy' in get(b, 'status').lower() else 'Đã đặt'
        writes.append(write(f'slots/{doc_id(b)}', fields(
            venueId=venue_id, venueName=get(b, 'venueName'), field=get(b, 'field'), date=get(b, 'date'), time=get(b, 'time'),
            status=status, paymentMethod=get(b, 'paymentMethod'), createdAt=get(b, 'createdAt'))))
    for p in docs('payments'):
        user, owner = links.get(get(p, 'bookingId'), ('', 'admin_super_01'))
        values = fields(ownerId=owner, **({'userId': user} if user else {}))
        writes.append(write(f'payments/{doc_id(p)}', values, list(values)))
    print(f'{len(links)} đơn ({unmatched} đơn không khớp đúng một sân: giao cho quản trị viên), tổng {len(writes)} lệnh ghi')
    if not APPLY:
        print('(xem trước; thêm --apply để ghi)')
        return
    commit(writes)
    print('đã cập nhật đơn, phiếu thu và tạo lịch bận công khai')


def strip():
    holders = [u for u in docs('users') if 'password' in u.get('fields', {})]
    print(f'{len(holders)} hồ sơ còn trường mật khẩu')
    if not APPLY:
        print('(xem trước; thêm --apply để ghi)')
        return
    if not EMULATOR and not os.path.exists(VERIFIED):
        sys.exit('chưa kiểm được đăng nhập bằng mật khẩu cũ (bước accounts), không xóa')
    commit([write(f'users/{doc_id(u)}', {}, ['password']) for u in holders])
    print('đã xóa trường mật khẩu (bản sao lưu vẫn giữ trong migration_backup/)')


if __name__ == '__main__':
    steps = {'backup': backup, 'accounts': accounts, 'data': data, 'strip': strip}
    chosen = [a for a in sys.argv[1:] if a in steps]
    if len(chosen) != 1:
        print(__doc__)
        sys.exit(1)
    print(f'dự án: {PROJECT}{" (bộ mô phỏng)" if EMULATOR else " (DỮ LIỆU THẬT)"}')
    steps[chosen[0]]()
