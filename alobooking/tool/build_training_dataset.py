"""Dựng BẢNG DỮ LIỆU HUẤN LUYỆN cho mô hình dự đoán số đơn đặt sân (nhiệt độ, thời tiết, giờ, ngày, mùa, ngày lễ).

  python tool/build_training_dataset.py

Đầu vào (đều có sẵn trong repo, không cần mạng nếu đã có file giờ):
  tool/data/hanoi_weather_daily.csv      thời tiết THẬT theo ngày, 2016 -> nay (Open-Meteo)
  tool/data/hanoi_weather_hourly.csv     thời tiết THẬT theo giờ, chỉ giai đoạn có nhãn; thiếu thì tự tải từ Open-Meteo
  assets/demo/simulated_bookings.json    đơn đặt sân MÔ PHỎNG (tool/simulate_bookings.py)

Đầu ra (tool/data/):
  training_daily.csv    1 dòng / ngày: lịch (thứ, mùa, lễ/Tết) + thời tiết thật + nhãn số đơn (chỉ giai đoạn mô phỏng)
  training_hourly.csv   1 dòng / giờ: thêm giờ, buổi, ca vàng, nhiệt độ, độ ẩm, mưa, mây, gió, mã thời tiết + nhãn số đơn theo giờ
  TRAINING_DATA_README.md  từ điển cột, nguồn, và những gì KHÔNG phải dữ liệu thật

Trung thực: cột thời tiết là dữ liệu quan trắc/tái phân tích thật; cột nhãn (số đơn) là MÔ PHỎNG và được đánh dấu.
Ngày không có nhãn để trống, không điền số đoán.
"""
import csv
import datetime as dt
import json
import math
import os
import sys
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, 'tool', 'data')
LABEL_SOURCE = 'mo_phong'

# ── Lịch ngày nghỉ: GIỐNG VnCalendar của ứng dụng (lib/services/forecast/demand_forecast_service.dart) ──
# App chỉ khai báo 2026–2027; các năm trước do dự án bổ sung theo lịch âm–dương để bảng dùng được cho cả chục năm.
TET = {y: dt.date(*d) for y, d in {
    2016: (2016, 2, 8), 2017: (2017, 1, 28), 2018: (2018, 2, 16), 2019: (2019, 2, 5), 2020: (2020, 1, 25),
    2021: (2021, 2, 12), 2022: (2022, 2, 1), 2023: (2023, 1, 22), 2024: (2024, 2, 10), 2025: (2025, 1, 29),
    2026: (2026, 2, 17), 2027: (2027, 2, 6)}.items()}
GIO_TO = {y: dt.date(*d) for y, d in {
    2016: (2016, 4, 16), 2017: (2017, 4, 6), 2018: (2018, 4, 25), 2019: (2019, 4, 14), 2020: (2020, 4, 2),
    2021: (2021, 4, 21), 2022: (2022, 4, 10), 2023: (2023, 4, 29), 2024: (2024, 4, 18), 2025: (2025, 4, 7),
    2026: (2026, 4, 26), 2027: (2027, 4, 16)}.items()}
TET_FACTOR = 0.3

DAY_NAMES = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật']


def holiday(d):
    """(tên, hệ số nhu cầu của lịch, có nghỉ làm không) hoặc None."""
    for t in TET.values():
        diff = (d - t).days
        if -7 <= diff <= -4: return ('Cận Tết Nguyên Đán', 0.75, False)
        if -3 <= diff <= -1: return ('Giáp Tết (những ngày cuối năm âm lịch)', 0.5, True)
        if 0 <= diff <= 3: return ('Tết Nguyên Đán', 0.3, True)
        if 4 <= diff <= 6: return ('Sau Tết Nguyên Đán', 0.6, True)
    if d in GIO_TO.values(): return ('Giỗ Tổ Hùng Vương', 1.2, True)
    fixed = {(1, 1): 'Tết Dương lịch', (4, 30): 'Giải phóng miền Nam (30/4)', (5, 1): 'Quốc tế Lao động (1/5)', (9, 2): 'Quốc khánh (2/9)'}
    if (d.month, d.day) in fixed: return (fixed[(d.month, d.day)], 1.2, True)
    if (d.month, d.day) == (11, 20): return ('Ngày Nhà giáo Việt Nam (20/11)', 1.1, False)
    if (d.month, d.day) == (12, 24): return ('Đêm Giáng sinh', 1.1, False)
    return None


