import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/data/info_pages.dart';
import 'package:alobooking/screens/info_page_screen.dart';

Future<bool> _loadRealFont() async {
  final f = File('C:/Windows/Fonts/segoeui.ttf');
  if (!f.existsSync()) return false;
  final loader = FontLoader('TestSans')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
  return true;
}

Finder _k(String key) => find.byKey(ValueKey(key));

/// Gom toàn bộ chữ của một trang để kiểm tra nội dung.
List<String> _allText(InfoPage p) => [
      p.title,
      p.intro,
      p.note,
      for (final s in p.sections) ...[s.heading, ...s.paragraphs, ...s.bullets],
      for (final f in p.faq) ...[f.question, f.answer],
    ];

Future<void> _open(WidgetTester tester, InfoPageId id, {double width = 1280}) async {
  tester.view.physicalSize = Size(width, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'TestSans'),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(child: ElevatedButton(key: const ValueKey('go'), onPressed: () => InfoPageScreen.open(context, id), child: const Text('mở'))),
      ),
    ),
  ));
  await tester.tap(_k('go'));
  await tester.pumpAndSettle();
}

void main() {
  var realFont = false;
  setUpAll(() async {
    realFont = await _loadRealFont();
  });

  group('Nội dung các trang', () {
    test('có đủ bảy trang, mã không trùng, trang nào cũng có tiêu đề, mở đầu và nội dung', () {
      expect(InfoPages.all.length, 7);
      expect(InfoPages.all.map((p) => p.id).toSet().length, 7);
      for (final p in InfoPages.all) {
        expect(InfoPages.of(p.id), same(p));
        expect(p.title.trim(), isNotEmpty);
        expect(p.intro.trim(), isNotEmpty);
        expect(p.sections.isNotEmpty || p.faq.isNotEmpty, isTrue, reason: '${p.id.name} trống');
        for (final t in _allText(p).where((t) => t != p.note)) {
          expect(t.trim(), isNotEmpty, reason: 'có đoạn rỗng ở ${p.id.name}');
        }
        for (final s in p.sections) {
          expect(s.paragraphs.isNotEmpty || s.bullets.isNotEmpty, isTrue, reason: 'mục "${s.heading}" của ${p.id.name} trống');
        }
      }
    });

    test('không tự bịa thông tin liên hệ: không có số điện thoại, hotline, email hay đường dẫn trong nội dung', () {
      final bad = RegExp(r'(\b0\d{9}\b|\b1[89]00\s?\d{3,4}\b|\b\d{4}\s\d{3,4}\b|[\w.]+@[\w.]+\.\w+|https?://|www\.)');
      for (final p in InfoPages.all) {
        for (final t in _allText(p)) {
          expect(bad.hasMatch(t), isFalse, reason: 'trang ${p.id.name} có thông tin liên hệ cứng: "$t"');
        }
      }
    });

    test('không có quy định tự đặt: hoàn tiền luôn ghi là do chủ sân xử lý, không hứa mốc thời gian hay phần trăm', () {
      final all = [for (final p in InfoPages.all) ..._allText(p)].join('\n');
      expect(all, contains('do chủ sân xử lý theo chính sách của sân'));
      // không có cam kết kiểu "hoàn 100%", "trong 24 giờ", "miễn phí hủy"...
      expect(RegExp(r'hoàn\s+\d+\s*%|trong\s+\d+\s*(giờ|ngày)|miễn phí hủy|bảo đảm hoàn', caseSensitive: false).hasMatch(all), isFalse);
    });

    test('chỉ ba trang điều khoản/chính sách có ngày cập nhật', () {
      for (final p in InfoPages.all) {
        final hasNote = p.note.isNotEmpty;
        final expected = {InfoPageId.terms, InfoPageId.privacy, InfoPageId.payments}.contains(p.id);
        expect(hasNote, expected, reason: p.id.name);
      }
      expect(InfoPages.updated, startsWith('Cập nhật lần cuối: '));
    });

    test('mô tả đúng cách thanh toán: chỉ chuyển khoản VietQR, không tiền mặt', () {
      final pay = _allText(InfoPages.payments).join('\n');
      expect(pay, contains('VietQR'));
      expect(pay, contains('không nhận tiền mặt'));
      expect(pay, contains('Chờ xác nhận'));
      expect(pay, contains('Hủy đặt sân'));
    });

    test('giờ vàng 16:00 – 22:00 khớp với cấu hình đặt sân', () {
      for (final p in [InfoPages.guide, InfoPages.faq, InfoPages.payments]) {
        expect(_allText(p).join('\n'), contains('16:00 – 22:00'), reason: p.id.name);
      }
    });
  });

  group('Màn hình trang thông tin', () {
    testWidgets('Hiện tiêu đề, lời mở, các mục và danh sách gạch đầu dòng', (tester) async {
      await _open(tester, InfoPageId.about);
      expect(tester.widget<Text>(_k('info-title')).data, 'Giới thiệu AloBooking');
      expect(find.text(InfoPages.about.intro), findsOneWidget);
      for (final s in InfoPages.about.sections) {
        expect(find.text(s.heading), findsOneWidget);
      }
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
      expect(_k('info-note'), findsNothing, reason: 'trang Giới thiệu không có ngày cập nhật');
      if (realFont) expect(tester.takeException(), isNull);
    });

    testWidgets('Hướng dẫn: các bước được đánh số 1..7', (tester) async {
      await _open(tester, InfoPageId.guide);
      for (var i = 1; i <= 7; i++) {
        expect(find.text('$i'), findsOneWidget, reason: 'thiếu bước $i');
      }
      expect(find.text('8'), findsNothing);
    });

    testWidgets('Điều khoản có ngày cập nhật', (tester) async {
      await _open(tester, InfoPageId.terms);
      expect(tester.widget<Text>(_k('info-note')).data, InfoPages.updated);
    });

    testWidgets('Câu hỏi thường gặp: câu trả lời chỉ hiện khi mở, mở được từng câu', (tester) async {
      await _open(tester, InfoPageId.faq);
      final first = InfoPages.faq.faq.first;
      expect(find.text(first.question), findsOneWidget);
      expect(find.text(first.answer), findsNothing);
      await tester.tap(_k('info-faq-0'));
      await tester.pumpAndSettle();
      expect(find.text(first.answer), findsOneWidget);
      // mở câu khác không làm câu trên biến mất
      final second = InfoPages.faq.faq[1];
      await tester.tap(_k('info-faq-1'));
      await tester.pumpAndSettle();
      expect(find.text(second.answer), findsOneWidget);
      expect(find.text(first.answer), findsOneWidget);
    });

    testWidgets('"Xem thêm" chuyển sang trang khác, thay trang hiện tại, quay lại là về nơi bắt đầu', (tester) async {
      await _open(tester, InfoPageId.about);
      expect(_k('info-more-about'), findsNothing, reason: 'không tự liên kết tới chính nó');
      expect(find.byType(ActionChip), findsNWidgets(6));
      await tester.ensureVisible(_k('info-more-privacy'));
      await tester.tap(_k('info-more-privacy'));
      await tester.pumpAndSettle();
      expect(_k('info-page-privacy'), findsOneWidget);
      expect(_k('info-page-about'), findsNothing);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byType(InfoPageScreen), findsNothing, reason: 'chỉ một lớp trang, không chồng');
      expect(_k('go'), findsOneWidget);
    });

    for (final id in InfoPageId.values) {
      for (final w in [1280.0, 390.0]) {
        testWidgets('${id.name} ở rộng ${w.toInt()}px không tràn bố cục', (tester) async {
          await _open(tester, id, width: w);
          expect(find.byType(InfoPageScreen), findsOneWidget);
          if (realFont) expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
