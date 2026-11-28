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
│   │   │   ├── admin/ home/    Phần tách theo tab của trang quản trị và trang chủ
│   │   ├── theme/              Màu, phông chữ, kiểu dùng chung
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
│   ├── firestore.rules         Luật truy cập Firestore (đang mở, xem docs/dac-ta-yeu-cau.md mục 5)
│   ├── firebase.json           Cấu hình Firebase Hosting
│   └── dart_defines.example.json   Mẫu file khóa bí mật (xem bên dưới)
└── docs/
    ├── report/                 Báo cáo đồ án (.docx và bản .md), slide, checklist
    ├── diagrams/               Sơ đồ use case, dữ liệu, kiến trúc, hoạt động…
    ├── archive/                Bản cũ: web admin viết bằng Vue, sơ đồ phương án ban đầu
    └── dac-ta-yeu-cau.md       Đặc tả yêu cầu
```

## Yêu cầu môi trường

- **Dart 3.13.1 trở lên** (`sdk: ^3.13.1` trong `alobooking/pubspec.yaml`), đi kèm Flutter 3.47.
- Dự án được phát triển và kiểm thử với Flutter 3.47.1 (kênh stable), Dart 3.13.1; GitHub Actions dùng đúng phiên bản này.
- Trình duyệt Chrome để chạy bản web; Python 3 nếu muốn chạy các script trong `alobooking/tool/`.

## Chạy ứng dụng

Chạy trong thư mục `alobooking/`.

1. Sao chép `dart_defines.example.json` thành `dart_defines.json` và điền khóa thật (Gemini, thông tin nhận tiền). File này đã được `.gitignore`, không đưa lên git.
2. Cài thư viện và chạy:

```
flutter pub get
flutter run -d web-server --web-port 8801 --web-hostname localhost --dart-define-from-file=dart_defines.json
```

Mở http://localhost:8801/.

## Đưa lên web (Firebase Hosting)

Đang chạy tại https://alobooking-b2484.web.app. Trong thư mục `alobooking/`:

```
flutter build web --release --no-tree-shake-icons --dart-define-from-file=dart_defines.json --dart-define=GEMINI_API_KEY= --dart-define=DEMO_ACCOUNTS=false
firebase deploy --only hosting
```

Hai tham số cuối của lệnh build giữ cho khóa Gemini và tài khoản demo không lọt vào bản web công khai.

## Kiểm thử

```
flutter test
dart analyze --fatal-infos
flutter test test/integration/gemini_live_test.dart --dart-define-from-file=dart_defines.json   # gọi Gemini thật
```

Test gọi Gemini tự bỏ qua khi không truyền khóa. Trên GitHub Actions, thêm secret `GEMINI_API_KEY` thì bước này mới chạy.

## Tự xác nhận thanh toán qua SePay

Máy nhận webhook ở [sepay-webhook/](sepay-webhook/README.md) (Cloudflare Worker). Kiểm thử: `node --test test/worker.test.mjs` trong thư mục đó.

## Script lấy dữ liệu (`alobooking/tool/`)

| Script | Việc làm |
| --- | --- |
| `crawl_news.py` | Lấy tin thể thao từ RSS, đăng lên mục Khám phá (có ghi nguồn) |
| `crawl_weather.py` | Tải thời tiết nhiều năm của Hà Nội về `tool/data/` |
| `simulate_bookings.py` | Sinh đơn đặt sân mô phỏng vào `assets/demo/` (luôn gắn nhãn mô phỏng) |
| `check_auth_roles.dart` | Chạy tay kiểm tra đăng nhập theo vai trò (cần mạng) |
| `build_training_dataset.py` | Dựng bảng dữ liệu huấn luyện theo ngày và theo giờ |