def season_of(d):
    m = d.month
    return 'Xuân' if 2 <= m <= 4 else 'Hạ' if 5 <= m <= 8 else 'Thu' if 9 <= m <= 11 else 'Đông'


def calendar_cols(d):
    h = holiday(d)
    name = h[0] if h else ''
    kind = 'none'
    tet = 0.0
    if h:
        if h[1] < 1:
            kind = 'tet'
            tet = min(1.0, max(0.0, math.log(h[1]) / math.log(TET_FACTOR)))
        elif h[2]:
            kind = 'off'
    weekend = d.weekday() >= 5
    return {
        'weekday_no': d.weekday() + 1, 'weekday': DAY_NAMES[d.weekday()], 'is_weekend': int(weekend),
        'season': season_of(d), 'holiday_name': name, 'holiday_kind': kind, 'tet_intensity': round(tet, 3),
        'is_day_off': int(weekend or (h is not None and h[2])),
    }


def rain_level(mm):
    if mm <= 0: return 'Không mưa'
    if mm < 1: return 'Mưa rất nhẹ'
    if mm < 5: return 'Mưa nhỏ'
    if mm < 15: return 'Mưa vừa'
    if mm < 30: return 'Mưa to'
    return 'Mưa rất to'


def temp_level(tmax, tmin):
    if tmax >= 35: return 'Nắng nóng gay gắt'
    if tmax >= 32: return 'Nóng'
    if tmin < 12: return 'Rét đậm'
    if tmin < 18: return 'Lạnh'
    return 'Dễ chịu'


WMO = {0: 'Trời quang', 1: 'Ít mây', 2: 'Nhiều mây', 3: 'Âm u', 45: 'Sương mù', 48: 'Sương mù đóng băng',
       51: 'Mưa phùn nhẹ', 53: 'Mưa phùn', 55: 'Mưa phùn dày', 56: 'Mưa phùn lạnh', 57: 'Mưa phùn lạnh dày',
       61: 'Mưa nhẹ', 63: 'Mưa vừa', 65: 'Mưa to', 66: 'Mưa lạnh', 67: 'Mưa lạnh to',
       80: 'Mưa rào nhẹ', 81: 'Mưa rào', 82: 'Mưa rào rất to', 95: 'Dông', 96: 'Dông kèm mưa đá nhẹ', 99: 'Dông kèm mưa đá'}


def num(x, nd=1):
    return '' if x is None else round(x, nd)


# ───────────────────────── Đọc dữ liệu nguồn ─────────────────────────

def read_daily_weather():
    out = {}
    with open(os.path.join(DATA, 'hanoi_weather_daily.csv'), encoding='utf-8') as f:
        for r in csv.DictReader(f):
            out[r['date']] = (float(r['tmax']), float(r['tmin']), float(r['rain_mm']))
    return out


def fetch_hourly(start, end):
    params = {
        'latitude': 21.0285, 'longitude': 105.8542, 'start_date': start, 'end_date': end, 'timezone': 'Asia/Bangkok',
        'hourly': 'temperature_2m,relative_humidity_2m,precipitation,cloud_cover,wind_speed_10m,weather_code',
    }
    url = 'https://archive-api.open-meteo.com/v1/archive?' + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={'User-Agent': 'training-data-builder/1.0'})
    with urllib.request.urlopen(req, timeout=180) as r:
        h = json.loads(r.read())['hourly']
    rows = []
    for i, t in enumerate(h['time']):
        rows.append([t, h['temperature_2m'][i], h['relative_humidity_2m'][i], h['precipitation'][i],
                     h['cloud_cover'][i], h['wind_speed_10m'][i], h['weather_code'][i]])
    return rows


