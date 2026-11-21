import '../models/venue.dart';
import 'firestore_service.dart';
import 'news_feed.dart';
import 'weather_service.dart';

enum FeaturedKind { rated, cheapest, mostCourts }

/// Một sân được làm nổi bật ở Khám phá kèm lý do. Lý do luôn là một sự thật đếm được từ dữ liệu
/// (điểm đánh giá của khách, giá niêm yết, số sân đã khai báo), không phải xếp hạng tự đặt.
class FeaturedVenue {
  final Venue venue;
  final FeaturedKind kind;

  /// Ví dụ "Giá mềm nhất môn cầu lông".
  final String reason;

  /// Con số làm bằng chứng, ví dụ "70k - 90k/h", "4.5 ★ · 2 đánh giá", "12 sân".
  final String detail;

  const FeaturedVenue(this.venue, this.kind, this.reason, this.detail);
}

/// Những phần "hấp dẫn" của Khám phá nhưng tính từ dữ liệu thật: sân nổi bật, lời chào, gợi ý theo thời tiết.
class ExploreHighlights {
  ExploreHighlights._();

  /// Thứ tự các môn khi chọn "giá mềm nhất".
  static const sportOrder = ['badminton', 'pickleball', 'football', 'tennis', 'basketball'];

  static const _sportName = {
    'badminton': 'cầu lông',
    'pickleball': 'pickleball',
    'football': 'bóng đá',
    'tennis': 'tennis',
    'basketball': 'bóng rổ',
  };

  /// Giá thấp nhất trong khoảng giá niêm yết ("80k - 100k/h" -> 80000), null nếu chưa niêm yết.
  static int? lowestPrice(Venue v) {
    final m = RegExp(r'(\d+)\s*k\s*-\s*(\d+)\s*k', caseSensitive: false).firstMatch(v.price);
    if (m == null) return null;
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    final low = (a < b ? a : b) * 1000;
    return low > 0 ? low : null;
  }

  /// Chọn tối đa [max] sân nổi bật. Chỉ xét cụm sân do chủ sân/ban quản lý đăng và đã duyệt
  /// (bỏ sân minh họa và địa điểm lấy từ dữ liệu mở vì giá chỉ là tham khảo).
  /// Thứ tự: sân được khách đánh giá cao, rồi sân giá mềm nhất của từng môn, rồi sân khai báo nhiều sân nhất.
  static List<FeaturedVenue> featured({required List<Venue> venues, required List<ReviewItem> reviews, int max = 6}) {
    final pool = venues.where((v) => NewsFeed.isPublic(v) && !v.isImportedListing).toList();
    final out = <FeaturedVenue>[];
    final used = <int>{};

    void add(Venue v, FeaturedKind kind, String reason, String detail) {
      if (out.length >= max || !used.add(v.id)) return;
      out.add(FeaturedVenue(v, kind, reason, detail));
    }

    // 1. Được khách đánh giá cao: điểm trung bình từ 4.0 trở lên, tính từ đánh giá thật
    final stars = <int, List<int>>{};
    for (final r in reviews) {
      if (r.stars >= 1 && r.stars <= 5) stars.putIfAbsent(r.venueId, () => []).add(r.stars);
    }
    final rated = <(Venue, double, int)>[
      for (final v in pool)
        if (stars[v.id] != null && stars[v.id]!.fold<int>(0, (s, x) => s + x) / stars[v.id]!.length >= 4.0)
          (v, stars[v.id]!.fold<int>(0, (s, x) => s + x) / stars[v.id]!.length, stars[v.id]!.length),
    ]..sort((a, b) {
        final c = b.$2.compareTo(a.$2);
        if (c != 0) return c;
        final n = b.$3.compareTo(a.$3);
        return n != 0 ? n : a.$1.id.compareTo(b.$1.id);
      });
    for (final (v, avg, n) in rated.take(2)) {
      add(v, FeaturedKind.rated, 'Được khách đánh giá cao', '${avg.toStringAsFixed(1)} ★ · $n đánh giá');
    }

    // 2. Giá mềm nhất của từng môn (trong các sân đã niêm yết giá)
    for (final sport in sportOrder) {
      final cands = pool.where((v) => v.type == sport && lowestPrice(v) != null).toList()
        ..sort((a, b) {
          final c = lowestPrice(a)!.compareTo(lowestPrice(b)!);
          return c != 0 ? c : a.id.compareTo(b.id);
        });
      if (cands.isEmpty) continue;
      add(cands.first, FeaturedKind.cheapest, 'Giá mềm nhất môn ${_sportName[sport]}', cands.first.price);
    }

    // 3. Nhiều sân nhất: chỉ tính số sân chủ sân đã khai báo, không dùng số mặc định theo môn
    final declared = pool.where((v) => v.courtCount > 0).toList()
      ..sort((a, b) {
        final c = b.courtCount.compareTo(a.courtCount);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    if (declared.isNotEmpty) add(declared.first, FeaturedKind.mostCourts, 'Nhiều sân nhất', '${declared.first.courtCount} sân');

    return out;
  }

  /// Lời chào theo giờ trong ngày.
  static String greeting(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 11) return 'Chào buổi sáng';
    if (h >= 11 && h < 14) return 'Chào buổi trưa';
    if (h >= 14 && h < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  /// Gợi ý ra sân dựa trên thời tiết thật. Trả về null khi không lấy được dữ liệu thật,
  /// không bao giờ đoán thời tiết.
  static String? weatherTip(WeatherData w) {
    if (!w.isLive) return null;
    if (w.rainMm >= 0.5) return 'Đang mưa: nên chọn sân trong nhà hoặc sân có mái che.';
    if (w.temperature >= 35) return 'Trời rất nóng: nên chơi vào chiều muộn hoặc buổi tối.';
    final p = w.eveningRainProb;
    if (p == null) return w.isOutdoorFavorable ? 'Trời tạnh ráo, thuận lợi để ra sân.' : null;
    if (p >= 60) return 'Tối nay dễ mưa ($p%): nên chọn sân có mái che.';
    if (p >= 30) return 'Tối nay có thể mưa ($p%): hãy có sẵn phương án sân có mái che.';
    return 'Tối nay ít khả năng mưa ($p%): hợp ra sân ngoài trời.';
  }

  /// Chữ ngắn cho viên thời tiết: "☀️ 29°C · Trời quang". Null nếu không có dữ liệu thật.
  static String? weatherChip(WeatherData w) {
    if (!w.isLive) return null;
    return '${w.emoji} ${w.temperature.round()}°C · ${w.condition}';
  }
}
