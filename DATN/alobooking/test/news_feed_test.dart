import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/models/news_post.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/services/firestore_service.dart';
import 'package:alobooking/services/news_feed.dart';

final _now = DateTime(2026, 11, 21, 10, 30); // thứ bảy

Venue _v(
  int id,
  String name, {
  String type = 'badminton',
  String district = 'Cầu Giấy',
  String price = '80k - 100k/h',
  String source = '',
  String status = 'approved',
  DateTime? approvedAt,
}) =>
    Venue(
      id: id,
      name: name,
      type: type,
      district: district,
      distance: '',
      address: '$id Phố Thử, $district, Hà Nội',
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
      approvedAt: approvedAt,
    );

NewsPost _p(String id, String title, DateTime at, {String category = 'promo', bool pinned = false, int venueId = 0}) =>
    NewsPost(id: id, title: title, body: 'Nội dung $title', category: category, pinned: pinned, venueId: venueId, createdAt: at);

ReviewItem _r(String id, int venueId, DateTime at, {String comment = 'Sân sạch, đèn sáng', String user = 'Lan', int stars = 5}) =>
    ReviewItem(id: id, venueId: venueId, userId: 'u$id', userName: user, stars: stars, comment: comment, createdAt: at);

void main() {
  group('NewsPost', () {
    test('ghi rồi đọc lại Firestore giữ nguyên mọi trường', () {
      final p = NewsPost(
        id: 'n1',
        title: 'Giảm 20% giờ vàng',
        body: 'Áp dụng cuối tuần',
        category: 'promo',
        imageUrl: 'https://x/y.jpg',
        venueId: 7,
        pinned: true,
        author: 'AloBooking',
        createdAt: DateTime(2026, 11, 20, 9, 5),
      );
      final back = NewsPost.tryFromFirestoreFields('n1', p.toFirestoreFields())!;
      expect(back.title, p.title);
      expect(back.body, p.body);
      expect(back.category, 'promo');
      expect(back.imageUrl, p.imageUrl);
      expect(back.venueId, 7);
      expect(back.pinned, isTrue);
      expect(back.createdAt, p.createdAt);
    });

    test('thiếu tiêu đề hoặc ngày hỏng thì bỏ qua, không bịa ngày', () {
      expect(NewsPost.tryFromFirestoreFields('a', {'title': {'stringValue': ''}, 'createdAt': {'stringValue': '2026-11-20T09:00:00'}}), isNull);
      expect(NewsPost.tryFromFirestoreFields('a', {'title': {'stringValue': 'Có tên'}, 'createdAt': {'stringValue': 'hôm qua'}}), isNull);
      expect(NewsPost.tryFromFirestoreFields('a', {'title': {'stringValue': 'Có tên'}}), isNull);
    });

    test('loại lạ rơi về Thông báo, nhãn đúng với từng loại', () {
      expect(NewsPost.labelOf('promo'), 'Ưu đãi');
      expect(NewsPost.labelOf('event'), 'Sự kiện');
      expect(NewsPost.labelOf('update'), 'Có gì mới');
      expect(NewsPost.labelOf('xyz'), 'Thông báo');
      expect(NewsKind.fromCategory('xyz'), NewsKind.notice);
    });

    test('copyWith không đổi ngày đăng và mã tin', () {
      final p = _p('n1', 'A', DateTime(2026, 11, 1));
      final q = p.copyWith(title: 'B', pinned: true);
      expect(q.id, 'n1');
      expect(q.createdAt, p.createdAt);
      expect(q.title, 'B');
      expect(q.pinned, isTrue);
    });
  });

  group('Venue.approvedAt', () {
    test('đi qua toJson/fromJson và copyWith', () {
      final at = DateTime(2026, 11, 18, 14, 0);
      final v = _v(1, 'Sân A', approvedAt: at);
      expect(Venue.fromJson(v.toJson()).approvedAt, at);
      expect(v.copyWith(name: 'B').approvedAt, at, reason: 'sửa tên không làm mất ngày duyệt');
      expect(Venue.fromJson(_v(2, 'Sân B').toJson()).approvedAt, isNull);
    });
  });

  group('NewsFeed.build', () {
    test('tin admin: đúng loại, ghim lên đầu, còn lại mới nhất trước', () {
      final feed = NewsFeed.build(
        posts: [
          _p('a', 'Cũ', DateTime(2026, 11, 10), category: 'event'),
          _p('b', 'Ghim cũ', DateTime(2026, 11, 1), category: 'notice', pinned: true),
          _p('c', 'Mới', DateTime(2026, 11, 20), category: 'update'),
        ],
        venues: const [],
        reviews: const [],
        now: _now,
      );
      expect(feed.map((e) => e.title), ['Ghim cũ', 'Mới', 'Cũ']);
      expect(feed.map((e) => e.kind), [NewsKind.notice, NewsKind.update, NewsKind.event]);
      expect(feed.every((e) => !e.isAuto), isTrue);
      expect(feed.first.pinned, isTrue);
    });

    test('sân mới: chỉ sân thật đã duyệt, có ngày duyệt trong 30 ngày', () {
      final recent = _now.subtract(const Duration(days: 3));
      final venues = [
        _v(1, 'Sân Mới', approvedAt: recent),
        _v(2, 'Sân Chờ Duyệt', status: 'pending', approvedAt: recent),
        _v(3, '[Demo] Cầu lông 01', source: 'demo', approvedAt: recent),
        _v(4, 'Sân OSM', source: 'osm', approvedAt: recent),
        _v(5, 'Sân Overture', source: 'overture', approvedAt: recent),
        _v(6, 'Sân Không Rõ Ngày'),
        _v(7, 'Sân Quá Cũ', approvedAt: _now.subtract(const Duration(days: 31))),
        _v(8, 'Sân Ngày Tương Lai', approvedAt: _now.add(const Duration(days: 1))),
      ];
      final feed = NewsFeed.build(posts: const [], venues: venues, reviews: const [], now: _now);
      expect(feed.map((e) => e.venueId), [1]);
      final e = feed.single;
      expect(e.kind, NewsKind.newVenue);
      expect(e.isAuto, isTrue);
      expect(e.title, 'Sân Mới vừa lên AloBooking');
      expect(e.body, contains('Cầu lông tại Cầu Giấy'));
      expect(e.body, contains('Giá 80k - 100k/h'));
      expect(e.time, recent);
    });

    test('sân chưa niêm yết giá thì tin không ghi giá', () {
      final feed = NewsFeed.build(
        posts: const [],
        venues: [_v(1, 'Sân Liên Hệ', price: 'Liên hệ', approvedAt: _now.subtract(const Duration(days: 1)))],
        reviews: const [],
        now: _now,
      );
      expect(feed.single.body, isNot(contains('Giá')));
    });

    test('đánh giá mới: cần nội dung, sân công khai, trong 30 ngày; tối đa 10', () {
      final recent = _now.subtract(const Duration(days: 2));
      final venues = [_v(1, 'Sân A'), _v(2, '[Demo] Sân', source: 'demo'), _v(3, 'Sân Chờ', status: 'pending')];
      final reviews = [
        _r('ok', 1, recent, user: 'Lan', stars: 4),
        _r('rong', 1, recent, comment: '   '),
        _r('demo', 2, recent),
        _r('cho', 3, recent),
        _r('la', 99, recent),
        _r('cu', 1, _now.subtract(const Duration(days: 40))),
      ];
      final feed = NewsFeed.build(posts: const [], venues: venues, reviews: reviews, now: _now);
      expect(feed.map((e) => e.id), ['review-ok']);
      final e = feed.single;
      expect(e.kind, NewsKind.review);
      expect(e.title, 'Lan đánh giá Sân A');
      expect(e.stars, 4);
      expect(e.body, 'Sân sạch, đèn sáng');

      final many = [for (var i = 0; i < 15; i++) _r('r$i', 1, _now.subtract(Duration(hours: i + 1)))];
      final capped = NewsFeed.build(posts: const [], venues: venues, reviews: many, now: _now);
      expect(capped.length, NewsFeed.maxAutoReviews);
      expect(capped.first.id, 'review-r0', reason: 'đánh giá mới nhất đứng trước');
    });

    test('bỏ phần vai trò dính trong tên người đánh giá', () {
      final feed = NewsFeed.build(
        posts: const [],
        venues: [_v(1, 'Sân A')],
        reviews: [
          _r('a', 1, _now.subtract(const Duration(hours: 1)), user: 'Nguyễn Văn Khách (Khách hàng)'),
          _r('b', 1, _now.subtract(const Duration(hours: 2)), user: 'Minh (Hà Đông)'),
          _r('c', 1, _now.subtract(const Duration(hours: 3)), user: '(Khách hàng)'),
        ],
        now: _now,
      );
      expect(feed.map((e) => e.title), [
        'Nguyễn Văn Khách đánh giá Sân A',
        'Minh (Hà Đông) đánh giá Sân A',
        'Một khách hàng đánh giá Sân A',
      ]);
    });

    test('đánh giá không tên hiện là "Một khách hàng"', () {
      final feed = NewsFeed.build(
        posts: const [],
        venues: [_v(1, 'Sân A')],
        reviews: [_r('x', 1, _now.subtract(const Duration(hours: 1)), user: '  ')],
        now: _now,
      );
      expect(feed.single.title, 'Một khách hàng đánh giá Sân A');
    });

    test('trộn tin admin, sân mới, đánh giá theo thời gian; tin ghim vẫn trên cùng', () {
      final feed = NewsFeed.build(
        posts: [
          _p('p1', 'Tin 5 ngày trước', _now.subtract(const Duration(days: 5))),
          _p('p2', 'Tin ghim', _now.subtract(const Duration(days: 20)), pinned: true),
        ],
        venues: [_v(1, 'Sân A', approvedAt: _now.subtract(const Duration(days: 1)))],
        reviews: [_r('r', 1, _now.subtract(const Duration(hours: 2)))],
        now: _now,
      );
      expect(feed.map((e) => e.id), ['post-p2', 'review-r', 'venue-1', 'post-p1']);
    });
  });

  group('Số liệu và gợi ý cho trang chi tiết', () {
    test('stats: chỉ đếm sân công khai (đã duyệt, không demo); số đánh giá chỉ của sân đó', () {
      final venues = [
        _v(1, 'A'),
        _v(2, 'B', district: 'Đống Đa', type: 'tennis'),
        _v(3, '[Demo]', source: 'demo'),
        _v(4, 'Chờ', status: 'pending'),
        _v(5, 'Dữ liệu mở', source: 'osm', district: '  '),
      ];
      final st = NewsFeed.stats(venues, [
        _r('1', 1, _now),
        _r('2', 2, _now),
        _r('3', 3, _now), // sân demo
        _r('4', 4, _now), // sân chưa duyệt
        _r('5', 99, _now), // sân không tồn tại
        ReviewItem(id: '6', venueId: 1, userId: 'u', userName: 'x', stars: 0, comment: '', createdAt: _now), // sao không hợp lệ
      ]);
      expect(st.places, 3);
      expect(st.districts, 2, reason: 'khu vực trống không tính');
      expect(st.sports, 2);
      expect(st.reviews, 2);
    });

    test('stats: không có dữ liệu thì toàn số 0, không bịa số', () {
      final st = NewsFeed.stats(const [], const []);
      expect((st.places, st.districts, st.sports, st.reviews), (0, 0, 0, 0));
    });

    test('reviewsOf: chỉ đánh giá của sân đó, mới nhất trước, bỏ sao không hợp lệ', () {
      final list = NewsFeed.reviewsOf(1, [
        _r('cu', 1, _now.subtract(const Duration(days: 5))),
        _r('moi', 1, _now.subtract(const Duration(hours: 1))),
        _r('khac', 2, _now),
        ReviewItem(id: 'sai', venueId: 1, userId: 'u', userName: 'x', stars: 9, comment: '', createdAt: _now),
      ]);
      expect(list.map((r) => r.id), ['moi', 'cu']);
    });

    test('similarVenues: cùng môn, loại demo/chưa duyệt/chính nó; cùng quận và có giá lên trước', () {
      final base = _v(1, 'Gốc', district: 'Cầu Giấy');
      final all = [
        base,
        _v(2, 'Cùng quận', district: 'Cầu Giấy'),
        _v(3, 'Khác quận', district: 'Đống Đa'),
        _v(4, 'Khác môn', type: 'tennis'),
        _v(5, '[Demo]', source: 'demo'),
        _v(6, 'Chờ duyệt', status: 'pending'),
        _v(7, 'Mở cùng quận', source: 'osm', district: 'Cầu Giấy'),
        _v(8, 'Cùng quận chưa giá', district: 'Cầu Giấy', price: 'Liên hệ'),
      ];
      final ids = NewsFeed.similarVenues(base, all).map((v) => v.id).toList();
      expect(ids, [2, 8, 7, 3]);
      expect(NewsFeed.similarVenues(base, all, max: 2).length, 2);
      expect(NewsFeed.similarVenues(base, [base]), isEmpty);
    });

    test('relatedEntries: bỏ chính tin đó, cùng loại lên trước rồi mới nhất trước, tối đa max', () {
      NewsEntry e(String id, NewsKind k, int hoursAgo) => NewsEntry(id: id, kind: k, title: id, time: _now.subtract(Duration(hours: hoursAgo)));
      final all = [e('a', NewsKind.update, 1), e('b', NewsKind.promo, 2), e('c', NewsKind.update, 3), e('d', NewsKind.event, 4), e('f', NewsKind.update, 5)];
      expect(NewsFeed.relatedEntries(all[0], all).map((x) => x.id), ['c', 'f', 'b']);
      expect(NewsFeed.relatedEntries(all[1], all, max: 2).map((x) => x.id), ['a', 'c']);
      expect(NewsFeed.relatedEntries(all[0], [all[0]]), isEmpty);
    });

    test('fullDate và reviewerName', () {
      expect(NewsFeed.fullDate(DateTime(2026, 11, 3, 7, 5)), '07:05 · 03/11/2026');
      expect(NewsFeed.reviewerName('Lan (Khách hàng)'), 'Lan');
      expect(NewsFeed.reviewerName('   '), 'Một khách hàng');
      expect(NewsFeed.reviewerName('Minh (Hà Đông)'), 'Minh (Hà Đông)');
    });
  });

  group('NewsFeed.ago / dayLabel', () {
    test('ago', () {
      expect(NewsFeed.ago(_now.subtract(const Duration(seconds: 20)), _now), 'Vừa xong');
      expect(NewsFeed.ago(_now.add(const Duration(minutes: 5)), _now), 'Vừa xong', reason: 'lệch đồng hồ không ra số âm');
      expect(NewsFeed.ago(_now.subtract(const Duration(minutes: 5)), _now), '5 phút trước');
      expect(NewsFeed.ago(_now.subtract(const Duration(hours: 3, minutes: 10)), _now), '3 giờ trước');
      expect(NewsFeed.ago(_now.subtract(const Duration(days: 2, hours: 5)), _now), '2 ngày trước');
      expect(NewsFeed.ago(DateTime(2026, 11, 3, 8, 0), _now), '03/11/2026');
    });

    test('dayLabel', () {
      expect(NewsFeed.dayLabel(DateTime(2026, 11, 21, 0, 5), _now), 'Hôm nay');
      expect(NewsFeed.dayLabel(DateTime(2026, 11, 20, 23, 59), _now), 'Hôm qua');
      expect(NewsFeed.dayLabel(DateTime(2026, 11, 17, 12), _now), 'Thứ ba, 17/11');
      expect(NewsFeed.dayLabel(DateTime(2026, 11, 15, 12), _now), 'Chủ nhật, 15/11');
    });
  });
}
