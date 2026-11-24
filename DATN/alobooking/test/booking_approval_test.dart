import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/screens/admin_screen.dart';
import 'package:alobooking/screens/owner_screen.dart';
import 'package:alobooking/services/auth_service.dart';
import 'package:alobooking/services/booking_approval.dart';
import 'package:alobooking/services/firestore_service.dart';
import 'package:alobooking/services/venue_cache.dart';

Venue _venue(String name, {String ownerId = 'admin_super_01', String ownerName = 'Hệ Thống Alobooking', int id = 1}) => Venue(
      id: id,
      name: name,
      type: 'badminton',
      district: 'Cầu Giấy',
      distance: '',
      address: '1 Phố Thử',
      hours: '06:00 – 22:00',
      tags: const [],
      rating: 4.5,
      price: '80k - 100k/h',
      lat: 21.0,
      lng: 105.8,
      image: '',
      logo: '',
      ownerId: ownerId,
      ownerName: ownerName,
      approvalStatus: 'approved',
    );

BookingItem _booking(String id, String venueName, {String status = 'Chờ xác nhận'}) => BookingItem(
      id: id,
      customer: 'Khách $id',
      phone: '0900000000',
      venueName: venueName,
      field: 'Sân 1',
      time: '18:00 - 19:00',
      date: '25/11/2026',
      amount: '100.000đ',
      status: status,
      paymentMethod: 'VietQR',
    );

Future<void> _loadFont() async {
  final f = File('C:/Windows/Fonts/segoeui.ttf');
  if (!f.existsSync()) return;
  final loader = FontLoader('Be Vietnam Pro')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
}

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _venueDoc(int id, String name, {String? ownerId, String? ownerName}) => {
      'name': 'projects/x/databases/(default)/documents/venues/$id',
      'fields': {
        'id': {'integerValue': '$id'},
        'name': {'stringValue': name},
        'type': {'stringValue': 'badminton'},
        'approvalStatus': {'stringValue': 'approved'},
        'price': {'stringValue': '80k - 100k/h'},
        if (ownerId != null) 'ownerId': {'stringValue': ownerId},
        if (ownerName != null) 'ownerName': {'stringValue': ownerName},
      },
    };

Map<String, dynamic> _bookingDoc(String id, String venueName, {String status = 'Chờ xác nhận'}) => {
      'name': 'projects/x/databases/(default)/documents/bookings/$id',
      'fields': {
        'id': {'stringValue': id},
        'customer': {'stringValue': 'Khách $id'},
        'phone': {'stringValue': '0900000000'},
        'venueName': {'stringValue': venueName},
        'field': {'stringValue': 'Sân 1'},
        'time': {'stringValue': '18:00 - 19:00'},
        'date': {'stringValue': '25/11/2026'},
        'amount': {'stringValue': '100.000đ'},
        'status': {'stringValue': status},
        'paymentMethod': {'stringValue': 'VietQR'},
        'createdAt': {'stringValue': '2026-11-20T10:00:00'},
      },
    };

/// Máy chủ giả: sân và đơn cố định, ghi lại mọi lần đổi trạng thái đơn.
class _Server {
  _Server({this.failPatch = false});
  final bool failPatch;
  final patches = <String, String>{}; // mã đơn -> trạng thái mới

  MockClient client({required List<Map<String, dynamic>> venues, required List<Map<String, dynamic>> bookings}) => MockClient((r) async {
        if (r.method == 'GET' && r.url.path.endsWith('/venues')) return http.Response(jsonEncode({'documents': venues}), 200, headers: _json);
        if (r.method == 'GET' && r.url.path.endsWith('/bookings')) return http.Response(jsonEncode({'documents': bookings}), 200, headers: _json);
        if (r.method == 'PATCH' && r.url.path.contains('/bookings/')) {
          if (failPatch) return http.Response('{}', 500);
          final id = r.url.path.split('/').last;
          patches[id] = (jsonDecode(r.body)['fields']['status']['stringValue']) as String;
          return http.Response('{}', 200, headers: _json);
        }
        return http.Response(jsonEncode({'documents': []}), 200, headers: _json);
      });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUpAll(_loadFont);
  setUp(() {
    VenueCache.clear();
    AuthService.logout();
  });

