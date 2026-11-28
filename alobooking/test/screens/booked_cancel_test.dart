import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alobooking/models/user.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/screens/booked_screen.dart';
import 'package:alobooking/services/auth_service.dart';

Map<String, dynamic> _booking(String id, String time) => {
      'name': 'projects/p/databases/(default)/documents/bookings/$id',
      'fields': {
        for (final e in {
          'id': id,
          'venueName': 'Sân thử',
          'date': '01/12/2026',
          'time': time,
          'status': 'Đã xác nhận',
          'userId': 'u1',
          'amount': '100,000đ',
        }.entries)
          e.key: {'stringValue': e.value},
      },
    };

final _venue = Venue(
  id: 1, name: 'Sân thử', type: 'badminton', district: 'Cầu Giấy', distance: '', address: 'Hà Nội',
  hours: '05:00 – 23:00', tags: const [], rating: 0, price: '100k - 100k/h', lat: 21, lng: 105.8, image: '', logo: '',
);

/// Mở màn "Sân đã đặt" với giờ hiện tại cố định; trả về danh sách yêu cầu ghi lên Firestore giả.
Future<List<String>> _open(WidgetTester tester, {required DateTime Function() clock, required List<String> times}) async {
  tester.view.physicalSize = const Size(500, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final writes = <String>[];
  final fake = MockClient((request) async {
    if (request.method != 'GET') {
      writes.add('${request.method} ${request.url.path}');
      return http.Response('{}', 200);
    }
    final body = {'documents': [for (var i = 0; i < times.length; i++) _booking('BK-$i', times[i])]};
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json; charset=utf-8'});
  });
  await http.runWithClient(() async {
    await tester.pumpWidget(MaterialApp(home: BookedScreen(allVenues: [_venue], clock: clock)));
    await tester.pumpAndSettle();
  }, () => fake);
  return writes;
}

void main() {
  setUp(() => AuthService.setCurrentUserForTest(AppUser(uid: 'u1', fullName: 'Khách Thử', email: 'k@example.com', phone: '0900000000')));
  tearDown(() => AuthService.setCurrentUserForTest(null));

  testWidgets('Đơn còn xa giờ chơi có nút hủy; đơn còn dưới 2 tiếng thì không, và có ghi lý do', (tester) async {
    // 16:30: ca 18:00 còn 1 tiếng 30 phút, ca 20:00 còn 3 tiếng 30 phút
    await _open(tester, clock: () => DateTime(2026, 12, 1, 16, 30), times: ['18:00 - 19:00', '20:00 - 21:00']);
    expect(find.text('Hủy đặt sân'), findsOneWidget);
    expect(find.byKey(const ValueKey('cancel-closed-BK-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('cancel-closed-BK-1')), findsNothing);
  });

  testWidgets('Đơn nhiều ca tính theo ca sớm nhất', (tester) async {
    await _open(tester, clock: () => DateTime(2026, 12, 1, 16, 30), times: ['21:00 - 22:00, 18:00 - 19:00']);
    expect(find.text('Hủy đặt sân'), findsNothing);
    expect(find.byKey(const ValueKey('cancel-closed-BK-0')), findsOneWidget);
  });

  testWidgets('Hộp thoại mở lâu đến quá hạn thì bấm xác nhận cũng không hủy được', (tester) async {
    var now = DateTime(2026, 12, 1, 15, 59);
    final writes = await _open(tester, clock: () => now, times: ['18:00 - 19:00']);
    await tester.tap(find.text('Hủy đặt sân'));
    await tester.pumpAndSettle();
    expect(find.text('Xác nhận hủy đặt sân'), findsOneWidget);

    now = DateTime(2026, 12, 1, 16, 5);
    await tester.tap(find.text('Xác nhận hủy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã quá hạn hủy'), findsOneWidget);
    expect(writes, isEmpty, reason: 'không được ghi trạng thái "Đã hủy" lên cơ sở dữ liệu');
  });
}
