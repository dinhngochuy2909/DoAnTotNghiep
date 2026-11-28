"""Lấy tiêu đề tin thể thao từ RSS công khai của các báo và đăng vào mục Khám phá (collection `news`).

  python tool/crawl_news.py --dry       chỉ in danh sách sẽ đăng, không ghi gì
  python tool/crawl_news.py             đăng tin mới và xóa tin RSS cũ không còn trong danh sách
  python tool/crawl_news.py --delete    xóa toàn bộ tin lấy từ RSS (id bắt đầu bằng rss_)

Nguyên tắc:
 - Chỉ lưu TIÊU ĐỀ + LIÊN KẾT BÀI GỐC + TÊN BÁO + GIỜ ĐĂNG. Không chép nội dung, không chép ảnh của báo.
 - Ứng dụng hiển thị "Nguồn: <báo>" và nút "Đọc bài gốc" dẫn về báo.
 - Bỏ tin cá cược/soi kèo. Ưu tiên môn app có: cầu lông, pickleball, tennis, bóng rổ, bóng đá.
 - Mã tin = rss_ + băm của đường dẫn, chạy lại nhiều lần không bị trùng.

Chỉ quản trị viên được ghi tin: đặt biến môi trường ALOBOOKING_ADMIN_EMAIL và ALOBOOKING_ADMIN_PASSWORD
(khóa Firebase đọc từ FIREBASE_API_KEY hoặc dart_defines.json). Chạy thử --dry thì không cần.
"""
import datetime as dt
import email.utils
import hashlib
import html
import json
import os
import re
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

sys.stdout.reconfigure(encoding='utf-8')

BASE = 'https://firestore.googleapis.com/v1/projects/alobooking-b2484/databases/(default)/documents'
UA = 'AloBooking-student-project/1.0 (RSS reader)'
VN = dt.timezone(dt.timedelta(hours=7))

FEEDS = [
    ('VnExpress', 'https://vnexpress.net/rss/the-thao.rss'),
    ('Tuổi Trẻ', 'https://tuoitre.vn/rss/the-thao.rss'),
    ('Thanh Niên', 'https://thanhnien.vn/rss/the-thao.rss'),
]
MAX_TOTAL = 9
MAX_PER_SOURCE = 3
MAX_AGE_DAYS = 3

# Môn mà AloBooking có: ưu tiên tin liên quan
SPORT_WORDS = re.compile(r'cầu lông|pickleball|tennis|quần vợt|bóng rổ|bóng đá|futsal|sân cỏ|thể thao toàn quốc', re.I)
RACKET_WORDS = re.compile(r'cầu lông|pickleball|tennis|quần vợt|bóng rổ', re.I)
# Tin cá cược/soi kèo: không đưa vào ứng dụng
BAD_WORDS = re.compile(r'cá cược|soi kèo|kèo |nhà cái|tỷ lệ cược|odds|xổ số|18\+', re.I)


def parse_date(s):
    s = re.sub(r'\s+', ' ', (s or '').replace(' ', ' ').replace(' ', ' ')).strip()  # Tuổi Trẻ dùng dấu cách hẹp trước AM/PM
    try:
        d = email.utils.parsedate_to_datetime(s)  # "Tue, 24 Nov 2026 16:47:01 +0700"
        if d.tzinfo is None:
            d = d.replace(tzinfo=VN)
        return d
    except Exception:
        pass
    m = re.match(r'^(\d{1,2})/(\d{1,2})/(\d{4}) (\d{1,2}):(\d{2}):(\d{2}) (AM|PM)$', s)  # Tuổi Trẻ: 11/24/2026 4:43:00 PM
    if m:
        mo, da, y, h, mi, se, ap = m.groups()
        h = int(h) % 12 + (12 if ap == 'PM' else 0)
        return dt.datetime(int(y), int(mo), int(da), h, int(mi), int(se), tzinfo=VN)
    m = re.match(r'^\w{3}, (\d{1,2}) (\w{3}) (\d{2}) (\d{2}):(\d{2}):(\d{2}) ([+-]\d{4})$', s)  # Thanh Niên: Tue, 24 Nov 26 17:20:00 +0700
    if m:
        da, mon, yy, h, mi, se, tz = m.groups()
        months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        sign = 1 if tz[0] == '+' else -1
        off = dt.timezone(sign * dt.timedelta(hours=int(tz[1:3]), minutes=int(tz[3:5])))
        return dt.datetime(2000 + int(yy), months.index(mon) + 1, int(da), int(h), int(mi), int(se), tzinfo=off)
    return None


def fetch_feed(name, url):
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    raw = urllib.request.urlopen(req, timeout=30).read()
    out = []
    for it in ET.fromstring(raw).findall('.//item'):
        title = html.unescape((it.findtext('title') or '')).strip()
        title = re.sub(r'\s+', ' ', title)
        link = (it.findtext('link') or '').strip()
        when = parse_date(it.findtext('pubDate'))
        if title and link.startswith('https://') and when:
            out.append({'source': name, 'title': title, 'url': link.split('?')[0].split('#')[0], 'time': when})
    return out


