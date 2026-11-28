# TÀI LIỆU ĐẶC TẢ YÊU CẦU VÀ PHẠM VI ĐỒ ÁN

> **Đề tài:** Xây dựng ứng dụng đa nền tảng quản lý và đặt sân thể thao bằng Flutter tích hợp AI thông minh
> **Sinh viên:** Đinh Ngọc Huy — MSV: 2251162033 — Lớp: 64HTTT1
> **GVHD:** TS. Đỗ Oanh Cường
> **Trường:** Đại học Thủy Lợi — Khoa Công nghệ Thông tin

Tài liệu mô tả đúng sản phẩm hiện có trong mã nguồn. Những phần dự kiến ban đầu nhưng chưa làm được liệt kê ở mục 6.

---

## 1. PHẠM VI ĐỀ TÀI

### 1.1 Mô tả tổng quan
Ứng dụng web đặt sân thể thao (cầu lông, pickleball, bóng đá, tennis, bóng rổ), dữ liệu sân tập trung ở Hà Nội:
- **Khách hàng** tìm sân, xem lịch trống theo sân con và theo giờ, đặt sân và thanh toán bằng chuyển khoản VietQR; đơn tự xác nhận khi tiền về (qua SePay).
- **Chủ sân** quản lý cụm sân của mình và tự duyệt đơn đặt.
- **Quản trị viên** duyệt cụm sân đăng mới, theo dõi đơn, thanh toán, khách hàng, tin tức, thống kê và dự báo.
- **Khách vãng lai** xem sân, bản đồ, trang Khám phá và hỏi trợ lý ảo.

### 1.2 Thành phần hệ thống

| Thành phần | Mô tả | Công nghệ |
|---|---|---|
| Ứng dụng | Toàn bộ giao diện và nghiệp vụ, chạy trong trình duyệt | Flutter Web / Dart |
| Cơ sở dữ liệu | Cloud Firestore, ứng dụng gọi REST API kèm ID token; luật bảo mật theo vai trò | Firestore REST, Security Rules |
| Xác thực | Firebase Authentication (email, mật khẩu); `users/{uid}` lưu hồ sơ và vai trò | Identity Toolkit REST |
| Chatbot | Truy xuất dữ liệu (lọc + BM25) rồi sinh câu trả lời | RAG + Gemini API |
| Dự báo | Số đơn theo ngày và tỷ lệ hủy | Hồi quy Poisson (IRLS, điều chuẩn L2) và logistic (L2) viết bằng Dart thuần |
| Thời tiết | Hiện tại, dự báo và lịch sử | Open-Meteo |
| Bản đồ | Vị trí cụm sân | OpenStreetMap qua thư viện Leaflet (không cần khóa API) |
| Triển khai | Trang web tĩnh | Firebase Hosting |
| Đối soát thanh toán | Nhận thông báo tiền về, xác nhận đơn | Webhook SePay + Cloudflare Worker (`sepay-webhook/`) |
| Script dữ liệu | Tin RSS, thời tiết, đơn mô phỏng, bảng huấn luyện | Python (`alobooking/tool/`) |

Sơ đồ: [kiến trúc](diagrams/kien-truc-he-thong.png), [use case](diagrams/use-case.png), [dữ liệu](diagrams/mo-hinh-du-lieu.png).

### 1.3 Các nhóm người dùng

| Vai trò | Cách xác định | Quyền chính |
|---|---|---|
| Khách vãng lai | Chưa đăng nhập hoặc vai trò `guest` | Xem, hỏi chatbot; không đặt sân |
| Khách hàng | `role = customer` | Đặt, thanh toán, đánh giá |
| Chủ sân | `role = owner`, sở hữu sân qua `ownerId` | Quản lý sân và đơn của sân mình |
| Quản trị viên | `role = admin` | Duyệt sân, theo dõi toàn hệ thống |

Vai trò chỉ lấy từ trường `role` đã lưu, không suy ra từ email.

---

## 2. YÊU CẦU CHỨC NĂNG

### 2.1 Danh sách use case

