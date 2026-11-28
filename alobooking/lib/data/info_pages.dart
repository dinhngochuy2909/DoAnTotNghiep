import 'package:flutter/material.dart';

/// Các trang thông tin mở từ chân trang. Mọi câu ở đây mô tả đúng cách ứng dụng đang vận hành
/// (đặt sân, thanh toán VietQR, hủy đơn, duyệt sân, dữ liệu lưu trữ); không có quy định nào được tự đặt thêm.
/// Quy định thuộc về chủ sân (ví dụ hoàn tiền) được ghi rõ là do chủ sân quyết định.
enum InfoPageId { about, guide, faq, owners, terms, privacy, payments }

/// Một mục có tiêu đề, gồm đoạn văn và/hoặc danh sách gạch đầu dòng (hoặc đánh số).
class InfoSection {
  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;

  /// true: danh sách đánh số 1, 2, 3... (các bước); false: gạch đầu dòng.
  final bool numbered;

  const InfoSection(this.heading, {this.paragraphs = const [], this.bullets = const [], this.numbered = false});
}

class FaqItem {
  final String question;
  final String answer;
  const FaqItem(this.question, this.answer);
}

class InfoPage {
  final InfoPageId id;
  final String title;
  final IconData icon;
  final String intro;
  final List<InfoSection> sections;
  final List<FaqItem> faq;

  /// Dòng ghi chú nhỏ dưới tiêu đề, ví dụ ngày cập nhật.
  final String note;

  const InfoPage({
    required this.id,
    required this.title,
    required this.icon,
    required this.intro,
    this.sections = const [],
    this.faq = const [],
    this.note = '',
  });
}

class InfoPages {
  InfoPages._();

  /// Ngày cập nhật nội dung các trang điều khoản/chính sách.
  static const updated = 'Cập nhật lần cuối: 21/11/2026';

  static const about = InfoPage(
    id: InfoPageId.about,
    title: 'Giới thiệu AloBooking',
    icon: Icons.info_outline_rounded,
    intro: 'AloBooking là nền tảng đặt sân thể thao trực tuyến cho người chơi tại Hà Nội: tìm sân, xem giá và khung giờ trống, '
        'đặt sân rồi thanh toán bằng chuyển khoản ngay trên một ứng dụng.',
    sections: [
      InfoSection('Bạn làm được gì với AloBooking', bullets: [
        'Tìm sân cầu lông, pickleball, bóng đá, tennis, bóng rổ theo môn, theo tên hoặc theo quận.',
        'Xem sân trên bản đồ, đọc giá, giờ mở cửa, tiện ích và đánh giá của khách.',
        'Chọn sân con và khung giờ còn trống trên sơ đồ đặt sân, thanh toán bằng chuyển khoản VietQR.',
        'Theo dõi và hủy lượt đặt trong mục "Sân đã đặt".',
        'Hỏi trợ lý AI để tra cứu sân theo nhu cầu của bạn.',
        'Xem bảng tin Khám phá: tin mới của AloBooking, sân mới được duyệt và đánh giá mới của khách.',
      ]),
      InfoSection('Dữ liệu sân đến từ đâu', paragraphs: [
        'Sân trên AloBooking có ba nguồn và luôn được ghi chú rõ:',
      ], bullets: [
        'Sân do chủ sân đăng và được ban quản lý duyệt: giá và giờ mở cửa do chủ sân niêm yết.',
        'Địa điểm lấy từ dữ liệu mở (OpenStreetMap, Overture Maps): giá, giờ mở cửa và số sân chỉ là mức tham khảo, hãy liên hệ sân để xác nhận.',
        'Sân minh họa (Demo): chỉ để trình diễn ứng dụng, không phải cơ sở có thật nên không nhận đặt hay thanh toán.',
      ]),
      InfoSection('Về hình ảnh', paragraphs: [
        'Sân chưa có ảnh thật được hiển thị bằng ảnh minh họa từ Pexels và Unsplash, luôn kèm nhãn "Ảnh minh họa". '
            'Khi chủ sân đăng ảnh thật, nhãn này sẽ biến mất.',
      ]),
    ],
  );