def read_hourly_weather(start, end):
    path = os.path.join(DATA, 'hanoi_weather_hourly.csv')
    if not os.path.exists(path):
        print(f'Tải thời tiết theo giờ {start} -> {end} từ Open-Meteo ...')
        rows = fetch_hourly(start, end)
        with open(path, 'w', newline='', encoding='utf-8') as f:
            w = csv.writer(f)
            w.writerow(['time', 'temp_c', 'humidity_pct', 'rain_mm', 'cloud_pct', 'wind_kmh', 'weather_code'])
            w.writerows(rows)
    out = {}
    with open(path, encoding='utf-8') as f:
        for r in csv.DictReader(f):
            def fl(k):
                return float(r[k]) if r[k] != '' else None
            code = r['weather_code']
            out[r['time']] = (fl('temp_c'), fl('humidity_pct'), fl('rain_mm'), fl('cloud_pct'), fl('wind_kmh'), int(float(code)) if code != '' else None)
    return out


def slot_hours(slot):
    """'18:30 - 20:00' -> (18*60+30, 20*60)"""
    a, b = [s.strip() for s in slot.split('-')]
    ah, am = map(int, a.split(':'))
    bh, bm = map(int, b.split(':'))
    return ah * 60 + am, bh * 60 + bm


# ───────────────────────── Dựng bảng ─────────────────────────

