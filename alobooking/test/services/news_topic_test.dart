import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/data/venue_photos.dart';
import 'package:alobooking/services/news_feed.dart';
import 'package:alobooking/services/news_topic.dart';
import 'package:alobooking/widgets/news_visuals.dart';

NewsEntry _sport(String id, String title, {String body = '', String imageUrl = '', NewsKind kind = NewsKind.sport}) => NewsEntry(
      id: id,
      kind: kind,
      title: title,
      body: body,
      imageUrl: imageUrl,
      time: DateTime(2026, 11, 24, 8),
      byline: 'VnExpress',
      sourceName: 'VnExpress',
      sourceUrl: 'https://vnexpress.net/bai-viet.html',
    );

void main() {
  group('NewsTopic.sportOf: nhận ra môn từ tiêu đề', () {
    test('mỗi môn nhận đúng, không phân biệt dấu và hoa thường', () {
      expect(NewsTopic.sportOf('Quần vợt TP.HCM lập cú đúp HCV'), 'tennis');
      expect(NewsTopic.sportOf('Sinner vô địch ATP Finals'), 'tennis');
      expect(NewsTopic.sportOf('Giải PICKLEBALL toàn quốc khai mạc'), 'pickleball');
      expect(NewsTopic.sportOf('Tay vợt cầu lông Việt Nam thắng ngược'), 'badminton');
      expect(NewsTopic.sportOf('Hà Nội Buffaloes thắng ở giải bóng rổ chuyên nghiệp'), 'basketball');
      expect(NewsTopic.sportOf('V-League vòng 10: derby Thủ đô'), 'football');
      expect(NewsTopic.sportOf('Đội tuyển bóng đá nữ Việt Nam tập trung'), 'football');
    });

    test('tin không rõ môn (đua xe đạp, điền kinh...) thì trả về null, không gán đại', () {
      expect(NewsTopic.sportOf('Cua-rơ dừng trước vạch đích để nhường đồng đội ở Đại hội Thể thao toàn quốc'), isNull);
      expect(NewsTopic.sportOf('Kình ngư lập kỷ lục mới'), isNull);
      expect(NewsTopic.sportOf(''), isNull);
    });

    test('chỉ khớp nguyên từ: "atp" nằm trong từ khác không bị nhận nhầm', () {
      expect(NewsTopic.sportOf('Các vận động viên chatpt tập luyện'), isNull);
    });

    test('môn đặc thù được ưu tiên hơn "bóng đá"', () {
      expect(NewsTopic.sportOf('Quần vợt và bóng đá cùng thu hút khán giả'), 'tennis');
    });
  });

  group('newsCoverUrl cho tin thể thao không kèm ảnh', () {
    test('tin rõ môn dùng ảnh minh họa đúng môn, ổn định giữa các lần gọi', () {
      final e = _sport('rss_1', 'Quần vợt TP.HCM lập cú đúp HCV');
      final url = newsCoverUrl(e, null);
      expect(url, isNotEmpty);
      expect(VenuePhotos.isStock(url), isTrue);
      expect(VenuePhotos.forSport('tennis').contains(url), isTrue);
      expect(newsCoverUrl(e, null), url, reason: 'cùng một tin phải luôn ra cùng một ảnh');
    });

    test('tin không rõ môn giữ nền chuyển sắc (không có ảnh)', () {
      expect(newsCoverUrl(_sport('rss_2', 'Cua-rơ dừng trước vạch đích'), null), isEmpty);
    });

    test('tin có ảnh riêng thì ưu tiên ảnh đó; tin loại khác không tự gán ảnh môn; đánh giá không có bìa', () {
      expect(newsCoverUrl(_sport('p1', 'Quần vợt', imageUrl: 'https://example.com/a.jpg'), null), 'https://example.com/a.jpg');
      expect(newsCoverUrl(_sport('p2', 'Quần vợt', kind: NewsKind.promo), null), isEmpty);
      expect(newsCoverUrl(_sport('p3', 'Quần vợt', kind: NewsKind.review), null), isEmpty);
    });
  });
}
