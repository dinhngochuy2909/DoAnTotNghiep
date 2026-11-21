import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/main.dart';
import 'package:alobooking/widgets/app_scroll_behavior.dart';
import 'package:alobooking/widgets/device_simulator_wrapper.dart';

// Mặc định Flutter không cho chuột kéo để cuộn, nên các dải ngang (chip chọn môn...) bị cắt mép phải
// và không có cách lướt tới trong khung demo điện thoại. Các test này giữ cho chuột/bàn di chuột vuốt được.

const _chipKey = ValueKey('chip-row');

Widget _chipRow({void Function(int)? onTap}) => SizedBox(
      height: 44,
      child: ListView(
        key: _chipKey,
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < 20; i++)
            GestureDetector(
              onTap: () => onTap?.call(i),
              child: Container(
                key: ValueKey('chip-$i'),
                width: 110,
                margin: const EdgeInsets.only(right: 8),
                color: Colors.green,
                alignment: Alignment.center,
                child: Text('Môn $i'),
              ),
            ),
        ],
      ),
    );

double _offset(WidgetTester tester) =>
    tester.state<ScrollableState>(find.descendant(of: find.byKey(_chipKey), matching: find.byType(Scrollable))).position.pixels;

Future<void> _drag(WidgetTester tester, Finder at, Offset by, {PointerDeviceKind kind = PointerDeviceKind.mouse}) async {
  // tester.drag tự đi quá ngưỡng "kéo" (slop) trước rồi mới đi nốt quãng còn lại, giống tay người
  await tester.drag(at, by, kind: kind);
  // Không dùng pumpAndSettle: nút chat AI nổi có hoạt ảnh lặp vô hạn nên không bao giờ "yên"
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 800));
}

void _useScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Đối chứng: không có AppScrollBehavior thì chuột kéo KHÔNG cuộn được dải ngang', (tester) async {
    _useScreen(tester, const Size(400, 800));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: _chipRow()))));
    await _drag(tester, find.byKey(_chipKey), const Offset(-200, 0));
    expect(_offset(tester), 0);
  });

  testWidgets('Có AppScrollBehavior: chuột và bàn di chuột kéo là cuộn được dải ngang', (tester) async {
    _useScreen(tester, const Size(400, 800));
    await tester.pumpWidget(MaterialApp(scrollBehavior: const AppScrollBehavior(), home: Scaffold(body: Center(child: _chipRow()))));

    await _drag(tester, find.byKey(_chipKey), const Offset(-200, 0));
    final afterMouse = _offset(tester);
    expect(afterMouse, greaterThan(100));

    await _drag(tester, find.byKey(_chipKey), const Offset(-150, 0), kind: PointerDeviceKind.trackpad);
    expect(_offset(tester), greaterThan(afterMouse));

    await _drag(tester, find.byKey(_chipKey), const Offset(150, 0), kind: PointerDeviceKind.touch);
    expect(_offset(tester), lessThan(afterMouse + 150), reason: 'ngón tay vẫn vuốt được như cũ');
  });

  testWidgets('Bấm vào chip vẫn là bấm, không bị coi là kéo', (tester) async {
    _useScreen(tester, const Size(400, 800));
    final taps = <int>[];
    await tester.pumpWidget(MaterialApp(scrollBehavior: const AppScrollBehavior(), home: Scaffold(body: Center(child: _chipRow(onTap: taps.add)))));
    await tester.tap(find.byKey(const ValueKey('chip-1')));
    expect(taps, [1]);
    expect(_offset(tester), 0);
  });

  testWidgets('Danh sách dọc cũng kéo chuột để cuộn được', (tester) async {
    _useScreen(tester, const Size(400, 800));
    await tester.pumpWidget(MaterialApp(
      scrollBehavior: const AppScrollBehavior(),
      home: Scaffold(body: ListView(key: const ValueKey('v'), children: [for (var i = 0; i < 40; i++) SizedBox(height: 80, child: Text('Dòng $i'))])),
    ));
    await _drag(tester, find.byKey(const ValueKey('v')), const Offset(0, -300));
    expect(tester.state<ScrollableState>(find.descendant(of: find.byKey(const ValueKey('v')), matching: find.byType(Scrollable))).position.pixels, greaterThan(200));
  });

  group('Khung demo điện thoại', () {
    Future<void> openFrame(WidgetTester tester, {Widget? home}) async {
      _useScreen(tester, const Size(1440, 900));
      await tester.pumpWidget(MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        builder: (context, child) => DeviceSimulatorWrapper(child: child!),
        home: home ?? Scaffold(body: Center(child: _chipRow())),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.textContaining('Xem Demo iPhone'));
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('Giữ chuột kéo dải chip trong khung điện thoại là lướt được', (tester) async {
      await openFrame(tester);
      expect(_offset(tester), 0);
      await _drag(tester, find.byKey(_chipKey), const Offset(-220, 0));
      expect(_offset(tester), greaterThan(100));
    });

    testWidgets('iPhone: vuốt nảy ở mép, không thanh cuộn; Samsung: dừng cứng', (tester) async {
      late BuildContext inner;
      await openFrame(tester, home: Scaffold(body: Builder(builder: (c) {
        inner = c;
        return Center(child: _chipRow());
      })));
      expect(ScrollConfiguration.of(inner), isA<PhoneScrollBehavior>());
      expect(ScrollConfiguration.of(inner).getScrollPhysics(inner), isA<BouncingScrollPhysics>());

      await tester.tap(find.byKey(const ValueKey('device-Samsung Galaxy S25')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(ScrollConfiguration.of(inner).getScrollPhysics(inner), isA<ClampingScrollPhysics>());
      expect(find.byType(Scrollbar), findsNothing);
    });

    testWidgets('Ứng dụng thật: dải chọn môn ở trang chủ lướt được bằng chuột trong khung điện thoại', (tester) async {
      _useScreen(tester, const Size(1440, 900));
      final errors = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
      addTearDown(() => FlutterError.onError = old);

      await tester.pumpWidget(const AlobookingApp());
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.textContaining('Xem Demo iPhone'));
      await tester.pump(const Duration(seconds: 1));

      final row = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal).first;
      final pos = tester.state<ScrollableState>(find.descendant(of: row, matching: find.byType(Scrollable))).position;
      expect(pos.maxScrollExtent, greaterThan(0), reason: 'dải chip dài hơn khung điện thoại nên phải cuộn được');
      expect(pos.pixels, 0);

      await _drag(tester, row, const Offset(-200, 0));
      expect(pos.pixels, greaterThan(50));
      expect(errors.where((e) => e.contains('Overlay') || e.contains('Navigator')), isEmpty);
    });
  });
}
