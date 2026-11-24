import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/models/news_post.dart';
import 'package:alobooking/screens/explore_screen.dart';
import 'package:alobooking/screens/news_detail_screen.dart';
import 'package:alobooking/services/firestore_service.dart' show ReviewItem;
import 'package:alobooking/services/news_feed.dart';
import 'package:alobooking/services/weather_service.dart';
import 'package:alobooking/widgets/news_visuals.dart';

final _now = DateTime(2026, 11, 24, 18, 0);

NewsPost _ext({String url = 'https://vnexpress.net/bai-viet-1.html', String source = 'VnExpress', String title = 'Quần vợt TP.HCM giành HCV'}) => NewsPost(
      id: 'rss_1',
      title: title,
      body: '',
      category: NewsPost.sportCategory,
      author: source,
      createdAt: _now.subtract(const Duration(hours: 2)),
      sourceName: source,
      sourceUrl: url,
    );

Future<void> _loadFont() async {
  final f = File('C:/Windows/Fonts/segoeui.ttf');
  if (!f.existsSync()) return;
  final loader = FontLoader('TestSans')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
}

void main() {
  setUpAll(_loadFont);

  group('NewsPost: nguồn báo ngoài', () {
    test('Đọc và ghi lại tên báo, đường dẫn; tin admin không có hai trường này', () {
      final p = NewsPost.tryFromFirestoreFields('rss_1', {
        'title': {'stringValue': 'Tiêu đề'},
        'category': {'stringValue': 'sport'},
        'createdAt': {'stringValue': '2026-11-24T15:12:00+07:00'},
        'sourceName': {'stringValue': ' VnExpress '},
        'sourceUrl': {'stringValue': 'https://vnexpress.net/a.html'},
      })!;
      expect(p.sourceName, 'VnExpress');
      expect(p.isExternal, isTrue);
      final back = p.toFirestoreFields();
      expect(back['sourceName'], {'stringValue': 'VnExpress'});
      expect(back['sourceUrl'], {'stringValue': 'https://vnexpress.net/a.html'});

      final admin = NewsPost(id: 'a', title: 'Giảm giá', body: 'x', createdAt: _now);
      expect(admin.isExternal, isFalse);
      expect(admin.toFirestoreFields().containsKey('sourceUrl'), isFalse, reason: 'tin admin không ghi trường thừa');
    });

    test('Chỉ http/https mới là liên kết hợp lệ (chặn javascript:, file:, rỗng)', () {
      expect(NewsPost.isSafeHttpUrl('https://tuoitre.vn/a.htm'), isTrue);
      expect(NewsPost.isSafeHttpUrl('http://thanhnien.vn/a'), isTrue);
      for (final bad in ['', 'javascript:alert(1)', 'file:///c:/x', 'vnexpress.net/a', 'https://', 'ftp://x.com/a']) {
        expect(NewsPost.isSafeHttpUrl(bad), isFalse, reason: bad);
      }
      expect(_ext(url: 'javascript:alert(1)').isExternal, isFalse);
    });

    test('copyWith giữ nguyên nguồn; nhãn loại là "Tin thể thao" và không nằm trong danh sách admin chọn', () {
      final c = _ext().copyWith(title: 'Tiêu đề mới');
      expect(c.sourceUrl, 'https://vnexpress.net/bai-viet-1.html');
      expect(c.sourceName, 'VnExpress');
      expect(NewsPost.labelOf('sport'), 'Tin thể thao');
      expect(NewsPost.categories.any((x) => x.$1 == 'sport'), isFalse);
    });
  });

  group('NewsFeed: tin thể thao', () {
    test('Tin báo ngoài thành loại sport, ghi "Nguồn: <báo>", tin admin vẫn "Đăng bởi"', () {
      final feed = NewsFeed.build(
        posts: [_ext(), NewsPost(id: 'a', title: 'Giảm giá', body: 'x', createdAt: _now.subtract(const Duration(hours: 5)))],
        venues: const [],
        reviews: const [],
        now: _now,
      );
      final e = feed.firstWhere((x) => x.id == 'post-rss_1');
      expect(e.kind, NewsKind.sport);
      expect(e.isExternal, isTrue);
      expect(e.creditLine, 'Nguồn: VnExpress');
      expect(e.sourceUrl, 'https://vnexpress.net/bai-viet-1.html');
      expect(feed.firstWhere((x) => x.id == 'post-a').creditLine, 'Đăng bởi AloBooking');
    });

    test('Liên kết không hợp lệ thì không coi là tin ngoài (không có nút mở)', () {
      final feed = NewsFeed.build(posts: [_ext(url: 'javascript:alert(1)')], venues: const [], reviews: const [], now: _now);
      expect(feed.single.isExternal, isFalse);
      expect(feed.single.creditLine, startsWith('Đăng bởi'));
    });

    test('Thiếu tên báo thì ghi theo tên miền', () {
      final feed = NewsFeed.build(posts: [_ext(source: '')], venues: const [], reviews: const [], now: _now);
      expect(feed.single.creditLine, 'Nguồn: vnexpress.net');
    });

    test('Mọi loại tin đều có kiểu hiển thị (không crash khi thêm loại mới)', () {
      for (final k in NewsKind.values) {
        expect(NewsKindStyle.of(k).icon, isNotNull, reason: k.name);
        expect(k.label, isNotEmpty);
      }
    });
  });


  testWidgets('Khám phá: thẻ tin thể thao có nhãn, ghi nguồn, và có bộ lọc "Tin thể thao"', (tester) async {
    tester.view.physicalSize = const Size(1280, 5200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'TestSans'),
      home: ExploreScreen(
        venues: const [],
        newsLoader: () async => (
              posts: [_ext(), NewsPost(id: 'rss_2', title: 'Bài thứ hai', body: '', category: 'sport', author: 'Tuổi Trẻ', createdAt: _now.subtract(const Duration(hours: 3)), sourceName: 'Tuổi Trẻ', sourceUrl: 'https://tuoitre.vn/b.htm')],
              reviews: <ReviewItem>[],
              failed: false,
            ),
        weatherLoader: () async => WeatherData.defaultHanoi(),
        now: _now,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('news-credit-post-rss_1')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('news-card-post-rss_1')), matching: find.text('Nguồn: VnExpress')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('news-card-post-rss_2')), matching: find.text('Nguồn: Tuổi Trẻ')), findsOneWidget);
    expect(find.text('Tin thể thao'), findsWidgets, reason: 'nhãn loại trên thẻ và chip lọc');
    expect(tester.takeException(), isNull);
  });

  group('Trang chi tiết tin ngoài', () {
    Future<void> openDetail(WidgetTester tester, NewsEntry e) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'TestSans'), home: NewsDetailScreen(entry: e, now: _now, entries: [e])));
      await tester.pump(const Duration(milliseconds: 200));
    }

    NewsEntry entry(NewsPost p) => NewsFeed.build(posts: [p], venues: const [], reviews: const [], now: _now).single;

    testWidgets('Có nút "Đọc bài gốc tại <báo>", lời nhắc nội dung thuộc báo gốc, và bấm thì mở đúng liên kết', (tester) async {
      Uri? opened;
      final old = NewsDetailScreen.launcher;
      NewsDetailScreen.launcher = (u) async {
        opened = u;
        return true;
      };
      addTearDown(() => NewsDetailScreen.launcher = old);

      await openDetail(tester, entry(_ext()));
      expect(find.text('Đọc bài gốc tại VnExpress'), findsOneWidget);
      expect(find.byKey(const ValueKey('news-detail-source-note')), findsOneWidget);
      expect(find.textContaining('Nguồn: VnExpress'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('news-detail-source')));
      await tester.pump();
      expect(opened.toString(), 'https://vnexpress.net/bai-viet-1.html');
      expect(find.textContaining('Không mở được bài gốc'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Không mở được liên kết: báo cho người dùng thay vì im lặng', (tester) async {
      final old = NewsDetailScreen.launcher;
      NewsDetailScreen.launcher = (u) async => false;
      addTearDown(() => NewsDetailScreen.launcher = old);
      await openDetail(tester, entry(_ext()));
      await tester.tap(find.byKey(const ValueKey('news-detail-source')));
      await tester.pump();
      expect(find.textContaining('Không mở được bài gốc'), findsOneWidget);
    });

    testWidgets('Liên kết lạ (javascript:) thì không có nút mở; tin admin cũng không có', (tester) async {
      await openDetail(tester, entry(_ext(url: 'javascript:alert(1)')));
      expect(find.byKey(const ValueKey('news-detail-source')), findsNothing);

      await openDetail(tester, entry(NewsPost(id: 'a', title: 'Giảm giá', body: 'Nội dung', createdAt: _now)));
      expect(find.byKey(const ValueKey('news-detail-source')), findsNothing);
      expect(find.textContaining('Đăng bởi AloBooking'), findsOneWidget);
    });
  });
}
