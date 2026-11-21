import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/models/news_post.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/screens/explore_screen.dart';
import 'package:alobooking/screens/venue_detail_screen.dart';
import 'package:alobooking/services/firestore_service.dart';

/// Hôm nay giả định: thứ bảy 21/11/2026, 10:30.
final _now = DateTime(2026, 11, 21, 10, 30);

Venue _v(int id, String name, {DateTime? approvedAt, String source = ''}) => Venue(
      id: id,
      name: name,
      type: 'badminton',
      district: 'Cầu Giấy',
      distance: '',
      address: '$id Phố Thử, Cầu Giấy, Hà Nội',
      hours: '06:00 – 22:00',
      tags: const [],
      rating: 4.5,
      price: '80k - 100k/h',
      lat: 21.0,
      lng: 105.8,
      image: '',
      logo: '',
      source: source,
      approvedAt: approvedAt,
    );

NewsPost _p(String id, String title, DateTime at, {String category = 'promo', bool pinned = false, int venueId = 0, String body = 'Nội dung ngắn'}) =>
    NewsPost(id: id, title: title, body: body, category: category, pinned: pinned, venueId: venueId, createdAt: at);

ReviewItem _r(String id, int venueId, DateTime at, {String comment = 'Sân sạch, đèn sáng', String user = 'Lan', int stars = 5}) =>
    ReviewItem(id: id, venueId: venueId, userId: 'u$id', userName: user, stars: stars, comment: comment, createdAt: at);

List<Venue> _venues() => [
      _v(1, 'Sân Alpha', approvedAt: _now.subtract(const Duration(days: 1))),
      _v(2, 'Sân Beta'),
    ];

NewsBundle _bundle({List<NewsPost>? posts, List<ReviewItem>? reviews, bool failed = false}) => (
      posts: posts ??
          [
            _p('ghim', 'Khai trương cụm sân mới', _now.subtract(const Duration(days: 9)), category: 'event', pinned: true),
            _p('km', 'Giảm 20% giờ vàng', _now.subtract(const Duration(hours: 3)), category: 'promo', venueId: 2),
            _p('hq', 'Cập nhật cách đặt sân', _now.subtract(const Duration(days: 1, hours: 2)), category: 'update'),
          ],
      reviews: reviews ?? [_r('r1', 2, _now.subtract(const Duration(hours: 1)), stars: 4)],
      failed: failed,
    );

/// Test mặc định dùng font Ahem nên báo tràn giả; nếu có Segoe UI thì nạp để đo gần thực tế.
Future<bool> _loadRealFont() async {
  final f = File('C:/Windows/Fonts/segoeui.ttf');
  if (!f.existsSync()) return false;
  final loader = FontLoader('TestSans')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
  return true;
}

Future<void> _open(
  WidgetTester tester, {
  List<Venue>? venues,
  NewsLoader? loader,
  Size size = const Size(1280, 3200), // đủ cao để mọi thẻ đều được dựng (danh sách dựng lười)
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'TestSans'),
    home: ExploreScreen(venues: venues ?? _venues(), newsLoader: loader ?? () async => _bundle(), now: _now),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Finder _k(String key) => find.byKey(ValueKey(key));

/// Mã các thẻ tin đang dựng, theo thứ tự từ trên xuống.
List<String> _cardIds(WidgetTester tester) => [
      for (final w in tester.widgetList(find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('news-card-'))))
        '${(w.key as ValueKey).value}'.substring('news-card-'.length),
    ];

