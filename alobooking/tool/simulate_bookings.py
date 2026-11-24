"""Sinh ĐƠN ĐẶT SÂN MÔ PHỎNG để minh họa mô hình dự đoán số đơn. KHÔNG phải đơn thật.

  python tool/simulate_bookings.py

Cách sinh: số đơn mỗi ngày ~ Poisson(λ) nhân nhiễu log-chuẩn, với
  log λ = nền + Σ hệ số × yếu tố  (thứ, ngày lễ/Tết, mùa, mưa, nóng, lạnh)
dùng THỜI TIẾT THẬT của Hà Nội (tool/data/hanoi_weather_daily.csv) và cùng lịch lễ/Tết với ứng dụng.
Các hệ số "đáp án" được ghi trong file kết quả, cố ý KHÁC mức giả định của mô hình, để kiểm tra
mô hình có tìm lại được đáp án từ dữ liệu hay chỉ lặp lại giả định.

Kết quả: assets/demo/simulated_bookings.json (có cờ simulated=true và đáp án).
Hạt giống cố định nên chạy lại cho đúng cùng một kết quả.
"""
import csv
import datetime as dt
import json
import math
import os
import random
import sys

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEED = 20261124
START = dt.date(2025, 11, 25)
END = dt.date(2026, 10, 9)  # trước các đơn mẫu thật từ 14/10/2026: cách ≥ 4 ngày nên mô hình coi là hai giai đoạn riêng

# Đáp án (log). Cố ý khác mức giả định của mô hình (thứ Bảy 0.22, mưa -0.35, ...).
TRUTH = {
    'intercept': math.log(8.0),
    'sat': 0.45, 'sun': 0.40, 'fri': 0.12,
    'holiday': 0.30, 'tet': -1.5,
    'rain': -0.80, 'heat': -0.20, 'cold': -0.30,
    'summer': -0.15, 'autumn': 0.12, 'winter': -0.20,
}
DISPERSION_SIGMA = 0.20  # nhiễu log-chuẩn: số đơn dao động nhiều hơn Poisson thuần, giống đời thật

# ── Lịch ngày lễ: giống hệt VnCalendar trong ứng dụng (lib/services/forecast/demand_forecast_service.dart) ──
TET = [dt.date(2026, 2, 17), dt.date(2027, 2, 6)]
GIO_TO = [dt.date(2026, 4, 26), dt.date(2027, 4, 16)]
TET_DEMAND = 0.3


def holiday(d):
    """(demandFactor, dayOff) hoặc None."""
    for t in TET:
        diff = (d - t).days
        if -7 <= diff <= -4: return (0.75, False)
        if -3 <= diff <= -1: return (0.5, True)
        if 0 <= diff <= 3: return (0.3, True)
        if 4 <= diff <= 6: return (0.6, True)
    if d in GIO_TO: return (1.2, True)
    if (d.month, d.day) in [(1, 1), (4, 30), (5, 1), (9, 2)]: return (1.2, True)
    if (d.month, d.day) in [(11, 20), (12, 24)]: return (1.1, False)
    return None


def season(d):
    m = d.month
    return 'spring' if 2 <= m <= 4 else 'summer' if 5 <= m <= 8 else 'autumn' if 9 <= m <= 11 else 'winter'


def features(d, tmax, tmin, rain):
    h = holiday(d)
    wd = d.weekday()  # 0=Thứ Hai
    tet = 0.0
    if h and h[0] < 1:
        tet = min(1.0, max(0.0, math.log(h[0]) / math.log(TET_DEMAND)))
    s = season(d)
    return {
        'sat': 1.0 if wd == 5 else 0.0, 'sun': 1.0 if wd == 6 else 0.0, 'fri': 1.0 if wd == 4 else 0.0,
        'holiday': 1.0 if (h and h[0] >= 1 and h[1]) else 0.0,
        'tet': tet,
        'rain': min(1.0, rain / 10.0),
        'heat': max(0.0, tmax - 32) / 4,
        'cold': max(0.0, 18 - tmin) / 4,
        'summer': 1.0 if s == 'summer' else 0.0, 'autumn': 1.0 if s == 'autumn' else 0.0, 'winter': 1.0 if s == 'winter' else 0.0,
    }


