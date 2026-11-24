import '../models/venue.dart';
import 'booking_slots.dart';
import 'firestore_service.dart';
import 'news_feed.dart';
import 'weather_service.dart';

enum FeaturedKind { rated, cheapest, mostCourts }

enum GoldenPhase { before, during, after }

/// Trạng thái ca giờ vàng so với bây giờ.
class GoldenStatus {
  final GoldenPhase phase;

  /// before: còn bao lâu nữa thì bắt đầu; during: còn bao lâu nữa thì hết; after: còn bao lâu nữa tới ca ngày mai.
  final Duration remaining;

  /// Vị trí của "bây giờ" trong ngày, từ 0 (0h) đến 1 (24h).
  final double dayFraction;

  const GoldenStatus(this.phase, this.remaining, this.dayFraction);
}

enum RainTag { fine, maybe, likely }

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

  /// Ca giờ vàng (16:00 – 22:00, cùng cấu hình với màn đặt sân) so với thời điểm [now].
  static GoldenStatus goldenStatus(DateTime now) {
    final start = DateTime(now.year, now.month, now.day, BookingSlots.goldenStartHour);
    final end = DateTime(now.year, now.month, now.day, BookingSlots.goldenEndHour);
    final fraction = (now.hour * 60 + now.minute) / 1440.0;
    if (now.isBefore(start)) return GoldenStatus(GoldenPhase.before, start.difference(now), fraction);
    if (now.isBefore(end)) return GoldenStatus(GoldenPhase.during, end.difference(now), fraction);
    final tomorrow = start.add(const Duration(days: 1));
    return GoldenStatus(GoldenPhase.after, tomorrow.difference(now), fraction);
  }

  /// "2 giờ 15 phút", "1 giờ", "45 phút". Làm tròn lên theo phút để không bao giờ hiện "0 phút".
  static String durationLabel(Duration d) {
    final minutes = ((d.inSeconds + 59) ~/ 60).clamp(1, 24 * 60);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m phút';
    return m == 0 ? '$h giờ' : '$h giờ $m phút';
  }

  /// Câu mô tả ca giờ vàng cho thẻ "Giờ vàng hôm nay".
  static String goldenMessage(GoldenStatus g) {
    switch (g.phase) {
      case GoldenPhase.before:
        return 'Giờ vàng bắt đầu sau ${durationLabel(g.remaining)}';
      case GoldenPhase.during:
        return 'Đang là giờ vàng, còn ${durationLabel(g.remaining)}';
      case GoldenPhase.after:
        return 'Giờ vàng hôm nay đã kết thúc, ngày mai bắt đầu lúc ${BookingSlots.goldenStartHour}:00';
    }
  }

  /// Số địa điểm sân công khai theo từng môn (đã duyệt, không tính sân minh họa).
  static Map<String, int> countBySport(List<Venue> venues) {
    final out = <String, int>{for (final s in sportOrder) s: 0};
    for (final v in venues) {
      if (!NewsFeed.isPublic(v) || !out.containsKey(v.type)) continue;
      out[v.type] = out[v.type]! + 1;
    }
    return out;
  }

  /// "T2".."T7", "CN".
  static String dayShort(DateTime d) => const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][d.weekday - 1];

  /// Mức mưa của một ngày: đẹp trời (xác suất dưới 30% và mưa dưới 1 mm), có thể mưa (dưới 60%), dễ mưa.
  static RainTag rainTag(DayWeather d) {
    if (d.rainProb < 30 && d.rainMm < 1) return RainTag.fine;
    if (d.rainProb < 60) return RainTag.maybe;
    return RainTag.likely;
  }

  /// Ngày đẹp nhất để ra sân: khả năng mưa thấp nhất (rồi lượng mưa thấp nhất, rồi ngày gần nhất).
  /// Chỉ trả về ngày có khả năng mưa dưới 40%; không có thì null để không tô vẽ một ngày "đẹp" không có thật.
  static DayWeather? bestDay(List<DayWeather> days) {
    DayWeather? best;
    for (final d in days) {
      if (d.rainProb >= 40) continue;
      if (best == null || d.rainProb < best.rainProb || (d.rainProb == best.rainProb && d.rainMm < best.rainMm)) best = d;
    }
    return best;
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

  /// Chữ ngắn cho viên thời tiết: "29°C · Trời quang" (biểu tượng bầu trời vẽ riêng bằng SkyIcon).
  /// Null nếu không có dữ liệu thật.
  static String? weatherChip(WeatherData w) {
    if (!w.isLive) return null;
    return '${w.temperature.round()}°C · ${w.condition}';
  }
}