void main() {
  var realFont = false;
  setUpAll(() async {
    realFont = await _loadRealFont();
  });

  testWidgets('Hiện vòng tải trước, rồi dòng tin gồm tin ghim, tin admin, sân mới và đánh giá theo thứ tự thời gian', (tester) async {
    final done = Completer<NewsBundle>();
    await _open(tester, loader: () => done.future);
    expect(_k('news-loading'), findsOneWidget);

    done.complete(_bundle());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(_k('news-loading'), findsNothing);
    expect(find.text('Có gì mới ở AloBooking'), findsOneWidget);
    // ghim trước; rồi mới nhất trước: đánh giá (1 giờ), khuyến mãi (3 giờ), sân mới (hôm qua 10:30), cập nhật (hôm qua 8:30)
    expect(_cardIds(tester), ['post-ghim', 'review-r1', 'post-km', 'venue-1', 'post-hq']);
    expect(find.text('Tin ghim'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Hôm qua'), findsOneWidget);
    expect(find.text('5 tin gần đây: ưu đãi, sự kiện, sân mới và đánh giá của khách.'), findsOneWidget);
    if (realFont) expect(tester.takeException(), isNull);
  });

  testWidgets('Nhãn loại, thời gian tương đối, người đăng và dòng "tự động" hiện đúng', (tester) async {
    await _open(tester);
    expect(find.descendant(of: _k('news-card-post-km'), matching: find.text('Ưu đãi')), findsOneWidget);
    expect(find.descendant(of: _k('news-card-post-km'), matching: find.text('3 giờ trước')), findsOneWidget);
    expect(find.descendant(of: _k('news-card-post-km'), matching: find.text('Đăng bởi AloBooking')), findsOneWidget);
    expect(find.descendant(of: _k('news-card-review-r1'), matching: find.text('Tự động từ dữ liệu AloBooking')), findsOneWidget);
    expect(find.descendant(of: _k('news-card-review-r1'), matching: find.text('Lan đánh giá Sân Beta')), findsOneWidget);
    expect(find.descendant(of: _k('news-card-venue-1'), matching: find.text('Sân Alpha vừa lên AloBooking')), findsOneWidget);
    expect(find.descendant(of: _k('news-card-post-ghim'), matching: find.byIcon(Icons.push_pin)), findsOneWidget);
    // đánh giá 4 sao: 4 sao đầy
    expect(find.descendant(of: _k('news-card-review-r1'), matching: find.byIcon(Icons.star_rounded)), findsNWidgets(4));
  });

  testWidgets('Sân mới dùng ảnh kho thì ghi rõ "Ảnh minh họa"', (tester) async {
    await _open(tester);
    expect(find.descendant(of: _k('news-card-venue-1'), matching: find.text('Ảnh minh họa')), findsOneWidget);
    expect(find.descendant(of: _k('news-card-post-km'), matching: find.text('Ảnh minh họa')), findsNothing);
  });

  testWidgets('Chip lọc có số lượng; chọn Ưu đãi chỉ còn tin ưu đãi; loại không có tin báo rõ', (tester) async {
    await _open(tester);
    expect(find.text('Tất cả (5)'), findsOneWidget);
    expect(find.text('Ưu đãi (1)'), findsOneWidget);
    expect(find.text('Sự kiện (1)'), findsOneWidget);
    expect(find.text('Sân mới (1)'), findsOneWidget);
    expect(find.text('Đánh giá (1)'), findsOneWidget);
    expect(find.text('Thông báo (0)'), findsOneWidget);

    await tester.tap(_k('news-chip-promo'));
    await tester.pump();
    expect(_cardIds(tester), ['post-km']);

    await tester.tap(_k('news-chip-notice'));
    await tester.pump();
    expect(_cardIds(tester), isEmpty);
    expect(_k('news-empty-filter'), findsOneWidget);
    expect(find.textContaining('Chưa có tin thuộc loại "Thông báo"'), findsOneWidget);

    await tester.tap(_k('news-chip-all'));
    await tester.pump();
    expect(_cardIds(tester).length, 5);
    expect(_k('news-empty-filter'), findsNothing);
  });

  testWidgets('Chưa có tin nào: báo trống, không bịa tin mẫu', (tester) async {
    await _open(tester, venues: [_v(2, 'Sân Beta')], loader: () async => _bundle(posts: const [], reviews: const []));
    expect(_k('news-empty'), findsOneWidget);
    expect(find.text('Chưa có tin mới'), findsOneWidget);
    expect(_cardIds(tester), isEmpty);
  });

  testWidgets('Tải lỗi hoàn toàn: báo lỗi và nút Thử lại tải lại được', (tester) async {
    var calls = 0;
    // Sân không có ngày duyệt nên không tự sinh "sân mới": mất tin từ máy chủ là hết tin để hiện.
    await _open(tester, venues: [_v(2, 'Sân Beta')], loader: () async {
      calls++;
      return calls == 1 ? _bundle(posts: const [], reviews: const [], failed: true) : _bundle();
    });
    expect(_k('news-error'), findsOneWidget);
    expect(find.text('Không tải được tin'), findsOneWidget);
    expect(_k('news-empty'), findsNothing);

    await tester.tap(_k('news-retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 2);
    expect(_k('news-error'), findsNothing);
    expect(_cardIds(tester).length, 4, reason: '3 tin admin + 1 đánh giá (sân này không có ngày duyệt nên không có "sân mới")');
  });

  testWidgets('Lỗi một phần: vẫn hiện tin đã có kèm dải cảnh báo', (tester) async {
    await _open(tester, loader: () async => _bundle(failed: true));
    expect(_k('news-failed-banner'), findsOneWidget);
    expect(_cardIds(tester).length, 5);
  });

  testWidgets('Loader ném lỗi thì cũng báo lỗi chứ không treo', (tester) async {
    await _open(tester, venues: [_v(2, 'Sân Beta')], loader: () async => throw Exception('mất mạng'));
    expect(_k('news-error'), findsOneWidget);
  });

  testWidgets('Nút làm mới gọi tải lại', (tester) async {
    var calls = 0;
    await _open(tester, loader: () async {
      calls++;
      return _bundle();
    });
    expect(calls, 1);
    await tester.tap(_k('news-refresh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 2);
  });

  testWidgets('Nội dung dài được thu gọn, bấm Xem thêm / Thu gọn', (tester) async {
    final long = List.filled(40, 'Áp dụng cho mọi khung giờ vàng.').join(' ');
    await _open(
      tester,
      loader: () async => _bundle(posts: [_p('dai', 'Tin dài', _now.subtract(const Duration(hours: 1)), body: long)], reviews: const []),
    );
    expect(_k('news-more-post-dai'), findsOneWidget);
    expect(find.text('Xem thêm'), findsOneWidget);
    final collapsed = tester.getSize(_k('news-card-post-dai')).height;

    await tester.tap(_k('news-more-post-dai'));
    await tester.pump();
    expect(find.text('Thu gọn'), findsOneWidget);
    expect(tester.getSize(_k('news-card-post-dai')).height, greaterThan(collapsed));

    await tester.tap(_k('news-more-post-dai'));
    await tester.pump();
    expect(find.text('Xem thêm'), findsOneWidget);
  });

  testWidgets('Tin ngắn không có nút Xem thêm', (tester) async {
    await _open(tester);
    expect(find.text('Xem thêm'), findsNothing);
  });

  testWidgets('Tin gắn sân: bấm Xem sân mở trang chi tiết đúng sân', (tester) async {
    await _open(tester);
    expect(find.descendant(of: _k('news-card-post-km'), matching: find.text('Sân Beta')), findsOneWidget);
    await tester.ensureVisible(_k('news-venue-post-km'));
    await tester.tap(_k('news-venue-post-km'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(VenueDetailScreen), findsOneWidget);
    expect(tester.widget<VenueDetailScreen>(find.byType(VenueDetailScreen)).venue.id, 2);
  });

  testWidgets('Tin gắn sân không còn trong danh sách thì không hiện nút Xem sân', (tester) async {
    await _open(tester, venues: [_v(1, 'Sân Alpha', approvedAt: _now.subtract(const Duration(days: 1)))]);
    expect(_k('news-card-post-km'), findsOneWidget);
    expect(_k('news-venue-post-km'), findsNothing);
  });

  testWidgets('Điện thoại 390px: dòng tin và chip lọc không tràn bố cục', (tester) async {
    await _open(tester, size: const Size(390, 844));
    expect(find.text('Có gì mới ở AloBooking'), findsOneWidget);
    expect(_cardIds(tester), isNotEmpty);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pump();
    if (realFont) expect(tester.takeException(), isNull);
  });

  testWidgets('Màn rộng: cột tin giữ bề rộng đọc được (≤ 760)', (tester) async {
    await _open(tester, size: const Size(1600, 1000));
    expect(tester.getSize(_k('news-card-post-km')).width, lessThanOrEqualTo(760));
    if (realFont) expect(tester.takeException(), isNull);
  });
}
