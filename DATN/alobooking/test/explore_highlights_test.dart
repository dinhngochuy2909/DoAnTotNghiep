import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/services/explore_highlights.dart';
import 'package:alobooking/services/firestore_service.dart';
import 'package:alobooking/services/weather_service.dart';

Venue _v(
  int id,
  String name, {
  String type = 'badminton',
  String price = '80k - 100k/h',
  String source = '',
  String status = 'approved',
  int courts = 0,
  String district = 'Cầu Giấy',
}) =>
    Venue(
      id: id,
      name: name,
      type: type,
      district: district,
      distance: '',
      address: '$id Phố Thử',
      hours: '06:00 – 22:00',
      tags: const [],
      rating: 4.5,
      price: price,
      lat: 21.0,
      lng: 105.8,
      image: '',
      logo: '',
      source: source,
      approvalStatus: status,
      courtCount: courts,
    );

ReviewItem _r(String id, int venueId, int stars) =>
    ReviewItem(id: id, venueId: venueId, userId: 'u$id', userName: 'Khách', stars: stars, comment: 'ok', createdAt: DateTime(2026, 11, 20));

WeatherData _w({
  double temp = 28,
  double rain = 0,
  bool live = true,
  bool favorable = true,
  int? evening,
  String condition = 'Trời quang',
  String emoji = '☀️',
}) =>
    WeatherData(
      temperature: temp,
      rainMm: rain,
      humidity: 70,
      condition: condition,
      description: '',
      emoji: emoji,
      isOutdoorFavorable: favorable,
      isLive: live,
      eveningRainProb: evening,
    );

