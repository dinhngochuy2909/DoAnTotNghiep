# BẢN TÓM TẮT ĐỀ CƯƠNG ĐỒ ÁN TỐT NGHIỆP

Trường Đại học Thủy lợi — Khoa Công nghệ Thông tin

Tên đề tài: Xây dựng ứng dụng đa nền tảng quản lý và đặt sân thể thao bằng Flutter tích hợp AI thông minh

Sinh viên thực hiện:Đinh Ngọc Huy

Lớp:64HTTT1

Mã sinh viên: 2251162033

Số điện thoại: 0396392904

Email: 2251162033@e.tlu.edu.vn

Giáo viên hướng dẫn: TS. Đỗ Oanh Cường Email: cuongdo@tlu.edu.vn

## TÓM TẮT ĐỀ TÀI

Trong bối cảnh các hoạt động thể thao ngày càng phát triển, nhu cầu tìm kiếm và đặt sân thể thao trực tuyến ngày càng phổ biến. Tuy nhiên, người dùng vẫn gặp khó khăn trong việc tìm kiếm sân phù hợp với nhu cầu, lựa chọn thời gian, mức giá và loại sân, đặc biệt khi có nhiều sân và nhiều khung giờ khác nhau. Bên cạnh đó, các đơn vị kinh doanh sân thể thao cần một công cụ hiệu quả để quản lý sân, khách hàng, lịch đặt và doanh thu.

Đề tài tập trung xây dựng “Ứng dụng đa nền tảng quản lý và đặt sân thể thao bằng Flutter tích hợp AI thông minh”, quản lý tập trung thông tin về cụm sân, người dùng, lịch đặt, giá và thanh toán. Ứng dụng phục vụ ba nhóm người dùng chính: khách hàng tìm sân, xem lịch trống theo từng sân con và từng giờ, đặt sân và thanh toán bằng mã VietQR, đơn được tự xác nhận khi tiền về; chủ sân quản lý cụm sân và tự duyệt đơn đặt của sân mình; quản trị viên duyệt cụm sân đăng mới và theo dõi toàn hệ thống. Người dùng chưa đăng nhập vẫn xem được sân, bản đồ và hỏi trợ lý ảo.

Điểm nhấn kỹ thuật là hai thành phần trí tuệ nhân tạo. Thứ nhất, chatbot trợ lý theo kỹ thuật Retrieval-Augmented Generation (RAG) truy xuất dữ liệu của hệ thống (sân, giá, lịch trống, thời tiết) để mô hình ngôn ngữ Gemini trả lời câu hỏi bằng tiếng Việt. Thứ hai, mô hình hồi quy Poisson có điều chuẩn dự báo số đơn đặt sân theo ngày từ thứ trong tuần, ngày lễ và Tết, mùa, lượng mưa và nhiệt độ, kèm khoảng dự đoán và đánh giá mức tin cậy.

Ứng dụng được phát triển bằng Flutter, lưu dữ liệu trên Cloud Firestore thông qua REST API và triển khai trên Firebase Hosting; việc nhận biết tiền về dùng webhook của dịch vụ SePay. Trong phạm vi đồ án, ứng dụng được kiểm thử trên nền web; việc đóng gói cho Android và iOS, gợi ý sân cá nhân hóa theo lịch sử người dùng và tích hợp cổng thanh toán là hướng phát triển.

## CÁC MỤC TIÊU CHÍNH

### 1. Phân tích và thiết kế hệ thống:

Xác định các yêu cầu chức năng và phi chức năng; phân tích quy trình đặt và duyệt đơn đặt sân; thiết kế dữ liệu trên Cloud Firestore gồm người dùng, cụm sân, đơn đặt, phiếu thu, đánh giá, tin tức và thông báo; thiết kế kiến trúc tổng thể và phân quyền người dùng.

Hệ thống có các nhóm người dùng:

- Quản trị viên.
- Chủ sân.
- Khách hàng.
- Khách vãng lai (chỉ xem).
### 2. Xây dựng module quản lý sân thể thao:

Xây dựng chức năng thêm, sửa, xóa cụm sân của năm môn (cầu lông, pickleball, bóng đá, tennis, bóng rổ); quản lý số sân con, giờ mở cửa, khoảng giá giờ thường và giá ca giờ vàng 16:00 – 22:00; duyệt cụm sân đăng mới.

Hệ thống theo dõi các trạng thái:

- Cụm sân: chờ duyệt, đã duyệt, bị từ chối.
- Ô giờ trên lịch: còn trống, đã đặt, tạm khóa.
- Đơn đặt: chờ xác nhận, đã xác nhận, hoàn thành, đã hủy.
### 3. Xây dựng hệ thống đặt sân trực tuyến:

Cho phép khách hàng tìm kiếm, lọc sân theo môn và khu vực, xem trên bản đồ, chọn ngày, sân con và các giờ còn trống, đặt sân và theo dõi trạng thái đơn.

Kiểm tra lại lịch ngay trước khi ghi đơn để hạn chế nhiều người đặt trùng một khung giờ.

### 4. Xây dựng module quản lý khách hàng và thanh toán:

Đăng ký, đăng nhập (mật khẩu được băm kèm salt), xem lịch sử đặt sân, đánh giá sân đã chơi, đánh dấu sân yêu thích và nhận thông báo.

Phương thức thanh toán:

- Chuyển khoản ngân hàng bằng mã VietQR đúng số tiền, nội dung chuyển khoản là mã đơn.
- Đơn được tự xác nhận khi nhận được thông báo tiền về hợp lệ từ SePay.
Giao dịch không tự xác nhận được do chủ sân (hoặc quản trị viên đối với sân do hệ thống quản lý) đối chiếu và xác nhận.

### 5. Xây dựng chatbot trợ lý và mô hình dự báo số đơn đặt sân:

Xây dựng chatbot hỏi đáp theo kỹ thuật RAG và mô hình dự báo số đơn đặt sân của 7 ngày tới.

Các thuộc tính đầu vào của mô hình dự báo:

- Thứ trong tuần.
- Ngày lễ nghỉ và dịp Tết.
- Mùa trong năm.
- Lượng mưa.
- Nhiệt độ cao nhất và thấp nhất trong ngày.
Mô hình được đánh giá bằng kiểm định chéo với các độ đo MAE, RMSE, độ phủ khoảng dự đoán và so sánh với các cách đoán đơn giản.

### 6. Xây dựng dashboard thống kê và hỗ trợ ra quyết định:

Hiển thị các thông tin thống kê về:

- Doanh thu theo thời gian và theo môn.
- Số lượt đặt sân và tỷ lệ hủy.
- Khung giờ được đặt nhiều nhất.
- Cụm sân có doanh thu cao nhất.
- Kết quả dự báo số đơn các ngày tới.
Chủ sân có trang riêng để xem doanh thu, đơn đặt và khách quen của các sân mình quản lý.

## NỘI DUNG CHÍNH

### 1. Nghiên cứu cơ sở lý thuyết

Nghiên cứu quy trình quản lý và đặt sân thể thao trực tuyến, kiến trúc ứng dụng Flutter và cơ sở dữ liệu dạng tài liệu.

Nghiên cứu mô hình ngôn ngữ lớn và kỹ thuật Retrieval-Augmented Generation (RAG).

Nghiên cứu hồi quy Poisson cho dữ liệu đếm, điều chuẩn, kiểm định chéo và các yếu tố ngoại cảnh ảnh hưởng đến nhu cầu (thời tiết, ngày lễ, cuối tuần, mùa).

Nghiên cứu các công nghệ sử dụng:

