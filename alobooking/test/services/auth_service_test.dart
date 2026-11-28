// Đăng ký, đăng nhập qua Firebase Authentication và đọc dữ liệu theo vai trò (máy chủ giả).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alobooking/models/user.dart';
import 'package:alobooking/services/auth_service.dart';
import 'package:alobooking/services/firestore_service.dart';
import 'package:alobooking/services/session.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
http.Response _ok(Object body) => http.Response(jsonEncode(body), 200, headers: _json);
http.Response _identityError(String code) => http.Response(jsonEncode({'error': {'message': code}}), 400, headers: _json);

const _signedIn = {'localId': 'u1', 'idToken': 'token-u1', 'refreshToken': 'r', 'expiresIn': '3600'};

Map<String, dynamic> _doc(String path, Map<String, String> fields) => {
      'name': 'projects/p/databases/(default)/documents/$path',
      'fields': {for (final e in fields.entries) e.key: {'stringValue': e.value}},
    };

/// Chạy [body] với máy chủ giả, ghi lại mọi yêu cầu.
Future<List<http.Request>> _with(Future<http.Response> Function(http.Request r) handler, Future<void> Function() body) async {
  final seen = <http.Request>[];
  await http.runWithClient(body, () => MockClient((r) {
        seen.add(r);
        return handler(r);
      }));
  return seen;
}