void main() {
  group('lowestPrice', () {
    test('lấy mức thấp trong khoảng giá, kể cả khi nhập ngược', () {
      expect(ExploreHighlights.lowestPrice(_v(1, 'a', price: '80k - 100k/h')), 80000);
      expect(ExploreHighlights.lowestPrice(_v(1, 'a', price: '160k - 80k/h')), 80000);
      expect(ExploreHighlights.lowestPrice(_v(1, 'a', price: '320k - 400k/trận')), 320000);
    });

    test('chưa niêm yết hoặc giá 0 thì null', () {
      expect(ExploreHighlights.lowestPrice(_v(1, 'a', price: 'Liên hệ')), isNull);
      expect(ExploreHighlights.lowestPrice(_v(1, 'a', price: '')), isNull);
      expect(ExploreHighlights.lowestPrice(_v(1, 'a', price: '0k - 0k/h')), isNull);
    });
  });

  group('featured', () {
    test('không có dữ liệu thì không có sân nổi bật, không bịa', () {
      expect(ExploreHighlights.featured(venues: const [], reviews: const []), isEmpty);
    });

    test('sân được đánh giá cao: điểm trung bình từ 4.0, tối đa 2 sân, điểm cao đứng trước', () {
      final venues = [_v(1, 'A'), _v(2, 'B'), _v(3, 'C'), _v(4, 'D')];
      final reviews = [
        _r('1', 1, 5), _r('2', 1, 5),
        _r('3', 2, 5), _r('4', 2, 4),
        _r('5', 3, 3), // 3.0: không đủ
        _r('6', 4, 5), _r('7', 4, 5), _r('8', 4, 4), // 4.67 nhưng chỉ lấy 2 sân đầu
      ];
      final rated = ExploreHighlights.featured(venues: venues, reviews: reviews).where((f) => f.kind == FeaturedKind.rated).toList();
      expect(rated.map((f) => f.venue.id), [1, 4], reason: 'điểm 5.0 rồi 4.67; sân 2 (4.5) bị cắt vì chỉ lấy 2');
      expect(rated.first.detail, '5.0 ★ · 2 đánh giá');
      expect(rated.first.reason, 'Được khách đánh giá cao');
      expect(rated.map((f) => f.venue.id), isNot(contains(3)));
    });

    test('đánh giá có số sao không hợp lệ bị bỏ qua', () {
      final out = ExploreHighlights.featured(venues: [_v(1, 'A')], reviews: [_r('1', 1, 0), _r('2', 1, 9)]);
      expect(out.where((f) => f.kind == FeaturedKind.rated), isEmpty);
    });

    test('giá mềm nhất của từng môn, chỉ tính sân đã niêm yết giá; giá nhập ngược vẫn đúng', () {
      final venues = [
        _v(10, 'Đắt', price: '90k - 100k/h'),
        _v(11, 'Rẻ nhất', price: '160k - 60k/h'), // thực chất 60k
        _v(12, 'Chưa giá', price: 'Liên hệ'),
        _v(20, 'Tennis A', type: 'tennis', price: '200k - 250k/h'),
        _v(21, 'Tennis B', type: 'tennis', price: '180k - 225k/h'),
      ];
      final out = ExploreHighlights.featured(venues: venues, reviews: const []).where((f) => f.kind == FeaturedKind.cheapest).toList();
      expect(out.map((f) => f.venue.id), [11, 21]);
      expect(out.first.reason, 'Giá mềm nhất môn cầu lông');
      expect(out.last.reason, 'Giá mềm nhất môn tennis');
      expect(out.first.detail, '160k - 60k/h', reason: 'ghi đúng giá niêm yết của sân');
    });

    test('nhiều sân nhất: chỉ tính số sân đã khai báo, không dùng số mặc định theo môn', () {
      final none = ExploreHighlights.featured(venues: [_v(1, 'A'), _v(2, 'B')], reviews: const []);
      expect(none.where((f) => f.kind == FeaturedKind.mostCourts), isEmpty);

      final out = ExploreHighlights.featured(venues: [_v(1, 'A', courts: 8), _v(2, 'B', courts: 12, type: 'football', price: 'Liên hệ'), _v(3, 'C')], reviews: const []);
      final most = out.singleWhere((f) => f.kind == FeaturedKind.mostCourts);
      expect(most.venue.id, 2);
      expect(most.detail, '12 sân');
    });

    test('loại sân minh họa, sân chưa duyệt và địa điểm từ dữ liệu mở khỏi mọi nhóm', () {
      final venues = [
        _v(1, '[Demo]', source: 'demo', price: '10k - 20k/h', courts: 30),
        _v(2, 'Chờ duyệt', status: 'pending', price: '10k - 20k/h', courts: 30),
        _v(3, 'Từ OSM', source: 'osm', price: '10k - 20k/h', courts: 30),
        _v(4, 'Từ Overture', source: 'overture', price: '10k - 20k/h', courts: 30),
        _v(5, 'Sân thật', price: '90k - 100k/h', courts: 4),
      ];
      final reviews = [for (final id in [1, 2, 3, 4]) _r('r$id', id, 5)];
      final out = ExploreHighlights.featured(venues: venues, reviews: reviews);
      expect(out.map((f) => f.venue.id).toSet(), {5});
    });

    test('một sân chỉ xuất hiện một lần dù đạt nhiều tiêu chí; tối đa max sân', () {
      final venues = [_v(1, 'A', courts: 20), _v(2, 'B', type: 'pickleball'), _v(3, 'C', type: 'football'), _v(4, 'D', type: 'tennis'), _v(5, 'E', type: 'basketball')];
      final out = ExploreHighlights.featured(venues: venues, reviews: [_r('1', 1, 5)]);
      final ids = out.map((f) => f.venue.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'không trùng sân');
      expect(out.first.kind, FeaturedKind.rated);
      expect(out.first.venue.id, 1, reason: 'sân 1 vừa được đánh giá cao, vừa rẻ nhất cầu lông, vừa nhiều sân: chỉ hiện một lần');
      expect(ExploreHighlights.featured(venues: venues, reviews: [_r('1', 1, 5)], max: 2).length, 2);
    });
  });

  group('greeting', () {
    test('theo giờ trong ngày', () {
      String g(int h, [int m = 0]) => ExploreHighlights.greeting(DateTime(2026, 11, 21, h, m));
      expect(g(4, 59), 'Chào buổi tối');
      expect(g(5), 'Chào buổi sáng');
      expect(g(10, 59), 'Chào buổi sáng');
      expect(g(11), 'Chào buổi trưa');
      expect(g(13, 59), 'Chào buổi trưa');
      expect(g(14), 'Chào buổi chiều');
      expect(g(17, 59), 'Chào buổi chiều');
      expect(g(18), 'Chào buổi tối');
      expect(g(23), 'Chào buổi tối');
    });
  });

  group('weatherTip / weatherChip', () {
    test('không lấy được thời tiết thật thì không nói gì, không đoán', () {
      final w = _w(live: false, evening: 5);
      expect(ExploreHighlights.weatherTip(w), isNull);
      expect(ExploreHighlights.weatherChip(w), isNull);
    });

    test('đang mưa thì khuyên sân có mái che, ưu tiên hơn dự báo buổi tối', () {
      expect(ExploreHighlights.weatherTip(_w(rain: 1.2, evening: 0)), contains('Đang mưa'));
    });

    test('quá nóng', () {
      expect(ExploreHighlights.weatherTip(_w(temp: 36, evening: 0)), contains('rất nóng'));
    });

    test('dự báo buổi tối: dễ mưa / có thể mưa / ít khả năng mưa, kèm đúng phần trăm', () {
      expect(ExploreHighlights.weatherTip(_w(evening: 70)), 'Tối nay dễ mưa (70%): nên chọn sân có mái che.');
      expect(ExploreHighlights.weatherTip(_w(evening: 60)), contains('dễ mưa (60%)'));
      expect(ExploreHighlights.weatherTip(_w(evening: 40)), contains('có thể mưa (40%)'));
      expect(ExploreHighlights.weatherTip(_w(evening: 30)), contains('có thể mưa (30%)'));
      expect(ExploreHighlights.weatherTip(_w(evening: 10)), 'Tối nay ít khả năng mưa (10%): hợp ra sân ngoài trời.');
    });

    test('không có dự báo buổi tối: chỉ nói tạnh ráo khi thuận lợi, còn không thì im lặng', () {
      expect(ExploreHighlights.weatherTip(_w(evening: null)), contains('tạnh ráo'));
      expect(ExploreHighlights.weatherTip(_w(evening: null, favorable: false)), isNull);
    });

    test('viên thời tiết ghi nhiệt độ làm tròn và tình trạng', () {
      expect(ExploreHighlights.weatherChip(_w(temp: 28.6)), '29°C · Trời quang');
    });
  });

  group('WeatherService.eveningOutlook', () {
    Map<String, dynamic> data({List<int>? probs, bool daily = true}) {
      final hours = [for (var h = 15; h <= 23; h++) '2026-11-21T${h.toString().padLeft(2, '0')}:00'];
      final p = probs ?? [0, 0, 10, 50, 20, 5, 0, 0, 90]; // 15h..23h; 90% lúc 23h nằm ngoài buổi tối
      return {
        if (daily) 'daily': {'time': ['2026-11-21', '2026-11-22']},
        'hourly': {
          'time': hours,
          'temperature_2m': [for (var h = 15; h <= 23; h++) (h >= 18 && h <= 22) ? 24.0 : 30.0],
          'precipitation_probability': p,
        },
      };
    }

    test('lấy khả năng mưa lớn nhất và nhiệt độ trung bình trong 18h–22h', () {
      final r = WeatherService.eveningOutlook(data(), nowHour: 15)!;
      expect(r.$1, 50, reason: 'lớn nhất trong 18h–22h; 90% lúc 23h bị bỏ');
      expect(r.$2, closeTo(24, 0.001));
    });

    test('đã quá 22h thì không còn "tối nay"', () {
      expect(WeatherService.eveningOutlook(data(), nowHour: 22), isNull);
      expect(WeatherService.eveningOutlook(data(), nowHour: 23), isNull);
      expect(WeatherService.eveningOutlook(data(), nowHour: 21), isNotNull);
    });

    test('dữ liệu thiếu hoặc hỏng thì null, không ném lỗi', () {
      expect(WeatherService.eveningOutlook(data(daily: false), nowHour: 10), isNull);
      expect(WeatherService.eveningOutlook(const {}, nowHour: 10), isNull);
      expect(WeatherService.eveningOutlook({'daily': {'time': ['2030-01-01']}, 'hourly': {'time': <String>[], 'temperature_2m': [], 'precipitation_probability': []}}, nowHour: 10), isNull);
    });
  });

  DayForecast day(int offset, {int prob = 10, double mm = 0}) => DayForecast(
        date: DateTime(2026, 11, 21 + offset),
        emoji: '☀️',
        condition: 'Trời quang',
        tempMax: 30,
        tempMin: 22,
        rainProb: prob,
        rainMm: mm,
      );

  group('goldenStatus / durationLabel / goldenMessage', () {
    GoldenStatus at(int h, [int m = 0]) => ExploreHighlights.goldenStatus(DateTime(2026, 11, 21, h, m));

    test('trước giờ vàng: còn bao lâu nữa tới 16:00', () {
      final g = at(15);
      expect(g.phase, GoldenPhase.before);
      expect(g.remaining, const Duration(hours: 1));
      expect(at(2).phase, GoldenPhase.before);
      expect(at(2).remaining, const Duration(hours: 14));
    });

    test('16:00 đã là giờ vàng (tính cả mốc bắt đầu); 21:59 vẫn còn 1 phút; 22:00 là hết', () {
      expect(at(16).phase, GoldenPhase.during);
      expect(at(16).remaining, const Duration(hours: 6));
      expect(at(21, 59).phase, GoldenPhase.during);
      expect(at(21, 59).remaining, const Duration(minutes: 1));
      expect(at(22).phase, GoldenPhase.after);
    });

    test('sau giờ vàng: đếm tới ca 16:00 ngày mai', () {
      expect(at(23, 30).remaining, const Duration(hours: 16, minutes: 30));
      expect(at(22).remaining, const Duration(hours: 18));
    });

    test('vị trí "bây giờ" trong ngày từ 0 đến 1', () {
      expect(at(0).dayFraction, 0);
      expect(at(12).dayFraction, 0.5);
      expect(at(23, 59).dayFraction, closeTo(1, 0.001));
      expect(at(23, 59).dayFraction, lessThan(1));
    });

    test('durationLabel làm tròn lên theo phút, không bao giờ hiện 0 phút', () {
      expect(ExploreHighlights.durationLabel(const Duration(minutes: 45)), '45 phút');
      expect(ExploreHighlights.durationLabel(const Duration(minutes: 60)), '1 giờ');
      expect(ExploreHighlights.durationLabel(const Duration(minutes: 135)), '2 giờ 15 phút');
      expect(ExploreHighlights.durationLabel(const Duration(seconds: 30)), '1 phút');
      expect(ExploreHighlights.durationLabel(Duration.zero), '1 phút');
      expect(ExploreHighlights.durationLabel(const Duration(minutes: 59, seconds: 1)), '1 giờ');
    });

    test('goldenMessage cho cả ba giai đoạn', () {
      expect(ExploreHighlights.goldenMessage(at(14, 45)), 'Giờ vàng bắt đầu sau 1 giờ 15 phút');
      expect(ExploreHighlights.goldenMessage(at(20)), 'Đang là giờ vàng, còn 2 giờ');
      expect(ExploreHighlights.goldenMessage(at(23)), 'Giờ vàng hôm nay đã kết thúc, ngày mai bắt đầu lúc 16:00');
    });
  });

  group('countBySport / dayShort', () {
    test('chỉ đếm sân công khai (đã duyệt, không demo); môn lạ bị bỏ; môn không có sân là 0', () {
      final venues = [
        _v(1, 'A'),
        _v(2, 'B'),
        _v(3, '[Demo]', source: 'demo'),
        _v(4, 'Chờ', status: 'pending'),
        _v(5, 'Tennis', type: 'tennis'),
        _v(6, 'Từ OSM', type: 'tennis', source: 'osm'),
        _v(7, 'Môn lạ', type: 'golf'),
      ];
      final c = ExploreHighlights.countBySport(venues);
      expect(c, {'badminton': 2, 'pickleball': 0, 'football': 0, 'tennis': 2, 'basketball': 0});
      expect(ExploreHighlights.countBySport(const []).values.every((n) => n == 0), isTrue);
    });

    test('dayShort: thứ hai là T2 ... chủ nhật là CN', () {
      // 21/11/2026 là thứ bảy
      expect(ExploreHighlights.dayShort(DateTime(2026, 11, 21)), 'T7');
      expect(ExploreHighlights.dayShort(DateTime(2026, 11, 22)), 'CN');
      expect(ExploreHighlights.dayShort(DateTime(2026, 11, 23)), 'T2');
      expect(ExploreHighlights.dayShort(DateTime(2026, 11, 25)), 'T4');
    });
  });

  group('rainTag / bestDay', () {
    test('rainTag: ranh giới 30% / 60% và 1 mm', () {
      expect(ExploreHighlights.rainTag(day(0, prob: 0)), RainTag.fine);
      expect(ExploreHighlights.rainTag(day(0, prob: 29, mm: 0.9)), RainTag.fine);
      expect(ExploreHighlights.rainTag(day(0, prob: 29, mm: 1)), RainTag.maybe, reason: 'ít xác suất nhưng mưa từ 1 mm thì không còn "đẹp"');
      expect(ExploreHighlights.rainTag(day(0, prob: 30)), RainTag.maybe);
      expect(ExploreHighlights.rainTag(day(0, prob: 59)), RainTag.maybe);
      expect(ExploreHighlights.rainTag(day(0, prob: 60)), RainTag.likely);
      expect(ExploreHighlights.rainTag(day(0, prob: 100, mm: 40)), RainTag.likely);
    });

    test('bestDay: khả năng mưa thấp nhất; bằng nhau thì ít mưa hơn; vẫn bằng thì ngày gần hơn', () {
      expect(ExploreHighlights.bestDay([day(0, prob: 30), day(1, prob: 10), day(2, prob: 20)])!.date.day, 22);
      expect(ExploreHighlights.bestDay([day(0, prob: 10, mm: 2), day(1, prob: 10, mm: 0.5), day(2, prob: 10, mm: 0.5)])!.date.day, 22);
      expect(ExploreHighlights.bestDay([day(0, prob: 10), day(1, prob: 10)])!.date.day, 21);
    });

    test('bestDay: không có ngày nào dưới 40% (hoặc không có dự báo) thì null, không tô vẽ', () {
      expect(ExploreHighlights.bestDay([day(0, prob: 40), day(1, prob: 90)]), isNull);
      expect(ExploreHighlights.bestDay(const []), isNull);
      expect(ExploreHighlights.bestDay([day(0, prob: 39)]), isNotNull);
    });
  });

  group('WeatherService.skyOf', () {
    test('phân loại theo mã thời tiết WMO và lượng mưa', () {
      expect(WeatherService.skyOf(0, 0), Sky.clear);
      expect(WeatherService.skyOf(1, 0), Sky.partly);
      expect(WeatherService.skyOf(2, 0), Sky.partly);
      expect(WeatherService.skyOf(3, 0), Sky.cloudy);
      expect(WeatherService.skyOf(45, 0), Sky.fog);
      expect(WeatherService.skyOf(48, 0), Sky.fog);
      expect(WeatherService.skyOf(61, 0), Sky.rain);
      expect(WeatherService.skyOf(81, 0), Sky.rain);
      expect(WeatherService.skyOf(3, 2.5), Sky.rain, reason: 'đang có mưa thì là mưa dù trời nhiều mây');
      expect(WeatherService.skyOf(95, 0), Sky.storm);
      expect(WeatherService.skyOf(99, 30), Sky.storm);
    });
  });

  group('WeatherService.dailyForecast', () {
    Map<String, dynamic> data({int days = 7}) => {
          'daily': {
            'time': [for (var i = 0; i < days; i++) '2026-11-${21 + i}'],
            'weather_code': <num?>[for (var i = 0; i < days; i++) i == 1 ? 63 : 0],
            'temperature_2m_max': <num?>[for (var i = 0; i < days; i++) 30.0 - i],
            'temperature_2m_min': <num?>[for (var i = 0; i < days; i++) 22.0],
            'precipitation_sum': <num?>[for (var i = 0; i < days; i++) i == 1 ? 12.5 : 0.0],
            'precipitation_probability_max': <num?>[for (var i = 0; i < days; i++) i == 1 ? 85 : 10],
          },
        };

    test('đọc đủ số liệu từng ngày, kèm biểu tượng và mô tả', () {
      final d = WeatherService.dailyForecast(data());
      expect(d.length, 7);
      expect(d.first.date, DateTime(2026, 11, 21));
      expect(d.first.tempMax, 30);
      expect(d.first.tempMin, 22);
      expect(d.first.rainProb, 10);
      expect(d.first.emoji, '☀️');
      expect(d[1].rainProb, 85);
      expect(d[1].rainMm, 12.5);
      expect(d[1].emoji, '⛈️', reason: 'mưa trên 5 mm dùng biểu tượng mưa to');
      expect(d[1].condition, 'Mưa to');
    });

    test('chỉ lấy tối đa 7 ngày', () {
      expect(WeatherService.dailyForecast(data(days: 10)).length, 7);
    });

    test('ngày thiếu số liệu thì bỏ qua chứ không điền số đoán', () {
      final d = data();
      ((d['daily'] as Map)['precipitation_probability_max'] as List)[2] = null;
      ((d['daily'] as Map)['temperature_2m_max'] as List)[3] = null;
      final out = WeatherService.dailyForecast(d);
      expect(out.length, 5);
      expect(out.map((x) => x.date.day), isNot(contains(23)));
      expect(out.map((x) => x.date.day), isNot(contains(24)));
    });

    test('mỗi ngày có phân loại bầu trời để vẽ icon', () {
      final d = WeatherService.dailyForecast(data());
      expect(d.first.sky, Sky.clear);
      expect(d[1].sky, Sky.rain);
    });

    test('dữ liệu hỏng thì trả về rỗng, không ném lỗi', () {
      expect(WeatherService.dailyForecast(const {}), isEmpty);
      expect(WeatherService.dailyForecast({'daily': {'time': ['hôm nay'], 'weather_code': [0], 'temperature_2m_max': [30], 'temperature_2m_min': [20], 'precipitation_sum': [0], 'precipitation_probability_max': [0]}}), isEmpty);
    });
  });
}
