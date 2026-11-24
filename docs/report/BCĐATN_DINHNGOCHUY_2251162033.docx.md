

| ![logo][image1] |  TRƯỜNG ĐẠI HỌC THUỶ LỢI  KHOA CÔNG NGHỆ THÔNG TIN  BẢN TÓM TẮT ĐỀ CƯƠNG ĐỒ ÁN TỐT NGHIỆP  |
| :---: | :---: |

**Tên đề tài: Xây dựng ứng dụng đa nền tảng quản lý và đặt sân thể thao bằng Flutter tích hợp AI thông minh**

*Sinh viên thực hiện*:	Đinh Ngọc Huy

*Lớp*:	64HTTT1

*Mã sinh viên:* 2251162033

*Số điện thoại: 0396392904*

*Email:*	 2251162033@e.tlu.edu.vn

*Giáo viên hướng dẫn*: TS. Đỗ Oanh Cường               Email: cuongdo@tlu.edu.vn                   

			                         

**TÓM TẮT ĐỀ TÀI**

Trong bối cảnh các hoạt động thể thao ngày càng phát triển, nhu cầu tìm kiếm và đặt sân thể thao trực tuyến ngày càng phổ biến. Tuy nhiên, người dùng vẫn gặp khó khăn trong việc tìm kiếm sân phù hợp với nhu cầu, lựa chọn thời gian, mức giá và loại sân, đặc biệt khi có nhiều sân và nhiều khung giờ khác nhau. Bên cạnh đó, các đơn vị kinh doanh sân thể thao cần một công cụ hiệu quả để quản lý sân, khách hàng, lịch đặt và doanh thu.

Đề tài tập trung xây dựng **“Ứng dụng đa nền tảng quản lý và đặt sân thể thao bằng Flutter tích hợp AI gợi ý thông minh”**, trong đó các thông tin về sân thể thao, khách hàng, lịch đặt, giá sân và giao dịch được quản lý tập trung. Ứng dụng cung cấp trải nghiệm liền mạch trên các thiết bị **Android và iOS**, cho phép khách hàng tìm kiếm sân, xem lịch trống, lựa chọn khung giờ và thực hiện đặt sân trực tuyến; đồng thời cung cấp ứng dụng quản trị hỗ trợ quản lý sân, khách hàng, lịch đặt và doanh thu.

Điểm nhấn kỹ thuật của đồ án là **hệ thống AI gợi ý thông minh**, sử dụng thông tin về lịch sử đặt sân, sở thích của người dùng, loại sân, khung giờ, mức giá và các yếu tố ngoại cảnh như **thời tiết, ngày lễ, cuối tuần** để đưa ra các gợi ý sân và khung giờ phù hợp. Hệ thống có khả năng học từ hành vi sử dụng của người dùng để từng bước cải thiện mức độ phù hợp của các đề xuất.

Ứng dụng được phát triển bằng **Flutter** theo hướng đa nền tảng, kết hợp với hệ thống Backend và cơ sở dữ liệu để quản lý dữ liệu tập trung. Thành phần AI được tích hợp thông qua API nhằm cung cấp chức năng phân tích và gợi ý cho người dùng.

**CÁC MỤC TIÊU CHÍNH**

**1\. Phân tích và thiết kế hệ thống:** 

Xác định các yêu cầu chức năng và phi chức năng; phân tích quy trình đặt sân thể thao; thiết kế cơ sở dữ liệu gồm sân thể thao, khách hàng, lịch đặt, bảng giá, thanh toán và dữ liệu phục vụ Machine Learning; thiết kế kiến trúc tổng thể và phân quyền người dùng.

Hệ thống dự kiến có các nhóm người dùng:

* Quản trị viên.

* Nhân viên quản lý sân.

* Khách hàng.

**2\. Xây dựng module quản lý sân thể thao:** 

Xây dựng chức năng thêm, sửa, xóa và cập nhật thông tin sân; quản lý loại sân, trạng thái sân, giá sân và khung giờ hoạt động.

Hệ thống hỗ trợ theo dõi trạng thái sân như:

* Đang trống.

* Đã được đặt.

* Đang sử dụng.

* Tạm ngừng hoạt động.

**3\. Xây dựng hệ thống đặt sân trực tuyến:** 

Cho phép khách hàng tìm kiếm sân, xem lịch trống, lựa chọn ngày và khung giờ, thực hiện đặt sân và theo dõi trạng thái đặt sân.