  group('BookingApproval: ai được duyệt đơn nào', () {
    final venues = [
      _venue('Sân Hệ Thống'),
      _venue('Sân Chủ Riêng', ownerId: 'owner_a', ownerName: 'Trần Văn A', id: 2),
      _venue('Sân Không Chủ', ownerId: '', id: 3),
    ];

    test('Đơn của sân có chủ riêng do chủ sân đó duyệt; sân hệ thống, sân không chủ, sân không tìm thấy do admin duyệt', () {
      expect(BookingApproval.approverId(_booking('1', 'Sân Chủ Riêng'), venues), 'owner_a');
      expect(BookingApproval.approverId(_booking('2', 'Sân Hệ Thống'), venues), BookingApproval.adminOwnerId);
      expect(BookingApproval.approverId(_booking('3', 'Sân Không Chủ'), venues), BookingApproval.adminOwnerId);
      expect(BookingApproval.approverId(_booking('4', 'Sân Đã Bị Xóa'), venues), BookingApproval.adminOwnerId);
      expect(BookingApproval.isOwnerManaged(_booking('1', 'Sân Chủ Riêng'), venues), isTrue);
      expect(BookingApproval.isOwnerManaged(_booking('2', 'Sân Hệ Thống'), venues), isFalse);
    });

    test('Khớp tên sân không phân biệt hoa thường và khoảng trắng thừa', () {
      expect(BookingApproval.venueOf(_booking('1', '  sân chủ riêng '), venues)?.id, 2);
    });

    test('Chủ sân chỉ duyệt đơn của sân mình; admin chỉ duyệt đơn của sân hệ thống; vai trò khác không duyệt', () {
      final own = _booking('1', 'Sân Chủ Riêng');
      final sys = _booking('2', 'Sân Hệ Thống');
      bool can(String role, String uid, BookingItem b) => BookingApproval.canApprove(role: role, uid: uid, b: b, venues: venues);
      expect(can('owner', 'owner_a', own), isTrue);
      expect(can('owner', 'owner_b', own), isFalse, reason: 'chủ sân khác không được duyệt');
      expect(can('owner', 'owner_a', sys), isFalse, reason: 'chủ sân không duyệt đơn của sân hệ thống');
      expect(can('admin', 'admin_super_01', own), isFalse, reason: 'admin không duyệt đơn của sân có chủ riêng');
      expect(can('admin', 'admin_super_01', sys), isTrue);
      expect(can('customer', 'u1', sys), isFalse);
      expect(can('guest', '', sys), isFalse);
      expect(can('owner', '', own), isFalse, reason: 'chưa đăng nhập thì không có quyền');
    });

    test('Nhãn chỉ xem nêu rõ chủ sân', () {
      expect(BookingApproval.viewOnlyLabel(_booking('1', 'Sân Chủ Riêng'), venues), 'Chờ chủ sân Trần Văn A xác nhận');
      expect(BookingApproval.viewOnlyLabel(_booking('1', 'Sân Chủ Riêng', status: 'Đã xác nhận'), venues), 'Do chủ sân Trần Văn A quản lý');
      final noName = [_venue('Sân X', ownerId: 'owner_z', ownerName: '')];
      expect(BookingApproval.viewOnlyLabel(_booking('1', 'Sân X'), noName), 'Chờ chủ sân xác nhận');
    });
  });

  group('Màn Admin', () {
    final venueDocs = [
      _venueDoc(1, 'Sân Chủ Riêng', ownerId: 'owner_a', ownerName: 'Trần Văn A'),
      _venueDoc(2, 'Sân Hệ Thống'),
    ];
    final bookingDocs = [
      _bookingDoc('BK-OWN', 'Sân Chủ Riêng'),
      _bookingDoc('BK-SYS', 'Sân Hệ Thống'),
      _bookingDoc('BK-GONE', 'Sân Đã Bị Xóa'),
    ];

    Future<_Server> openBookings(WidgetTester tester, {bool failPatch = false, int tab = 2, Size size = const Size(1440, 3000)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      AuthService.loginAsAdminDemo();
      final server = _Server(failPatch: failPatch);
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(home: AdminScreen(initialVenues: const [], initialTabIndex: tab)));
        await _settle(tester);
      }, () => server.client(venues: venueDocs, bookings: bookingDocs));
      return server;
    }

