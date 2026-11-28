# Bảng dữ liệu huấn luyện: nhiệt độ, thời tiết, giờ, ngày, mùa, ngày lễ

Sinh bằng `python tool/build_training_dataset.py` (chạy lại cho đúng cùng kết quả). Mở bằng Excel được (CSV có BOM UTF-8, tiếng Việt hiển thị đúng).

| File | Số dòng | Mỗi dòng là | Giai đoạn |
|---|---|---|---|
| `training_daily.csv` | 3.976 | một ngày | 01/01/2016 → 19/11/2026 (nhãn chỉ có 319 ngày: 25/11/2025 → 09/10/2026) |
| `training_hourly.csv` | 5.742 | một giờ (05:00–22:59) | 25/11/2025 → 09/10/2026 (319 ngày × 18 giờ) |
| `hanoi_weather_hourly.csv` | 7.656 | một giờ (đủ 24 giờ) | 25/11/2025 → 09/10/2026, thời tiết gốc để dựng bảng giờ |

## Cái gì là THẬT, cái gì là MÔ PHỎNG

- **Thời tiết (nhiệt độ, mưa, độ ẩm, mây, gió, mã thời tiết): dữ liệu thật** của Hà Nội (21.0285, 105.8542) từ [Open-Meteo.com](https://open-meteo.com) (CC BY 4.0; số liệu tái phân tích, không phải trạm đo tại sân). Ô nào nguồn không có thì để trống, không điền số đoán.
- **Lịch (thứ, mùa, ngày lễ/Tết)**: tính theo quy ước của ứng dụng (cùng `VnCalendar`). Ứng dụng chỉ khai báo ngày Tết và Giỗ Tổ của 2026–2027; các năm 2016–2025 do dự án **bổ sung thêm**, cần đối chiếu lại với lịch chính thức trước khi dùng cho việc khác.
- **Nhãn số đơn (`bookings_*`, `cancelled_in_hour`): MÔ PHỎNG**, do `tool/simulate_bookings.py` tự sinh, **không phải đơn đặt sân thật**, và luôn kèm `label_source = mo_phong`. Các dòng ngoài giai đoạn 25/11/2025 → 09/10/2026 không có nhãn (`has_label = 0`), ô nhãn để trống.
- Phân bố đơn theo giờ trong ngày là **giả định** của bộ sinh dữ liệu (cao nhất 18:30–21:30), nên không dùng để kết luận giờ nào đắt khách ngoài đời.

## Cột của `training_daily.csv`

| Cột | Ý nghĩa |
|---|---|
| `date`, `year`, `month`, `day`, `day_of_year` | ngày dương lịch |
| `weekday_no` (1 = Thứ Hai … 7 = Chủ Nhật), `weekday` | thứ trong tuần |
| `is_weekend` | 1 nếu Thứ Bảy/Chủ Nhật |
| `is_day_off` | 1 nếu cuối tuần hoặc lễ nghỉ làm |
| `season` | Xuân (2–4), Hạ (5–8), Thu (9–11), Đông (12–1), như `Seasons` trong app |
| `holiday_name`, `holiday_kind` | tên ngày lễ; `none` / `off` (lễ nghỉ) / `tet` (dịp Tết, nhu cầu giảm) |
| `tet_intensity` | 0..1, mùng 1–4 Tết = 1, cận Tết/sau Tết nhẹ hơn |
| `tmax_c`, `tmin_c`, `tmean_c` | nhiệt độ cao nhất, thấp nhất, trung bình (°C) |
| `rain_mm`, `rainy` | lượng mưa cả ngày (mm); `rainy` = 1 nếu ≥ 1 mm |
| `rain_index` | mưa 0..1 (10 mm trở lên = 1), đúng định nghĩa mô hình dùng |
| `rain_level` | Không mưa / rất nhẹ / nhỏ / vừa / to / rất to (mốc 0, 1, 5, 15, 30 mm) |
| `heat`, `cold` | số "bậc 4°C" vượt 32°C (nhiệt độ cao nhất) / dưới 18°C (nhiệt độ thấp nhất) |
| `temp_level` | Dễ chịu / Lạnh / Rét đậm / Nóng / Nắng nóng gay gắt |
| `bookings_retained` | **nhãn mô phỏng**: số đơn giữ lại trong ngày (mô hình dự đoán cột này) |
| `bookings_cancelled` | **nhãn mô phỏng**: số đơn bị hủy thêm |
| `has_label`, `label_source` | có nhãn không; nguồn nhãn |

## Cột của `training_hourly.csv`

Các cột lịch như trên (`date`, `weekday_no`, `weekday`, `is_weekend`, `is_day_off`, `month`, `season`, `holiday_name`, `holiday_kind`) và:

| Cột | Ý nghĩa |
|---|---|
| `hour` | giờ bắt đầu, 5..22 |
| `day_period` | Sáng (5–10h), Trưa (11–13h), Chiều (14–17h), Tối (18–22h) |
| `is_golden_hour` | 1 nếu thuộc ca giờ vàng 16:00–22:00 của app |
| `temp_c`, `humidity_pct`, `rain_mm`, `cloud_pct`, `wind_kmh` | nhiệt độ, độ ẩm, mưa trong giờ, mây, gió (thật) |
| `weather_code`, `weather_label` | mã thời tiết WMO và nhãn tiếng Việt (Trời quang, Ít mây, Mưa nhẹ, Dông...) |
| `bookings_in_hour` | **nhãn mô phỏng**: số đơn giữ lại có ca chơi chạm vào giờ đó (ca 90 phút tính cho cả hai giờ) |
| `cancelled_in_hour` | **nhãn mô phỏng**: tương tự cho đơn hủy |

## Lưu ý khi dùng để huấn luyện

- Chỉ **319 ngày** (và 5.742 giờ của chúng) có nhãn. Các ngày còn lại chỉ có đặc trưng, không dùng được để học.
- Thêm cột không nâng được độ chính xác theo ngày lên 95%: số đơn mỗi ngày là số đếm ngẫu nhiên (~6,5 đơn/ngày). Chính mô hình hiện tại (sai số 2,13 đơn/ngày) đã sát mức tốt nhất có thể (2,17 nếu biết sẵn đáp án). Bảng này có ích để thử mô hình theo giờ, hoặc khi có đơn thật.
- Khi có đơn thật, thay các cột nhãn bằng số đơn thật (bỏ cờ `mo_phong`), giữ nguyên các cột đặc trưng.
