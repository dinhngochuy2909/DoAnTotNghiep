import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alobooking/models/user.dart';
import 'package:alobooking/screens/booked_screen.dart';
import 'package:alobooking/services/auth_service.dart';

void main() {
  setUp(() => AuthService.setCurrentUserForTest(AppUser(uid: 'u1', fullName: 'Khách Thử', email: 'k@example.com', phone: '0900000000')));
  tearDown(() => AuthService.setCurrentUserForTest(null));

  testWidgets('Khách xem được đơn sắp tới nhưng không có nút tự hủy', (tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final next = DateTime.now().add(const Duration(days: 3));
    final date = '${next.day.toString().padLeft(2, '0')}/${next.month.toString().padLeft(2, '0')}/${next.year}';
    final booking = {
      'name': 'projects/p/databases/(default)/documents/bookings/BK-1',
      'fields': {
        for (final e in {'id': 'BK-1', 'venueName': 'Sân thử', 'date': date, 'time': '18:00 - 19:00', 'status': 'Đã xác nhận', 'userId': 'u1', 'amount': '100.000 đ'}.entries)
          e.key: {'stringValue': e.value},
      },
    };
    // Khách đọc đơn của mình bằng truy vấn lọc (runQuery).
    final fake = MockClient((request) async => http.Response.bytes(
        utf8.encode(jsonEncode(request.url.path.endsWith(':runQuery') ? [{'document': booking}] : {'documents': []})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'}));

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: BookedScreen()));
      await tester.pumpAndSettle();
    }, () => fake);

    expect(find.text('Sân thử'), findsOneWidget);
    expect(find.text('Hủy đặt sân'), findsNothing);
    expect(find.textContaining('Hủy đặt'), findsNothing);
  });
}