Xây dựng quy trình xử lý đặt sân nhằm hạn chế tình trạng trùng lịch hoặc nhiều người cùng đặt một khung giờ.

**4\. Xây dựng module quản lý khách hàng và thanh toán:** 

Quản lý thông tin tài khoản khách hàng, lịch sử đặt sân và trạng thái thanh toán.

Hệ thống có thể hỗ trợ các phương thức thanh toán như:

* Thanh toán trực tiếp.

* Chuyển khoản qua mã QR ngân hàng.

Quản trị viên có thể kiểm tra và xác nhận trạng thái thanh toán của đơn đặt sân.

**5\. Xây dựng mô hình Machine Learning dự báo nhu cầu sử dụng sân:** 

Thu thập và xử lý dữ liệu lịch sử đặt sân để xây dựng tập dữ liệu huấn luyện.

Các thuộc tính đầu vào có thể bao gồm:

* Ngày đặt sân.

* Thứ trong tuần.

* Khung giờ.

* Loại sân.

* Giá sân.

* Số lượt đặt trong các khoảng thời gian trước đó.

* Các yếu tố ngoại cảnh khác(thời tiết, dịp lễ,…).

Mô hình Machine Learning được sử dụng để dự báo số lượt đặt sân hoặc mức độ nhu cầu sử dụng sân trong một ngày hoặc khung giờ cụ thể.

Thực hiện đánh giá mô hình bằng các chỉ số phù hợp và lựa chọn mô hình có kết quả dự báo phù hợp với tập dữ liệu.

**6\. Xây dựng dashboard thống kê và hỗ trợ ra quyết định:** 

Hiển thị các thông tin thống kê về:

* Số lượt đặt sân.

* Doanh thu.

* Tỷ lệ sử dụng sân.

* Khung giờ cao điểm.

* Khung giờ thấp điểm.

* Xu hướng đặt sân theo ngày/tuần/tháng.

* Kết quả dự báo nhu cầu sử dụng sân.

Kết quả Machine Learning được trực quan hóa bằng biểu đồ và bảng thống kê nhằm hỗ trợ người quản lý trong việc đưa ra quyết định vận hành.

**NỘI DUNG CHÍNH**

**1\. Nghiên cứu cơ sở lý thuyết**

Nghiên cứu mô hình hệ thống quản lý và đặt sân thể thao trực tuyến, kiến trúc ứng dụng đa nền tảng và các phương pháp xây dựng hệ thống quản lý đặt lịch.

Nghiên cứu các khái niệm cơ bản về hệ thống gợi ý và AI, phương pháp phân tích dữ liệu người dùng, lịch sử đặt sân và các yếu tố liên quan để đưa ra gợi ý sân và khung giờ phù hợp.

Nghiên cứu các yếu tố ngoại cảnh có thể được sử dụng trong hệ thống gợi ý như thời tiết, ngày lễ, cuối tuần và khung giờ

Nghiên cứu các công nghệ sử dụng trong quá trình xây dựng ứng dụng như:

* **Flutter:** Framework phát triển ứng dụng đa nền tảng cho Android và iOS. 

* **Dart:** Ngôn ngữ lập trình sử dụng để phát triển ứng dụng Flutter. 

* **Flutter UI & Material Design:** Xây dựng giao diện và các thành phần tương tác trên ứng dụng. 

* **State Management:** Quản lý trạng thái và dữ liệu trong ứng dụng Flutter. 

* **REST API:** Kết nối ứng dụng Flutter với hệ thống Backend và cơ sở dữ liệu. 

* **Firebase:** Hỗ trợ xác thực người dùng, thông báo và các dịch vụ liên quan nếu được sử dụng. 

* **SQLite:** Lưu trữ dữ liệu cục bộ trên thiết bị phục vụ các chức năng phù hợp. 

* **AI Recommendation:** Xây dựng và tích hợp hệ thống gợi ý sân, khung giờ dựa trên thông tin người dùng và dữ liệu đặt sân. 

* **API thời tiết:** Cung cấp dữ liệu thời tiết để hỗ trợ hệ thống gợi ý sân phù hợp. 

* **Git/GitHub:** Quản lý mã nguồn và quá trình phát triển ứng dụng.

**2\. Phân tích và thiết kế hệ thống**

Xác định yêu cầu chức năng và phi chức năng của hệ thống.

