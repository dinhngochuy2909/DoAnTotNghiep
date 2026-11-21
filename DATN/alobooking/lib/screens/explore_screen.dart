import 'package:flutter/material.dart';

import '../models/news_post.dart';
import '../models/venue.dart';
import '../services/firestore_service.dart';
import '../services/news_feed.dart';
import '../widgets/venue_image_view.dart';
import 'venue_detail_screen.dart';

/// Dữ liệu một lần tải dòng tin: tin admin đăng, đánh giá của khách, và cờ báo tải lỗi một phần/toàn bộ.
typedef NewsBundle = ({List<NewsPost> posts, List<ReviewItem> reviews, bool failed});
typedef NewsLoader = Future<NewsBundle> Function();

Future<NewsBundle> _loadFromFirestore() async {
  FirestoreService.lastLoadFailed = false;
  final r = await Future.wait<Object?>([FirestoreService.getNews(), FirestoreService.getAllReviews()]);
  return (
    posts: r[0] as List<NewsPost>,
    reviews: r[1] as List<ReviewItem>,
    failed: FirestoreService.lastLoadFailed,
  );
}

/// Màn hình KHÁM PHÁ: dòng tin cập nhật những điều mới của AloBooking — ưu đãi, sự kiện, thông báo do admin đăng,
/// cùng sân mới được duyệt và đánh giá mới của khách (tự sinh từ dữ liệu thật, không có tin nào bịa).
class ExploreScreen extends StatefulWidget {
  final List<Venue> venues;

  /// Chỉ dùng khi kiểm thử: thay cho việc đọc Firestore / đồng hồ hệ thống.
  final NewsLoader? newsLoader;
  final DateTime? now;