  static const guide = InfoPage(
    id: InfoPageId.guide,
    title: 'Hướng dẫn đặt sân',
    icon: Icons.menu_book_outlined,
    intro: 'Đặt một sân chỉ mất vài bước. Bạn cần đăng nhập để đặt sân; chế độ khách chỉ để xem.',
    sections: [
      InfoSection('Các bước đặt sân', numbered: true, bullets: [
        'Đăng nhập. Chưa có tài khoản thì đăng ký bằng họ tên, email, số điện thoại và mật khẩu.',
        'Tìm sân bằng ô tìm kiếm, bộ lọc theo môn ở trang chủ hoặc mở Bản đồ.',
        'Mở sân bạn chọn để xem giá, giờ mở cửa, tiện ích, hình ảnh và đánh giá, rồi bấm "ĐẶT LỊCH NGAY".',
        'Chọn ngày, sau đó chạm vào các ô trắng trên bảng để chọn sân con và khung giờ. Ô đã có người đặt, đang khóa hoặc bảo trì, hay đang có sự kiện thì không chọn được.',
        'Kiểm tra tổng số giờ và tổng tiền rồi xác nhận. Đơn được ghi nhận ở trạng thái "Chờ xác nhận".',
        'Chuyển khoản theo mã VietQR với đúng số tiền và nội dung chuyển khoản của đơn. Ban quản lý xác nhận đơn khi nhận được tiền.',
        'Theo dõi đơn trong mục "Sân đã đặt" (Tất cả, Sắp diễn ra, Đã hoàn tất, Đã hủy).',
      ]),
      InfoSection('Lưu ý', bullets: [
        'Giờ vàng là ca 16:00 – 22:00, giá cao hơn một chút so với giờ thường.',
        'Sân chưa niêm yết giá thì chưa nhận đặt online, hãy liên hệ sân.',
        'Nếu có người vừa đặt trùng khung giờ bạn chọn, hệ thống sẽ báo để bạn chọn lại giờ trống.',
        'Sân minh họa (Demo) không nhận đặt.',
      ]),
    ],
  );

  static const faq = InfoPage(
    id: InfoPageId.faq,
    title: 'Câu hỏi thường gặp',
    icon: Icons.help_outline_rounded,
    intro: 'Những câu hỏi người chơi hay hỏi nhất. Bấm vào câu hỏi để xem trả lời.',
    faq: [
      FaqItem('Tôi có thể trả tiền mặt tại sân không?',
          'Với lượt đặt qua AloBooking, thanh toán chỉ bằng chuyển khoản ngân hàng qua mã VietQR, không nhận tiền mặt.'),
      FaqItem('Làm sao biết đơn của tôi đã được xác nhận?',
          'Đơn ở trạng thái "Chờ xác nhận" cho tới khi chủ sân (hoặc ban quản lý AloBooking với sân do AloBooking quản lý) nhận được tiền chuyển khoản đúng số tiền và nội dung. Bạn xem trạng thái trong mục "Sân đã đặt".'),
      FaqItem('Tôi muốn hủy lượt đặt thì làm thế nào?',
          'Vào "Sân đã đặt", chọn đơn đang chờ xác nhận hoặc sắp diễn ra rồi bấm "Hủy đặt sân". '
              'Việc hoàn tiền (nếu có) do chủ sân xử lý theo chính sách của sân.'),
      FaqItem('Vì sao tôi không đặt được một số sân?',
          'Có ba lý do thường gặp: bạn chưa đăng nhập (chế độ khách chỉ xem), sân chưa niêm yết giá nên chưa nhận đặt online, '
              'hoặc đó là sân minh họa (Demo) chỉ để trình diễn.'),
      FaqItem('Giờ vàng là gì?',
          'Là ca 16:00 – 22:00 với mức giá cao hơn một chút so với giờ thường. Màn đặt sân ghi riêng giá giờ vàng và giá giờ thường.'),
      FaqItem('Ảnh sân có phải ảnh thật không?',
          'Ảnh có nhãn "Ảnh minh họa" lấy từ Pexels và Unsplash, không phải ảnh thật của sân. Ảnh do chủ sân đăng thì không có nhãn này.'),
      FaqItem('Giá và giờ mở cửa của sân lấy từ dữ liệu mở có chính xác không?',
          'Đó chỉ là mức tham khảo từ OpenStreetMap hoặc Overture Maps, chưa được cơ sở xác nhận. Hãy liên hệ sân trước khi đến.'),
      FaqItem('Trợ lý AI có luôn đúng không?',
          'Trợ lý tra danh sách sân và lịch đặt hiện có rồi mới trả lời, nhưng vẫn có thể sai sót. Hãy kiểm tra lại giá và giờ trống ở trang sân trước khi đặt.'),
      FaqItem('Tôi là chủ sân, làm sao đưa sân lên AloBooking?',
          'Xem mục "Dành cho chủ sân" ở cuối trang: bạn đăng sân, ban quản lý duyệt, rồi sân hiển thị công khai.'),
    ],
  );

