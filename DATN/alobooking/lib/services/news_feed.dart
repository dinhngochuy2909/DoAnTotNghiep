import '../models/news_post.dart';
import '../models/venue.dart';
import 'firestore_service.dart';

/// Loại một mục trong dòng tin Khám phá.
enum NewsKind {
  notice('Thông báo'),
  update('Có gì mới'),
  promo('Ưu đãi'),
  event('Sự kiện'),
  newVenue('Sân mới'),
  review('Đánh giá');

  final String label;
  const NewsKind(this.label);

  static NewsKind fromCategory(String category) {
    switch (category) {
      case 'promo':
        return NewsKind.promo;
      case 'event':
        return NewsKind.event;
      case 'update':
        return NewsKind.update;
      default:
        return NewsKind.notice;
    }
  }
}

/// Một mục trong dòng tin: tin admin đăng, hoặc tin tự sinh từ dữ liệu thật (sân mới duyệt, đánh giá mới).
class NewsEntry {
  final String id;
  final NewsKind kind;
  final String title;
  final String body;
  final String imageUrl;
  final DateTime time;
  final bool pinned;

  /// Sân gắn kèm (0 = không có).
  final int venueId;

  /// Số sao (chỉ với mục đánh giá).
  final int stars;

  /// Người đăng / người đánh giá.
  final String byline;

  const NewsEntry({
    required this.id,
    required this.kind,
    required this.title,
    this.body = '',
    this.imageUrl = '',
    required this.time,
    this.pinned = false,
    this.venueId = 0,
    this.stars = 0,
    this.byline = '',
  });

  /// Mục do hệ thống tự sinh từ dữ liệu, không phải bài admin viết.
  bool get isAuto => kind == NewsKind.newVenue || kind == NewsKind.review;
}

/// Gộp tin admin đăng với tin tự sinh từ dữ liệu thật thành một dòng tin theo thời gian.
class NewsFeed {
  /// Sân mới và đánh giá mới chỉ hiện trong khoảng này kể từ lúc phát sinh.
  static const autoWindow = Duration(days: 30);
  static const maxAutoReviews = 10;
  static const maxAutoVenues = 10;

  /// Tên người đánh giá được lưu kèm vai trò, ví dụ "Nguyễn Văn Khách (Khách hàng)"; bỏ phần vai trò khi hiển thị.
  static final _roleSuffix = RegExp(r'\s*\((khách hàng|chủ sân|quản trị viên|admin)\)\s*$', caseSensitive: false);