  const ExploreScreen({super.key, required this.venues, this.newsLoader, this.now});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const _green = Color(0xFF15803D);
  static const _ink = Color(0xFF0F172A);
  static const _grey = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);

  /// Màu nhãn từng loại tin: (màu nhấn, màu chữ đậm hơn để đủ tương phản trên nền nhạt, biểu tượng).
  static const _style = <NewsKind, (Color, Color, IconData)>{
    NewsKind.promo: (Color(0xFFF97316), Color(0xFFC2410C), Icons.local_offer_outlined),
    NewsKind.event: (Color(0xFF8B5CF6), Color(0xFF6D28D9), Icons.event_outlined),
    NewsKind.update: (Color(0xFF16A34A), Color(0xFF15803D), Icons.new_releases_outlined),
    NewsKind.notice: (Color(0xFF2563EB), Color(0xFF1D4ED8), Icons.campaign_outlined),
    NewsKind.newVenue: (Color(0xFF0D9488), Color(0xFF0F766E), Icons.stadium_outlined),
    NewsKind.review: (Color(0xFFF59E0B), Color(0xFFB45309), Icons.star_outline_rounded),
  };

  /// Thứ tự các nhãn lọc.
  static const _filterOrder = [
    NewsKind.promo,
    NewsKind.event,
    NewsKind.newVenue,
    NewsKind.update,
    NewsKind.notice,
    NewsKind.review,
  ];

  /// Nội dung dài hơn mức này thì thu gọn và có nút "Xem thêm".
  static const _collapseOver = 200;

  late DateTime _now;
  bool _loading = true;
  bool _failed = false;
  List<NewsEntry> _entries = const [];
  NewsKind? _kind;
  final Set<String> _expanded = {};

  late final Map<int, Venue> _venueById = {for (final v in widget.venues) v.id: v};

  @override
  void initState() {
    super.initState();
    _now = widget.now ?? DateTime.now();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    NewsBundle b;
    try {
      b = await (widget.newsLoader ?? _loadFromFirestore)();
    } catch (_) {
      b = (posts: const <NewsPost>[], reviews: const <ReviewItem>[], failed: true);
    }
    if (!mounted) return;
    final now = widget.now ?? DateTime.now();
    setState(() {
      _now = now;
      _failed = b.failed;
      _entries = NewsFeed.build(posts: b.posts, venues: widget.venues, reviews: b.reviews, now: now);
      _loading = false;
    });
  }

  List<NewsEntry> get _visible => _kind == null ? _entries : _entries.where((e) => e.kind == _kind).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('KHÁM PHÁ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, fontStyle: FontStyle.italic)),
        actions: [
          IconButton(
            key: const ValueKey('news-refresh'),
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading && _entries.isEmpty
          ? const Center(child: CircularProgressIndicator(key: ValueKey('news-loading'), color: _green))
          : RefreshIndicator(
              color: _green,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    sliver: SliverList(delegate: SliverChildListDelegate(_items())),
                  ),
                ],
              ),
            ),
    );
  }

  /// Giữ cột tin ở bề rộng dễ đọc trên màn hình lớn.
  Widget _narrow(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SizedBox(width: double.infinity, child: child),
        ),
      );

  List<Widget> _items() {
    final out = <Widget>[
      _narrow(_intro()),
      _narrow(_filters()),
    ];
    if (_failed && _entries.isNotEmpty) out.add(_narrow(_failedBanner()));

    final list = _visible;
    if (list.isEmpty) {
      out.add(_narrow(_emptyState()));
      return out;
    }

    final pinned = list.where((e) => e.pinned).toList();
    if (pinned.isNotEmpty) {
      out.add(_narrow(_heading('Tin ghim', icon: Icons.push_pin_outlined)));
      for (final e in pinned) {
        out.add(_narrow(_card(e)));
      }
    }

    String? lastDay;
    for (final e in list.where((e) => !e.pinned)) {
      final day = NewsFeed.dayLabel(e.time, _now);
      final key = '${e.time.year}-${e.time.month}-${e.time.day}';
      if (key != lastDay) {
        out.add(_narrow(_heading(day)));
        lastDay = key;
      }
      out.add(_narrow(_card(e)));
    }
    return out;
  }

  Widget _intro() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Có gì mới ở AloBooking', style: TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            _loading ? 'Đang cập nhật…' : '${_entries.length} tin gần đây: ưu đãi, sự kiện, sân mới và đánh giá của khách.',
            style: const TextStyle(color: _grey, fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    int count(NewsKind k) => _entries.where((e) => e.kind == k).length;
    Widget chip(String key, String label, int n, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          key: ValueKey(key),
          label: Text('$label ($n)'),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
          selectedColor: _green,
          backgroundColor: Colors.white,
          side: BorderSide(color: selected ? _green : _line),
          labelStyle: TextStyle(color: selected ? Colors.white : _ink, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SingleChildScrollView(
        key: const ValueKey('news-chips'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('news-chip-all', 'Tất cả', _entries.length, _kind == null, () => setState(() => _kind = null)),
            for (final k in _filterOrder) chip('news-chip-${k.name}', k.label, count(k), _kind == k, () => setState(() => _kind = k)),
          ],
        ),
      ),
    );
  }

  Widget _heading(String text, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: _grey), const SizedBox(width: 6)],
          Text(text, style: const TextStyle(color: _grey, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
        ],
      ),
    );
  }

  Widget _failedBanner() {
    return Container(
      key: const ValueKey('news-failed-banner'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFCD34D))),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text('Một số tin chưa tải được nên danh sách có thể chưa đầy đủ. Kéo xuống hoặc bấm làm mới để thử lại.',
                style: TextStyle(color: Color(0xFF78350F), fontSize: 12.5, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final String key;
    final String title;
    final String sub;
    final IconData icon;
    if (_entries.isEmpty && _failed) {
      key = 'news-error';
      icon = Icons.cloud_off_rounded;
      title = 'Không tải được tin';
      sub = 'Kiểm tra kết nối mạng rồi thử lại.';
    } else if (_entries.isEmpty) {
      key = 'news-empty';
      icon = Icons.newspaper_rounded;
      title = 'Chưa có tin mới';
      sub = 'Ưu đãi và sự kiện do AloBooking đăng, sân mới được duyệt và đánh giá mới của khách sẽ hiện ở đây.';
    } else {
      key = 'news-empty-filter';
      icon = Icons.filter_list_off_rounded;
      title = 'Chưa có tin thuộc loại "${_kind?.label ?? ''}"';
      sub = 'Chọn "Tất cả" để xem mọi tin.';
    }
    return Container(
      key: ValueKey(key),
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(icon, size: 40, color: _grey),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: _grey, fontSize: 13.5, height: 1.45)),
          if (key == 'news-error') ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('news-retry'),
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(backgroundColor: _green),
            ),
          ],
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      );

  Widget _card(NewsEntry e) {
    final style = _style[e.kind]!;
    final venue = e.venueId == 0 ? null : _venueById[e.venueId];
    final expanded = _expanded.contains(e.id);
    final long = e.body.length > _collapseOver || '\n'.allMatches(e.body).length >= 4;
    final hasImage = e.imageUrl.trim().isNotEmpty;

    return Container(
      key: ValueKey('news-card-${e.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            AspectRatio(
              aspectRatio: 16 / 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VenueImageView(imageUrl: e.imageUrl),
                  // Ảnh sân lấy từ kho ảnh minh họa thì nói rõ, không để khách tưởng là ảnh thật của sân.
                  if (e.kind == NewsKind.newVenue && venue != null && venue.hasStockImage)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                        child: const Text('Ảnh minh họa', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: style.$1.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(style.$3, size: 14, color: style.$2),
                          const SizedBox(width: 4),
                          Text(e.kind.label, style: TextStyle(color: style.$2, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    if (e.pinned) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.push_pin, size: 14, color: _grey),
                    ],
                    const Spacer(),
                    Text(NewsFeed.ago(e.time, _now), style: const TextStyle(color: _grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(e.title, style: const TextStyle(color: _ink, fontSize: 16.5, fontWeight: FontWeight.w800, height: 1.3)),
                if (e.stars > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(i <= e.stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: const Color(0xFFF59E0B)),
                    ],
                  ),
                ],
                if (e.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    e.body.trim(),
                    maxLines: expanded || !long ? null : 4,
                    overflow: expanded || !long ? TextOverflow.clip : TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF334155), fontSize: 14, height: 1.5),
                  ),
                  if (long)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: ValueKey('news-more-${e.id}'),
                        onPressed: () => setState(() => expanded ? _expanded.remove(e.id) : _expanded.add(e.id)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), foregroundColor: _green),
                        child: Text(expanded ? 'Thu gọn' : 'Xem thêm', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
                if (venue != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: _line)),
                    child: Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 16, color: _grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(venue.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        TextButton(
                          key: ValueKey('news-venue-${e.id}'),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VenueDetailScreen(venue: venue))),
                          style: TextButton.styleFrom(foregroundColor: _green),
                          child: const Text('Xem sân', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  e.isAuto ? 'Tự động từ dữ liệu AloBooking' : 'Đăng bởi ${e.byline}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
