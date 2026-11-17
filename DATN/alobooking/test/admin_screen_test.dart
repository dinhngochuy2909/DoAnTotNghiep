import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/data/venues_data.dart';
import 'package:alobooking/screens/admin_screen.dart';

/// Test mặc định dùng font Ahem (mỗi chữ rộng bằng cỡ chữ) nên báo tràn giả.
/// Nếu máy có Segoe UI (hỗ trợ tiếng Việt) thì nạp để đo độ rộng chữ gần thực tế.
Future<bool> _loadRealFont() async {
  final f = File('C:/Windows/Fonts/segoeui.ttf');
  if (!f.existsSync()) return false;
  final loader = FontLoader('Be Vietnam Pro')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
  return true;
}

void main() {
  var realFont = false;
  setUpAll(() async {
    realFont = await _loadRealFont();
  });

  const sizes = {
    'desktop 1440': Size(1440, 900),
    'laptop 1024': Size(1024, 768),
    'tablet 800': Size(800, 1000),
    'phone 390': Size(390, 844),
  };
  const tabs = ['Tổng quan', 'Quản lý sân', 'Đơn đặt sân', 'Khách hàng', 'Thanh toán'];

  for (final entry in sizes.entries) {
    for (var tab = 0; tab < tabs.length; tab++) {
      testWidgets('Admin ${tabs[tab]} hiển thị không lỗi bố cục ở ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(MaterialApp(
          home: AdminScreen(initialVenues: sampleVenues, initialTabIndex: tab),
        ));
        // Mạng trong test luôn trả lỗi nên dữ liệu rơi về mẫu; chờ tải xong
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump(const Duration(milliseconds: 800));

        if (realFont) expect(tester.takeException(), isNull);
        expect(find.text(tabs[tab]), findsWidgets);
      });
    }
  }

  testWidgets('Trang Tổng quan không còn số liệu bịa cứng', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: AdminScreen(initialVenues: sampleVenues)));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));

    for (final fake in ['128.500.000đ', '984 lượt', '86.2%', 'Cloud Sync Live', 'ROOT ADMIN', 'v2.5.0', 'ML Forecast', '+18% so với hôm qua']) {
      expect(find.textContaining(fake), findsNothing, reason: 'còn chuỗi giả: $fake');
    }
  });
}