    testWidgets('Đơn của sân có chủ riêng: admin không có nút duyệt/hủy, chỉ thấy "Chờ chủ sân … xác nhận"', (tester) async {
      await openBookings(tester);
      expect(find.byKey(const ValueKey('admin-booking-owner-note-BK-OWN')), findsOneWidget);
      expect(find.text('Chờ chủ sân Trần Văn A xác nhận'), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-booking-confirm-BK-OWN')), findsNothing);
      expect(find.byKey(const ValueKey('admin-booking-cancel-BK-OWN')), findsNothing);
    });

    testWidgets('Đơn của sân hệ thống (và sân không còn trong danh sách): admin vẫn duyệt được', (tester) async {
      await openBookings(tester);
      for (final id in ['BK-SYS', 'BK-GONE']) {
        expect(find.byKey(ValueKey('admin-booking-confirm-$id')), findsOneWidget, reason: id);
        expect(find.byKey(ValueKey('admin-booking-cancel-$id')), findsOneWidget, reason: id);
        expect(find.byKey(ValueKey('admin-booking-owner-note-$id')), findsNothing, reason: id);
      }
    });

    testWidgets('Bấm xác nhận đơn hệ thống thì ghi đúng đơn đó lên máy chủ, không đụng đơn của chủ sân', (tester) async {
      late _Server server;
      tester.view.physicalSize = const Size(1440, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      AuthService.loginAsAdminDemo();
      server = _Server();
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(home: AdminScreen(initialVenues: const [], initialTabIndex: 2)));
        await _settle(tester);
        final btn = find.byKey(const ValueKey('admin-booking-confirm-BK-SYS'));
        await tester.ensureVisible(btn);
        await tester.tap(btn);
        await _settle(tester);
      }, () => server.client(venues: venueDocs, bookings: bookingDocs));
      expect(server.patches['BK-SYS'], 'Đã xác nhận');
      expect(server.patches.containsKey('BK-OWN'), isFalse);
    });

    testWidgets('Lưu thất bại thì báo lỗi và đơn vẫn "Chờ xác nhận" (không giả vờ đã duyệt)', (tester) async {
      tester.view.physicalSize = const Size(1440, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      AuthService.loginAsAdminDemo();
      final server = _Server(failPatch: true);
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(home: AdminScreen(initialVenues: const [], initialTabIndex: 2)));
        await _settle(tester);
        final btn = find.byKey(const ValueKey('admin-booking-confirm-BK-SYS'));
        await tester.ensureVisible(btn);
        await tester.tap(btn);
        await _settle(tester);
        expect(find.textContaining('Không xác nhận được đơn BK-SYS'), findsOneWidget);
        expect(find.byKey(const ValueKey('admin-booking-confirm-BK-SYS')), findsOneWidget, reason: 'nút vẫn còn vì đơn chưa được duyệt');
      }, () => server.client(venues: venueDocs, bookings: bookingDocs));
    });

    testWidgets('Tổng quan: tách đơn chờ admin xác nhận và đơn đang chờ chủ sân', (tester) async {
      await openBookings(tester, tab: 0);
      expect(find.text('Đơn chờ admin xác nhận'), findsOneWidget);
      expect(find.text('Đơn đang chờ chủ sân xác nhận'), findsOneWidget);
      // BK-SYS + BK-GONE là của admin, BK-OWN là của chủ sân
      expect(find.descendant(of: find.ancestor(of: find.text('Đơn chờ admin xác nhận'), matching: find.byType(Row)).first, matching: find.text('2')), findsWidgets);
    });

    testWidgets('Vừa khít điện thoại 390px không tràn bố cục', (tester) async {
      await openBookings(tester, size: const Size(390, 3600));
      expect(find.byKey(const ValueKey('admin-booking-owner-note-BK-OWN')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Màn Chủ sân', () {
    final venueDocs = [
      _venueDoc(1, 'Sân Của Tôi', ownerId: 'owner_chuan_01', ownerName: 'Trần Văn Chủ Sân'),
      _venueDoc(2, 'Sân Người Khác', ownerId: 'owner_khac', ownerName: 'Người Khác'),
    ];
    final bookingDocs = [
      _bookingDoc('BK-MINE', 'Sân Của Tôi'),
      _bookingDoc('BK-DONE', 'Sân Của Tôi', status: 'Đã xác nhận'),
      _bookingDoc('BK-OTHER', 'Sân Người Khác'),
    ];

    Future<void> open(WidgetTester tester, _Server server, Future<void> Function() body) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      AuthService.loginAsOwnerDemo();
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(home: OwnerScreen(initialVenues: const [], initialTabIndex: 2)));
        await _settle(tester);
        await body();
      }, () => server.client(venues: venueDocs, bookings: bookingDocs));
    }

    testWidgets('Chủ sân chỉ thấy đơn của sân mình, có ghi chú "không cần admin duyệt"', (tester) async {
      await open(tester, _Server(), () async {
        expect(find.text('BK-MINE'), findsOneWidget);
        expect(find.text('BK-OTHER'), findsNothing, reason: 'không thấy đơn của chủ sân khác');
        expect(find.byKey(const ValueKey('owner-bookings-note')), findsOneWidget);
        expect(find.textContaining('không cần admin duyệt'), findsOneWidget);
      });
    });

    testWidgets('Chủ sân tự xác nhận đơn: ghi lên máy chủ và đơn chuyển sang "Đã xác nhận"', (tester) async {
      final server = _Server();
      await open(tester, server, () async {
        await tester.tap(find.byKey(const ValueKey('owner-booking-confirm-BK-MINE')));
        await _settle(tester);
        expect(find.textContaining('Đã xác nhận đơn BK-MINE'), findsOneWidget);
        expect(find.byKey(const ValueKey('owner-booking-confirm-BK-MINE')), findsNothing);
        expect(find.byKey(const ValueKey('owner-booking-complete-BK-MINE')), findsOneWidget, reason: 'sau khi xác nhận thì có nút hoàn thành');
      });
      expect(server.patches['BK-MINE'], 'Đã xác nhận');
      expect(server.patches.containsKey('BK-OTHER'), isFalse);
    });

    testWidgets('Chủ sân hủy đơn: có hộp thoại hỏi lại, giữ đơn thì không đổi gì, hủy thì ghi "Đã hủy"', (tester) async {
      final server = _Server();
      await open(tester, server, () async {
        await tester.tap(find.byKey(const ValueKey('owner-booking-cancel-BK-MINE')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Hủy đơn này?'), findsOneWidget);
        await tester.tap(find.text('Giữ đơn'));
        await _settle(tester);
        expect(server.patches, isEmpty, reason: 'chọn giữ đơn thì không ghi gì');

        await tester.tap(find.byKey(const ValueKey('owner-booking-cancel-BK-MINE')));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(const ValueKey('owner-booking-confirm-cancel')));
        await _settle(tester);
        expect(find.textContaining('Đã hủy đơn BK-MINE'), findsOneWidget);
      });
      expect(server.patches['BK-MINE'], 'Đã hủy');
    });

    testWidgets('Chủ sân đánh dấu hoàn thành đơn đã xác nhận', (tester) async {
      final server = _Server();
      await open(tester, server, () async {
        await tester.tap(find.byKey(const ValueKey('owner-booking-complete-BK-DONE')));
        await _settle(tester);
        expect(find.textContaining('Đơn BK-DONE đã hoàn thành'), findsOneWidget);
      });
      expect(server.patches['BK-DONE'], 'Hoàn thành');
    });

    testWidgets('Lưu thất bại thì báo lỗi, đơn vẫn chờ xác nhận', (tester) async {
      final server = _Server(failPatch: true);
      await open(tester, server, () async {
        await tester.tap(find.byKey(const ValueKey('owner-booking-confirm-BK-MINE')));
        await _settle(tester);
        expect(find.textContaining('Không xác nhận được đơn BK-MINE'), findsOneWidget);
        expect(find.byKey(const ValueKey('owner-booking-confirm-BK-MINE')), findsOneWidget);
      });
    });
  });
}