- Flutter, Dart: xây dựng giao diện, nghiệp vụ và mô hình dự báo.
- Material Design: thiết kế giao diện và các thành phần tương tác.
- Cloud Firestore (REST API): lưu trữ và truy xuất dữ liệu.
- Firebase Hosting: triển khai ứng dụng web.
- Gemini API và xếp hạng BM25: truy xuất tri thức và sinh câu trả lời cho chatbot.
- Open-Meteo: dự báo thời tiết và dữ liệu thời tiết lịch sử.
- VietQR và OpenStreetMap (thư viện Leaflet): mã chuyển khoản và bản đồ.
- SePay và Cloudflare Workers: báo tiền về bằng webhook và tự xác nhận đơn.
- Python: thu thập tin tức, thời tiết và sinh dữ liệu mô phỏng.
- Git/GitHub: quản lý mã nguồn.
### 2. Phân tích và thiết kế hệ thống

Xác định yêu cầu chức năng và phi chức năng của hệ thống.

Thiết kế dữ liệu gồm các nhóm (collection):

- Người dùng (users).
- Cụm sân (venues).
- Đơn đặt sân (bookings).
- Phiếu thu (payments).
- Đánh giá (reviews).
- Tin tức (news).
- Thông báo (notifications).
Thiết kế kiến trúc tổng thể của hệ thống và phân quyền người dùng.

Xây dựng các sơ đồ:

- Use Case Diagram.
- Mô hình dữ liệu (ERD).
- Activity Diagram.
- Sequence Diagram.
- State Diagram của đơn đặt.
### 3. Xây dựng các module nghiệp vụ chính

### Module quản lý sân thể thao

- Thêm, sửa, xóa cụm sân.
- Quản lý số sân con, giờ mở cửa và khoảng giá.
- Duyệt cụm sân đăng mới.
### Module đặt sân

- Tìm kiếm, lọc sân và xem bản đồ.
- Xem lịch theo sân con và giờ.
- Kiểm tra trùng giờ trước khi lưu.
- Đặt nhiều khung giờ trong một lần.
- Theo dõi trạng thái và lịch sử đặt sân.
### Module khách hàng

- Đăng ký, đăng nhập.
- Xem lịch sử đặt sân.
- Đánh giá sân đã chơi.
- Đánh dấu sân yêu thích, nhận thông báo.
### Module thanh toán

- Tạo mã VietQR theo từng đơn.
- Quản lý phiếu thu và trạng thái thanh toán.
- Tự xác nhận đơn khi tiền về (SePay).
- Chủ sân hoặc quản trị viên xác nhận giao dịch.
### Module quản trị và thống kê

- Duyệt và quản lý sân.
- Theo dõi đơn đặt, thanh toán và khách hàng.
- Đăng và quản lý tin tức.
- Thống kê doanh thu, lượt đặt, tỷ lệ hủy, giờ cao điểm.
### Module khám phá

- Thời tiết, giờ vàng và khu vực có nhiều sân.
- Tin thể thao tổng hợp qua RSS, ghi rõ nguồn.
### 4. Xây dựng mô hình dự báo số đơn đặt sân

Thu thập đơn đặt sân từ hệ thống và dữ liệu thời tiết Hà Nội nhiều năm từ Open-Meteo. Do số đơn thật còn ít, đề tài sinh thêm dữ liệu mô phỏng được gắn nhãn rõ ràng, không lẫn vào số liệu thật.

Pipeline thu thập dữ liệu viết bằng Python: crawl_news.py lấy tin thể thao qua RSS, crawl_weather.py tải thời tiết nhiều năm từ Open-Meteo, simulate_bookings.py sinh đơn mô phỏng có nhãn, build_training_dataset.py dựng bảng dữ liệu huấn luyện theo ngày và theo giờ.

Dữ liệu được tổ chức theo ngày, bao gồm:

### Dữ liệu hệ thống:

- Ngày chơi.
- Số đơn không bị hủy.
- Số đơn bị hủy.
### Dữ liệu ngoại cảnh:

- Nhiệt độ cao nhất, thấp nhất.
- Lượng mưa.
- Ngày lễ nghỉ và dịp Tết.
- Thứ trong tuần, cuối tuần.
- Mùa trong năm.
Xây dựng mô hình hồi quy Poisson điều chuẩn L2 kéo hệ số về giả định chuyên môn, ước lượng bằng thuật toán bình phương tối thiểu có trọng số lặp lại (IRLS); kết hợp mô hình hồi quy logistic điều chuẩn L2 ước lượng tỷ lệ hủy đơn. Cả hai được cài đặt bằng Dart thuần và huấn luyện ngay trong ứng dụng.

