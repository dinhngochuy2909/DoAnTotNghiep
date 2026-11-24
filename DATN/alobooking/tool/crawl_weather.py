"""Tải thời tiết lịch sử THẬT của Hà Nội từ Open-Meteo (miễn phí, không cần key) và lưu ra CSV.

  python tool/crawl_weather.py [ngày_bắt_đầu] [ngày_kết_thúc]

Mặc định: 2016-01-01 -> 5 ngày trước hôm nay (kho lưu trữ trễ vài ngày).
Kết quả: data/hanoi_weather_daily.csv (date, tmax, tmin, rain_mm) và
         data/hanoi_climate_monthly.json (trung bình theo tháng, dùng để kiểm tra hợp lý).
Nguồn dữ liệu: Open-Meteo.com (CC BY 4.0), tọa độ Hà Nội 21.0285, 105.8542, múi giờ Asia/Bangkok.
"""
import csv
import datetime as dt
import json
import os
import sys
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, 'data')
start = sys.argv[1] if len(sys.argv) > 1 else '2016-01-01'
end = sys.argv[2] if len(sys.argv) > 2 else (dt.date.today() - dt.timedelta(days=5)).isoformat()

params = {
    'latitude': 21.0285,
    'longitude': 105.8542,
    'start_date': start,
    'end_date': end,
    'daily': 'temperature_2m_max,temperature_2m_min,precipitation_sum',
    'timezone': 'Asia/Bangkok',
}
url = 'https://archive-api.open-meteo.com/v1/archive?' + urllib.parse.urlencode(params)
req = urllib.request.Request(url, headers={'User-Agent': 'AloBooking-student-project/1.0'})
with urllib.request.urlopen(req, timeout=120) as r:
    data = json.loads(r.read())

d = data['daily']
rows = []
skipped = 0
for t, hi, lo, mm in zip(d['time'], d['temperature_2m_max'], d['temperature_2m_min'], d['precipitation_sum']):
    if hi is None or lo is None or mm is None:
        skipped += 1  # không điền số đoán cho ngày thiếu số liệu
        continue
    rows.append((t, round(hi, 1), round(lo, 1), round(mm, 1)))

os.makedirs(OUT_DIR, exist_ok=True)
with open(os.path.join(OUT_DIR, 'hanoi_weather_daily.csv'), 'w', newline='', encoding='utf-8') as f:
    w = csv.writer(f)
    w.writerow(['date', 'tmax', 'tmin', 'rain_mm'])
    w.writerows(rows)

# Tổng hợp theo tháng (trung bình nhiều năm) để đối chiếu với khí hậu Hà Nội đã biết
by = {m: {'tmax': [], 'tmin': [], 'rain': [], 'rainy': 0, 'n': 0, 'years': set()} for m in range(1, 13)}
for t, hi, lo, mm in rows:
    y, m = int(t[:4]), int(t[5:7])
    b = by[m]
    b['tmax'].append(hi)
    b['tmin'].append(lo)
    b['rain'].append(mm)
    b['n'] += 1
    b['years'].add(y)
    if mm >= 1.0:
        b['rainy'] += 1
monthly = []
for m in range(1, 13):
    b = by[m]
    years = max(1, len(b['years']))
    monthly.append({
        'month': m,
        'tmax_avg': round(sum(b['tmax']) / len(b['tmax']), 1),
        'tmin_avg': round(sum(b['tmin']) / len(b['tmin']), 1),
        'rain_mm_per_month': round(sum(b['rain']) / years, 0),
        'rainy_days_per_month': round(b['rainy'] / years, 1),
        'days': b['n'],
    })
json.dump({'source': 'Open-Meteo.com (CC BY 4.0)', 'from': rows[0][0], 'to': rows[-1][0], 'days': len(rows), 'skipped': skipped, 'monthly': monthly},
          open(os.path.join(OUT_DIR, 'hanoi_climate_monthly.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)

print(f'Đã lưu {len(rows)} ngày ({rows[0][0]} -> {rows[-1][0]}), bỏ qua {skipped} ngày thiếu số liệu')
print('Tháng | tmax | tmin | mm/tháng | ngày mưa/tháng')
for x in monthly:
    print(f"{x['month']:>5} | {x['tmax_avg']:>4} | {x['tmin_avg']:>4} | {x['rain_mm_per_month']:>8.0f} | {x['rainy_days_per_month']:>5}")
