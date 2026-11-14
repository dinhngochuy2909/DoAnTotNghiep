# TÀI LIỆU ĐẶC TẢ YÊU CẦU VÀ PHẠM VI ĐỒ ÁN

> **Đề tài:** Xây dựng ứng dụng đa nền tảng quản lý và đặt sân thể thao bằng Flutter tích hợp AI thông minh
> **Sinh viên:** Đinh Ngọc Huy — MSV: 2251162033 — Lớp: 64HTTT1
> **GVHD:** TS. Đỗ Oanh Cường
> **Trường:** Đại học Thuỷ Lợi — Khoa Công nghệ Thông tin

---

## 1. PHẠM VI ĐỀ TÀI

### 1.1 Mô tả tổng quan
Hệ thống quản lý và đặt sân thể thao trực tuyến cho phép:
- **Khách hàng** tìm kiếm, xem lịch trống, lựa chọn khung giờ và đặt sân trực tuyến trên ứng dụng di động (Android/iOS).
- **Nhân viên quản lý sân** quản lý thông tin sân, loại sân, trạng thái, giá và khung giờ hoạt động.
- **Quản trị viên** quản lý toàn bộ hệ thống: người dùng, sân, đơn đặt, thanh toán, thống kê doanh thu và dashboard dự báo AI.

### 1.2 Phạm vi hệ thống

| Thành phần | Mô tả | Công nghệ |
|---|---|---|
| Ứng dụng di động | Giao diện người dùng đa nền tảng (Android & iOS) | Flutter / Dart |
| Web Admin | Giao diện quản trị viên và nhân viên | Vue 3 |
| Backend API | Xử lý nghiệp vụ, xác thực, phân quyền | Laravel (PHP) |
| Cơ sở dữ liệu | Lưu trữ dữ liệu tập trung | PostgreSQL |
| AI/ML API | Dự báo nhu cầu, gợi ý thông minh | Python (Flask/FastAPI) |
| Xác thực | Đăng nhập, đăng ký, quản lý phiên | Firebase Authentication |
| Thông báo | Push notification đến người dùng | Firebase Cloud Messaging |
| Lưu trữ file | Hình ảnh sân, avatar người dùng | Firebase Storage |

### 1.3 Các nhóm người dùng

| Vai trò | Mô tả | Quyền hạn chính |
|---|---|---|
| **Quản trị viên** | Người quản lý toàn bộ hệ thống | Toàn quyền: quản lý người dùng, sân, đơn đặt, thanh toán, thống kê, AI |
| **Nhân viên quản lý sân** | Người vận hành sân hàng ngày | Quản lý sân, khung giờ, giá, trạng thái sân, xem đơn đặt |
| **Khách hàng** | Người sử dụng dịch vụ đặt sân | Đăng ký, đăng nhập, tìm kiếm, đặt sân, thanh toán, xem lịch sử |

---

## 2. YÊU CẦU CHỨC NĂNG

### 2.1 Module Quản lý Khách hàng (UC-01 → UC-05)

| Mã UC | Chức năng | Mô tả | Actor |
|---|---|---|---|
| UC-01 | Đăng ký tài khoản | Khách hàng tạo tài khoản mới bằng email/SĐT, xác thực OTP | Khách hàng |
| UC-02 | Đăng nhập | Xác thực người dùng bằng email/SĐT + mật khẩu hoặc đăng nhập Google | Khách hàng, Nhân viên, Quản trị viên |
| UC-03 | Đăng xuất | Kết thúc phiên làm việc, xóa token | Tất cả |
| UC-04 | Cập nhật thông tin cá nhân | Sửa tên, SĐT, avatar, địa chỉ | Khách hàng |
| UC-05 | Xem lịch sử đặt sân | Hiển thị danh sách các đơn đặt sân đã thực hiện | Khách hàng |

**Quy tắc nghiệp vụ:**
- Mỗi email/SĐT chỉ được đăng ký 1 tài khoản duy nhất
- Mật khẩu tối thiểu 8 ký tự, bao gồm chữ hoa, chữ thường và số
- Phiên đăng nhập hết hạn sau 30 ngày không hoạt động

### 2.2 Module Đặt sân (UC-06 → UC-13)

| Mã UC | Chức năng | Mô tả | Actor |
|---|---|---|---|
| UC-06 | Tìm kiếm sân | Tìm sân theo tên, loại sân, khu vực, khoảng giá | Khách hàng |
| UC-07 | Xem lịch sân | Xem lịch sân theo ngày, hiển thị khung giờ trống/đã đặt | Khách hàng |
| UC-08 | Kiểm tra sân còn trống | Hệ thống kiểm tra real-time khung giờ còn trống | Hệ thống |
| UC-09 | Chọn ngày/khung giờ | Khách hàng chọn ngày và khung giờ muốn đặt | Khách hàng |
| UC-10 | Đặt sân | Xác nhận đặt sân, tạo đơn đặt, gửi thông báo | Khách hàng |
| UC-11 | Hủy đặt sân | Hủy đơn đặt sân trước thời gian quy định | Khách hàng |
| UC-12 | Theo dõi trạng thái đặt sân | Xem trạng thái đơn: Chờ xác nhận → Đã xác nhận → Hoàn thành/Đã hủy | Khách hàng |
| UC-13 | Nhận AI gợi ý sân | Hệ thống AI gợi ý sân và khung giờ phù hợp dựa trên lịch sử | Khách hàng |