Thiết kế cơ sở dữ liệu bao gồm:

* Người dùng.

* Khách hàng.

* Sân thể thao.

* Loại sân.

* Khung giờ.

* Bảng giá.

* Đơn đặt sân.

* Chi tiết đặt sân.

* Thanh toán.

* Dữ liệu lịch sử phục vụ Machine Learning.

Thiết kế kiến trúc tổng thể của hệ thống và phân quyền người dùng.

Xây dựng các sơ đồ:

* Use Case Diagram.

* ERD.

* Activity Diagram.

* Sequence Diagram.

* Class Diagram.

**3\. Xây dựng các module nghiệp vụ chính**

**Xây dựng các module nghiệp vụ chính**

**Module quản lý sân thể thao**

* Thêm/sửa/xóa sân.

* Quản lý loại sân.

* Quản lý trạng thái sân.

* Quản lý giá sân.

* Quản lý khung giờ hoạt động.

**Module đặt sân**

* Tìm kiếm sân.

* Xem lịch sân.

* Kiểm tra sân còn trống.

* Đặt sân.

* Hủy đặt sân.

* Theo dõi trạng thái đặt sân.

* Xem lịch sử đặt sân.

**Module khách hàng**

* Đăng ký tài khoản.

* Đăng nhập.

* Cập nhật thông tin cá nhân.

* Xem lịch sử đặt sân.

* Theo dõi trạng thái đơn đặt sân.

**Module thanh toán**

* Thanh toán trực tiếp.

* Thanh toán chuyển khoản QR.

* Quản lý trạng thái thanh toán.

* Xác nhận giao dịch.

**Module quản trị và thống kê**

* Quản lý người dùng.

* Quản lý sân.

* Quản lý đơn đặt sân.

* Quản lý thanh toán.

* Thống kê doanh thu.

* Thống kê số lượt đặt sân.

* Thống kê hiệu suất sử dụng sân.

**4\. Xây dựng mô hình Machine Learning dự báo nhu cầu sân**

Thu thập dữ liệu lịch sử đặt sân từ hệ thống và bổ sung các dữ liệu ngoại cảnh có liên quan đến nhu cầu sử dụng sân.

Dữ liệu được tổ chức theo ngày và khung giờ, bao gồm:

**Dữ liệu hệ thống:**

* Ngày và giờ.

* Thứ trong tuần.

* Loại sân.

* Giá sân.

* Số lượt đặt.

* Số lượt hủy.

* Tỷ lệ sử dụng sân.

**Dữ liệu ngoại cảnh:**

* Nhiệt độ.

* Lượng mưa.

* Trạng thái thời tiết.

* Ngày lễ và kỳ nghỉ.

* Cuối tuần.

* Sự kiện thể thao hoặc sự kiện đặc biệt.

* Chương trình khuyến mãi.

Tiến hành làm sạch dữ liệu, xử lý dữ liệu thiếu, mã hóa các biến phân loại và xây dựng các đặc trưng phù hợp cho mô hình.

Sau đó tiến hành huấn luyện và so sánh một số mô hình Machine Learning như Random Forest, Gradient Boosting và XGBoost.

Mô hình được đánh giá bằng các chỉ số MAE, RMSE và R².

Kết quả dự báo được tích hợp vào hệ thống thông qua API và hiển thị trên dashboard.

**5\. Tích hợp Machine Learning vào hệ thống**

Thu thập, tổng hợp và xử lý dữ liệu lịch sử đặt sân kết hợp với các yếu tố ngoại cảnh có khả năng ảnh hưởng đến nhu cầu sử dụng sân thể thao.

Các nhóm dữ liệu đầu vào dự kiến bao gồm:

* **Thông tin thời gian:** ngày, tháng, thứ trong tuần, khung giờ.

* **Thông tin sân:** loại sân, số lượng sân, giá sân.

* **Dữ liệu lịch sử:** số lượt đặt sân, tỷ lệ sử dụng sân, số lượt hủy.

* **Yếu tố thời tiết:** nhiệt độ, lượng mưa, trạng thái thời tiết như nắng, nhiều mây, mưa.

* **Ngày lễ và kỳ nghỉ:** ngày lễ, Tết, kỳ nghỉ dài ngày và cuối tuần.

* **Sự kiện đặc biệt:** các sự kiện thể thao, giải đấu hoặc hoạt động có khả năng ảnh hưởng đến nhu cầu sử dụng sân.

