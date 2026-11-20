import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/data/venue_photos.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/screens/venue_detail_screen.dart';

Venue _venue({String type = 'football', int id = 7, String image = ''}) => Venue(
      id: id,
      name: 'Sân thử nghiệm',
      type: type,
      district: 'Cầu Giấy',
      distance: '1.0km',
      address: '1 Phố Thử, Cầu Giấy, Hà Nội',
      hours: '06:00 – 23:00',
      tags: const [],
      rating: 4.5,
      price: '80k - 100k/h',
      lat: 21.03,
      lng: 105.8,
      image: image,
      logo: '',
    );

void main() {
  group('Kho ảnh minh họa', () {
    test('mỗi môn có nhiều ảnh, đều là đường dẫn https, không trùng nhau trong cùng môn', () {
      for (final sport in ['badminton', 'pickleball', 'tennis', 'basketball', 'football']) {
        final list = VenuePhotos.forSport(sport);
        expect(list.length, greaterThanOrEqualTo(15), reason: sport);
        expect(list.every((u) => u.startsWith('https://')), isTrue, reason: sport);
        expect(list.toSet().length, list.length, reason: '$sport có ảnh trùng');
      }
    });

    test('ảnh của môn này không lẫn sang môn khác (trừ khi cố ý dùng chung)', () {
      final seen = <String, String>{};
      for (final e in VenuePhotos.bySport.entries) {
        for (final u in e.value) {
          expect(seen.containsKey(u) && seen[u] != e.key, isFalse, reason: '$u dùng cho cả ${seen[u]} và ${e.key}');
          seen[u] = e.key;
        }
      }
    });

    test('forVenue ổn định theo id và các sân liền nhau có ảnh khác nhau', () {
      expect(VenuePhotos.forVenue('tennis', 5), VenuePhotos.forVenue('tennis', 5));
      final firstEight = {for (var id = 0; id < 8; id++) VenuePhotos.forVenue('tennis', id)};
      expect(firstEight.length, 8);
    });

    test('gallery: ảnh chính đứng đầu, đủ số ảnh, cùng môn và không lặp', () {
      final main = VenuePhotos.forSport('basketball').first;
      final g = VenuePhotos.gallery('basketball', main, 3, count: 6);
      expect(g.first, main);
      expect(g.length, 6);
      expect(g.toSet().length, 6);
      expect(g.every(VenuePhotos.forSport('basketball').contains), isTrue);
    });

    test('gallery của sân chưa có ảnh vẫn đủ ảnh cùng môn', () {
      final g = VenuePhotos.gallery('football', '', 10, count: 4);
      expect(g.length, 4);
      expect(g.every(VenuePhotos.forSport('football').contains), isTrue);
    });

    test('isStock nhận ra ảnh Pexels/Unsplash, không nhận ảnh do chủ sân đăng', () {
      expect(VenuePhotos.isStock(VenuePhotos.forSport('tennis').first), isTrue);
      expect(VenuePhotos.isStock('https://example.com/san-cua-toi.jpg'), isFalse);
      expect(VenuePhotos.isStock('data:image/png;base64,AAAA'), isFalse);
      expect(VenuePhotos.isStock(''), isFalse);
    });
  });

  group('Venue.displayImage', () {
    test('sân chưa có ảnh dùng ảnh minh họa đúng môn; sân có ảnh thật giữ ảnh thật', () {
      final none = _venue(type: 'pickleball', id: 12);
      expect(none.displayImage, VenuePhotos.forVenue('pickleball', 12));
      expect(VenuePhotos.forSport('pickleball').contains(none.displayImage), isTrue);
      expect(none.hasStockImage, isTrue);

      final own = _venue(image: 'https://example.com/san-cua-toi.jpg');
      expect(own.displayImage, 'https://example.com/san-cua-toi.jpg');
      expect(own.hasStockImage, isFalse);
    });
  });

  group('Trang chi tiết sân', () {
    testWidgets('sân dùng ảnh minh họa có nhãn "Ảnh minh họa"; sân có ảnh thật thì không', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(home: VenueDetailScreen(venue: _venue())));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('stock-image-badge')), findsOneWidget);

      await tester.pumpWidget(MaterialApp(
        home: VenueDetailScreen(venue: _venue(image: 'https://example.com/san-cua-toi.jpg')),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('stock-image-badge')), findsNothing);
    });
  });
}
