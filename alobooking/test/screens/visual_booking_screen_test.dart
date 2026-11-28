import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/models/user.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/screens/visual_booking_screen.dart';
import 'package:alobooking/services/auth_service.dart';

Venue _venue({String type = 'pickleball', int courtCount = 0}) => Venue(
      id: 1,
      name: 'Cụm sân thử nghiệm',
      type: type,
      district: 'Cầu Giấy',
      distance: '1.0km',
      address: '1 Phố Thử, Cầu Giấy, Hà Nội',
      hours: '06:00 – 23:00',
      tags: const ['Mái che'],
      rating: 4.5,
      price: '100k - 200k/h',
      lat: 21.03,
      lng: 105.8,
      image: '',
      logo: '',
      courtCount: courtCount,
    );

/// Test mặc định dùng font Ahem (mỗi chữ rộng bằng cỡ chữ) nên báo tràn giả ở màn hình hẹp.
/// Nếu máy có Segoe UI (hỗ trợ tiếng Việt) thì nạp để đo độ rộng chữ gần thực tế.
Future<bool> _loadRealFont() async {
  final f = File('C:/Windows/Fonts/segoeui.ttf');
  if (!f.existsSync()) return false;
  final loader = FontLoader('TestSans')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
  return true;
}

Future<void> _openBooking(WidgetTester tester, Venue venue, {Size size = const Size(1000, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'TestSans'), home: VisualBookingScreen(venue: venue)));
  // Không dùng pumpAndSettle: màn hình có gọi mạng (trong test luôn trả 400)
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  var realFont = false;
  setUpAll(() async {
    realFont = await _loadRealFont();
  });
  tearDown(() => AuthService.setCurrentUserForTest(null));

  group('Số sân con của cụm', () {
    test('mặc định theo môn, nhiều hơn 3 sân; khai báo thì dùng số đã khai báo', () {
      expect(_venue(type: 'pickleball').courts, 6);
      expect(_venue(type: 'badminton').courts, 8);
      expect(_venue(type: 'football').courts, 4);
      expect(_venue(type: 'basketball').courts, 2);
      expect(_venue(type: 'badminton', courtCount: 12).courts, 12);
      expect(_venue(type: 'badminton', courtCount: 12).courtNames.last, 'Cầu lông 12');
    });

    test('số sân được lưu và đọc lại qua JSON và copyWith', () {
      final v = _venue(courtCount: 9);
      expect(Venue.fromJson(v.toJson()).courts, 9);
      expect(v.copyWith(name: 'X').courts, 9);
      expect(v.copyWith(courtCount: 3).courts, 3);
    });
  });

  group('Sân nhập từ OpenStreetMap (chưa có giá)', () {
    test('giá "Liên hệ" thì chưa niêm yết; giá dạng 100k - 200k/h thì đã niêm yết', () {
      expect(_venue().hasListedPrice, isTrue);
      expect(_venue().copyWith(price: 'Liên hệ').hasListedPrice, isFalse);
      expect(_venue().copyWith(price: '').hasListedPrice, isFalse);
      expect(_venue().copyWith(price: '320k - 650k/trận').hasListedPrice, isTrue);
    });

    test('chưa có đánh giá thì ghi "Mới", không hiện điểm giả', () {
      expect(_venue().copyWith(rating: 0).ratingLabel, 'Mới');
      expect(_venue().copyWith(rating: 4.5).ratingLabel, '4.5');
    });

    test('nguồn dữ liệu được giữ qua JSON và copyWith', () {
      final v = _venue().copyWith(source: 'osm');
      expect(v.fromOpenStreetMap, isTrue);
      expect(Venue.fromJson(v.toJson()).fromOpenStreetMap, isTrue);
    });

    test('sân nhập từ Overture Maps cũng được coi là sân nhập từ dữ liệu mở (giá, giờ chỉ là mức tham khảo)', () {
      final v = _venue().copyWith(source: 'overture');
      expect(v.isImportedListing, isTrue);
      expect(v.fromOpenStreetMap, isFalse);
      expect(Venue.fromJson(v.toJson()).source, 'overture');
      expect(_venue().copyWith(source: 'osm').isImportedListing, isTrue);
      expect(_venue().isImportedListing, isFalse);
    });

    test('sân demo được nhận diện, giữ qua JSON và không bị coi là sân nhập từ dữ liệu mở', () {
      final v = _venue().copyWith(source: 'demo');
      expect(v.isDemo, isTrue);
      expect(v.isImportedListing, isFalse);
      expect(Venue.fromJson(v.toJson()).isDemo, isTrue);
      expect(_venue().isDemo, isFalse);
      expect(_venue().copyWith(source: 'osm').isDemo, isFalse);
    });

    testWidgets('sân demo hiện cảnh báo và không cho chọn giờ để đặt', (tester) async {
      await _openBooking(tester, _venue().copyWith(name: '[Demo] Cầu lông Cầu Giấy 01', source: 'demo'));
      expect(find.byKey(const ValueKey('demo-venue-notice')), findsOneWidget);
      final cell = find.byKey(const ValueKey('slot-0-18'));
      await tester.ensureVisible(cell);
      await tester.tap(cell);
      await tester.pump();
      expect(find.textContaining('Đây là sân demo'), findsOneWidget);
      expect(find.textContaining('Tổng giờ: 0h00'), findsWidgets);
      expect(find.text('TIẾP THEO'), findsOneWidget);
    });

    testWidgets('không cho chọn giờ và không hiện giá bịa khi sân chưa niêm yết giá', (tester) async {
      await _openBooking(tester, _venue().copyWith(price: 'Liên hệ', source: 'osm'));
      expect(find.textContaining('chưa niêm yết giá'), findsWidgets);
      final cell = find.byKey(const ValueKey('slot-0-18'));
      await tester.ensureVisible(cell);
      await tester.tap(cell);
      await tester.pump();
      expect(find.textContaining('Tổng giờ: 0h00'), findsWidgets);
    });
  });

  testWidgets('Cụm pickleball hiển thị đủ 6 sân và thanh tổng tiền', (tester) async {
    await _openBooking(tester, _venue());
    for (var i = 1; i <= 6; i++) {
      expect(find.text('Pickleball $i'), findsOneWidget);
    }
    expect(find.text('Pickleball 7'), findsNothing);
    expect(find.textContaining('Tổng giờ: 0h00'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cụm cầu lông khai báo 12 sân hiển thị đủ 12 sân, không còn nhãn Pickleball', (tester) async {
    await _openBooking(tester, _venue(type: 'badminton', courtCount: 12));
    for (var i = 1; i <= 12; i++) {
      expect(find.text('Cầu lông $i'), findsOneWidget);
    }
    expect(find.textContaining('Pickleball'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Màn hình điện thoại không tràn bố cục khi cụm có nhiều sân', (tester) async {
    await _openBooking(tester, _venue(type: 'badminton', courtCount: 12), size: const Size(390, 844));
    final e = tester.takeException();
    // Không có font thật thì chữ rộng hơn thực tế, bỏ qua kiểm tra tràn ở bước này
    if (realFont) expect(e, isNull);
    expect(find.text('Cầu lông 12'), findsOneWidget);
  });

  testWidgets('Ghi chú hủy lịch khớp chức năng: chỉ cách hủy, không còn nói là không hủy được', (tester) async {
    await _openBooking(tester, _venue());
    expect(find.textContaining('có thể hủy trong mục "Sân đã đặt"'), findsOneWidget);
    expect(find.textContaining('KHÔNG hỗ trợ'), findsNothing);
  });

  testWidgets('Xác nhận đặt sân chỉ có chuyển khoản, không có tiền mặt', (tester) async {
    AuthService.setCurrentUserForTest(AppUser(
      uid: 'u1',
      fullName: 'Khách Thử',
      email: 'khach@example.com',
      phone: '0900000000',
    ));
    await _openBooking(tester, _venue());

    final cell = find.byKey(const ValueKey('slot-0-18'));
    await tester.ensureVisible(cell);
    await tester.tap(cell);
    await tester.pump();
    expect(find.textContaining('Tổng giờ: 1h00'), findsWidgets);

    await tester.tap(find.text('TIẾP THEO'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Xác Nhận Đặt Sân'), findsOneWidget);
    expect(find.textContaining('Chuyển khoản ngân hàng bằng mã VietQR'), findsOneWidget);
    expect(find.text('Tiền mặt tại sân'), findsNothing);
    expect(find.text('XÁC NHẬN & THANH TOÁN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
