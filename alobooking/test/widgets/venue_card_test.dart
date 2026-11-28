import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/theme/app_theme.dart';
import 'package:alobooking/widgets/venue_card.dart';

Venue _v({
  int id = 1,
  String name = 'Sân Cầu Lông Cầu Giấy Dịch Vọng',
  String type = 'badminton',
  String source = '',
  String status = 'approved',
  String image = '',
  String hours = '05:00 – 23:00',
  String price = '80k - 100k/h',
  String distance = '0.8km',
  double rating = 4.9,
}) =>
    Venue(
      id: id,
      name: name,
      type: type,
      district: 'Cầu Giấy',
      distance: distance,
      address: '35 Trần Quý Kiên, Dịch Vọng, Cầu Giấy, Hà Nội',
      hours: hours,
      tags: const [],
      rating: rating,
      price: price,
      lat: 21.0,
      lng: 105.8,
      image: image,
      logo: '',
      source: source,
      approvalStatus: status,
    );

DateTime _at(int h) => DateTime(2026, 11, 25, h, 30);

Future<void> _pump(
  WidgetTester tester,
  Venue venue, {
  double width = 380,
  double height = 420,
  bool fav = false,
  bool manage = false,
  DateTime? now,
  VoidCallback? onTap,
  VoidCallback? onBook,
  VoidCallback? onFav,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) async {
  tester.view.physicalSize = Size(width + 40, height + 40);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: VenueCard(
            venue: venue,
            isFavorite: fav,
            canManage: manage,
            now: now ?? _at(10),
            onTap: onTap ?? () {},
            onBook: onBook ?? () {},
            onToggleFavorite: onFav ?? () {},
            onEdit: manage ? (onEdit ?? () {}) : null,
            onDelete: manage ? (onDelete ?? () {}) : null,
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

Finder _k(String key) => find.byKey(ValueKey(key));

/// Test mặc định dùng phông Ahem (mỗi chữ rộng bằng cỡ chữ) nên báo tràn giả: nạp đúng phông đóng gói của ứng dụng để đo gần thực tế.
Future<void> _loadAppFont() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader(AppTheme.fontFamily);
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$w.ttf'));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadAppFont);

  testWidgets('Hiện đủ thông tin: tên, địa chỉ, khoảng cách, giờ, giá, điểm và môn', (tester) async {
    await _pump(tester, _v());
    expect(find.text('Sân Cầu Lông Cầu Giấy Dịch Vọng'), findsOneWidget);
    expect(find.textContaining('35 Trần Quý Kiên'), findsOneWidget);
    expect(find.textContaining('0.8km'), findsOneWidget);
    expect(find.text('05:00 – 23:00'), findsOneWidget);
    expect(find.text('80k - 100k/h'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('🏸 Cầu lông'), findsOneWidget);
    expect(find.text('Đặt lịch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sân mới chưa có điểm hiện "Mới"; chưa có giá hiện "Liên hệ"; thiếu khoảng cách thì không hiện dấu chấm lửng', (tester) async {
    await _pump(tester, _v(rating: 0, price: '', distance: ''));
    expect(find.text('Mới'), findsOneWidget);
    expect(find.text('Liên hệ'), findsOneWidget);
    expect(find.textContaining(' · '), findsNothing);
  });

  group('Trạng thái mở cửa tính theo giờ thật', () {
    testWidgets('Trong giờ hoạt động: "Đang mở"', (tester) async {
      await _pump(tester, _v(), now: _at(10));
      expect(find.text('Đang mở'), findsOneWidget);
      expect(find.text('Đã đóng'), findsNothing);
    });

    testWidgets('Ngoài giờ hoạt động: "Đã đóng", không còn nói "Mở cửa" cho mọi sân như trước', (tester) async {
      await _pump(tester, _v(), now: _at(2));
      expect(find.text('Đã đóng'), findsOneWidget);
      expect(find.text('Đang mở'), findsNothing);
    });

    testWidgets('Giờ không đọc được thì không hiện nhãn mở/đóng', (tester) async {
      await _pump(tester, _v(hours: 'Liên hệ'));
      expect(_k('venue-card-status-1'), findsNothing);
    });
  });

  group('Nguồn của sân được nói thật', () {
    testWidgets('Sân do chủ sân/admin nhập và đã duyệt: "Đã xác thực"', (tester) async {
      await _pump(tester, _v(source: ''));
      expect(find.text('Đã xác thực'), findsOneWidget);
    });

    testWidgets('Địa điểm nhập từ dữ liệu mở (OpenStreetMap, Overture): "Dữ liệu mở", không ghi đã xác thực', (tester) async {
      for (final src in ['osm', 'overture']) {
        await _pump(tester, _v(source: src));
        expect(find.text('Dữ liệu mở'), findsOneWidget, reason: src);
        expect(find.text('Đã xác thực'), findsNothing, reason: src);
      }
    });

    testWidgets('Sân minh họa: "Sân minh họa"', (tester) async {
      await _pump(tester, _v(source: 'demo'));
      expect(find.text('Sân minh họa'), findsOneWidget);
      expect(find.text('Đã xác thực'), findsNothing);
    });
  });

  group('Nhãn "Ảnh minh họa"', () {
    testWidgets('Sân chưa có ảnh riêng dùng ảnh trong kho nên có nhãn', (tester) async {
      await _pump(tester, _v(image: ''));
      expect(find.text('Ảnh minh họa'), findsOneWidget);
    });

    testWidgets('Sân có ảnh riêng của chủ sân thì không có nhãn', (tester) async {
      await _pump(tester, _v(image: 'https://example.com/san-that.jpg'));
      expect(find.text('Ảnh minh họa'), findsNothing);
    });
  });

  group('Thao tác', () {
    testWidgets('Bấm thẻ mở chi tiết; bấm Đặt lịch chỉ đặt lịch; bấm tim chỉ đổi yêu thích', (tester) async {
      var tapped = 0, booked = 0, faved = 0;
      await _pump(tester, _v(), onTap: () => tapped++, onBook: () => booked++, onFav: () => faved++);

      await tester.tap(find.text('Đặt lịch'));
      expect([tapped, booked, faved], [0, 1, 0], reason: 'nút Đặt lịch không được mở luôn trang chi tiết');

      await tester.tap(_k('venue-fav-1'));
      expect([tapped, booked, faved], [0, 1, 1]);

      await tester.tap(find.text('Sân Cầu Lông Cầu Giấy Dịch Vọng'));
      expect([tapped, booked, faved], [1, 1, 1]);
    });

    testWidgets('Biểu tượng tim đổi theo trạng thái yêu thích', (tester) async {
      await _pump(tester, _v(), fav: false);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      await _pump(tester, _v(), fav: true);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });
  });

  group('Thanh quản lý (chủ sân, quản trị viên)', () {
    testWidgets('Khách thường không thấy Sửa, Xóa', (tester) async {
      await _pump(tester, _v(), manage: false);
      expect(find.text('Sửa'), findsNothing);
      expect(find.text('Xóa'), findsNothing);
    });

    testWidgets('Người quản lý thấy trạng thái duyệt và bấm được Sửa, Xóa', (tester) async {
      var edited = 0, deleted = 0;
      await _pump(tester, _v(), height: 470, manage: true, onEdit: () => edited++, onDelete: () => deleted++);
      expect(find.text('Đã duyệt'), findsOneWidget);
      await tester.tap(_k('venue-edit-1'));
      await tester.tap(_k('venue-delete-1'));
      expect([edited, deleted], [1, 1]);
    });

    testWidgets('Trạng thái hiển thị đúng với sân chờ duyệt và bị từ chối', (tester) async {
      await _pump(tester, _v(status: 'pending'), height: 470, manage: true);
      expect(find.text('Chờ duyệt'), findsOneWidget);
      await _pump(tester, _v(status: 'rejected'), height: 470, manage: true);
      expect(find.text('Bị từ chối'), findsOneWidget);
    });
  });

  testWidgets('Không tràn bố cục ở các bề rộng thẻ thường gặp (điện thoại hẹp đến máy tính 3 cột), kể cả tên và địa chỉ rất dài', (tester) async {
    final long = _v(
      name: 'Cụm Sân Pickleball Và Cầu Lông Quốc Tế Hoàng Quốc Việt Cầu Giấy Park Plaza',
      price: '1.200.000đ - 2.500.000đ/trận',
      distance: '12.4km',
      source: 'osm',
    );
    for (final w in [270.0, 300.0, 340.0, 380.0, 460.0, 560.0]) {
      await _pump(tester, long, width: w, height: w * 0.5 + 178, now: _at(10));
      expect(tester.takeException(), isNull, reason: 'bề rộng $w');
    }
    await _pump(tester, long, width: 340, height: 340 * 0.5 + 178 + 48, manage: true);
    expect(tester.takeException(), isNull, reason: 'có thanh quản lý');
  });
}