void main() {
  tearDown(AuthService.logout);

  test('đăng ký: tạo tài khoản rồi lưu hồ sơ khách hàng bằng token, không lưu mật khẩu', () async {
    final seen = await _with((r) async => r.url.path.endsWith('accounts:signUp') ? _ok(_signedIn) : _ok({}), () async {
      final result = await AuthService.register(fullName: 'An', email: 'An@Thu.vn ', phone: '09', password: 'matkhau123');
      expect(result.success, isTrue, reason: result.message);
    });
    expect(AuthService.currentUser!.uid, 'u1');
    expect(AuthService.currentUser!.role, 'customer');
    final profile = seen.singleWhere((r) => r.url.path.endsWith('/users'));
    expect(profile.url.queryParameters['documentId'], 'u1');
    expect(profile.headers['Authorization'], 'Bearer token-u1');
    final fields = jsonDecode(profile.body)['fields'] as Map<String, dynamic>;
    expect(fields['email']['stringValue'], 'an@thu.vn');
    expect(fields.keys, isNot(contains('password')));
    expect(profile.body, isNot(contains('matkhau123')));
  });

  test('đăng nhập: lấy hồ sơ theo uid, giữ đúng vai trò đã lưu; đăng xuất thì bỏ token', () async {
    final seen = await _with(
        (r) async => r.url.path.endsWith('accounts:signInWithPassword')
            ? _ok(_signedIn)
            : _ok(_doc('users/u1', {'fullName': 'Chủ', 'email': 'c@thu.vn', 'role': 'owner'})), () async {
      expect((await AuthService.login(email: 'c@thu.vn', password: 'x123456')).success, isTrue);
    });
    expect(AuthService.currentUser!.isOwner, isTrue);
    expect(seen.last.url.path, endsWith('/users/u1'));
    expect(seen.last.headers['Authorization'], 'Bearer token-u1');
    AuthService.logout();
    expect(AuthService.currentUser, isNull);
    expect(Session.hasToken, isFalse);
  });

  test('sai mật khẩu, email trùng: báo đúng câu và không đăng nhập', () async {
    await _with((r) async => _identityError('INVALID_LOGIN_CREDENTIALS'), () async {
      final result = await AuthService.login(email: 'a@thu.vn', password: 'sai');
      expect(result.success, isFalse);
      expect(result.message, 'Email hoặc mật khẩu không đúng!');
    });
    await _with((r) async => _identityError('EMAIL_EXISTS'), () async {
      final result = await AuthService.register(fullName: 'A', email: 'a@thu.vn', phone: '', password: 'matkhau123');
      expect(result.message, 'Email này đã được đăng ký!');
    });
    expect(AuthService.isLoggedIn, isFalse);
    expect(Session.hasToken, isFalse);
  });

  test('có tài khoản nhưng thiếu hồ sơ: tạo hồ sơ khách hàng', () async {
    final seen = await _with((r) async {
      if (r.url.path.endsWith('accounts:signInWithPassword')) return _ok(_signedIn);
      return r.method == 'GET' ? http.Response('{}', 404) : _ok({});
    }, () async {
      expect((await AuthService.login(email: 'moi@thu.vn', password: 'x123456')).success, isTrue);
    });
    expect(AuthService.currentUser!.role, 'customer');
    expect(seen.last.method, 'POST');
  });

  group('đọc đơn theo vai trò', () {
    Future<List<http.Request>> load(AppUser? user, List<BookingItem> out) {
      AuthService.setCurrentUserForTest(user);
      return _with((r) async {
        if (!r.url.path.endsWith(':runQuery')) return _ok({'documents': [_doc('bookings/BK-1', {'id': 'BK-1'})]});
        final field = jsonDecode(r.body)['structuredQuery']['where']['fieldFilter']['field']['fieldPath'] as String;
        return _ok([{'document': _doc('bookings/BK-$field', {'id': 'BK-$field'})}]);
      }, () async => out.addAll(await FirestoreService.getBookings()));
    }

    AppUser user(String role) => AppUser(uid: 'u1', fullName: 'A', email: 'a@thu.vn', phone: '09', role: role);

    test('chưa đăng nhập thì không hỏi máy chủ', () async {
      final out = <BookingItem>[];
      expect(await load(null, out), isEmpty);
      expect(out, isEmpty);
    });

    test('khách chỉ truy vấn đơn của mình', () async {
      final out = <BookingItem>[];
      final seen = await load(user('customer'), out);
      expect(seen, hasLength(1));
      expect(seen.single.body, contains('"userId"'));
      expect(out.map((b) => b.id), ['BK-userId']);
    });

    test('chủ sân thấy đơn sân mình và đơn mình đặt; quản trị viên liệt kê tất cả', () async {
      final owner = <BookingItem>[];
      await load(user('owner'), owner);
      expect(owner.map((b) => b.id).toSet(), {'BK-userId', 'BK-ownerId'});
      final admin = <BookingItem>[];
      final seen = await load(user('admin'), admin);
      expect(seen.single.method, 'GET');
      expect(admin.map((b) => b.id), ['BK-1']);
    });
  });

  test('tạo đơn ghi đơn, lịch công khai và phiếu thu trong một lần; lịch không có thông tin cá nhân', () async {
    final seen = await _with((r) async => _ok({}), () async {
      expect(
          await FirestoreService.createBooking(
              id: 'BK-123456', customer: 'Nguyễn Văn A', phone: '0912345678', venueName: 'Sân A', venueId: 7, ownerId: 'chu1',
              userId: 'u1', field: 'Sân 1', time: '18:00 - 19:00', date: '01/12/2026', amount: '100.000đ'),
          isTrue);
    });
    final writes = (jsonDecode(seen.first.body)['writes'] as List).cast<Map<String, dynamic>>();
    expect(seen.first.url.path, endsWith('documents:commit'));
    expect(writes.map((w) => (w['update']['name'] as String).split('documents/').last),
        ['bookings/BK-123456', 'slots/BK-123456', 'payments/PAY-123456']);
    final slot = writes[1]['update']['fields'] as Map<String, dynamic>;
    expect(slot.keys.toSet(), {'venueId', 'venueName', 'field', 'date', 'time', 'status', 'paymentMethod', 'createdAt'});
    expect(jsonEncode(slot), isNot(contains('0912345678')));
    expect(writes[0]['update']['fields']['ownerId']['stringValue'], 'chu1');
    expect(writes[2]['update']['fields']['userId']['stringValue'], 'u1');
  });

  test('khách quen của chủ sân dựng từ đơn, gộp theo số điện thoại, bỏ đơn đã hủy', () {
    BookingItem b(String id, String phone, String status) => BookingItem(
        id: id, customer: 'An', phone: phone, venueName: 'Sân A', field: 'Cầu lông 2', time: '18:00 - 19:00',
        date: '01/12/2026', amount: '100.000đ', status: status, paymentMethod: 'VietQR');
    final customers = FirestoreService.customersFromBookings(
        [b('1', '0912 345 678', 'Đã xác nhận'), b('2', '0912345678', 'Chờ xác nhận'), b('3', '0999', 'Đã hủy')]);
    expect(customers, hasLength(1));
    expect(customers.single.bookingsCount, 2);
    expect(customers.single.totalSpent, '100.000đ');
    expect(customers.single.favoriteSport, 'Cầu lông');
  });
}