  static const owners = InfoPage(
    id: InfoPageId.owners,
    title: 'Dành cho chủ sân',
    icon: Icons.stadium_outlined,
    intro: 'Dành cho chủ cụm sân muốn đưa sân lên AloBooking và nhận đặt online.',
    sections: [
      InfoSection('Cách đưa sân lên', numbered: true, bullets: [
        'Tài khoản đăng ký mới có vai trò khách hàng. Quyền chủ sân do ban quản lý cấp, hãy liên hệ ban quản lý để được cấp.',
        'Đăng sân mới: nhập tên, môn, quận, địa chỉ, giá thuê, giờ hoạt động, số sân con, tiện ích và ảnh.',
        'Sân mới ở trạng thái "Chờ duyệt". Ban quản lý kiểm tra rồi duyệt hoặc từ chối (kèm lý do).',
        'Sau khi được duyệt, sân hiển thị công khai, nhận đặt online và xuất hiện ở bảng tin Khám phá mục "Sân mới".',
      ]),
      InfoSection('Quản lý sân của bạn', bullets: [
        'Xem lịch đặt và doanh thu của sân mình trong mục "Quản Lý Sân" và "Doanh Thu".',
        'Thay ảnh minh họa bằng ảnh thật của sân; khi đó nhãn "Ảnh minh họa" biến mất.',
        'Nhập giá dạng "100k - 200k/h" để sân nhận đặt online. Nếu để "Liên hệ" thì khách chưa đặt online được.',
        'Khi khách hủy đơn, việc hoàn tiền (nếu có) do chủ sân xử lý theo chính sách của sân.',
      ]),
    ],
  );

  static const terms = InfoPage(
    id: InfoPageId.terms,
    title: 'Điều khoản sử dụng',
    icon: Icons.gavel_rounded,
    intro: 'Khi sử dụng AloBooking, bạn đồng ý với các điều khoản dưới đây. Nội dung mô tả cách ứng dụng đang vận hành ở giai đoạn hiện tại.',
    note: updated,
    sections: [
      InfoSection('Tài khoản', bullets: [
        'Cung cấp thông tin chính xác khi đăng ký (họ tên, email, số điện thoại).',
        'Tự bảo quản mật khẩu; mọi thao tác từ tài khoản của bạn được coi là do bạn thực hiện.',
        'Chế độ khách chỉ để xem sân, không đặt sân được.',
      ]),
      InfoSection('Đặt sân và thanh toán', bullets: [
        'Thanh toán bằng chuyển khoản ngân hàng, không nhận tiền mặt.',
        'Đơn chỉ được xác nhận khi chủ sân (hoặc ban quản lý AloBooking với sân do AloBooking quản lý) nhận được tiền đúng số tiền và nội dung chuyển khoản.',
        'Mỗi khung giờ của một sân chỉ có một người đặt.',
        'Giá do chủ sân niêm yết. Với địa điểm lấy từ dữ liệu mở, giá chỉ là mức tham khảo.',
      ]),
      InfoSection('Nội dung bạn đăng', bullets: [
        'Đánh giá phải trung thực, dựa trên trải nghiệm của chính bạn. Họ tên và nội dung đánh giá hiển thị công khai.',
        'Không đăng nội dung sai sự thật, xúc phạm người khác hoặc vi phạm pháp luật.',
      ]),
      InfoSection('Trợ lý AI', paragraphs: [
        'Trợ lý trả lời dựa trên dữ liệu sân và lịch đặt hiện có nhưng có thể chưa chính xác. '
            'Hãy kiểm tra lại giá và giờ trống ở trang sân trước khi đặt.',
      ]),
      InfoSection('Dữ liệu và hình ảnh của bên thứ ba', paragraphs: [
        'Một phần dữ liệu vị trí sân: © OpenStreetMap contributors (giấy phép ODbL), © Overture Maps Foundation (giấy phép CDLA-Permissive-2.0). '
            'Ảnh minh họa các môn thể thao: Pexels, Unsplash.',
      ]),
      InfoSection('Thay đổi điều khoản', paragraphs: [
        'Điều khoản có thể được cập nhật khi ứng dụng thay đổi. Ngày cập nhật gần nhất ghi ở đầu trang.',
      ]),
    ],
  );