Đánh giá bằng kiểm định chéo với MAE, RMSE, độ phủ khoảng 80%, so sánh với cách luôn đoán trung bình và cách chỉ dùng giả định. Kết quả hiển thị ở trang quản trị kèm nhận xét về độ tin cậy.

### 5. Xây dựng chatbot trợ lý theo kỹ thuật RAG

Chatbot hoạt động theo bốn bước:

- Hiểu câu hỏi: trích bộ lọc về môn, quận, giá, giờ và chủ đề.
- Truy xuất: sân phù hợp, lịch trống, thống kê giá, thời tiết, dự báo và đoạn chính sách liên quan (BM25).
- Dựng ngữ cảnh từ dữ liệu đã truy xuất.
- Gemini sinh câu trả lời kèm thẻ sân có nút đặt lịch.
Ràng buộc mô hình chỉ trả lời theo dữ liệu được cung cấp; khi không gọi được mô hình ngôn ngữ, chatbot trình bày trực tiếp dữ liệu đã truy xuất.

### 6. Xây dựng dashboard hỗ trợ quản lý

Dashboard cung cấp:

- Doanh thu theo thời gian và theo môn.
- Số đơn và tỷ lệ hủy theo kỳ thống kê.
- Khung giờ được đặt nhiều nhất.
- Cụm sân doanh thu cao nhất.
- Dự báo số đơn trong các ngày tiếp theo.
Dựa trên các số liệu này, người quản lý có thể xác định giờ cao điểm, chuẩn bị nhân sự cho ngày đông và xây dựng ưu đãi cho ngày vắng.

### 7. Triển khai hệ thống:

Triển khai ứng dụng web trên Firebase Hosting; dữ liệu lưu trên Cloud Firestore; khóa API và thông tin tài khoản được cấu hình ngoài mã nguồn.

### 8. Kiểm thử và hoàn thiện

Thực hiện kiểm thử tự động (chạy trên GitHub Actions) và kiểm thử trên trình duyệt đối với:

- Đăng nhập và phân quyền.
- Quản lý sân.
- Đặt sân.
- Tính giá và mã VietQR.
- Tự xác nhận thanh toán qua SePay.
- Duyệt đơn đặt sân.
- Mô hình và kết quả dự báo.
- Giao diện người dùng.
Sửa lỗi, tối ưu số lượt đọc dữ liệu và hoàn thiện tài liệu.

## KẾT QUẢ DỰ KIẾN

### 1. Lý thuyết:

- Nắm vững quy trình phân tích, thiết kế và xây dựng hệ thống đặt sân thể thao trực tuyến.
- Hiểu kiến trúc ứng dụng Flutter và cơ sở dữ liệu tài liệu Cloud Firestore.
- Hiểu và vận dụng kỹ thuật RAG kết hợp mô hình ngôn ngữ lớn.
- Hiểu mô hình hồi quy Poisson cho dữ liệu đếm và cách xây dựng tập dữ liệu dự báo.
- Hiểu phương pháp đánh giá mô hình bằng kiểm định chéo và so sánh với đường cơ sở.
- Hoàn thiện báo cáo đồ án với đầy đủ sơ đồ thiết kế, kết quả thực nghiệm và kiểm thử.
### 2. Thực nghiệm:

- Ứng dụng web đặt sân hoạt động với ba vai trò khách hàng, chủ sân và quản trị viên.
- Khách hàng tìm sân, xem lịch trống, đặt sân, thanh toán bằng mã VietQR và đơn được tự xác nhận khi nhận được tiền.
- Chủ sân quản lý cụm sân, duyệt đơn đặt và xem doanh thu.
- Quản trị viên duyệt sân, theo dõi đơn, thanh toán, khách hàng và đăng tin tức.
- Chatbot trả lời câu hỏi dựa trên dữ liệu của hệ thống.
- Mô hình dự báo số đơn 7 ngày tới, công bố trung thực sai số và mức tin cậy.
- Ứng dụng được triển khai thử nghiệm trên Firebase Hosting.
- Vượt qua bộ kiểm thử tự động cho các chức năng cốt lõi; phân quyền theo vai trò trong ứng dụng.
## KẾ HOẠCH THỰC HIỆN

| TT | Thời gian | Nội dung công việc | Kết quả dự kiến đạt được |
|---|---|---|---|
| 1 | Tuần 1 - 3 | - Khảo sát, phân tích yêu cầu, xác định phạm vi đề tài. <br> - Nghiên cứu Flutter, Cloud Firestore, RAG và dự báo dữ liệu đếm. <br> - Thiết kế dữ liệu và kiến trúc tổng thể. | - Tài liệu đặc tả yêu cầu. <br> - Sơ đồ Use Case, mô hình dữ liệu. <br> - Kiến trúc tổng thể. |
| 2 | Tuần 4 - 9 | - Dựng ứng dụng Flutter, kết nối Firestore qua REST. <br> - Danh sách sân, tìm kiếm, bản đồ. <br> - Đặt lịch theo sân con và giờ, thanh toán VietQR, tự xác nhận qua SePay. <br> - Đăng nhập, phân quyền; trang chủ sân và quản trị. | - Các module nghiệp vụ chính hoạt động. <br> - Hoàn thành luồng đặt, thanh toán và duyệt đơn. |
| 3 | Tuần 10 - 12 | - Thu thập dữ liệu sân, tin tức, thời tiết; sinh dữ liệu mô phỏng. <br> - Xây dựng chatbot RAG. <br> - Xây dựng và đánh giá mô hình dự báo. | - Bộ dữ liệu huấn luyện. <br> - Chatbot trợ lý. <br> - Mô hình dự báo và kết quả đánh giá. |
| 4 | Tuần 13 - 14 | - Tích hợp dự báo vào trang quản trị và chatbot. <br> - Xây dựng dashboard thống kê. <br> - Kiểm thử tự động, sửa lỗi, tối ưu. | - Dashboard hoàn chỉnh. <br> - Bộ kiểm thử đạt. |
| 5 | Tuần 15 | - Triển khai trên Firebase Hosting. <br> - Hoàn thiện báo cáo, slide và hồ sơ bảo vệ. | - Ứng dụng chạy trên web. <br> - Báo cáo và slide hoàn chỉnh. |

## TÀI LIỆU THAM KHẢO

[1] Google, Flutter Documentation, 2026. https://docs.flutter.dev  
[2] Google, Dart Documentation, 2026. https://dart.dev/guides  
[3] Google, Cloud Firestore REST API, 2026. https://firebase.google.com/docs/firestore/use-rest-api  
[4] Google, Firebase Hosting Documentation, 2026. https://firebase.google.com/docs/hosting  
[5] Google, Gemini API Documentation, 2026. https://ai.google.dev/gemini-api/docs  
[6] P. Lewis et al., Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks, NeurIPS 2020. https://arxiv.org/abs/2005.11401  
[7] S. Robertson, H. Zaragoza, The Probabilistic Relevance Framework: BM25 and Beyond, 2009.  
[8] P. McCullagh, J. A. Nelder, Generalized Linear Models, 2nd ed., 1989.  
[9] R. J. Hyndman, G. Athanasopoulos, Forecasting: Principles and Practice, 3rd ed., 2021. https://otexts.com/fpp3/  
[10] Open-Meteo, Weather Forecast and Historical Weather APIs, 2026. https://open-meteo.com/en/docs  
[11] EMVCo, EMV QR Code Specification for Payment Systems, 2026. https://www.emvco.com/emv-technologies/qr-codes/  
[12] OpenStreetMap contributors, OpenStreetMap, 2026. https://www.openstreetmap.org/copyright
