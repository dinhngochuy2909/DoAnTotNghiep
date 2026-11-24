import 'dart:async';

import 'package:flutter/material.dart';

import '../data/venue_photos.dart';
import '../models/news_post.dart';
import '../models/venue.dart';
import '../services/booking_slots.dart';
import '../services/explore_highlights.dart';
import '../services/firestore_service.dart';
import '../services/news_feed.dart';
import '../services/weather_service.dart';
import '../widgets/news_visuals.dart';
import '../widgets/venue_image_view.dart';
import 'news_detail_screen.dart';
import 'venue_detail_screen.dart';
import 'venue_finder_screen.dart';

/// Dữ liệu một lần tải dòng tin: tin admin đăng, đánh giá của khách, và cờ báo tải lỗi một phần/toàn bộ.
typedef NewsBundle = ({
  List<NewsPost> posts,
  List<ReviewItem> reviews,
  bool failed,
});
typedef NewsLoader = Future<NewsBundle> Function();
typedef WeatherLoader = Future<WeatherData> Function();

Future<NewsBundle> _loadFromFirestore() async {
  FirestoreService.lastLoadFailed = false;
  final r = await Future.wait<Object?>([
    FirestoreService.getNews(),
    FirestoreService.getAllReviews(),
  ]);
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
  final WeatherLoader? weatherLoader;
  final DateTime? now;

  const ExploreScreen({
    super.key,
    required this.venues,
    this.newsLoader,
    this.weatherLoader,
    this.now,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const _green = Color(0xFF15803D);
  static const _ink = Color(0xFF0F172A);
  static const _grey = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);

  /// Ảnh nền banner đầu trang: một ảnh minh họa trong kho (sân bóng đá buổi tối).
  static final String _heroPhoto = VenuePhotos.pick(
    'football',
    23,
  ).replaceFirst('w=800&h=450', 'w=1200&h=520');

  /// Thứ tự các nhãn lọc.
  static const _filterOrder = [
    NewsKind.promo,
    NewsKind.event,
    NewsKind.newVenue,
    NewsKind.update,
    NewsKind.notice,
    NewsKind.sport,
    NewsKind.review,
  ];

  /// Nội dung dài hơn mức này thì thu gọn và có nút "Xem thêm".
  static const _collapseOver = 200;

  late DateTime _now;

  /// Đồng hồ cập nhật mỗi 30 giây cho thẻ giờ vàng và lời chào (không dùng cho nhãn "x giờ trước" của tin).
  late DateTime _clock;
  Timer? _tick;
  bool _loading = true;
  bool _failed = false;
  List<NewsEntry> _entries = const [];
  List<ReviewItem> _reviews = const [];
  List<FeaturedVenue> _featured = const [];
  WeatherData? _weather;
  NewsKind? _kind;
  final Set<String> _expanded = {};

  late final Map<int, Venue> _venueById = {
    for (final v in widget.venues) v.id: v,
  };

  @override
  void initState() {
    super.initState();
    _now = widget.now ?? DateTime.now();
    _clock = _now;
    // Khi kiểm thử đã cố định giờ thì không chạy đồng hồ.
    if (widget.now == null) {
      _tick = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() => _clock = DateTime.now());
      });
    }
    _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Thời tiết thật của Hà Nội cho lời chào ở banner. Tải riêng, lỗi thì chỉ ẩn phần thời tiết.
  Future<void> _loadWeather() async {
    try {
      final w =
          await (widget.weatherLoader ?? WeatherService.getCurrentWeather)();
      if (mounted) setState(() => _weather = w);
    } catch (_) {}
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    _loadWeather();
    NewsBundle b;
    try {
      b = await (widget.newsLoader ?? _loadFromFirestore)();
    } catch (_) {
      b = (
        posts: const <NewsPost>[],
        reviews: const <ReviewItem>[],
        failed: true,
      );
    }
    if (!mounted) return;
    final now = widget.now ?? DateTime.now();
    setState(() {
      _now = now;
      _failed = b.failed;
      _reviews = b.reviews;
      _featured = ExploreHighlights.featured(
        venues: widget.venues,
        reviews: b.reviews,
      );
      _entries = NewsFeed.build(
        posts: b.posts,
        venues: widget.venues,
        reviews: b.reviews,
        now: now,
      );
      _loading = false;
    });
  }

  List<NewsEntry> get _visible => _kind == null
      ? _entries
      : _entries.where((e) => e.kind == _kind).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'KHÁM PHÁ',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          IconButton(
            key: const ValueKey('news-refresh'),
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
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
    // Lần tải đầu chưa có tin: banner và khung xương thay cho vòng quay trống trơn.
    if (_loading && _entries.isEmpty)
      return [_narrow(_hero()), _narrow(_skeleton())];

    final out = <Widget>[
      _narrow(_hero()),
      if (!_loading) _narrow(_stats()),
      if (!_loading && _kind == null) ...[
        _narrow(_planSection()),
        _narrow(_sportTiles()),
        if (_featured.isNotEmpty) _narrow(_featuredSection()),
      ],
      _narrow(_filters()),
    ];
    if (_failed && _entries.isNotEmpty) out.add(_narrow(_failedBanner()));

    final list = _visible;
    if (list.isEmpty) {
      out.add(_narrow(_emptyState()));
      return out;
    }

    // Tin đứng đầu danh sách (nếu có ảnh bìa) được trình bày lớn hơn để thành điểm nhấn.
    final featuredId = list.first.kind == NewsKind.review
        ? null
        : list.first.id;

    var revealIndex = 0;
    final pinned = list.where((e) => e.pinned).toList();
    if (pinned.isNotEmpty) {
      out.add(_narrow(_heading('Tin ghim', icon: Icons.push_pin_outlined)));
      for (final e in pinned) {
        out.add(
          _narrow(
            _Reveal(
              key: ValueKey('reveal-${e.id}'),
              index: revealIndex++,
              child: _card(e, featured: e.id == featuredId),
            ),
          ),
        );
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
      out.add(
        _narrow(
          _Reveal(
            key: ValueKey('reveal-${e.id}'),
            index: revealIndex++,
            child: _card(e, featured: e.id == featuredId),
          ),
        ),
      );
    }
    return out;
  }

  /// Banner đầu trang: ảnh nền, lời chào theo giờ, thời tiết thật của Hà Nội kèm gợi ý ra sân, số tin hiện có.
  /// Thời tiết chỉ hiện khi lấy được dữ liệu thật; không bao giờ hiện số đoán.
  Widget _hero() {
    final fallback = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF166534), Color(0xFF0D9488)],
        ),
      ),
    );
    final w = _weather;
    final weather = w == null ? null : ExploreHighlights.weatherChip(w);
    final tip = w == null ? null : ExploreHighlights.weatherTip(w);
    final evening = _clock.hour < 5 || _clock.hour >= 18;

    Widget pill(Widget child, {Key? key}) => Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );

    return Container(
      key: const ValueKey('news-hero'),
      constraints: const BoxConstraints(minHeight: 176),
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33166534),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: VenueImageView(imageUrl: _heroPhoto, errorWidget: fallback),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xE6064E3B),
                    Color(0xB3166534),
                    Color(0x33000000),
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // chừa chỗ bên phải cho nhãn "Ảnh minh họa" ở góc trên, tránh đè lên viên thời tiết
                  Padding(
                    padding: const EdgeInsets.only(right: 96),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        pill(
                          key: const ValueKey('news-greeting'),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                evening
                                    ? Icons.nights_stay_rounded
                                    : Icons.wb_sunny_rounded,
                                size: 14,
                                color: const Color(0xFFFDE047),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                ExploreHighlights.greeting(_clock),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (weather != null)
                          pill(
                            key: const ValueKey('news-weather'),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Hà Nội · ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SkyIcon(w!.sky, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  weather,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Có gì mới ở AloBooking',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _loading
                        ? 'Đang cập nhật…'
                        : (_failed && _entries.isEmpty
                              ? 'Chưa tải được tin. Kéo xuống hoặc bấm làm mới để thử lại.'
                              : '${_entries.length} tin gần đây: ưu đãi, sự kiện, sân mới và đánh giá của khách.'),
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                  if (tip != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 15,
                            color: Color(0xFFFDE047),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tip,
                            key: const ValueKey('news-weather-tip'),
                            style: const TextStyle(
                              color: Color(0xFFFEF9C3),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Positioned(right: 8, top: 8, child: StockPhotoLabel()),
        ],
      ),
    );
  }

  /// Khung xương hiện trong lúc tải tin lần đầu: nhấp nháy nhẹ, báo trước hình dáng của thẻ tin.
  Widget _skeleton() {
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(6),
      ),
    );
    Widget card() => Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 7,
            child: Container(color: const Color(0xFFE2E8F0)),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(200, 16),
                const SizedBox(height: 10),
                LayoutBuilder(builder: (_, c) => bar(c.maxWidth, 12)),
                const SizedBox(height: 6),
                LayoutBuilder(builder: (_, c) => bar(c.maxWidth * 0.7, 12)),
              ],
            ),
          ),
        ],
      ),
    );
    return _Pulse(
      key: const ValueKey('news-loading'),
      child: Column(children: [card(), card()]),
    );
  }

  static const _gold = Color(0xFFF59E0B);

  /// Tên đầy đủ của ngày trong lịch thời tiết: "Hôm nay", "Ngày mai", "Thứ ba, 24/11".
  String _dayName(DateTime d) {
    final today = DateTime(_clock.year, _clock.month, _clock.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Ngày mai';
    const names = [
      'Thứ hai',
      'Thứ ba',
      'Thứ tư',
      'Thứ năm',
      'Thứ sáu',
      'Thứ bảy',
      'Chủ nhật',
    ];
    return '${names[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  /// Khối "Lên kế hoạch ra sân": đồng hồ giờ vàng hôm nay và (khi có thời tiết thật) lịch 7 ngày.
  Widget _planSection() {
    final week = _weekStrip();
    return Column(
      key: const ValueKey('news-plan'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Lên kế hoạch ra sân', icon: Icons.event_available_outlined),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _goldenCard(),
              if (week != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: _line),
                ),
                week,
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _goldenCard() {
    final g = ExploreHighlights.goldenStatus(_clock);
    final during = g.phase == GoldenPhase.during;
    return Column(
      key: const ValueKey('news-golden'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wb_twilight_rounded,
                color: _gold,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Giờ vàng hôm nay',
                    style: TextStyle(
                      color: _grey,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ExploreHighlights.goldenMessage(g),
                    key: const ValueKey('news-golden-message'),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            const start = BookingSlots.goldenStartHour / 24;
            const end = BookingSlots.goldenEndHour / 24;
            double x(double f) => w * f;
            Widget tick(double f, String label) => Positioned(
              left: (x(f) - 14).clamp(0, w - 28),
              top: 22,
              width: 28,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _grey, fontSize: 10.5),
              ),
            );
            return SizedBox(
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 8,
                    height: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _line,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  Positioned(
                    left: x(start),
                    width: x(end - start),
                    top: 8,
                    height: 10,
                    child: Container(
                      key: const ValueKey('news-golden-window'),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFBBF24),
                            Color(0xFFF59E0B),
                            Color(0xFFEA580C),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  tick(6 / 24, '6h'),
                  tick(12 / 24, '12h'),
                  tick(start, '${BookingSlots.goldenStartHour}h'),
                  tick(end, '${BookingSlots.goldenEndHour}h'),
                  Positioned(
                    left: (x(g.dayFraction) - 8).clamp(0, w - 16),
                    top: 5,
                    child: Container(
                      key: const ValueKey('news-golden-now'),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: during ? _gold : _ink,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(color: Color(0x40000000), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          'Ca giờ vàng ${BookingSlots.goldenLabel} có giá cao hơn một chút so với giờ thường.',
          style: const TextStyle(color: _grey, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const ValueKey('news-golden-find'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VenueFinderScreen(venues: widget.venues),
            ),
          ),
          icon: const Icon(Icons.search_rounded, size: 18),
          label: const Text(
            'Tìm sân còn trống',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: TextButton.styleFrom(
            foregroundColor: _green,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
  }

  /// Lịch thời tiết 7 ngày từ dữ liệu thật; null khi không lấy được thời tiết thật.
  Widget? _weekStrip() {
    final w = _weather;
    if (w == null || !w.isLive || w.daily.isEmpty) return null;
    final days = w.daily;
    final best = ExploreHighlights.bestDay(days);
    final today = DateTime(_clock.year, _clock.month, _clock.day);

    const tagText = {
      RainTag.fine: 'Đẹp trời',
      RainTag.maybe: 'Có thể mưa',
      RainTag.likely: 'Dễ mưa',
    };
    const tagColor = {
      RainTag.fine: Color(0xFF15803D),
      RainTag.maybe: Color(0xFFB45309),
      RainTag.likely: Color(0xFFB91C1C),
    };

    return Column(
      key: const ValueKey('news-week'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.calendar_month_outlined, size: 18, color: _green),
            SizedBox(width: 8),
            Text(
              'Ngày nào ra sân đẹp?',
              style: TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = days[i];
              final tag = ExploreHighlights.rainTag(d);
              final isBest = identical(d, best);
              final isToday =
                  DateTime(d.date.year, d.date.month, d.date.day) == today;
              return Container(
                key: ValueKey(
                  'news-day-${d.date.year}-${d.date.month}-${d.date.day}',
                ),
                width: 82,
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isBest ? const Color(0xFFF0FDF4) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isBest ? const Color(0xFF16A34A) : _line,
                    width: isBest ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      isToday ? 'Hôm nay' : ExploreHighlights.dayShort(d.date),
                      style: TextStyle(
                        color: _ink,
                        fontSize: 12.5,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${d.date.day.toString().padLeft(2, '0')}/${d.date.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: _grey, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 28,
                      child: Center(child: SkyIcon(d.sky, size: 24)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.tempMax.round()}°/${d.tempMin.round()}°',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.water_drop_outlined,
                          size: 12,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${d.rainProb}%',
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      tagText[tag]!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: tagColor[tag],
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isBest)
                      const Text(
                        '★ Đẹp nhất',
                        style: TextStyle(
                          color: Color(0xFF15803D),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          best == null
              ? 'Tuần này ngày nào cũng có khả năng mưa từ 40%: hãy ưu tiên sân có mái che.'
              : 'Ngày đẹp nhất để ra sân: ${_dayName(best.date)} (khả năng mưa ${best.rainProb}%).',
          key: const ValueKey('news-week-best'),
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  /// Ô "Khám phá theo môn": ảnh minh họa, số địa điểm thật của môn đó; bấm mở màn tìm sân với môn đã chọn.
  Widget _sportTiles() {
    final counts = ExploreHighlights.countBySport(widget.venues);
    if (counts.values.every((n) => n == 0)) return const SizedBox.shrink();
    const sports = [
      ('badminton', 'Cầu lông', 21),
      ('pickleball', 'Pickleball', 7),
      ('tennis', 'Tennis', 33),
      ('football', 'Bóng đá', 20),
      ('basketball', 'Bóng rổ', 24),
    ];
    return Column(
      key: const ValueKey('news-sports'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Khám phá theo môn', icon: Icons.sports_tennis_outlined),
        SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sports.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final (type, name, photo) = sports[i];
              final n = counts[type] ?? 0;
              return InkWell(
                key: ValueKey('news-sport-$type'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VenueFinderScreen(
                      venues: widget.venues,
                      initialSport: type,
                    ),
                  ),
                ),
                child: Container(
                  width: 138,
                  clipBehavior: Clip.antiAlias,
                  decoration: _cardDecoration().copyWith(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _HoverZoom(
                        child: VenueImageView(
                          imageUrl: VenuePhotos.pick(type, photo),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00000000),
                              Color(0x00000000),
                              Color(0xCC000000),
                            ],
                            stops: [0, 0.4, 1],
                          ),
                        ),
                      ),
                      const Positioned(
                        right: 6,
                        top: 6,
                        child: StockPhotoLabel(),
                      ),
                      Positioned(
                        left: 12,
                        right: 8,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '$n địa điểm',
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  /// Dải "Sân nổi bật": vuốt ngang. Mỗi sân kèm đúng lý do và con số lấy từ dữ liệu thật.
  Widget _featuredSection() {
    const kindStyle = {
      FeaturedKind.rated: (Color(0xFFF59E0B), Icons.star_rounded),
      FeaturedKind.cheapest: (Color(0xFF16A34A), Icons.sell_outlined),
      FeaturedKind.mostCourts: (Color(0xFF2563EB), Icons.grid_view_rounded),
    };
    return Column(
      key: const ValueKey('news-featured'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Sân nổi bật', icon: Icons.local_fire_department_outlined),
        SizedBox(
          height: 228,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _featured.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final f = _featured[i];
              final v = f.venue;
              final st = kindStyle[f.kind]!;
              return InkWell(
                key: ValueKey('news-featured-${v.id}'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VenueDetailScreen(venue: v),
                  ),
                ),
                child: Container(
                  width: 236,
                  clipBehavior: Clip.antiAlias,
                  decoration: _cardDecoration().copyWith(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 118,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _HoverZoom(
                              child: VenueImageView(imageUrl: v.displayImage),
                            ),
                            Positioned(
                              left: 8,
                              top: 8,
                              right: 8,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: st.$1,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        st.$2,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          f.reason,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (v.hasStockImage)
                              const Positioned(
                                right: 6,
                                bottom: 6,
                                child: StockPhotoLabel(),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  size: 13,
                                  color: _grey,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    v.district.trim().isEmpty
                                        ? Venue.courtLabel(v.type)
                                        : '${Venue.courtLabel(v.type)} · ${v.district.trim()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              f.detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _green,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// Dải số liệu tổng quan, đếm từ dữ liệu thật (không có số nào nhập tay).
  Widget _stats() {
    final st = NewsFeed.stats(widget.venues, _reviews);
    if (st.places == 0) return const SizedBox.shrink();
    Widget tile(String key, IconData icon, Color color, int n, String label) =>
        Container(
          key: ValueKey(key),
          width: 156,
          height: 80,
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 21, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _fmt(n),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _grey,
                        fontSize: 11.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('AloBooking trong số liệu', icon: Icons.insights_outlined),
        SingleChildScrollView(
          key: const ValueKey('news-stats'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              tile(
                'news-stat-places',
                Icons.stadium_outlined,
                _green,
                st.places,
                'Địa điểm sân',
              ),
              tile(
                'news-stat-areas',
                Icons.map_outlined,
                const Color(0xFF2563EB),
                st.districts,
                'Khu vực có sân',
              ),
              tile(
                'news-stat-sports',
                Icons.sports_tennis_rounded,
                const Color(0xFFEA580C),
                st.sports,
                'Môn thể thao',
              ),
              tile(
                'news-stat-reviews',
                Icons.star_rounded,
                const Color(0xFFD97706),
                st.reviews,
                'Đánh giá của khách',
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _filters() {
    int count(NewsKind k) => _entries.where((e) => e.kind == k).length;
    Widget chip(
      String key,
      String label,
      int n,
      bool selected,
      VoidCallback onTap, {
      required IconData icon,
      required Color iconColor,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          key: ValueKey(key),
          avatar: Icon(
            icon,
            size: 16,
            color: selected ? Colors.white : iconColor,
          ),
          label: Text('$label ($n)'),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
          selectedColor: _green,
          backgroundColor: Colors.white,
          side: BorderSide(color: selected ? _green : _line),
          labelStyle: TextStyle(
            color: selected ? Colors.white : _ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
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
            chip(
              'news-chip-all',
              'Tất cả',
              _entries.length,
              _kind == null,
              () => setState(() => _kind = null),
              icon: Icons.apps_rounded,
              iconColor: _green,
            ),
            for (final k in _filterOrder)
              chip(
                'news-chip-${k.name}',
                k.label,
                count(k),
                _kind == k,
                () => setState(() => _kind = k),
                icon: NewsKindStyle.of(k).icon,
                iconColor: NewsKindStyle.of(k).strong,
              ),
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
          if (icon != null) ...[
            Icon(icon, size: 16, color: _grey),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: const TextStyle(
              color: _grey,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _failedBanner() {
    return Container(
      key: const ValueKey('news-failed-banner'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Một số tin chưa tải được nên danh sách có thể chưa đầy đủ. Kéo xuống hoặc bấm làm mới để thử lại.',
              style: TextStyle(
                color: Color(0xFF78350F),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
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
      sub = FirestoreService.lastLoadFailed ? FirestoreService.failureMessage() : 'Kiểm tra kết nối mạng rồi thử lại.';
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
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _grey, fontSize: 13.5, height: 1.45),
          ),
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
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _line),
    boxShadow: const [
      BoxShadow(color: Color(0x0F0F172A), blurRadius: 14, offset: Offset(0, 6)),
    ],
  );

  void _open(NewsEntry e, Venue? venue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(
          entry: e,
          venue: venue,
          now: _now,
          venues: widget.venues,
          reviews: _reviews,
          entries: _entries,
        ),
      ),
    );
  }

  Widget _venueStrip(NewsEntry e, Venue venue) {
    final sub = [
      Venue.courtLabel(venue.type),
      if (venue.district.trim().isNotEmpty) venue.district.trim(),
      if (venue.hasStockImage) 'ảnh minh họa',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: VenueImageView(imageUrl: venue.displayImage),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _grey, fontSize: 11.5),
                ),
              ],
            ),
          ),
          TextButton(
            key: ValueKey('news-venue-${e.id}'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VenueDetailScreen(venue: venue),
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: _green),
            child: const Text(
              'Xem sân',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(NewsEntry e, {bool featured = false}) {
    final style = NewsKindStyle.of(e.kind);
    final venue = e.venueId == 0 ? null : _venueById[e.venueId];
    final expanded = _expanded.contains(e.id);
    final long =
        e.body.length > _collapseOver || '\n'.allMatches(e.body).length >= 4;
    final isReview = e.kind == NewsKind.review;
    // Ảnh bìa: ảnh của tin; không có thì dùng ảnh của sân gắn kèm; không có nữa thì nền chuyển sắc theo loại tin.
    // Đánh giá của khách không dùng ảnh bìa lớn, chỉ có ảnh nhỏ của sân ở dải bên dưới.
    final coverUrl = newsCoverUrl(e, venue);

    return Container(
      key: ValueKey('news-card-${e.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isReview)
            InkWell(
              key: ValueKey('news-cover-${e.id}'),
              onTap: () => _open(e, venue),
              child: _HoverZoom(
                child: NewsCover(
                  kind: e.kind,
                  imageUrl: coverUrl,
                  aspectRatio: featured ? 16 / 8 : 16 / 7,
                  timeLabel: NewsFeed.ago(e.time, _now),
                  pinned: e.pinned,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isReview) ...[
                  Row(
                    children: [
                      NewsKindBadge(kind: e.kind),
                      if (e.pinned) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.push_pin, size: 14, color: style.strong),
                      ],
                      const Spacer(),
                      Text(
                        NewsFeed.ago(e.time, _now),
                        style: const TextStyle(color: _grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                InkWell(
                  key: ValueKey('news-open-${e.id}'),
                  onTap: () => _open(e, venue),
                  child: Text(
                    e.title,
                    style: TextStyle(
                      color: _ink,
                      fontSize: featured ? 19 : 16.5,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                ),
                if (e.stars > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= e.stars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 18,
                          color: const Color(0xFFF59E0B),
                        ),
                    ],
                  ),
                ],
                if (e.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    e.body.trim(),
                    maxLines: expanded || !long ? null : 4,
                    overflow: expanded || !long
                        ? TextOverflow.clip
                        : TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  if (long)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: ValueKey('news-more-${e.id}'),
                        onPressed: () => setState(
                          () => expanded
                              ? _expanded.remove(e.id)
                              : _expanded.add(e.id),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          foregroundColor: _green,
                        ),
                        child: Text(
                          expanded ? 'Thu gọn' : 'Xem thêm',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
                if (venue != null) ...[
                  const SizedBox(height: 10),
                  _venueStrip(e, venue),
                ],
                const SizedBox(height: 10),
                Text(
                  e.creditLine,
                  key: ValueKey('news-credit-${e.id}'),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ hiện dần (mờ -> rõ, trượt lên nhẹ) với độ trễ theo thứ tự; thẻ ở xa chỉ chạy khi cuộn tới.
/// Người dùng bật "giảm chuyển động" thì hiện ngay, không hiệu ứng.
class _Reveal extends StatelessWidget {
  final int index;
  final Widget child;

  const _Reveal({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final delay = index.clamp(0, 5) * 80;
    final total = 420 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 18),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Phóng ảnh lên một chút khi rê chuột (máy tính), tự cắt phần tràn.
class _HoverZoom extends StatefulWidget {
  final Widget child;

  const _HoverZoom({required this.child});

  @override
  State<_HoverZoom> createState() => _HoverZoomState();
}

class _HoverZoomState extends State<_HoverZoom> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: ClipRect(
        child: AnimatedScale(
          scale: _hover ? 1.05 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Nhấp nháy nhẹ cho khung xương khi đang tải. Bật "giảm chuyển động" thì đứng yên.
class _Pulse extends StatefulWidget {
  final Widget child;

  const _Pulse({super.key, required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}
