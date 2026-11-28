import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/screens/venue_finder_screen.dart';
import 'package:alobooking/screens/visual_booking_screen.dart';
import 'package:alobooking/services/firestore_service.dart';

/// Hôm nay giả định: thứ bảy 21/11/2026, 10:30 (nên các khung giờ từ 11:00 trở đi mới còn đặt được).
final _now = DateTime(2026, 11, 21, 10, 30);

Venue _v(
  int id,
  String name, {
  String type = 'badminton',
  String district = 'Cầu Giấy',
  String price = '80k - 100k/h',
  String hours = '06:00 – 22:00',
  int courts = 2,
  double lat = 21.03,
  double lng = 105.80,
  String source = '',
  double rating = 4.5,
}) =>
    Venue(
      id: id,
      name: name,
      type: type,
      district: district,
      distance: '',
      address: '$id Phố Thử, $district, Hà Nội',
      hours: hours,
      tags: const [],
      rating: rating,
      price: price,
      lat: lat,
      lng: lng,
      image: '',
      logo: '',
      courtCount: courts,
      source: source,
    );

List<Venue> _venues() => [
      _v(1, 'Sân Alpha', rating: 4.8),
      _v(2, 'Sân Beta Tennis', type: 'tennis', district: 'Hà Đông', price: '200k - 250k/h', courts: 1, lat: 20.96, lng: 105.77, rating: 4.2),
      _v(3, '[Demo] Cầu lông Hà Đông 01', district: 'Hà Đông', source: 'demo', rating: 0, lat: 21.0, lng: 105.8),
      _v(4, 'Sân Gamma', price: 'Liên hệ'),
      _v(5, 'Sân Delta', type: 'pickleball', district: 'Đống Đa', price: '140k - 175k/h', courts: 6, lat: 21.01, lng: 105.82, rating: 4.9),
    ];

BookingItem _b(String venue, String field, String time, String date) => BookingItem(
      id: '$venue$field$time$date',
      customer: 'Khách',
      phone: '0900000000',
      venueName: venue,
      field: field,
      time: time,
      date: date,
      amount: '100000',
      status: 'Đã đặt',
      paymentMethod: 'Chuyển khoản',
    );

Future<List<BookingItem>> _bookings() async => [
      // Hôm nay: Alpha kín 1/2 sân lúc 11h, Beta (1 sân) kín lúc 12h
      _b('Sân Alpha', 'Cầu lông 1', '11:00 - 12:00', '21/11/2026'),
      _b('Sân Beta Tennis', 'Tennis 1', '12:00 - 13:00', '21/11/2026'),
      // Ngày mai: Alpha kín cả 2 sân lúc 7h
      _b('Sân Alpha', 'Cầu lông 1', '07:00 - 08:00', '22/11/2026'),
      _b('Sân Alpha', 'Cầu lông 2', '07:00 - 08:00', '22/11/2026'),
    ];

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
  Size size = const Size(1600, 1300),
  BookingsLoader? bookings,
  LocationLoader? location,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'TestSans'),
    home: VenueFinderScreen(
      venues: venues ?? _venues(),
      bookingsLoader: bookings ?? _bookings,
      locationLoader: location,
      now: _now,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

/// Mã các thẻ sân đang được dựng, theo thứ tự hiển thị.
List<int> _cardIds(WidgetTester tester) => [
      for (final w in tester.widgetList(find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('explore-card-'))))
        int.parse('${(w.key as ValueKey).value}'.substring('explore-card-'.length)),
    ];