* **Các yếu tố khác:** chương trình khuyến mãi hoặc thay đổi giá sân nếu có dữ liệu.

Thực hiện tiền xử lý dữ liệu, lựa chọn đặc trưng và xây dựng tập dữ liệu phục vụ huấn luyện mô hình.

Nghiên cứu và thử nghiệm một số thuật toán Machine Learning như:

* Linear Regression.

* Random Forest.

* Gradient Boosting.

* XGBoost.

Mô hình được sử dụng để dự báo **số lượt đặt sân hoặc mức độ nhu cầu sử dụng sân** theo ngày, khung giờ và loại sân.

Kết quả dự báo được đánh giá bằng các chỉ số phù hợp như MAE, RMSE và R², từ đó lựa chọn mô hình phù hợp để tích hợp vào hệ thống.

**6\. Xây dựng dashboard hỗ trợ quản lý**

Dashboard cung cấp các biểu đồ:

* Số lượt đặt sân theo ngày.

* Số lượt đặt theo khung giờ.

* Doanh thu theo thời gian.

* Tỷ lệ sử dụng từng sân.

* So sánh nhu cầu thực tế và nhu cầu dự báo.

* Dự báo nhu cầu trong các ngày tiếp theo.

Dựa trên kết quả dự báo, hệ thống có thể đưa ra các thông tin hỗ trợ quản lý như:

* Xác định khung giờ cao điểm.

* Xác định khung giờ thấp điểm.

* Hỗ trợ phân bổ sân.

* Hỗ trợ xây dựng chương trình khuyến mãi.

* Hỗ trợ tối ưu hiệu quả khai thác sân.

**7\. Triển khai hệ thống:** 

Đóng gói ứng dụng bằng Docker.

Xây dựng môi trường triển khai gồm:

* Laravel Backend.

* Vue 3 Frontend.

* PostgreSQL Database.

* Python Machine Learning API.

Có thể xây dựng pipeline CI/CD trên GitLab và triển khai hệ thống trên nền tảng cloud phù hợp.

**8\. Kiểm thử và hoàn thiện**

Thực hiện kiểm thử:

* Chức năng đăng nhập.

* Quản lý sân.

* Đặt sân.

* Hủy sân.

* Thanh toán.

* Quản lý đơn đặt sân.

* Phân quyền.

* API Machine Learning.

* Kết quả dự báo.

Sửa lỗi, tối ưu hệ thống và hoàn thiện tài liệu hướng dẫn sử dụng.

**KẾT QUẢ DỰ KIẾN**

**1\. Lý thuyết:**

*  Nắm vững quy trình phân tích, thiết kế và xây dựng hệ thống quản lý đặt sân thể thao trực tuyến.  
* Hiểu được quy trình quản lý lịch đặt sân, sân thể thao, khách hàng và thanh toán.  
* Nắm được các bước cơ bản trong quy trình xây dựng một mô hình Machine Learning.  
* Hiểu phương pháp xử lý dữ liệu lịch sử đặt sân và xây dựng tập dữ liệu phục vụ dự báo.  
*  Hiểu và áp dụng một số thuật toán Machine Learning cho bài toán dự báo nhu cầu.  
* Hiểu phương pháp đánh giá và so sánh kết quả của các mô hình dự báo.  
* Hoàn thiện báo cáo đồ án với đầy đủ các sơ đồ thiết kế, kết quả thực nghiệm, kiểm thử và tài liệu hướng dẫn.

**2\. Thực nghiệm:**

* Website đặt sân hoạt động đầy đủ với các chức năng quản lý sân, khách hàng, lịch đặt và thanh toán.  
* Khách hàng có thể tìm kiếm, xem lịch trống và đặt sân trực tuyến.  
* Quản trị viên có thể quản lý sân, đơn đặt sân, khách hàng và doanh thu.  
* Hệ thống có dashboard thống kê trực quan.  
* Mô hình Machine Learning có khả năng dự báo nhu cầu sử dụng sân dựa trên dữ liệu lịch sử.  
* Kết quả dự báo được tích hợp và hiển thị trực tiếp trên website.  
* Hệ thống có khả năng cung cấp thông tin hỗ trợ quản lý về khung giờ có nhu cầu cao và thấp.  
* Hệ thống được đóng gói và triển khai thử nghiệm trên môi trường cloud.  
* Vượt qua các bài kiểm thử chức năng cốt lõi và đảm bảo cơ chế xác thực, phân quyền người dùng