| Mã | Use case | Tác nhân |
|---|---|---|
| UC01 | Xem, tìm và lọc sân | Khách vãng lai, Khách hàng |
| UC02 | Xem bản đồ và trang Khám phá | Khách vãng lai, Khách hàng |
| UC03 | Hỏi chatbot trợ lý | Khách vãng lai, Khách hàng |
| UC04 | Đăng ký, đăng nhập | Khách vãng lai |
| UC05 | Đặt sân theo giờ | Khách hàng |
| UC06 | Thanh toán chuyển khoản VietQR | Khách hàng |
| UC07 | Xem lịch đã đặt | Khách hàng |
| UC08 | Đánh giá sân đã chơi | Khách hàng |
| UC09 | Đánh dấu yêu thích, nhận thông báo | Khách hàng |
| UC10 | Đăng ký, sửa, xóa cụm sân | Chủ sân |
| UC11 | Xác nhận, hủy, hoàn thành đơn | Chủ sân |
| UC12 | Xem doanh thu và khách quen | Chủ sân |
| UC13 | Duyệt cụm sân đăng mới | Quản trị viên |
| UC14 | Xem đơn, thanh toán, khách hàng | Quản trị viên |
| UC15 | Duyệt đơn của sân do hệ thống quản lý | Quản trị viên |
| UC16 | Đăng và quản lý tin tức | Quản trị viên |
| UC17 | Xem thống kê và dự báo số đơn | Quản trị viên |

### 2.2 Quy tắc nghiệp vụ

**Đặt sân**
- Lịch hiển thị theo sân con và giờ từ 05:00 đến 24:00; ô giờ có trạng thái trống, đã đặt hoặc tạm khóa.
- Số sân con mặc định theo môn khi chủ sân chưa khai báo: cầu lông 8, pickleball 6, bóng đá 4, tennis 4, bóng rổ 2.
- Ca giờ vàng 16:00 – 22:00 tính giá cao, giờ còn lại tính giá thấp trong khoảng giá chủ sân khai báo.
- Lịch được tải lại ngay trước khi ghi đơn để phát hiện trùng giờ.
- Trạng thái đơn: Chờ xác nhận → Đã xác nhận → Hoàn thành, hoặc Đã hủy ([sơ đồ](diagrams/trang-thai-don-dat.png)).
- Khách **không tự hủy** được đơn. Chỉ đơn đang chờ xác nhận mới hủy được trên ứng dụng, do chủ sân (hoặc quản trị viên với sân do hệ thống quản lý) thực hiện; đơn đã xác nhận không có nút hủy, sự cố và hoàn tiền xử lý ngoài ứng dụng.

- Đơn, dòng lịch bận và phiếu thu được ghi trong một lần (được cả hoặc không).
- Ô giờ đã đặt công khai ở collection `slots`, không có tên, số điện thoại hay số tiền.

**Tài khoản**
- Quên mật khẩu: Firebase Authentication gửi thư chứa đường dẫn đặt mật khẩu mới tới email đã đăng ký; ứng dụng không cho biết email đó có tài khoản hay không.

**Thanh toán**
- Chỉ chuyển khoản qua mã VietQR đúng số tiền, nội dung là mã đơn.
- Phiếu thu: Đang xử lý → Thành công hoặc Đã hoàn tiền.
- Tự xác nhận: SePay gửi webhook có chữ ký HMAC khi tiền về; máy nhận kiểm tra đúng tài khoản, đúng mã đơn trong nội dung, đủ số tiền, và số tiền trên đơn không thấp hơn bảng giá của sân rồi mới xác nhận. Máy nhận đăng nhập bằng tài khoản riêng chỉ được xác nhận đơn. Không đạt thì chủ sân xử lý thủ công.
- Màn thanh toán hỏi trạng thái đơn mỗi 4 giây (tối đa 10 phút), được xác nhận thì báo thành công và chuyển sang lịch đã đặt.
- Hoàn tiền do chủ sân xử lý ngoài ứng dụng.

**Quản lý sân và duyệt**
- Cụm sân mới của chủ sân phải được quản trị viên duyệt mới hiển thị cho khách.
- Chủ sân chỉ sửa, xóa sân và duyệt đơn của sân có `ownerId` là mình; quản trị viên duyệt đơn của sân do hệ thống quản lý.

**Đánh giá**
- Chỉ khách đã chơi xong tại sân mới được viết đánh giá.

