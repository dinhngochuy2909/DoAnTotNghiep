import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/widgets/floating_chat_button.dart';

Future<void> _pump(WidgetTester tester, {Widget? under}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          if (under != null) under,
          const Positioned.fill(child: FloatingChatButton()),
        ],
      ),
    ),
  ));
  await tester.pump();
}

/// AnimatedPositioned bắt đầu lướt ở khung hình kế tiếp, nên cần bơm hai lần (không dùng pumpAndSettle
/// vì nút có hiệu ứng nhịp đập lặp vô hạn).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(FloatingChatButton.resetSavedPosition);

  Future<void> useScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  final fab = find.byKey(const ValueKey('chat-fab'));

  testWidgets('Mặc định nằm góc phải phía trên thanh điều hướng', (tester) async {
    await useScreen(tester, const Size(400, 800));
    await _pump(tester);
    final p = tester.getTopLeft(fab);
    expect(p.dx, closeTo(400 - 56 - 16, 1));
    expect(p.dy, closeTo(800 - 56 - 86, 1));
  });

  testWidgets('Kéo sang trái và lên trên: nút đi theo tay rồi hít vào mép trái', (tester) async {
    await useScreen(tester, const Size(400, 800));
    await _pump(tester);
    final start = tester.getTopLeft(fab);

    await tester.drag(fab, const Offset(-250, -400));
    await _settle(tester);

    final end = tester.getTopLeft(fab);
    expect(end.dx, closeTo(8, 1), reason: 'hít vào mép trái');
    expect(end.dy, closeTo(start.dy - 400, 25), reason: 'đi lên theo tay');
  });

  testWidgets('Kéo nhẹ về bên phải thì hít lại mép phải, không văng ra ngoài màn hình', (tester) async {
    await useScreen(tester, const Size(400, 800));
    await _pump(tester);

    await tester.drag(fab, const Offset(500, 900)); // kéo vượt hẳn ra ngoài
    await _settle(tester);

    final p = tester.getTopLeft(fab);
    expect(p.dx, closeTo(400 - 56 - 8, 1));
    expect(p.dy, closeTo(800 - 56 - 8, 1));
  });

  testWidgets('Vị trí đã kéo được nhớ khi dựng lại (đổi giữa bản máy tính và khung điện thoại)', (tester) async {
    await useScreen(tester, const Size(400, 800));
    await _pump(tester);
    await tester.drag(fab, const Offset(-300, -200));
    await _settle(tester);
    final moved = tester.getTopLeft(fab);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester);
    final again = tester.getTopLeft(fab);
    expect(again.dx, closeTo(moved.dx, 1));
    expect(again.dy, closeTo(moved.dy, 1));
  });

  testWidgets('Vùng trống quanh nút không chặn chạm vào nội dung phía dưới', (tester) async {
    await useScreen(tester, const Size(400, 800));
    var taps = 0;
    await _pump(
      tester,
      under: Positioned(
        left: 20,
        top: 100,
        child: ElevatedButton(onPressed: () => taps++, child: const Text('Nút bên dưới')),
      ),
    );
    await tester.tap(find.text('Nút bên dưới'));
    expect(taps, 1);
  });
}