  static const privacy = InfoPage(
    id: InfoPageId.privacy,
    title: 'Chính sách bảo mật',
    icon: Icons.lock_outline_rounded,
    intro: 'Trang này nói rõ AloBooking lưu những gì về bạn, lưu ở đâu và dùng vào việc gì.',
    note: updated,
    sections: [
      InfoSection('Dữ liệu được lưu', bullets: [
        'Thông tin tài khoản: họ tên, email, số điện thoại. Mật khẩu được mã hóa (băm) trước khi lưu, không lưu dạng chữ thường.',
        'Lịch sử đặt sân và trạng thái thanh toán của từng đơn.',
        'Đánh giá bạn gửi, kèm họ tên của bạn và hiển thị công khai.',
        'Thông báo gửi tới tài khoản của bạn.',
      ]),
      InfoSection('Lưu ở đâu', paragraphs: [
        'Dữ liệu được lưu trên Google Cloud Firestore.',
      ]),
      InfoSection('Dùng vào việc gì', paragraphs: [
        'Tạo tài khoản và đăng nhập, xử lý đặt sân, đối soát thanh toán, hiển thị đánh giá, thống kê cho chủ sân và ban quản lý. '
            'Chủ sân và ban quản lý chỉ xem những thông tin về đơn đặt cần thiết để phục vụ bạn.',
      ]),
      InfoSection('Dịch vụ của bên thứ ba', bullets: [
        'Trợ lý AI: câu hỏi của bạn cùng dữ liệu sân liên quan được gửi tới Google Gemini để tạo câu trả lời.',
        'Bản đồ dùng ảnh nền OpenStreetMap, tải từ máy chủ của OpenStreetMap. Nếu bạn dùng chức năng định vị trên bản đồ, trình duyệt sẽ hỏi quyền vị trí và bạn có thể từ chối.',
        'Ảnh minh họa được tải từ Pexels và Unsplash.',
      ]),
      InfoSection('Quyền của bạn', paragraphs: [
        'Bạn có thể yêu cầu ban quản lý cho xem, sửa hoặc xóa dữ liệu tài khoản của mình qua mục "Liên hệ & Hỗ trợ" ở cuối trang.',
      ]),
    ],
  );

  static const payments = InfoPage(
    id: InfoPageId.payments,
    title: 'Thanh toán & hủy sân',
    icon: Icons.qr_code_2_rounded,
    intro: 'Cách thanh toán một lượt đặt sân, và việc cần làm khi bạn muốn hủy.',
    note: updated,
    sections: [
      InfoSection('Thanh toán', bullets: [
        'AloBooking chỉ nhận chuyển khoản ngân hàng qua mã VietQR (chuẩn NAPAS 247), không nhận tiền mặt.',
        'Sau khi xác nhận đặt, bạn nhận mã QR kèm số tiền và nội dung chuyển khoản. Hãy chuyển đúng số tiền và nội dung để đơn được đối soát.',
        'Đơn ở trạng thái "Chờ xác nhận" cho tới khi chủ sân (hoặc ban quản lý AloBooking với sân do AloBooking quản lý) nhận được tiền.',
        'Nếu hệ thống chưa tạo được mã QR, hãy liên hệ ban quản lý để nhận thông tin chuyển khoản cho đơn của bạn.',
      ]),
      InfoSection('Giá', paragraphs: [
        'Giá giờ thường và giá giờ vàng (16:00 – 22:00) được ghi ở màn đặt sân. Tổng tiền hiển thị trước khi bạn xác nhận.',
      ]),
      InfoSection('Hủy đặt sân', bullets: [
        'Vào "Sân đã đặt", chọn đơn đang chờ xác nhận hoặc sắp diễn ra và bấm "Hủy đặt sân". Đơn chuyển sang "Đã hủy".',
        'Việc hoàn tiền (nếu có) do chủ sân xử lý theo chính sách của sân. AloBooking chưa hoàn tiền tự động.',
      ]),
      InfoSection('Chuyển khoản sai', paragraphs: [
        'Nếu bạn chuyển sai số tiền hoặc nội dung, hãy liên hệ ban quản lý qua mục "Liên hệ & Hỗ trợ" ở cuối trang, kèm mã đơn (dạng BK-123456) để được đối soát.',
      ]),
    ],
  );

  static const List<InfoPage> all = [about, guide, faq, owners, terms, privacy, payments];

  static InfoPage of(InfoPageId id) => all.firstWhere((p) => p.id == id);
}
