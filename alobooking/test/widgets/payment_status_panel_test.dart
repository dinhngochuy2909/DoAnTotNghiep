import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/widgets/payment_status_panel.dart';

void main() {
  test('chỉ coi là đã thanh toán khi mọi đơn của lần đặt đã được xác nhận', () {
    expect(PaymentStatusPanel.stateOf(['Chờ xác nhận'], 1), PaymentState.waiting);
    expect(PaymentStatusPanel.stateOf(['Đã xác nhận', 'Chờ xác nhận'], 2), PaymentState.waiting);
    expect(PaymentStatusPanel.stateOf(['Đã xác nhận', 'Đã xác nhận'], 2), PaymentState.paid);
    expect(PaymentStatusPanel.stateOf(['Đã xác nhận', 'Đã hủy'], 2), PaymentState.cancelled);
    expect(PaymentStatusPanel.stateOf([], 0), PaymentState.waiting);
  });

  Future<void> pump(WidgetTester tester, StatusFetcher fetch, VoidCallback onPaid) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PaymentStatusPanel(
            bookingIds: const ['BK-1'],
            fetch: fetch,
            onPaid: onPaid,
            interval: const Duration(seconds: 4),
            timeout: const Duration(seconds: 20),
          ),
        ),
      ));

  testWidgets('đang chờ, tiền về thì báo đúng một lần và ngừng hỏi', (tester) async {
    var status = 'Chờ xác nhận';
    var calls = 0, paid = 0;
    await pump(tester, (ids) async {
      calls++;
      return [status];
    }, () => paid++);
    expect(find.byKey(const ValueKey('payment-waiting')), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(paid, 0);

    status = 'Đã xác nhận';
    await tester.pump(const Duration(seconds: 4));
    expect(paid, 1);
    expect(find.byKey(const ValueKey('payment-paid')), findsOneWidget);

    final after = calls;
    await tester.pump(const Duration(seconds: 30));
    expect(calls, after, reason: 'đã xong thì không đọc cơ sở dữ liệu nữa');
    expect(paid, 1);
  });

  testWidgets('mất mạng thì vẫn chờ; quá thời gian thì dừng và nói rõ đơn còn chờ xác nhận', (tester) async {
    var calls = 0;
    await pump(tester, (ids) async {
      calls++;
      return null;
    }, () => fail('không được báo thành công'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 4));
    }
    expect(find.byKey(const ValueKey('payment-timedOut')), findsOneWidget);
    final after = calls;
    await tester.pump(const Duration(seconds: 30));
    expect(calls, after);
  });
}