Finder _k(String key) => find.byKey(ValueKey(key));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_k(key));
  await tester.tap(_k(key));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  var realFont = false;
  setUpAll(() async {
    realFont = await _loadRealFont();
  });

  testWidgets('Cửa sổ rộng: bộ lọc bên trái, dải 14 ngày, thẻ sân xếp đúng thứ tự và đếm đúng khung giờ trống', (tester) async {
    await _open(tester);
    if (realFont) expect(tester.takeException(), isNull);

    expect(_k('explore-sidebar'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    for (final d in ['20261121', '20261122', '20261204']) {
      expect(_k('day-$d'), findsOneWidget);
    }
    expect(_k('day-20261205'), findsNothing);

    // Thứ tự "phù hợp nhất": sân thật còn chỗ (đánh giá cao trước) -> sân chưa còn khung giờ -> sân demo cuối cùng
    expect(_cardIds(tester), [5, 1, 2, 4, 3]);
    // Alpha: 11 khung (11h-21h); Beta: 11 khung trừ 12h đã kín = 10; Delta: 11 khung
    expect(find.text('5 sân · 32 khung giờ trống'), findsOneWidget);
  });

  testWidgets('Khung giờ lấy từ lịch đặt thật: ô còn một nửa số sân, ô kín; giờ đã qua của hôm nay bị ẩn', (tester) async {
    await _open(tester);
    expect(_k('explore-slot-1-10'), findsNothing, reason: '10h đã qua (hiện 10:30)');
    expect(_k('explore-slot-1-11'), findsOneWidget);
    expect(find.descendant(of: _k('explore-slot-1-11'), matching: find.text('1/2 sân')), findsOneWidget);
    expect(find.descendant(of: _k('explore-slot-1-12'), matching: find.text('2/2 sân')), findsOneWidget);
    expect(find.descendant(of: _k('explore-slot-2-12'), matching: find.text('Hết chỗ')), findsOneWidget);
    // Giờ vàng (16:00 - 22:00) có biểu tượng lửa, khung giờ thường thì không
    expect(find.descendant(of: _k('explore-slot-1-12'), matching: find.byIcon(Icons.local_fire_department_rounded)), findsNothing);
    await _tap(tester, 'pill-daypart-evening');
    expect(find.descendant(of: _k('explore-slot-1-18'), matching: find.byIcon(Icons.local_fire_department_rounded)), findsOneWidget);
  });

  testWidgets('Chọn ngày khác: khung giờ tính từ giờ mở cửa và theo lịch đặt của ngày đó', (tester) async {
    await _open(tester);
    await _tap(tester, 'day-20261122');
    expect(_k('explore-slot-1-6'), findsOneWidget);
    expect(find.descendant(of: _k('explore-slot-1-7'), matching: find.text('Hết chỗ')), findsOneWidget);
    expect(find.descendant(of: _k('explore-slot-1-11'), matching: find.text('2/2 sân')), findsOneWidget, reason: 'đơn của hôm nay không ảnh hưởng ngày mai');
    expect(find.text('Hôm nay'), findsOneWidget);
  });

  testWidgets('Ô hết chỗ khóa nút đặt; ô còn chỗ mở màn đặt sân đúng ngày đã chọn', (tester) async {
    await _open(tester);
    await _tap(tester, 'explore-slot-2-12');
    expect(find.descendant(of: _k('explore-detail-2'), matching: find.text('Hết chỗ')), findsWidgets);
    expect(tester.widget<ElevatedButton>(_k('explore-book-2')).onPressed, isNull);

    await _tap(tester, 'day-20261122');
    expect(tester.widget<ElevatedButton>(_k('explore-book-1')).onPressed, isNotNull);
    await _tap(tester, 'explore-book-1');
    await tester.pump(const Duration(milliseconds: 500));
    final screen = tester.widget<VisualBookingScreen>(find.byType(VisualBookingScreen));
    expect(screen.venue.id, 1);
    expect(screen.initialDate, DateTime(2026, 11, 22));
  });

  testWidgets('Sân demo có nhãn DEMO, không có ô giờ, ẩn được bằng công tắc', (tester) async {
    await _open(tester);
    expect(find.descendant(of: _k('explore-card-3'), matching: find.text('DEMO')), findsOneWidget);
    expect(_k('explore-demo-note-3'), findsOneWidget);
    expect(find.descendant(of: _k('explore-card-3'), matching: find.byType(ListView)), findsNothing);
    expect(_k('explore-book-3'), findsNothing, reason: 'sân demo không đặt được');

    await _tap(tester, 'explore-hide-demo');
    expect(_k('explore-card-3'), findsNothing);
    expect(_cardIds(tester), [5, 1, 2, 4]);
  });

  testWidgets('Sân chưa niêm yết giá không có ô giờ và báo liên hệ cơ sở', (tester) async {
    await _open(tester);
    expect(find.descendant(of: _k('explore-card-4'), matching: find.textContaining('chưa niêm yết giá')), findsOneWidget);
    expect(_k('explore-slot-4-11'), findsNothing);
  });

  testWidgets('Lọc theo môn, buổi chơi, khoảng giá, còn chỗ và tìm kiếm không dấu; Đặt lại trả về tất cả', (tester) async {
    await _open(tester);

    await _tap(tester, 'pill-sport-tennis');
    expect(_cardIds(tester), [2]);
    await _tap(tester, 'explore-reset');
    expect(_cardIds(tester), [5, 1, 2, 4, 3]);

    await _tap(tester, 'pill-daypart-evening');
    expect(_cardIds(tester), [5, 1, 2], reason: 'sân chưa niêm yết giá và sân demo không có khung giờ');
    expect(_k('explore-slot-1-17'), findsNothing);
    expect(_k('explore-slot-1-18'), findsOneWidget);
    await _tap(tester, 'explore-reset');

    await _tap(tester, 'pill-price-lt100');
    expect(_cardIds(tester), [1, 3], reason: 'sân demo cũng có giá 80k - 100k; sân chưa niêm yết giá thì không'); 
    await _tap(tester, 'pill-price-100to200');
    expect(_cardIds(tester), [5, 2]);
    await _tap(tester, 'explore-reset');

    await _tap(tester, 'explore-only-free');
    expect(_cardIds(tester), [5, 1, 2]);
    await _tap(tester, 'explore-reset');

    await tester.enterText(_k('explore-search'), 'ha dong');
    await tester.pump();
    expect(_cardIds(tester), [2, 3]);
    await tester.enterText(_k('explore-search'), 'alpha');
    await tester.pump();
    expect(_cardIds(tester), [1]);
    await tester.enterText(_k('explore-search'), 'cau giay alpha');
    await tester.pump();
    expect(_cardIds(tester), [1], reason: 'từ 3 từ trở lên chỉ cần có đủ các từ, không cần đúng thứ tự');
    await tester.enterText(_k('explore-search'), 'Hà Đông');
    await tester.pump();
    expect(_cardIds(tester), [2, 3], reason: 'không khớp nhầm "Hà Nội, Đống Đa"');
  });

  testWidgets('Theo quận/huyện: chọn một quận chỉ còn sân của quận đó', (tester) async {
    await _open(tester);
    await _tap(tester, 'area-district');
    expect(_k('pill-district-Hà Đông'), findsOneWidget);
    await _tap(tester, 'pill-district-Hà Đông');
    expect(_cardIds(tester), [2, 3]);
    await _tap(tester, 'pill-district-all');
    expect(_cardIds(tester).length, 5);
  });

  testWidgets('Không có kết quả: hiện thông báo và nút đặt lại', (tester) async {
    await _open(tester);
    await tester.enterText(_k('explore-search'), 'zzzz không có');
    await tester.pump();
    expect(find.text('Không có sân phù hợp với bộ lọc'), findsOneWidget);
    expect(find.text('0 sân · 0 khung giờ trống'), findsOneWidget);
    await _tap(tester, 'explore-empty-reset');
    expect(_cardIds(tester).length, 5);
  });

  testWidgets('Định vị: hiện khoảng cách, sắp xếp gần nhất và lọc theo bán kính', (tester) async {
    await _open(tester, location: () async => (lat: 21.03, lng: 105.80));
    await _tap(tester, 'explore-locate');
    await tester.pump(const Duration(milliseconds: 100));

    // Mặc định trong 10 km: cả 5 sân đều nằm trong, gần nhất lên trước
    expect(_cardIds(tester).first, 1);
    expect(find.descendant(of: _k('explore-card-1'), matching: find.textContaining('0,0 km')), findsOneWidget);
    expect(find.descendant(of: _k('explore-card-2'), matching: find.textContaining(RegExp(r'8,\d km'))), findsOneWidget);
    expect(_cardIds(tester).length, 5);

    await _tap(tester, 'pill-radius-5');
    expect(_cardIds(tester).contains(2), isFalse, reason: 'Beta cách khoảng 8,4 km');
    expect(_cardIds(tester).contains(5), isTrue, reason: 'Delta cách khoảng 2,9 km');
  });

  testWidgets('Không lấy được vị trí: báo lỗi, không lọc theo bán kính', (tester) async {
    await _open(tester, location: () async => null);
    await _tap(tester, 'explore-locate');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Không lấy được vị trí'), findsOneWidget);
    expect(_cardIds(tester).length, 5);
  });

  testWidgets('Không tải được lịch đặt: hiện cảnh báo và thử lại được', (tester) async {
    var calls = 0;
    await _open(tester, bookings: () async {
      calls++;
      if (calls == 1) throw Exception('mạng lỗi');
      return _bookings();
    });
    expect(find.textContaining('Chưa tải được lịch đặt sân'), findsOneWidget);
    await _tap(tester, 'explore-slot-1-11');
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Chưa tải được lịch đặt sân'), findsNothing);
    expect(find.descendant(of: _k('explore-slot-1-11'), matching: find.text('1/2 sân')), findsOneWidget);
  });

  testWidgets('Không có sân nào: hiện thông báo trống', (tester) async {
    await _open(tester, venues: const []);
    expect(find.text('Chưa có sân nào để khám phá.'), findsOneWidget);
  });

  testWidgets('Điện thoại: bộ lọc nằm trong bảng trượt lên, không tràn bố cục', (tester) async {
    await _open(tester, size: const Size(390, 844));
    if (realFont) expect(tester.takeException(), isNull);
    expect(_k('explore-sidebar'), findsNothing);
    expect(_k('explore-filter-button'), findsOneWidget);
    expect(find.text('Bộ lọc'), findsOneWidget);

    await _tap(tester, 'explore-filter-button');
    await tester.pump(const Duration(milliseconds: 400));
    expect(_k('pill-sport-tennis'), findsOneWidget);
    await tester.tap(_k('pill-sport-tennis'));
    await tester.pump();
    // Bảng lọc cập nhật ngay số kết quả
    expect(find.text('Xem 1 sân'), findsOneWidget);
    await tester.tap(_k('explore-sheet-apply'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(_cardIds(tester), [2]);
    expect(find.text('Bộ lọc (1)'), findsOneWidget);
    if (realFont) expect(tester.takeException(), isNull);
  });

  testWidgets('Điện thoại: thẻ sân hiện ô giờ và dải khung giờ đang chọn không tràn', (tester) async {
    await _open(tester, size: const Size(390, 844));
    await tester.enterText(_k('explore-search'), 'alpha');
    await tester.pump();
    expect(_cardIds(tester), [1]);
    expect(_k('explore-slot-1-11'), findsOneWidget);
    expect(_k('explore-detail-1'), findsOneWidget);
    expect(find.descendant(of: _k('explore-detail-1'), matching: find.textContaining('/ giờ')), findsOneWidget);
    if (realFont) expect(tester.takeException(), isNull);
  });
}