def main():
    daily_wx = read_daily_weather()
    sim = json.load(open(os.path.join(ROOT, 'assets', 'demo', 'simulated_bookings.json'), encoding='utf-8'))
    meta = sim['meta']
    assert meta['simulated'] is True

    kept, cancelled = {}, {}
    hour_kept, hour_cancel = {}, {}
    for row in sim['bookings']:
        _, date, slot, _, _, status, *_ = row
        is_cancel = status == 'Đã hủy'
        (cancelled if is_cancel else kept)[date] = (cancelled if is_cancel else kept).get(date, 0) + 1
        s, e = slot_hours(slot)
        for h in range(s // 60, (e - 1) // 60 + 1):
            if s < (h + 1) * 60 and e > h * 60:
                tgt = hour_cancel if is_cancel else hour_kept
                tgt[(date, h)] = tgt.get((date, h), 0) + 1

    lab_from, lab_to = meta['from'], meta['to']
    hourly_wx = read_hourly_weather(lab_from, lab_to)

    # ── theo ngày ──
    days = sorted(daily_wx)
    d0, d1 = dt.date.fromisoformat(days[0]), dt.date.fromisoformat(days[-1])
    assert (d1 - d0).days + 1 == len(days), 'thời tiết ngày bị thiếu ngày giữa chừng'
    dcols = ['date', 'year', 'month', 'day', 'day_of_year', 'weekday_no', 'weekday', 'is_weekend', 'is_day_off', 'season',
             'holiday_name', 'holiday_kind', 'tet_intensity',
             'tmax_c', 'tmin_c', 'tmean_c', 'rain_mm', 'rain_index', 'rainy', 'rain_level', 'heat', 'cold', 'temp_level',
             'bookings_retained', 'bookings_cancelled', 'has_label', 'label_source']
    out_daily = []
    for k in days:
        d = dt.date.fromisoformat(k)
        tmax, tmin, rain = daily_wx[k]
        c = calendar_cols(d)
        labeled = lab_from <= k <= lab_to
        out_daily.append({
            'date': k, 'year': d.year, 'month': d.month, 'day': d.day, 'day_of_year': d.timetuple().tm_yday,
            **c,
            'tmax_c': tmax, 'tmin_c': tmin, 'tmean_c': round((tmax + tmin) / 2, 2), 'rain_mm': rain,
            'rain_index': round(min(1.0, rain / 10), 3), 'rainy': int(rain >= 1.0), 'rain_level': rain_level(rain),
            'heat': round(max(0.0, tmax - 32) / 4, 3), 'cold': round(max(0.0, 18 - tmin) / 4, 3), 'temp_level': temp_level(tmax, tmin),
            'bookings_retained': kept.get(k, 0) if labeled else '', 'bookings_cancelled': cancelled.get(k, 0) if labeled else '',
            'has_label': int(labeled), 'label_source': LABEL_SOURCE if labeled else '',
        })

    # ── theo giờ (chỉ giai đoạn có nhãn, 05:00–22:59 là khung sân mở cửa trong mô phỏng) ──
    hcols = ['date', 'hour', 'weekday_no', 'weekday', 'is_weekend', 'is_day_off', 'month', 'season', 'holiday_name', 'holiday_kind',
             'day_period', 'is_golden_hour', 'temp_c', 'humidity_pct', 'rain_mm', 'cloud_pct', 'wind_kmh', 'weather_code', 'weather_label',
             'bookings_in_hour', 'cancelled_in_hour', 'label_source']
    out_hourly = []
    missing_wx = 0
    d = dt.date.fromisoformat(lab_from)
    end = dt.date.fromisoformat(lab_to)
    while d <= end:
        k = d.isoformat()
        c = calendar_cols(d)
        for h in range(5, 23):
            w = hourly_wx.get(f'{k}T{h:02d}:00')
            if w is None or w[0] is None:
                missing_wx += 1
                w = w or (None,) * 6
            temp, hum, rn, cloud, wind, code = w
            period = 'Sáng' if h < 11 else 'Trưa' if h < 14 else 'Chiều' if h < 18 else 'Tối'
            out_hourly.append({
                'date': k, 'hour': h, 'weekday_no': c['weekday_no'], 'weekday': c['weekday'], 'is_weekend': c['is_weekend'],
                'is_day_off': c['is_day_off'], 'month': d.month, 'season': c['season'], 'holiday_name': c['holiday_name'],
                'holiday_kind': c['holiday_kind'], 'day_period': period, 'is_golden_hour': int(16 <= h < 22),
                'temp_c': num(temp), 'humidity_pct': num(hum, 0), 'rain_mm': num(rn), 'cloud_pct': num(cloud, 0), 'wind_kmh': num(wind),
                'weather_code': '' if code is None else code, 'weather_label': '' if code is None else WMO.get(code, f'Mã {code}'),
                'bookings_in_hour': hour_kept.get((k, h), 0), 'cancelled_in_hour': hour_cancel.get((k, h), 0), 'label_source': LABEL_SOURCE,
            })
        d += dt.timedelta(days=1)

    for name, cols, rows in [('training_daily.csv', dcols, out_daily), ('training_hourly.csv', hcols, out_hourly)]:
        with open(os.path.join(DATA, name), 'w', newline='', encoding='utf-8-sig') as f:  # BOM để Excel đọc đúng tiếng Việt
            w = csv.DictWriter(f, fieldnames=cols)
            w.writeheader()
            w.writerows(rows)

    # ── Tự kiểm tra ──
    lab = [r for r in out_daily if r['has_label']]
    assert sum(r['bookings_retained'] for r in lab) == meta['retainedBookings'], 'tổng đơn giữ lại không khớp file mô phỏng'
    assert sum(r['bookings_cancelled'] for r in lab) == meta['cancelledBookings'], 'tổng đơn hủy không khớp'
    assert len(lab) == meta['days']
    # tổng đơn theo giờ phải bằng tổng số giờ phủ của mọi đơn (tính độc lập theo phút)
    expect = 0
    for row in sim['bookings']:
        if row[5] == 'Đã hủy': continue
        s, e = slot_hours(row[2])
        expect += sum(1 for h in range(24) if s < (h + 1) * 60 and e > h * 60)
    got = sum(r['bookings_in_hour'] for r in out_hourly)
    assert got == expect, f'đơn theo giờ {got} != {expect}'
    # mưa theo giờ cộng lại phải khớp mưa theo ngày (cùng nguồn Open-Meteo)
    by_day = {}
    for r in out_hourly:
        by_day.setdefault(r['date'], 0.0)
        by_day[r['date']] += r['rain_mm'] or 0.0
    off = [k for k, v in by_day.items() if abs(v - daily_wx[k][2]) > 1.0]
    print(f'Mưa giờ cộng lại lệch mưa ngày quá 1 mm: {len(off)}/{len(by_day)} ngày (khung 05–22h không gồm mưa đêm nên lệch nhẹ là bình thường)')

    print(f'training_daily.csv : {len(out_daily)} dòng ({days[0]} -> {days[-1]}), {len(lab)} dòng có nhãn mô phỏng')
    print(f'training_hourly.csv: {len(out_hourly)} dòng ({lab_from} -> {lab_to}), thiếu thời tiết giờ: {missing_wx}')
    print(f'Tổng đơn giữ lại {sum(r["bookings_retained"] for r in lab)}, đơn hủy {sum(r["bookings_cancelled"] for r in lab)}; lượt phủ giờ {got}')


main()
