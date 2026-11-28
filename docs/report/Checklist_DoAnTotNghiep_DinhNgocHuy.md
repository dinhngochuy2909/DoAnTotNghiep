# Checklist Đồ Án Tốt Nghiệp: Ứng dụng đa nền tảng quản lý và đặt sân thể thao

Cập nhật theo sản phẩm thực tế. `[x]` đã xong, `[ ]` chưa làm.

### Giai đoạn 1: Phân tích, thiết kế, nghiên cứu (Tuần 1 - 3)
- [x] Nghiên cứu Flutter, Dart, Cloud Firestore REST.
- [x] Nghiên cứu RAG, hồi quy Poisson và đánh giá mô hình dự báo.
- [x] Khảo sát, phân tích yêu cầu và xác định phạm vi.
- [x] Đặc tả yêu cầu ([dac-ta-yeu-cau.md](../dac-ta-yeu-cau.md)).
- [x] Mô hình dữ liệu, use case, hoạt động, tuần tự, trạng thái, kiến trúc ([diagrams](../diagrams/)).
- [ ] Class diagram.

### Giai đoạn 2: Các module nghiệp vụ (Tuần 4 - 9)
- [x] Ứng dụng Flutter Web kết nối Firestore.
- [x] Quản lý sân: thêm, sửa, xóa, loại sân, giá, giờ mở cửa, duyệt sân mới.
- [x] Khách hàng: đăng ký, đăng nhập, lịch sử đặt, đánh giá, thông báo.
- [ ] Khách hàng cập nhật thông tin cá nhân.
- [x] Đặt sân: tìm kiếm, xem lịch trống, đặt, hủy.
- [x] Thanh toán VietQR và xác nhận giao dịch.

### Giai đoạn 3: Dự báo nhu cầu (Tuần 10 - 12)
- [x] Thu thập thời tiết nhiều năm, ngày lễ; sinh đơn mô phỏng có nhãn.
- [x] Bảng dữ liệu huấn luyện theo ngày và theo giờ (`alobooking/tool/data/`).
- [x] Hồi quy Poisson có điều chuẩn, kiểm định chéo (MAE, RMSE, độ phủ).
- [ ] So sánh thêm các thuật toán dự báo khác.

### Giai đoạn 4: Tích hợp AI và Dashboard (Tuần 13 - 14)
- [x] Chatbot RAG với Gemini.
- [x] Thẻ dự báo số đơn 7 ngày trong trang quản trị và chatbot.
- [x] Dashboard doanh thu, lượt đặt, tỷ lệ hủy, giờ cao điểm.
- [ ] Gợi ý sân, khung giờ cá nhân hóa.
- [ ] Tỷ lệ sử dụng từng sân, khung giờ thấp điểm.

### Giai đoạn 5: Kiểm thử, triển khai, báo cáo (Tuần 15)
- [x] Kiểm thử tự động và `dart analyze`.
- [x] GitHub Actions chạy phân tích mã và kiểm thử (đã chạy thành công ngày 28/11/2026).
- [x] Triển khai web trên Firebase Hosting: https://alobooking-b2484.web.app
- [ ] Bảo mật phía máy chủ (Firebase Authentication + luật Firestore).
- [ ] Hoàn thiện cuốn báo cáo với ảnh giao diện mới.
- [ ] Chuẩn bị slide thuyết trình.
- [ ] Hồ sơ bảo vệ.