  static List<NewsEntry> build({
    required List<NewsPost> posts,
    required List<Venue> venues,
    required List<ReviewItem> reviews,
    required DateTime now,
  }) {
    final out = <NewsEntry>[];

    for (final p in posts) {
      out.add(NewsEntry(
        id: 'post-${p.id}',
        kind: NewsKind.fromCategory(p.category),
        title: p.title,
        body: p.body,
        imageUrl: p.imageUrl,
        time: p.createdAt,
        pinned: p.pinned,
        venueId: p.venueId,
        byline: p.author,
      ));
    }

    // Sân mới: đã duyệt, là cụm sân thật (không phải demo/dữ liệu mở) và có ngày duyệt trong 30 ngày qua.
    final fresh = venues.where((v) {
      final t = v.approvedAt;
      return v.isApproved && !v.isDemo && !v.isImportedListing && t != null && !t.isAfter(now) && now.difference(t) <= autoWindow;
    }).toList()
      ..sort((a, b) => b.approvedAt!.compareTo(a.approvedAt!));
    for (final v in fresh.take(maxAutoVenues)) {
      final bits = <String>[
        '${Venue.courtLabel(v.type)} tại ${v.district.isEmpty ? 'Hà Nội' : v.district}',
        if (v.address.trim().isNotEmpty) v.address.trim(),
        if (v.hasListedPrice) 'Giá ${v.price}',
      ];
      out.add(NewsEntry(
        id: 'venue-${v.id}',
        kind: NewsKind.newVenue,
        title: '${v.name} vừa lên AloBooking',
        body: bits.join(' · '),
        imageUrl: v.displayImage,
        time: v.approvedAt!,
        venueId: v.id,
        byline: 'AloBooking',
      ));
    }

    // Đánh giá mới: có nội dung, thuộc sân đang hiển thị công khai, trong 30 ngày qua.
    final byId = {for (final v in venues) v.id: v};
    final recent = reviews.where((r) {
      final v = byId[r.venueId];
      return v != null &&
          v.isApproved &&
          !v.isDemo &&
          r.comment.trim().isNotEmpty &&
          !r.createdAt.isAfter(now) &&
          now.difference(r.createdAt) <= autoWindow;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final r in recent.take(maxAutoReviews)) {
      final v = byId[r.venueId]!;
      final who = reviewerName(r.userName);
      out.add(NewsEntry(
        id: 'review-${r.id}',
        kind: NewsKind.review,
        title: '$who đánh giá ${v.name}',
        body: r.comment.trim(),
        time: r.createdAt,
        venueId: v.id,
        stars: r.stars,
        byline: who,
      ));
    }

    // Tin ghim lên đầu, còn lại mới nhất trước.
    out.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.time.compareTo(a.time);
    });
    return out;
  }

  /// Tên người đánh giá để hiển thị: bỏ phần vai trò dính kèm, không có tên thì "Một khách hàng".
  static String reviewerName(String raw) {
    final n = raw.replaceFirst(_roleSuffix, '').trim();
    return n.isEmpty ? 'Một khách hàng' : n;
  }

  /// Sân hiển thị công khai trong Khám phá: đã duyệt và không phải sân minh họa (demo).
  static bool isPublic(Venue v) => v.isApproved && !v.isDemo;

  /// Số liệu tổng quan, đếm từ dữ liệu thật: địa điểm sân công khai, số quận/huyện, số môn và số đánh giá của khách.
  static ({int places, int districts, int sports, int reviews}) stats(List<Venue> venues, List<ReviewItem> reviews) {
    final pub = venues.where(isPublic).toList();
    final ids = {for (final v in pub) v.id};
    return (
      places: pub.length,
      districts: {for (final v in pub) if (v.district.trim().isNotEmpty) v.district.trim()}.length,
      sports: {for (final v in pub) if (v.type.trim().isNotEmpty) v.type.trim()}.length,
      reviews: reviews.where((r) => ids.contains(r.venueId) && r.stars >= 1 && r.stars <= 5).length,
    );
  }

  /// Đánh giá của một sân (sao hợp lệ 1–5), mới nhất trước.
  static List<ReviewItem> reviewsOf(int venueId, List<ReviewItem> reviews) =>
      reviews.where((r) => r.venueId == venueId && r.stars >= 1 && r.stars <= 5).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Sân tương tự: cùng môn, ưu tiên cùng quận, rồi sân do chủ sân đăng và có giá niêm yết. Chỉ lấy sân công khai.
  static List<Venue> similarVenues(Venue v, List<Venue> all, {int max = 6}) {
    final list = all.where((o) => o.id != v.id && o.type == v.type && isPublic(o)).toList();
    int rank(Venue o) => (o.district == v.district ? 0 : 4) + (o.isImportedListing ? 2 : 0) + (o.hasListedPrice ? 0 : 1);
    list.sort((a, b) {
      final c = rank(a).compareTo(rank(b));
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    return list.take(max).toList();
  }

  /// Tin liên quan: các tin khác trong dòng tin, tin cùng loại đứng trước (giữ thứ tự mới nhất trước).
  static List<NewsEntry> relatedEntries(NewsEntry current, List<NewsEntry> all, {int max = 3}) {
    final others = all.where((e) => e.id != current.id).toList();
    final same = others.where((e) => e.kind == current.kind);
    final rest = others.where((e) => e.kind != current.kind);
    return [...same, ...rest].take(max).toList();
  }

  /// Ngày giờ đầy đủ: "20:03 · 21/11/2026".
  static String fullDate(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)} · ${two(t.day)}/${two(t.month)}/${t.year}';
  }

  /// "Vừa xong", "5 phút trước", "3 giờ trước", "2 ngày trước", hoặc ngày đầy đủ nếu đã quá 7 ngày.
  static String ago(DateTime t, DateTime now) {
    final d = now.difference(t);
    if (d.isNegative || d.inMinutes < 1) return 'Vừa xong';
    if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
    if (d.inHours < 24) return '${d.inHours} giờ trước';
    if (d.inDays < 7) return '${d.inDays} ngày trước';
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
  }

  /// Nhãn nhóm theo ngày: "Hôm nay", "Hôm qua", "Thứ ba, 17/11".
  static String dayLabel(DateTime t, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    const names = ['Thứ hai', 'Thứ ba', 'Thứ tư', 'Thứ năm', 'Thứ sáu', 'Thứ bảy', 'Chủ nhật'];
    return '${names[day.weekday - 1]}, ${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';
  }
}