**KẾ HOẠCH THỰC HIỆN**

| TT | Thời gian | Nội dung công việc | Kết quả dự kiến đạt được |
| :---: | :---: | :---- | :---- |
| 1 | Tuần 1 \- 3 | \- Khảo sát, phân tích yêu cầu và xác định phạm vi đề tài. \- Nghiên cứu nghiệp vụ đặt sân thể thao. \- Nghiên cứu cơ sở lý thuyết Machine Learning và bài toán dự báo nhu cầu. \- Thiết kế cơ sở dữ liệu và kiến trúc tổng thể. | \- Tài liệu đặc tả yêu cầu và phạm vi đồ án. \- Sơ đồ Use Case. \- Sơ đồ ERD. \- Kiến trúc tổng thể hệ thống. |
| 2 | Tuần 4 \- 9 | \- Xây dựng Backend Laravel. \- Xây dựng giao diện Vue 3\. \- Xây dựng module quản lý sân. \- Xây dựng module khách hàng. \- Xây dựng module đặt sân. \- Xây dựng quản lý thanh toán và đơn đặt sân. | \- Các module nghiệp vụ chính hoạt động. \- Hoàn thành luồng đặt sân cơ bản. \- Cơ sở dữ liệu hoàn chỉnh. |
| 3 | Tuần 10 \- 12 | \- Thu thập và xử lý dữ liệu lịch sử đặt sân. \- Phân tích dữ liệu. \- Xây dựng và huấn luyện các mô hình Machine Learning. \- Đánh giá và lựa chọn mô hình phù hợp. | \- Bộ dữ liệu huấn luyện. \- Mô hình Machine Learning. \- Kết quả đánh giá mô hình. |
| 4 | Tuần 13 \- 14 | \- Xây dựng API Machine Learning. \- Tích hợp mô hình dự báo vào hệ thống. \- Xây dựng dashboard thống kê và dự báo. | \- API dự báo hoạt động. \- Website hiển thị kết quả dự báo. \- Dashboard hoàn chỉnh. |
| 5 | Tuần 15 | \- Kiểm thử toàn bộ hệ thống. \- Sửa lỗi và tối ưu. \- Đóng gói và triển khai thử nghiệm. \- Hoàn thiện báo cáo, slide và hồ sơ bảo vệ. | \- Hệ thống hoàn chỉnh, sẵn sàng demo. \- Mô hình dự báo hoạt động ổn định. \- Báo cáo và slide hoàn chỉnh. |

**TÀI LIỆU THAM KHẢO** 

 \[1\] Google, *Flutter Documentation*, 2026\. [Flutter Documentation](https://docs.flutter.dev/)

\[2\] Google, *Dart Documentation*, 2026\. [Dart Documentation](https://dart.dev/docs)

\[3\] Google, *Firebase Documentation*, 2026\. [Firebase Documentation](https://firebase.google.com/docs/firestore)

\[4\] Google, *Cloud Firestore Documentation*, 2026\. [Cloud Firestore Documentation](https://firebase.google.com/docs/firestore)

\[5\] Google, *Firebase Authentication Documentation*, 2026\. [Firebase Authentication Documentation](https://firebase.google.com/docs/auth)

\[6\] Google, *Firebase Cloud Functions Documentation*, 2026\. [Cloud Functions Documentation](https://firebase.google.com/docs/functions)

\[7\] Google, *Firebase AI Logic Documentation*, 2026\. [Firebase AI Logic Documentation](https://firebase.google.com/docs/ai-logic)

\[8\] Google, *Gemini API Documentation*, 2026\. [Gemini API Documentation](https://ai.google.dev/gemini-api/docs)

\[9\] Google, *Firebase for Flutter Documentation*, 2026\. [Firebase for Flutter Documentation](https://firebase.google.com/docs/flutter)

\[10\] GitHub, *GitHub Actions Documentation*, 2026\. [GitHub Actions Documentation](https://docs.github.com/en/actions)

\[11\] Google, *Firebase Cloud Messaging Documentation*, 2026\. [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)

\[12\] Google, *Firebase Storage Documentation*, 2026\. [Firebase Storage Documentation](https://firebase.google.com/docs)

[image1]: <data:image/png;base64,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>