**Chatbot và dự báo**
- Chatbot chỉ đọc sân đã duyệt, không phải sân minh họa; khi không gọi được Gemini thì trình bày trực tiếp dữ liệu đã truy xuất ([quy trình](diagrams/chatbot-rag.png)).
- Dự báo số đơn 7 ngày tới từ thứ trong tuần, ngày lễ và Tết, mùa, mưa, nhiệt độ; đánh giá bằng kiểm định chéo (MAE, RMSE, độ phủ 80%) so với hai đường cơ sở ([quy trình](diagrams/du-bao-so-don.png)).
- Dữ liệu mô phỏng luôn có nhãn và không ghi lên Firestore.

---

## 3. YÊU CẦU PHI CHỨC NĂNG

- **Hiệu năng:** danh sách sân được lưu đệm 30 phút để giảm lượt đọc Firestore (gói miễn phí có hạn mức đọc mỗi ngày).
- **Bảo mật:** Firebase Authentication giữ mật khẩu; luật Firestore (`alobooking/firestore.rules`) phân quyền theo vai trò ở phía máy chủ, mặc định từ chối; khóa Gemini, khóa SePay và tài khoản nhận tiền nằm ngoài mã nguồn; bản web công khai không chứa khóa Gemini.
- **Khả dụng:** giao diện tiếng Việt, dùng được từ màn hình điện thoại đến máy tính.
- **Tương thích:** trình duyệt hiện đại, đã kiểm thử trên Chrome.
- **Kiểm thử:** `flutter test`, `dart analyze --fatal-infos` (không còn vấn đề nào), kiểm thử máy nhận webhook, và trên bộ mô phỏng Firebase: kiểm thử luật bảo mật cùng luồng đăng ký, đặt, duyệt, hủy. Tất cả chạy trên GitHub Actions (`.github/workflows/ci.yml`).
- **Kiểm thử tích hợp AI:** `test/integration/gemini_live_test.dart` gọi Gemini thật, tự bỏ qua khi không có khóa. Ngày 28/11/2026: ba model ưu tiên trả lời HTTP 200, model dự phòng cuối `gemini-flash-latest` quá 40 giây không trả lời.

---

## 4. MA TRẬN PHÂN QUYỀN (giao diện và luật Firestore)

| Chức năng | Khách vãng lai | Khách hàng | Chủ sân | Quản trị viên |
|---|:---:|:---:|:---:|:---:|
| Xem sân, bản đồ, Khám phá, chatbot | Có | Có | Có | Có |
| Đặt sân và thanh toán | Không | Có | Có | Có |
| Đánh giá sân đã chơi xong | Không | Có | Có | Có |
| Đăng ký, sửa, xóa sân | Không | Không | Sân của mình | Mọi sân |
| Duyệt cụm sân đăng mới | Không | Không | Không | Có |
| Xác nhận, hủy, hoàn thành đơn | Không | Không | Đơn sân của mình | Chỉ đơn sân hệ thống |
| Xem đơn, thanh toán, khách hàng | Không | Không | Của sân mình | Có |
| Đăng tin tức | Không | Không | Không | Có |
| Thống kê và dự báo toàn hệ thống | Không | Không | Doanh thu của mình | Có |

---

## 5. HẠN CHẾ ĐÃ BIẾT

- Luật chưa chặn được việc một người đã đăng nhập đặt giữ chỗ rồi không trả tiền, hoặc gửi thông báo rác.
- Chưa kiểm tra trùng giờ ở máy chủ: hai người đặt gần như cùng lúc vẫn có thể cùng thành công.
- Phiên đăng nhập chỉ giữ trong bộ nhớ, tải lại trang phải đăng nhập lại.
- Lịch trống và khách quen vẫn đối chiếu sân theo tên.
- Số đơn thật còn ít nên mô hình dự báo chưa chứng minh được hiệu quả trên dữ liệu thật.
- Chưa có cổng thanh toán; việc đối soát tự động dựa vào webhook của SePay.

## 6. CHƯA THỰC HIỆN (hướng phát triển)

- Ứng dụng Android, iOS (mã Flutter có thể đóng gói nhưng chưa kiểm thử).
- Gợi ý sân và khung giờ cá nhân hóa theo lịch sử người dùng.
- Dự báo theo khung giờ và loại sân; so sánh thêm các thuật toán dự báo khác.
- Cập nhật thông tin cá nhân, thanh toán tại sân, đặt cố định theo tháng.
- Thống kê tỷ lệ sử dụng từng sân, khung giờ thấp điểm.
- Thông báo đẩy, lưu trữ ảnh thật của từng sân.
