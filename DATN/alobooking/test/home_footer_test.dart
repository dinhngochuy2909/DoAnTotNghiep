import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/main.dart';
import 'package:alobooking/screens/info_page_screen.dart';

Finder _k(String key) => find.byKey(ValueKey(key));

/// Vị trí cuộn của danh sách trang chủ (nơi chân trang nằm ở cuối).
double _offset(WidgetTester tester) =>
    tester.state<ScrollableState>(find.descendant(of: find.byType(CustomScrollView).first, matching: find.byType(Scrollable)).first).position.pixels;

/// Không dùng pumpAndSettle: nút chat AI nổi có hoạt ảnh lặp vô hạn nên không bao giờ "yên".
Future<void> _wait(WidgetTester tester, [int ms = 700]) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(Duration(milliseconds: ms));
}

Future<void> _openHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 500); // thấp để danh sách phải cuộn mới thấy chân trang
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const AlobookingApp());
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _scrollDown(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -2000));
  await _wait(tester);
}

/// Font mặc định của test (Ahem) rất rộng nên báo tràn giả; nạp Segoe UI làm font của ứng dụng để đo gần thực tế.
Future<void> _loadRealFont() async {
  final f = File('C:/Windows/Fonts/segoeui.ttf');
  if (!f.existsSync()) return;
  final loader = FontLoader('Be Vietnam Pro')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
}

void main() {
  setUpAll(_loadRealFont);

  testWidgets('Chân trang thật trên trang chủ: "Trang chủ" và "Lên đầu trang" đưa người dùng về đầu trang', (tester) async {
    await _openHome(tester);
    expect(_offset(tester), 0);

    await _scrollDown(tester);
    expect(_offset(tester), greaterThan(100), reason: 'đã cuộn xuống tới chân trang');
    await tester.ensureVisible(_k('footer-link-home'));
    await tester.pump();
    await tester.tap(_k('footer-link-home'));
    await _wait(tester);
    expect(_offset(tester), 0);

    await _scrollDown(tester);
    expect(_offset(tester), greaterThan(100));
    await tester.ensureVisible(_k('footer-to-top'));
    await tester.pump();
    await tester.tap(_k('footer-to-top'));
    await _wait(tester);
    expect(_offset(tester), 0);
  });

  testWidgets('Bấm một môn ở chân trang: chip môn đó sáng lên và trang cuộn lên đầu', (tester) async {
    await _openHome(tester);
    Color? chipColor(String label) => tester.widget<Text>(find.text(label)).style?.color;

    expect(chipColor('Tennis 🎾'), isNot(Colors.white), reason: 'ban đầu chưa chọn môn nào');
    await _scrollDown(tester);
    await tester.ensureVisible(_k('footer-link-sport-tennis'));
    await tester.pump();
    await tester.tap(_k('footer-link-sport-tennis'));
    await _wait(tester);

    expect(_offset(tester), 0, reason: 'cuộn lên đầu để thấy các chip môn');
    expect(chipColor('Tennis 🎾'), Colors.white, reason: 'chip Tennis được chọn (chữ trắng trên nền xanh)');
    expect(chipColor('Cầu lông 🏸'), isNot(Colors.white));

    // chọn môn khác ở chân trang thì chip trước đó bỏ chọn
    await _scrollDown(tester);
    await tester.ensureVisible(_k('footer-link-sport-basketball'));
    await tester.pump();
    await tester.tap(_k('footer-link-sport-basketball'));
    await _wait(tester);
    expect(chipColor('Bóng rổ 🏀'), Colors.white);
    expect(chipColor('Tennis 🎾'), isNot(Colors.white));

    // "Trang chủ" trả về "Tất cả sân"
    await _scrollDown(tester);
    await tester.ensureVisible(_k('footer-link-home'));
    await tester.pump();
    await tester.tap(_k('footer-link-home'));
    await _wait(tester);
    expect(chipColor('Tất cả sân'), Colors.white);
    expect(chipColor('Bóng rổ 🏀'), isNot(Colors.white));
  });

  testWidgets('Từ chân trang trang chủ mở được trang Chính sách bảo mật', (tester) async {
    await _openHome(tester);
    await _scrollDown(tester);
    await tester.ensureVisible(_k('footer-link-info-privacy'));
    await tester.pump();
    await tester.tap(_k('footer-link-info-privacy'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(InfoPageScreen), findsOneWidget);
    expect(_k('info-page-privacy'), findsOneWidget);
  });
}
