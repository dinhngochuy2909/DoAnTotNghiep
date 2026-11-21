import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/data/info_pages.dart';
import 'package:alobooking/screens/info_page_screen.dart';
import 'package:alobooking/widgets/app_footer.dart';

/// Test mặc định dùng font Ahem nên báo tràn giả; nếu có Segoe UI thì nạp để đo gần thực tế.
Future<bool> _loadRealFont() async {
  final f = File('C:/Windows/Fonts/segoeui.ttf');
  if (!f.existsSync()) return false;
  final loader = FontLoader('TestSans')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
  return true;
}

Finder _k(String key) => find.byKey(ValueKey(key));

Future<void> _pump(WidgetTester tester, {FooterActions actions = const FooterActions(), double width = 1280}) async {
  tester.view.physicalSize = Size(width, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'TestSans'),
    home: Scaffold(body: SingleChildScrollView(child: AppFooter(actions: actions))),
  ));
  await tester.pump();
}

void main() {
  var realFont = false;
  setUpAll(() async {
    realFont = await _loadRealFont();
  });

  group('Bố cục chân trang', () {
    for (final w in [1920.0, 1280.0, 1100.0, 900.0, 760.0, 600.0, 390.0, 320.0]) {
      testWidgets('Rộng ${w.toInt()}px: đủ các cột, dải thanh toán & cam kết, không tràn', (tester) async {
        await _pump(tester, width: w, actions: FooterActions(onTop: () {}, onHome: () {}));
        for (final t in ['Liên kết nhanh', 'Thể thao', 'Về AloBooking', 'Chính sách', 'Liên hệ & Hỗ trợ', 'Thanh toán', 'Cam kết minh bạch']) {
          expect(find.text(t), findsOneWidget, reason: 'thiếu "$t" ở rộng ${w.toInt()}');
        }
        expect(_k('footer-trust'), findsOneWidget);
        expect(_k('footer-to-top'), findsOneWidget);
        if (realFont) expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Có đủ 4 cam kết và dòng "không nhận tiền mặt", đúng với cách ứng dụng chạy', (tester) async {
      await _pump(tester);
      for (final t in [
        'Kiểm tra trùng giờ trước khi ghi nhận đơn',
        'Sân chưa niêm yết giá không nhận đặt online',
        'Sân Demo luôn có nhãn, không nhận đặt hay thanh toán',
        'Ảnh minh họa và dữ liệu mở luôn ghi rõ nguồn',
        'Không nhận tiền mặt.',
        'Chuyển khoản VietQR',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
    });
  });

  group('Liên kết', () {
    testWidgets('Liên kết nhanh và các môn gọi đúng hành động', (tester) async {
      final calls = <String>[];
      await _pump(
        tester,
        actions: FooterActions(
          onHome: () => calls.add('home'),
          onSearch: () => calls.add('search'),
          onBooked: () => calls.add('booked'),
          onFavorites: () => calls.add('favorites'),
          onAccount: () => calls.add('account'),
          onTop: () => calls.add('top'),
          onSport: (t) => calls.add('sport:$t'),
        ),
      );
      for (final id in ['home', 'search', 'booked', 'favorites', 'account']) {
        await tester.tap(_k('footer-link-$id'));
      }
      for (final sport in ['badminton', 'pickleball', 'football', 'tennis', 'basketball']) {
        await tester.tap(_k('footer-link-sport-$sport'));
      }
      await tester.tap(_k('footer-to-top'));
      expect(calls, [
        'home', 'search', 'booked', 'favorites', 'account',
        'sport:badminton', 'sport:pickleball', 'sport:football', 'sport:tennis', 'sport:basketball',
        'top',
      ]);
    });

    testWidgets('Chưa gắn hành động thì liên kết chỉ là chữ thường, không bấm được; không có nút Lên đầu trang', (tester) async {
      await _pump(tester);
      Finder tappable(String key) => find.byWidgetPredicate((w) => w is InkWell && w.key == ValueKey(key));
      for (final id in ['home', 'search', 'booked', 'favorites', 'account', 'sport-tennis']) {
        expect(_k('footer-link-$id'), findsOneWidget, reason: 'vẫn hiện chữ: $id');
        expect(tappable('footer-link-$id'), findsNothing, reason: id);
      }
      expect(_k('footer-to-top'), findsNothing);
      // các trang thông tin thì luôn bấm được
      expect(tappable('footer-link-info-about'), findsOneWidget);
    });

    testWidgets('Bảy trang thông tin: mỗi liên kết ở chân trang mở đúng trang', (tester) async {
      final links = {
        InfoPageId.about: 'Giới thiệu AloBooking',
        InfoPageId.guide: 'Hướng dẫn đặt sân',
        InfoPageId.faq: 'Câu hỏi thường gặp',
        InfoPageId.owners: 'Dành cho chủ sân',
        InfoPageId.terms: 'Điều khoản sử dụng',
        InfoPageId.privacy: 'Chính sách bảo mật',
        InfoPageId.payments: 'Thanh toán & hủy sân',
      };
      for (final e in links.entries) {
        await _pump(tester);
        await tester.tap(_k('footer-link-info-${e.key.name}'));
        await tester.pumpAndSettle();
        expect(find.byType(InfoPageScreen), findsOneWidget, reason: e.key.name);
        expect(_k('info-page-${e.key.name}'), findsOneWidget);
        expect(tester.widget<Text>(_k('info-title')).data, e.value);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Dải thanh toán có đường dẫn tới trang Thanh toán & hủy sân', (tester) async {
      await _pump(tester);
      await tester.tap(_k('footer-trust-payments'));
      await tester.pumpAndSettle();
      expect(_k('info-page-payments'), findsOneWidget);
    });
  });
}