**Quy tắc nghiệp vụ:**
- Không cho phép đặt trùng khung giờ đã có người đặt (xử lý race condition)
- Hủy đặt sân miễn phí trước 2 giờ so với giờ bắt đầu
- Đơn đặt sân chưa thanh toán sẽ tự động hủy sau 30 phút
- Trạng thái đơn đặt: `pending` → `confirmed` → `in_use` → `completed` / `cancelled`

### 2.3 Module Thanh toán (UC-14 → UC-18)

| Mã UC | Chức năng | Mô tả | Actor |
|---|---|---|---|
| UC-14 | Thanh toán trực tiếp | Khách hàng thanh toán tại quầy khi đến sân | Khách hàng |
| UC-15 | Thanh toán QR | Chuyển khoản qua mã QR ngân hàng | Khách hàng |
| UC-16 | Quản lý trạng thái thanh toán | Theo dõi và cập nhật trạng thái thanh toán cho từng đơn | Quản trị viên |
| UC-17 | Xác nhận giao dịch | Xác nhận đã nhận thanh toán | Quản trị viên |
| UC-18 | Xem hóa đơn | Xem chi tiết hóa đơn và lịch sử thanh toán | Khách hàng |

**Quy tắc nghiệp vụ:**
- Trạng thái thanh toán: `unpaid` → `pending_verification` → `paid` / `refunded`
- Mã QR được tạo tự động kèm số tiền và nội dung chuyển khoản
- Hoàn tiền chỉ được thực hiện khi hủy đặt sân đúng quy định

### 2.4 Module Quản lý sân Thể thao (UC-19 → UC-24)

| Mã UC | Chức năng | Mô tả | Actor |
|---|---|---|---|
| UC-19 | Thêm sân mới | Tạo mới thông tin sân: tên, mô tả, hình ảnh, vị trí | Nhân viên |
| UC-20 | Sửa thông tin sân | Cập nhật thông tin sân đã tồn tại | Nhân viên |
| UC-21 | Xóa sân | Xóa mềm (đánh dấu inactive) hoặc xóa cứng sân | Nhân viên |
| UC-22 | Quản lý loại sân | CRUD loại sân: cầu lông, bóng đá, pickleball, tennis... | Nhân viên |
| UC-23 | Quản lý trạng thái sân | Cập nhật: Đang trống / Đã đặt / Đang sử dụng / Tạm ngừng | Nhân viên |
| UC-24 | Quản lý giá sân & khung giờ | Thiết lập giá theo khung giờ, ngày thường/cuối tuần/lễ | Nhân viên |

**Quy tắc nghiệp vụ:**
- Trạng thái sân: `available` / `booked` / `in_use` / `maintenance`
- Giá sân có thể khác nhau theo khung giờ (sáng/chiều/tối) và ngày (thường/cuối tuần/lễ)
- Không cho phép xóa sân đang có đơn đặt chưa hoàn thành

### 2.5 Module Quản trị & Thống kê (UC-25 → UC-32)

| Mã UC | Chức năng | Mô tả | Actor |
|---|---|---|---|
| UC-25 | Quản lý người dùng | Xem, khóa/mở khóa, phân vai trò tài khoản | Quản trị viên |
| UC-26 | Phân quyền | Gán vai trò và quyền hạn cho người dùng | Quản trị viên |
| UC-27 | Quản lý đơn đặt sân | Xem, xác nhận, hủy đơn đặt sân | Quản trị viên, Nhân viên |
| UC-28 | Quản lý thanh toán | Duyệt, xác nhận thanh toán, xử lý hoàn tiền | Quản trị viên |
| UC-29 | Thống kê doanh thu | Biểu đồ doanh thu theo ngày/tuần/tháng/năm | Quản trị viên |
| UC-30 | Thống kê lượt đặt sân | Số lượt đặt theo thời gian, loại sân | Quản trị viên |
| UC-31 | Thống kê hiệu suất sử dụng sân | Tỷ lệ sử dụng từng sân, khung giờ | Quản trị viên |
| UC-32 | Xác định khung giờ cao/thấp điểm | Phân tích khung giờ có nhu cầu cao nhất/thấp nhất | Quản trị viên |

### 2.6 Module AI & Dự báo (UC-33 → UC-38)

