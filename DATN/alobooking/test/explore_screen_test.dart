import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/models/news_post.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/screens/explore_screen.dart';
import 'package:alobooking/screens/news_detail_screen.dart';
import 'package:alobooking/screens/venue_detail_screen.dart';
import 'package:alobooking/services/firestore_service.dart';

/// Hôm nay giả định: thứ bảy 21/11/2026, 10:30.
final _now = DateTime(2026, 11, 21, 10, 30);

Venue _v(
  int id,
  String name, {
  DateTime? approvedAt,
  String source = '',
  String type = 'badminton',
  String district = 'Cầu Giấy',
  String status = 'approved',
  String price = '80k - 100k/h',
  List<String> tags = const [],
}) =>
    Venue(
      id: id,
      name: name,
      type: type,
      district: district,
      distance: '',
      address: '$id Phố Thử, $district, Hà Nội',
      hours: '06:00 – 22:00',
      tags: tags,
      rating: 4.5,
      price: price,
      lat: 21.0,
      lng: 105.8,
      image: '',
      logo: '',
      source: source,
      approvalStatus: status,
      approvedAt: approvedAt,
    );

NewsPost _p(String id, String title, DateTime at,
        {String category = 'promo', bool pinned = false, int venueId = 0, String body = 'Nội dung ngắn', String imageUrl = ''}) =>
    NewsPost(id: id, title: title, body: body, category: category, pinned: pinned, venueId: venueId, imageUrl: imageUrl, createdAt: at);

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

  testWidgets('Ảnh kho thì ghi rõ "Ảnh minh họa"; ảnh riêng của tin thì không', (tester) async {
    await _open(tester, loader: () async => _bundle(posts: [
          _p('ghim', 'Khai trương cụm sân mới', _now.subtract(const Duration(days: 9)), category: 'event', pinned: true, imageUrl: 'https://example.com/anh-that.jpg'),
          _p('km', 'Giảm 20% giờ vàng', _now.subtract(const Duration(hours: 3)), category: 'promo', venueId: 2),
          _p('hq', 'Cập nhật cách đặt sân', _now.subtract(const Duration(days: 1, hours: 2)), category: 'update'),
        ]));
    // sân mới dùng ảnh kho của sân
    expect(find.descendant(of: _k('news-card-venue-1'), matching: find.text('Ảnh minh họa')), findsOneWidget);
    // tin khuyến mãi không có ảnh riêng nhưng gắn Sân Beta → dùng ảnh sân (kho) nên cũng ghi minh họa
    expect(find.descendant(of: _k('news-card-post-km'), matching: find.text('Ảnh minh họa')), findsOneWidget);
    // ảnh admin tự đăng không phải ảnh kho → không dán nhãn
    expect(find.descendant(of: _k('news-card-post-ghim'), matching: find.text('Ảnh minh họa')), findsNothing);
    // tin không ảnh, không gắn sân → nền chuyển sắc, không có ảnh để dán nhãn
    expect(find.descendant(of: _k('news-card-post-hq'), matching: find.text('Ảnh minh họa')), findsNothing);
  });

  testWidgets('Banner đầu trang có ảnh minh họa; mọi tin (trừ đánh giá) có ảnh bìa, đánh giá chỉ có ảnh nhỏ của sân', (tester) async {
    await _open(tester);
    expect(_k('news-hero'), findsOneWidget);
    expect(find.descendant(of: _k('news-hero'), matching: find.text('Ảnh minh họa')), findsOneWidget);
    for (final id in ['post-ghim', 'post-km', 'post-hq', 'venue-1']) {
      expect(_k('news-cover-$id'), findsOneWidget, reason: 'tin $id phải có ảnh bìa');
    }
    expect(_k('news-cover-review-r1'), findsNothing);
    expect(find.descendant(of: _k('news-card-review-r1'), matching: find.text('Cầu lông · Cầu Giấy · ảnh minh họa')), findsOneWidget);
  });

  testWidgets('Tin đứng đầu được trình bày lớn hơn (ảnh bìa 16:8), các tin sau 16:7', (tester) async {
    await _open(tester);
    final first = tester.getSize(_k('news-cover-post-ghim'));
    final next = tester.getSize(_k('news-cover-post-km'));
    expect(first.width / first.height, closeTo(16 / 8, 0.02));
    expect(next.width / next.height, closeTo(16 / 7, 0.02));
  });

  testWidgets('Bấm ảnh bìa hoặc tiêu đề mở trang chi tiết với nội dung đầy đủ', (tester) async {
    final long = 'Dòng đầu. ${List.filled(30, 'Nội dung rất dài của tin.').join(' ')}';
    await _open(tester, loader: () async => _bundle(posts: [_p('km', 'Giảm 20% giờ vàng', _now.subtract(const Duration(hours: 3)), venueId: 2, body: long)]));

    await tester.tap(_k('news-cover-post-km'));
    await tester.pumpAndSettle();
    expect(find.byType(NewsDetailScreen), findsOneWidget);
    expect(find.text('Giảm 20% giờ vàng'), findsOneWidget);
    expect(tester.widget<Text>(_k('news-detail-body')).data, long, reason: 'trang chi tiết hiện đủ nội dung, không cắt');
    expect(tester.widget<Text>(_k('news-detail-body')).maxLines, isNull);

    // từ trang chi tiết sang trang sân
    await tester.tap(_k('news-detail-venue'));
    await tester.pumpAndSettle();
    expect(find.byType(VenueDetailScreen), findsOneWidget);
    expect(tester.widget<VenueDetailScreen>(find.byType(VenueDetailScreen)).venue.id, 2);

    // quay về, bấm tiêu đề cũng mở chi tiết
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(NewsDetailScreen), findsNothing);
    await tester.tap(_k('news-open-post-km'));
    await tester.pumpAndSettle();
    expect(find.byType(NewsDetailScreen), findsOneWidget);
  });

  testWidgets('Trang chi tiết đánh giá: có sao, không ảnh bìa, vẫn tới được sân', (tester) async {
    await _open(tester);
    await tester.tap(_k('news-open-review-r1'));
    await tester.pumpAndSettle();
    expect(find.byType(NewsDetailScreen), findsOneWidget);
    expect(find.text('Lan đánh giá Sân Beta'), findsOneWidget);
    expect(tester.widget<Text>(_k('news-detail-body')).data, 'Sân sạch, đèn sáng');
    expect(_k('news-detail-venue'), findsOneWidget);
    // đánh giá này cũng nằm trong danh sách đánh giá của chính sân đó
    expect(_k('news-detail-review-r1'), findsOneWidget);
  });

  testWidgets('Dải số liệu đếm từ dữ liệu thật: không tính sân minh họa hay sân chưa duyệt', (tester) async {
    final venues = [
      _v(1, 'Sân Alpha'),
      _v(2, 'Sân Beta'),
      _v(3, '[Demo] Sân', source: 'demo'),
      _v(4, 'Sân Chờ Duyệt', status: 'pending'),
      _v(5, 'Sân Dữ Liệu Mở', source: 'osm', type: 'tennis', district: 'Phường Xuân Đỉnh'),
    ];
    await _open(tester, venues: venues, loader: () async => _bundle(reviews: [_r('a', 2, _now), _r('b', 3, _now), _r('c', 4, _now)]));
    String numberOf(String key) => tester.widget<Text>(find.descendant(of: _k(key), matching: find.byType(Text)).first).data!;
    expect(numberOf('news-stat-places'), '3');
    expect(numberOf('news-stat-areas'), '2');
    expect(numberOf('news-stat-sports'), '2');
    expect(numberOf('news-stat-reviews'), '1', reason: 'chỉ tính đánh giá của sân công khai');
  });

  testWidgets('Số liệu lớn có dấu chấm ngăn cách hàng nghìn; chưa có sân nào thì ẩn dải số liệu', (tester) async {
    await _open(tester, venues: [for (var i = 1; i <= 1234; i++) _v(i, 'Sân $i')]);
    expect(tester.widget<Text>(find.descendant(of: _k('news-stat-places'), matching: find.byType(Text)).first).data, '1.234');
    await _open(tester, venues: const []);
    expect(_k('news-stats'), findsNothing);
  });

  group('Trang chi tiết tin', () {
    List<Venue> detailVenues() => [
          _v(1, 'Sân Alpha', approvedAt: _now.subtract(const Duration(days: 1))),
          _v(2, 'Sân Beta', tags: const ['Mái che', 'Đèn LED']),
          _v(3, 'Sân Gamma'),
          _v(4, 'Sân Delta Tennis', type: 'tennis'),
          _v(6, '[Demo] Cầu lông 01', source: 'demo'),
          _v(7, 'Sân Khác Quận', district: 'Đống Đa'),
          _v(5, 'Sân Dữ Liệu Mở', source: 'osm', district: 'Phường Xuân Đỉnh'),
        ];
    NewsBundle detailBundle() => _bundle(
          posts: [
            _p('km', 'Giảm 20% giờ vàng', _now.subtract(const Duration(hours: 3)), venueId: 2),
            _p('mo', 'Tin về sân dữ liệu mở', _now.subtract(const Duration(hours: 5)), category: 'update', venueId: 5),
            _p('hq', 'Cập nhật cách đặt sân', _now.subtract(const Duration(days: 1, hours: 2)), category: 'update'),
          ],
          reviews: [
            _r('r1', 2, _now.subtract(const Duration(hours: 1)), stars: 4),
            _r('r2', 2, _now.subtract(const Duration(days: 2)), stars: 5, user: 'Minh (Khách hàng)', comment: 'Sân rộng, sạch'),
            _r('r3', 3, _now.subtract(const Duration(days: 3)), stars: 3, comment: 'Tạm ổn'),
          ],
        );

    testWidgets('Tin gắn sân: thông tin sân thật, đánh giá của đúng sân đó, sân tương tự và tin khác', (tester) async {
      await _open(tester, venues: detailVenues(), loader: () async => detailBundle());
      await tester.tap(_k('news-open-post-km'));
      await tester.pumpAndSettle();

      // ngày giờ đăng đầy đủ: 21/11/2026 10:30 trừ 3 giờ
      expect(find.text('Đăng bởi AloBooking · 07:30 · 21/11/2026'), findsOneWidget);

      final info = _k('news-detail-venue-info');
      for (final t in ['Sân Beta', '2 Phố Thử, Cầu Giấy, Hà Nội', '06:00 – 22:00', '80k - 100k/h', '8 sân', 'Mái che', 'Đèn LED']) {
        expect(find.descendant(of: info, matching: find.text(t)), findsOneWidget, reason: 'thiếu "$t"');
      }
      expect(_k('news-detail-imported-note'), findsNothing);

      // đánh giá: chỉ của Sân Beta, trung bình (4+5)/2 = 4.5, người đánh giá đã bỏ phần vai trò
      expect(_k('news-detail-review-r1'), findsOneWidget);
      expect(_k('news-detail-review-r2'), findsOneWidget);
      expect(_k('news-detail-review-r3'), findsNothing, reason: 'r3 là đánh giá của sân khác');
      expect(tester.widget<Text>(_k('news-detail-avg')).data, '4.5');
      expect(find.text('2 đánh giá'), findsOneWidget);
      expect(find.descendant(of: _k('news-detail-review-r2'), matching: find.text('Minh')), findsOneWidget);

      // sân tương tự: cùng môn; không có sân minh họa, sân khác môn hay chính sân này
      expect(_k('news-similar-3'), findsOneWidget);
      expect(_k('news-similar-7'), findsOneWidget);
      expect(_k('news-similar-4'), findsNothing);
      expect(_k('news-similar-6'), findsNothing);
      expect(_k('news-similar-2'), findsNothing);

      // tin khác: không có chính tin này, tối đa 3 tin mới nhất (đánh giá 1 giờ, tin 5 giờ, sân mới hôm qua)
      expect(_k('news-related-post-km'), findsNothing);
      expect(_k('news-related-review-r1'), findsOneWidget);
      expect(_k('news-related-post-mo'), findsOneWidget);
      expect(_k('news-related-venue-1'), findsOneWidget);
      expect(_k('news-related-post-hq'), findsNothing, reason: 'chỉ hiện tối đa 3 tin khác');

      // sang sân tương tự
      await tester.tap(_k('news-similar-3'));
      await tester.pumpAndSettle();
      expect(tester.widget<VenueDetailScreen>(find.byType(VenueDetailScreen)).venue.id, 3);
    });

    testWidgets('Sân chưa có đánh giá thì nói thẳng, không bịa số', (tester) async {
      await _open(tester, venues: detailVenues(), loader: () async => detailBundle());
      await tester.tap(_k('news-open-post-mo'));
      await tester.pumpAndSettle();
      expect(_k('news-detail-no-reviews'), findsOneWidget);
      expect(_k('news-detail-avg'), findsNothing);
    });

    testWidgets('Sân từ dữ liệu mở: ghi rõ là tham khảo kèm nguồn, không hiện số sân', (tester) async {
      await _open(tester, venues: detailVenues(), loader: () async => detailBundle());
      await tester.tap(_k('news-open-post-mo'));
      await tester.pumpAndSettle();
      expect(_k('news-detail-imported-note'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap contributors'), findsWidgets);
      expect(find.text('Số sân'), findsNothing);
      expect(find.descendant(of: _k('news-detail-venue-info'), matching: find.text('80k - 100k/h (tham khảo)')), findsOneWidget);
    });

    testWidgets('Tin không gắn sân: không có khối thông tin sân/đánh giá nhưng vẫn có tin khác', (tester) async {
      await _open(tester, venues: detailVenues(), loader: () async => detailBundle());
      await tester.tap(_k('news-open-post-hq'));
      await tester.pumpAndSettle();
      expect(_k('news-detail-venue-info'), findsNothing);
      expect(_k('news-detail-reviews'), findsNothing);
      expect(_k('news-detail-similar'), findsNothing);
      expect(_k('news-detail-related'), findsOneWidget);
    });

    testWidgets('Bấm tin khác thì thay trang chi tiết (không chất chồng), quay lại là về Khám phá', (tester) async {
      await _open(tester, venues: detailVenues(), loader: () async => detailBundle());
      await tester.tap(_k('news-open-post-km'));
      await tester.pumpAndSettle();
      await tester.tap(_k('news-related-post-mo'));
      await tester.pumpAndSettle();
      expect(find.byType(NewsDetailScreen), findsOneWidget);
      expect(tester.widget<Text>(_k('news-detail-title')).data, 'Tin về sân dữ liệu mở');

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byType(NewsDetailScreen), findsNothing);
      expect(find.text('Có gì mới ở AloBooking'), findsOneWidget);
    });

    testWidgets('Sao chép nội dung tin vào bộ nhớ tạm và báo đã chép', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await _open(tester, venues: detailVenues(), loader: () async => detailBundle());
      await tester.tap(_k('news-open-post-km'));
      await tester.pumpAndSettle();
      await tester.tap(_k('news-detail-copy'));
      await tester.pump();
      expect(copied, 'Giảm 20% giờ vàng\n\nNội dung ngắn');
      expect(find.text('Đã sao chép nội dung tin'), findsOneWidget);
    });

    testWidgets('Điện thoại 390px: trang chi tiết đầy đủ không tràn bố cục', (tester) async {
      // chiều cao lớn để danh sách dựng đủ thẻ (dựng lười); bề rộng 390 mới là thứ cần kiểm tra
      await _open(tester, venues: detailVenues(), loader: () async => detailBundle(), size: const Size(390, 3200));
      await tester.tap(_k('news-open-post-km'));
      await tester.pumpAndSettle();
      expect(find.byType(NewsDetailScreen), findsOneWidget);
      expect(_k('news-detail-similar'), findsOneWidget);
      if (realFont) expect(tester.takeException(), isNull);
    });
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
    await _open(tester, size: const Size(1600, 3200));
    expect(tester.getSize(_k('news-card-post-km')).width, lessThanOrEqualTo(760));
    if (realFont) expect(tester.takeException(), isNull);
  });
}
