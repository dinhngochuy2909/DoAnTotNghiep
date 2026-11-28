# Tự xác nhận đơn qua SePay

Máy nhận (Cloudflare Worker, gói miễn phí, không cần thẻ) cho webhook của SePay:

1. SePay báo có tiền vào tài khoản đã liên kết.
2. Worker kiểm tra chữ ký, đúng tài khoản, đọc mã đơn trong nội dung chuyển khoản (`BK123456`) và so số tiền.
3. Đủ tiền thì đơn chuyển "Đã xác nhận", phiếu thu chuyển "Thành công".
4. Ứng dụng đang mở hộp QR thấy đơn đã xác nhận thì hiện dấu tích xanh và chuyển sang lịch đã đặt.

Chuyển thiếu tiền, sai mã, đơn đã hủy, hoặc số tiền trên đơn thấp hơn bảng giá của sân thì không đổi gì; chủ sân xử lý thủ công.

## Cài đặt (làm một lần)

```
npm install -g wrangler
wrangler login                      # mở trình duyệt, đăng nhập hoặc tạo tài khoản Cloudflare
cd sepay-webhook
wrangler deploy                     # in ra địa chỉ dạng https://alobooking-sepay.<tên>.workers.dev
wrangler secret put ACCOUNT_NUMBER      # số tài khoản đã liên kết SePay
wrangler secret put SEPAY_HMAC_SECRET   # khóa bí mật của webhook trên SePay
wrangler secret put BOT_EMAIL           # tài khoản riêng của máy nhận (vai trò "webhook")
wrangler secret put BOT_PASSWORD
wrangler secret put FIREBASE_API_KEY    # khóa web của dự án Firebase
```

Tài khoản máy nhận do `alobooking/tool/migrate_to_auth.py accounts` tạo. Luật Firestore chỉ cho tài khoản này chuyển đơn đang chờ sang đã xác nhận và phiếu thu sang thành công.

Trên my.sepay.vn:

- **Tích hợp WebHooks → Thêm webhook:** sự kiện "Có tiền vào", địa chỉ là địa chỉ worker ở trên, định dạng **JSON**, chứng thực **HMAC-SHA256** (dùng đúng khóa đã nhập ở `SEPAY_HMAC_SECRET`), bật "Tự động gửi lại khi server trả lỗi", chọn tài khoản MB đã liên kết.
- **Cấu hình công ty → Cấu hình chung → Cấu trúc mã thanh toán:** thêm tiền tố `BK`, hậu tố 6 chữ số (không bắt buộc, worker tự đọc được nội dung).

Nếu dùng kiểu API Key thay cho HMAC thì đặt `SEPAY_API_KEY` và **không** đặt `SEPAY_HMAC_SECRET`.

## Theo dõi và kiểm thử

```
npm test            # kiểm thử, không cần mạng
wrangler tail       # xem nhật ký khi có giao dịch
```

## Giới hạn

Máy nhận tin vào webhook có chữ ký của SePay. Giá được đối chiếu theo bảng giá hiện tại của sân: chủ sân đổi giá giữa lúc đặt và lúc chuyển tiền thì đơn phải xác nhận tay.