def choose(all_items, now):
    fresh = [x for x in all_items if (now - x['time']).days <= MAX_AGE_DAYS and x['time'] <= now + dt.timedelta(hours=1) and not BAD_WORDS.search(x['title'])]
    seen, uniq = set(), []
    for x in sorted(fresh, key=lambda x: x['time'], reverse=True):
        key = re.sub(r'\W+', '', x['title'].lower())
        if key in seen:
            continue
        seen.add(key)
        uniq.append(x)

    def score(x):  # cao hơn = ưu tiên hơn: môn có trong app, rồi mới nhất
        return (2 if RACKET_WORDS.search(x['title']) else 1 if SPORT_WORDS.search(x['title']) else 0, x['time'])

    picked, per = [], {}
    for x in sorted(uniq, key=score, reverse=True):
        if per.get(x['source'], 0) >= MAX_PER_SOURCE:
            continue
        picked.append(x)
        per[x['source']] = per.get(x['source'], 0) + 1
        if len(picked) >= MAX_TOTAL:
            break
    return sorted(picked, key=lambda x: x['time'], reverse=True)


def doc_id(url):
    return 'rss_' + hashlib.sha1(url.encode()).hexdigest()[:12]


_token = None


def admin_token():
    """Đăng nhập quản trị viên một lần để được ghi vào collection `news`."""
    global _token
    if _token:
        return _token
    key = os.environ.get('FIREBASE_API_KEY', '')
    defines = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'dart_defines.json')
    if not key and os.path.exists(defines):
        with open(defines, encoding='utf-8-sig') as f:
            key = json.load(f).get('FIREBASE_API_KEY', '')
    email, password = os.environ.get('ALOBOOKING_ADMIN_EMAIL'), os.environ.get('ALOBOOKING_ADMIN_PASSWORD')
    if not (key and email and password):
        raise SystemExit('Cần FIREBASE_API_KEY, ALOBOOKING_ADMIN_EMAIL và ALOBOOKING_ADMIN_PASSWORD để ghi tin.')
    req = urllib.request.Request(f'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={key}',
                                 data=json.dumps({'email': email, 'password': password, 'returnSecureToken': True}).encode(),
                                 headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=60) as r:
        _token = json.load(r)['idToken']
    return _token


def fs(method, path, body=None):
    headers = {'Content-Type': 'application/json'}
    if method != 'GET':
        headers['Authorization'] = 'Bearer ' + admin_token()
    req = urllib.request.Request(BASE + path, data=json.dumps(body).encode() if body is not None else None, method=method,
                                 headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read() or b'{}')
    except urllib.error.HTTPError as e:
        return e.code, {'error': e.read().decode('utf-8', 'replace')[:300]}


def existing_rss_ids():
    ids, tok = [], None
    while True:
        st, d = fs('GET', '/news?pageSize=100' + ('&pageToken=' + tok if tok else ''))
        if st != 200:
            raise SystemExit('Không đọc được danh sách tin: %s %s' % (st, d))
        ids += [x['name'].split('/')[-1] for x in d.get('documents', []) if x['name'].split('/')[-1].startswith('rss_')]
        tok = d.get('nextPageToken')
        if not tok:
            return ids


def to_fields(x):
    return {
        'title': {'stringValue': x['title']},
        'body': {'stringValue': ''},
        'category': {'stringValue': 'sport'},
        'imageUrl': {'stringValue': ''},
        'venueId': {'integerValue': '0'},
        'pinned': {'booleanValue': False},
        'author': {'stringValue': x['source']},
        'createdAt': {'stringValue': x['time'].isoformat()},
        'sourceName': {'stringValue': x['source']},
        'sourceUrl': {'stringValue': x['url']},
    }


def main():
    dry = '--dry' in sys.argv
    if '--delete' in sys.argv:
        for i in existing_rss_ids():
            print('xóa', i, fs('DELETE', '/news/' + i)[0])
        return
    now = dt.datetime.now(VN)
    items = []
    for name, url in FEEDS:
        try:
            got = fetch_feed(name, url)
            print(f'{name}: đọc được {len(got)} bài')
            items += got
        except Exception as e:
            print(f'{name}: LỖI {e} (bỏ qua nguồn này)')
    picked = choose(items, now)
    print(f'\nChọn {len(picked)} tin:')
    for x in picked:
        print(f"  [{x['source']}] {x['time'].astimezone(VN):%d/%m %H:%M}  {x['title'][:95]}")
    if dry:
        print('\n(chạy thử, chưa ghi gì)')
        return
    if not picked:
        print('Không có tin phù hợp, giữ nguyên tin cũ.')
        return
    keep = set()
    for x in picked:
        i = doc_id(x['url'])
        keep.add(i)
        st, d = fs('PATCH', '/news/' + i, {'fields': to_fields(x)})
        print('ghi', i, st if st == 200 else d)
    for i in existing_rss_ids():
        if i not in keep:
            print('xóa tin cũ', i, fs('DELETE', '/news/' + i)[0])


main()
