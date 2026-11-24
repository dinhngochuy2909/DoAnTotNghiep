# AloBooking – Đồ án tốt nghiệp

Ứng dụng đặt sân thể thao (Flutter Web, dữ liệu trên Firestore). Có ba vai trò: khách đặt sân, chủ sân duyệt đơn của sân mình, admin quản trị hệ thống.

## Cấu trúc thư mục

```
.
├── alobooking/                 Ứng dụng Flutter (toàn bộ mã nguồn)
│   ├── lib/
│   │   ├── main.dart           Điểm vào của ứng dụng
│   │   ├── models/             Kiểu dữ liệu: Venue, User, NewsPost, Payment…
│   │   ├── data/               Dữ liệu tĩnh: danh sách sân mẫu, ảnh minh họa, trang thông tin
│   │   ├── screens/            Các màn hình (đăng nhập, trang chủ, admin, chủ sân, chatbot…)
│   │   ├── widgets/            Thành phần giao diện dùng chung
│   │   └── services/           Xử lý nghiệp vụ và gọi dịch vụ ngoài
│   │       ├── ai/             Chatbot: Gemini + tra cứu RAG
│   │       ├── forecast/       Dự báo số đơn đặt sân, đơn mô phỏng
│   │       ├── weather/        Thời tiết Open-Meteo (hiện tại, dự báo, lịch sử)
│   │       └── platform/       Mã riêng cho web (chọn ảnh, vị trí, bộ nhớ đệm)
│   ├── test/                   Test tự động, cấu trúc phản chiếu lib/
│   ├── tool/                   Script Python lấy dữ liệu (tin RSS, thời tiết, đơn mô phỏng)
│   │   └── data/               Dữ liệu các script ghi ra (CSV, JSON)
│   ├── assets/demo/            Dữ liệu mô phỏng được đóng gói vào ứng dụng
│   ├── web/ android/ ios/ windows/   Thư mục nền tảng do Flutter sinh ra
│   ├── pubspec.yaml            Khai báo thư viện
│   ├── firestore.rules         Luật truy cập Firestore
│   └── dart_defines.example.json   Mẫu file khóa bí mật (xem bên dưới)
└── docs/
    ├── report/                 Báo cáo đồ án (.docx và bản .md), slide, checklist
    ├── diagrams/               Sơ đồ ERD, use case, kiến trúc hệ thống
    ├── archive/                Bản sao lưu cũ (web admin viết bằng Vue)
    └── dac-ta-yeu-cau.md       Đặc tả yêu cầu
```

## Chạy ứng dụng

Chạy trong thư mục `alobooking/`.

1. Sao chép `dart_defines.example.json` thành `dart_defines.json` và điền khóa thật (Gemini, thông tin nhận tiền). File này đã được `.gitignore`, không đưa lên git.
2. Cài thư viện và chạy:

```
flutter pub get
flutter run -d web-server --web-port 8801 --web-hostname localhost --dart-define-from-file=dart_defines.json
```

Mở http://localhost:8801/.

## Kiểm thử

```
flutter test
dart analyze
```

## Script lấy dữ liệu (`alobooking/tool/`)

| Script | Việc làm |
| --- | --- |
| `crawl_news.py` | Lấy tin thể thao từ RSS, đăng lên mục Khám phá (có ghi nguồn) |
| `crawl_weather.py` | Tải thời tiết nhiều năm của Hà Nội về `tool/data/` |
| `simulate_bookings.py` | Sinh đơn đặt sân mô phỏng vào `assets/demo/` (luôn gắn nhãn mô phỏng) |
| `check_auth_roles.dart` | Chạy tay kiểm tra đăng nhập theo vai trò (cần mạng) |
