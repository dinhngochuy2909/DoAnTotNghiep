// Nút "Quên mật khẩu?" ở màn đăng nhập: hỏi email rồi nhờ Firebase gửi thư (máy chủ giả).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alobooking/screens/login_screen.dart';

/// Phông mặc định của test rộng hơn phông thật nên báo tràn giả: nạp Segoe UI nếu máy có.
Future<void> _loadRealFont() async {
  final f = File('C:/Windows/Fonts/segoeui.ttf');
  if (!f.existsSync()) return;
  await (FontLoader('TestSans')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)))).load();
}

Future<List<http.Request>> _run(
  WidgetTester tester,
  http.Response Function(http.Request r) reply,
  Future<void> Function() body,
) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final seen = <http.Request>[];
  await http.runWithClient(() async {
    await tester.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'TestSans'), home: const LoginScreen()));
    await tester.pumpAndSettle();
    await body();
  }, () => MockClient((r) async {
        seen.add(r);
        return reply(r);
      }));
  return seen;
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadRealFont);

  testWidgets('gửi thư đặt lại mật khẩu tới email đã nhập, không tiết lộ email có tồn tại hay không', (tester) async {
    final seen = await _run(tester, (r) => _json({'email': 'a@thu.vn'}), () async {
      await tester.enterText(find.byType(TextFormField).first, 'A@Thu.vn');
      await _tap(tester, find.text('Quên mật khẩu?'));
      expect(find.text('Đặt lại mật khẩu'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'A@Thu.vn'), findsWidgets, reason: 'điền sẵn email đang nhập');
      await _tap(tester, find.byKey(const ValueKey('forgot-send')));
      expect(find.textContaining('Nếu email này đã đăng ký'), findsOneWidget);
      expect(find.text('Đặt lại mật khẩu'), findsNothing);
    });
    expect(seen.single.url.path, endsWith('accounts:sendOobCode'));
    expect(jsonDecode(seen.single.body), {'requestType': 'PASSWORD_RESET', 'email': 'a@thu.vn'});
    expect(seen.single.headers['X-Firebase-Locale'], 'vi');
  });

  testWidgets('email sai dạng thì không gửi; máy chủ báo quá nhiều lần thì nói đúng lý do', (tester) async {
    final seen = await _run(tester, (r) => _json({'error': {'message': 'RESET_PASSWORD_EXCEED_LIMIT'}}, 400), () async {
      await _tap(tester, find.text('Quên mật khẩu?'));
      await tester.enterText(find.byKey(const ValueKey('forgot-email')), 'khong-phai-email');
      await _tap(tester, find.byKey(const ValueKey('forgot-send')));
      expect(find.text('Email không hợp lệ'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('forgot-email')), 'a@thu.vn');
      await _tap(tester, find.byKey(const ValueKey('forgot-send')));
      expect(find.textContaining('quá nhiều lần'), findsOneWidget);
    });
    expect(seen, hasLength(1));
  });
}
