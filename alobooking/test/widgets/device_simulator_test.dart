import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/main.dart';
import 'package:alobooking/models/user.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/screens/visual_booking_screen.dart';
import 'package:alobooking/services/auth_service.dart';
import 'package:alobooking/widgets/device_simulator_wrapper.dart';

// Khung "Xem Demo iPhone" bọc cả ứng dụng ở MaterialApp.builder, tức là NẰM NGOÀI Navigator/Overlay của ứng dụng.
// Từ Flutter 3.4x, Tooltip (và IconButton có tooltip) không có Overlay sẽ báo "No Overlay widget found" và
// làm cả khung đỏ lòm. Các test này mở khung demo ở từng loại máy rồi đi hết luồng đặt sân.

Venue _venue() => Venue(
      id: 1,
      name: 'Cụm sân thử nghiệm',
      type: 'badminton',
      district: 'Cầu Giấy',
      distance: '1.0km',
      address: '1 Phố Thử, Cầu Giấy, Hà Nội',
      hours: '06:00 – 23:00',
      tags: const ['Mái che'],
      rating: 4.5,
      price: '80k - 100k/h',
      lat: 21.03,
      lng: 105.8,
      image: '',
      logo: '',
    );

Future<void> _loadFont() async {
  final f = File('C:/Windows/Fonts/segoeui.ttf');
  if (!f.existsSync()) return;
  final loader = FontLoader('TestSans')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
}

/// Chạy [body] và gom mọi lỗi framework (không dừng ở lỗi đầu tiên). Luôn khôi phục FlutterError.onError
/// trước khi trả về, để lỗi ở các bước sau của test (expect, find...) được báo bình thường thay vì làm kẹt test.
Future<List<String>> _capturing(Future<void> Function() body) async {
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
  try {
    await body();
  } finally {
    FlutterError.onError = old;
  }
  return errors;
}

void _useScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(_loadFont);
  tearDown(() => AuthService.setCurrentUserForTest(null));

  for (final dev in DeviceType.values) {
    for (final landscape in const [false, true]) {
      testWidgets('Khung demo ${dev.name} ${landscape ? "xoay ngang" : "dọc"}: đặt sân không lỗi', (tester) async {
        AuthService.setCurrentUserForTest(AppUser(uid: 'u1', fullName: 'Khách Thử', email: 'k@example.com', phone: '0900000000'));
        _useScreen(tester, const Size(1440, 900));

        final errors = await _capturing(() async {
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(fontFamily: 'TestSans'),
            builder: (context, child) => DeviceSimulatorWrapper(child: child!),
            home: VisualBookingScreen(venue: _venue()),
          ));
          await tester.pump(const Duration(milliseconds: 500));

          await tester.tap(find.textContaining('Xem Demo iPhone'));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.tap(find.byKey(ValueKey('device-${dev.name}')));
          await tester.pump(const Duration(milliseconds: 400));
          if (landscape) {
            await tester.tap(find.byIcon(Icons.screen_rotation));
            await tester.pump(const Duration(milliseconds: 400));
          }

          // Bảng giá hiện ca giờ vàng 16:00 – 22:00
          await tester.ensureVisible(find.text('Xem sân & bảng giá'));
          await tester.tap(find.text('Xem sân & bảng giá'));
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.textContaining('Ca giờ vàng (16:00 – 22:00)'), findsOneWidget);
          await tester.tap(find.text('Đã hiểu'));
          await tester.pump(const Duration(milliseconds: 400));

          // Chọn một giờ rồi sang bước xác nhận
          final cell = find.byKey(const ValueKey('slot-0-18'));
          await tester.ensureVisible(cell);
          await tester.tap(cell);
          await tester.pump();
          expect(find.textContaining('Tổng giờ: 1h00'), findsWidgets);
          await tester.tap(find.text('TIẾP THEO'));
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text('XÁC NHẬN & THANH TOÁN'), findsOneWidget);
        });

        expect(errors, isEmpty);
      });
    }
  }

  for (final size in const [Size(900, 700), Size(1366, 768)]) {
    testWidgets('Thanh điều khiển khung demo không tràn ở cửa sổ ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      _useScreen(tester, size);
      final errors = await _capturing(() async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(fontFamily: 'TestSans'),
          builder: (context, child) => DeviceSimulatorWrapper(child: child!),
          home: const Scaffold(body: SizedBox.expand()),
        ));
        await tester.tap(find.textContaining('Xem Demo iPhone'));
        await tester.pump(const Duration(milliseconds: 500));
      });
      expect(find.byKey(const ValueKey('device-iPad Pro 11"')), findsOneWidget);
      expect(errors, isEmpty);
    });
  }

  testWidgets('Ứng dụng thật (trang chủ) bật được khung demo điện thoại mà không lỗi Overlay/Navigator', (tester) async {
    _useScreen(tester, const Size(1440, 900));
    final errors = await _capturing(() async {
      await tester.pumpWidget(const AlobookingApp());
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.textContaining('Xem Demo iPhone'));
      await tester.pump(const Duration(seconds: 1));
    });
    expect(find.byKey(const ValueKey('device-iPhone 18')), findsOneWidget);
    // Trang chủ có thể báo tràn nhẹ vì thiếu font thật; chỉ cấm đúng lỗi thiếu Overlay/Navigator
    expect(errors.where((e) => e.contains('Overlay') || e.contains('Navigator')), isEmpty);
  });
}