| Mã UC | Chức năng | Mô tả | Actor |
|---|---|---|---|
| UC-33 | Dự báo nhu cầu sử dụng sân | ML dự đoán số lượt đặt theo ngày/khung giờ/loại sân | Quản trị viên |
| UC-34 | Gợi ý sân thông minh | AI gợi ý sân phù hợp với sở thích và lịch sử người dùng | Khách hàng |
| UC-35 | Gợi ý khung giờ phù hợp | Đề xuất khung giờ tốt nhất dựa trên nhu cầu và giá | Khách hàng |
| UC-36 | Phân tích thời tiết | Lấy dữ liệu thời tiết để hỗ trợ gợi ý sân ngoài trời/trong nhà | Hệ thống |
| UC-37 | Dashboard dự báo & trực quan hóa | Biểu đồ so sánh thực tế vs dự báo, xu hướng tương lai | Quản trị viên |
| UC-38 | Hỗ trợ xây dựng khuyến mãi | Gợi ý chương trình khuyến mãi cho khung giờ thấp điểm | Quản trị viên |

**Dữ liệu đầu vào cho ML:**

| Nhóm | Thuộc tính |
|---|---|
| Thời gian | Ngày, tháng, thứ trong tuần, khung giờ |
| Sân | Loại sân, số lượng sân, giá sân |
| Lịch sử | Số lượt đặt, tỷ lệ sử dụng, số lượt hủy |
| Thời tiết | Nhiệt độ, lượng mưa, trạng thái (nắng/mưa/mây) |
| Sự kiện | Ngày lễ, kỳ nghỉ, cuối tuần, sự kiện thể thao |
| Khuyến mãi | Chương trình giảm giá, thay đổi giá sân |

**Thuật toán dự kiến:** Linear Regression, Random Forest, Gradient Boosting, XGBoost
**Đánh giá mô hình:** MAE, RMSE, R²

---

## 3. YÊU CẦU PHI CHỨC NĂNG

### 3.1 Hiệu năng
- Thời gian phản hồi API ≤ 500ms cho các thao tác thông thường
- Hỗ trợ tối thiểu 100 người dùng đồng thời
- Trang web load trong ≤ 3 giây

### 3.2 Bảo mật
- Mã hóa mật khẩu bằng bcrypt
- Xác thực bằng JWT token (access + refresh token)
- Phân quyền theo vai trò (RBAC)
- HTTPS cho toàn bộ API
- Chống SQL Injection, XSS, CSRF

### 3.3 Khả năng mở rộng
- Kiến trúc microservices cho Backend và ML API
- Containerize bằng Docker
- Có thể triển khai trên cloud (AWS/GCP/Azure)
- CI/CD pipeline qua GitLab/GitHub Actions

### 3.4 Tính khả dụng
- Giao diện responsive, hỗ trợ đa thiết bị
- Hỗ trợ ngôn ngữ tiếng Việt
- UI/UX thân thiện, dễ sử dụng
- Thông báo push notification khi có cập nhật đơn đặt

### 3.5 Tương thích
- Android 8.0+ (API 26+)
- iOS 13.0+
- Web browsers: Chrome 80+, Firefox 78+, Safari 13+, Edge 80+

---

## 4. MA TRẬN PHÂN QUYỀN

| Chức năng | Khách hàng | Nhân viên | Quản trị viên |
|---|:---:|:---:|:---:|
| Đăng ký / Đăng nhập | ✅ | ✅ | ✅ |
| Cập nhật thông tin cá nhân | ✅ | ✅ | ✅ |
| Tìm kiếm sân | ✅ | ✅ | ✅ |
| Đặt sân / Hủy đặt | ✅ | ❌ | ❌ |
| Thanh toán | ✅ | ❌ | ❌ |
| Xem lịch sử đặt sân | ✅ | ❌ | ✅ |
| Nhận AI gợi ý | ✅ | ❌ | ❌ |
| Thêm/Sửa/Xóa sân | ❌ | ✅ | ✅ |
| Quản lý giá & khung giờ | ❌ | ✅ | ✅ |
| Quản lý trạng thái sân | ❌ | ✅ | ✅ |
| Xem đơn đặt sân | ❌ | ✅ | ✅ |
| Quản lý người dùng | ❌ | ❌ | ✅ |
| Phân quyền | ❌ | ❌ | ✅ |
| Xác nhận thanh toán | ❌ | ❌ | ✅ |
| Thống kê doanh thu | ❌ | ❌ | ✅ |
| Dashboard AI/ML | ❌ | ❌ | ✅ |

---

## 5. RÀNG BUỘC KỸ THUẬT

| Ràng buộc | Chi tiết |
|---|---|
| Framework Mobile | Flutter 3.x / Dart 3.x |
| Framework Web Admin | Vue 3 + Vite |
| Backend | Laravel 10+ (PHP 8.1+) |
| Database | PostgreSQL 15+ |
| ML/AI | Python 3.10+, scikit-learn, XGBoost |
| Authentication | Firebase Auth |
| Push Notification | Firebase Cloud Messaging |
| File Storage | Firebase Storage |
| API Specification | RESTful API (JSON) |
| Containerization | Docker + Docker Compose |
| Version Control | Git / GitHub |
| API Weather | OpenWeatherMap API |