def poisson(rng, lam):
    if lam > 30:
        return max(0, round(rng.gauss(lam, math.sqrt(lam))))
    l, k, p = math.exp(-lam), 0, 1.0
    while True:
        k += 1
        p *= rng.random()
        if p <= l:
            return k - 1


def main():
    rng = random.Random(SEED)
    wx = {}
    with open(os.path.join(ROOT, 'tool', 'data', 'hanoi_weather_daily.csv'), encoding='utf-8') as f:
        for r in csv.DictReader(f):
            wx[r['date']] = (float(r['tmax']), float(r['tmin']), float(r['rain_mm']))

    venues = ['Sân mô phỏng %s' % c for c in 'ABCDEFGH']
    slots = [('06:00 - 07:30', 0.07), ('07:30 - 09:00', 0.05), ('09:00 - 10:30', 0.04), ('14:00 - 15:30', 0.08), ('15:30 - 17:00', 0.12),
             ('17:00 - 18:30', 0.17), ('18:30 - 20:00', 0.20), ('20:00 - 21:30', 0.17), ('21:30 - 23:00', 0.10)]
    pays = ['VietQR', 'Ví MoMo', 'ZaloPay']
    rows, daily = [], []
    d = START
    while d <= END:
        key = d.isoformat()
        tmax, tmin, rain = wx[key]  # thiếu thời tiết thật thì dừng, không bịa
        ft = features(d, tmax, tmin, rain)
        eta = TRUTH['intercept'] + sum(TRUTH[k] * v for k, v in ft.items())
        lam = math.exp(eta + rng.gauss(0, DISPERSION_SIGMA) - DISPERSION_SIGMA ** 2 / 2)
        n = poisson(rng, lam)
        # đơn bị hủy là phần THÊM (mô hình đếm chỉ tính đơn giữ lại): hay hủy hơn khi mưa
        cancels = sum(1 for _ in range(n) if rng.random() < 0.06 + 0.25 * ft['rain'])
        daily.append((key, n, cancels))
        for i in range(n + cancels):
            cancelled = i >= n
            r, acc, slot = rng.random(), 0.0, slots[-1][0]
            for s, w in slots:
                acc += w
                if r <= acc:
                    slot = s
                    break
            lead = rng.choice([0, 0, 1, 1, 2, 3, 5, 7])
            rows.append([
                'SIM-%s-%03d' % (d.strftime('%Y%m%d'), i + 1), key, slot, rng.randrange(len(venues)), 1 + rng.randrange(4),
                'Đã hủy' if cancelled else ('Hoàn thành' if d < dt.date(2026, 10, 10) else 'Đã xác nhận'),
                rng.randrange(len(pays)), rng.choice([60, 80, 90, 100, 120, 150, 180]) * 1000, lead,
            ])
        d += dt.timedelta(days=1)

    meta = {
        'simulated': True,
        'warning': 'DỮ LIỆU MÔ PHỎNG do chương trình tự sinh, KHÔNG phải đơn đặt sân thật. Chỉ dùng để minh họa mô hình.',
        'generator': 'tool/simulate_bookings.py',
        'seed': SEED, 'from': START.isoformat(), 'to': END.isoformat(),
        'days': len(daily), 'retainedBookings': sum(x[1] for x in daily), 'cancelledBookings': sum(x[2] for x in daily),
        'weather': 'Open-Meteo.com (thời tiết thật của Hà Nội)',
        'truth': {k: round(v, 4) for k, v in TRUTH.items()},
        'dispersionSigma': DISPERSION_SIGMA,
        'venues': venues, 'payments': pays,
        'rowFormat': ['id', 'date', 'time', 'venueIndex', 'fieldNumber', 'status', 'paymentIndex', 'amountVnd', 'leadDays'],
    }
    out_dir = os.path.join(ROOT, 'assets', 'demo')
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, 'simulated_bookings.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump({'meta': meta, 'bookings': rows}, f, ensure_ascii=False, separators=(',', ':'))
    mean = meta['retainedBookings'] / meta['days']
    print(f"Đã sinh {meta['retainedBookings']} đơn giữ lại + {meta['cancelledBookings']} đơn hủy trong {meta['days']} ngày "
          f"({START} → {END}), trung bình {mean:.1f} đơn/ngày; file {os.path.getsize(path) / 1024:.0f} KB")


main()
