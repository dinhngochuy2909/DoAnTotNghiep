import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/screens/account_screen.dart';
import 'package:alobooking/services/auth_service.dart';

// Màn "Tài khoản" viết theo bố cục máy tính (thanh bên 320 + khung nội dung 460). Trong khung điện thoại
// 430px, khung nội dung chỉ còn ~110px nên chữ bị xếp mỗi dòng một ký tự. Ở màn hẹp phải là một cột cuộn.

Future<void> _loadFont() async {
  final f = File('C:/Windows/Fonts/segoeui.ttf');
  if (!f.existsSync()) return;
  final loader = FontLoader('TestSans')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
}

/// Mở màn hình và trả về các lỗi framework (tràn bố cục...) phát sinh khi dựng. Luôn khôi phục
/// FlutterError.onError trước khi trả về, để lỗi ở các bước sau của test được báo bình thường.
Future<List<String>> _open(WidgetTester tester, Size size) async {
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
  try {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'TestSans'),
      home: const AccountScreen(venues: []),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  } finally {
    FlutterError.onError = old;
  }
  return errors;
}

void main() {
  setUpAll(_loadFont);
  setUp(() => AuthService.setCurrentUserForTest(null));

  for (final size in const [Size(360, 800), Size(390, 844), Size(430, 932)]) {
    testWidgets('Điện thoại ${size.width.toInt()}px: thẻ tài khoản đọc được, không tràn bố cục', (tester) async {
      final errors = await _open(tester, size);

      final msg = find.textContaining('Bạn chưa đăng nhập');
      await tester.ensureVisible(msg);
      // Câu dài phải trải trên chiều rộng thẻ, không bị bẻ từng ký tự
      expect(tester.getSize(msg).width, greaterThan(200));
      expect(tester.getSize(msg).height, lessThan(80));
      expect(errors, isEmpty);
    });
  }

  testWidgets('Máy tính 1440px: vẫn hai khung (thanh bên 320 + thẻ 460), không lỗi', (tester) async {
    final errors = await _open(tester, const Size(1440, 900));
    final msg = find.textContaining('Bạn chưa đăng nhập');
    expect(tester.getTopLeft(msg).dx, greaterThan(320), reason: 'thẻ tài khoản nằm ở khung bên phải');
    expect(errors, isEmpty);
  });
}
