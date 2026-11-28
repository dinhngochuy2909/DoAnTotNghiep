// Kiểm thử đầu cuối: mã thật của ứng dụng chạy với bộ mô phỏng Firebase (Authentication + Firestore, có luật bảo mật).
// Tự bỏ qua khi không chạy với bộ mô phỏng.
//
//   firebase emulators:exec --only firestore,auth --project demo-alobooking
//     "flutter test test/integration/emulator_flow_test.dart --dart-define=FIREBASE_EMULATOR=127.0.0.1 --dart-define=FIREBASE_PROJECT=demo-alobooking"
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/services/auth_service.dart';
import 'package:alobooking/services/booking_slots.dart';
import 'package:alobooking/services/firebase_config.dart';
import 'package:alobooking/services/firestore_service.dart';
import 'package:alobooking/services/venue_cache.dart';

const _password = 'matkhau-thu-123';
const _owner = {'Authorization': 'Bearer owner', 'Content-Type': 'application/json'};

/// Tạo tài khoản rồi gán vai trò bằng quyền quản trị của bộ mô phỏng; trả về uid.
Future<String> _account(String email, String role) async {
  AuthService.logout();
  final made = await AuthService.register(fullName: email.split('@').first, email: email, phone: '09${email.length}', password: _password);
  expect(made.success, isTrue, reason: '$email: ${made.message}');
  final uid = AuthService.currentUser!.uid;
  final res = await http.patch(Uri.parse('${FirebaseConfig.firestoreUrl}/users/$uid?updateMask.fieldPaths=role'),
      headers: _owner, body: jsonEncode({'fields': {'role': {'stringValue': role}}}));
  expect(res.statusCode, 200);
  AuthService.logout();
  return uid;
}

Future<void> _login(String email) async {
  AuthService.logout();
  final result = await AuthService.login(email: email, password: _password);
  expect(result.success, isTrue, reason: '$email: ${result.message}');
}

Venue _venue(int id, String ownerId, {String status = 'approved'}) => Venue(
      id: id, name: 'Sân Mô Phỏng $id', type: 'badminton', district: 'Cầu Giấy', distance: '1km', address: 'Hà Nội',
      hours: '05:00 – 23:00', tags: const [], rating: 4.5, price: '80k - 100k/h', lat: 21, lng: 105, image: '', logo: '',
      ownerId: ownerId, approvalStatus: status,
    );

Future<bool> _book(String id, Venue v, String userId, {String field = 'Cầu lông 1'}) => FirestoreService.createBooking(
    id: id, customer: 'Khách A', phone: '0912345678', venueName: v.name, venueId: v.id, ownerId: v.ownerId, userId: userId,
    field: field, time: '10:00 - 11:00', date: '01/12/2030', amount: '80.000đ');

void main() {
  final onEmulator = FirebaseConfig.firestoreUrl.startsWith('http://');

  test('đăng ký, đặt sân, duyệt, hủy, đọc theo vai trò đều qua được luật bảo mật', () async {
    final host = Uri.parse(FirebaseConfig.firestoreUrl).host;
    final project = FirebaseConfig.projectId;
    expect(project, startsWith('demo-'), reason: 'chỉ được xóa dữ liệu của dự án demo-*');
    await http.delete(Uri.parse('http://$host:8080/emulator/v1/projects/$project/databases/(default)/documents'));
    await http.delete(Uri.parse('http://$host:9099/emulator/v1/projects/$project/accounts'));
    VenueCache.clear();

    await _account('admin@thu.vn', 'admin');
    final ownerId = await _account('chusan@thu.vn', 'owner');
    final customerId = await _account('khach@thu.vn', 'customer');
    await _account('khac@thu.vn', 'customer');

    // Quên mật khẩu: bộ mô phỏng giữ lại mã trong thư; đặt mật khẩu mới rồi đăng nhập được
    expect((await AuthService.sendPasswordReset('khac@thu.vn')).success, isTrue);
    final codes = jsonDecode((await http.get(Uri.parse('http://$host:9099/emulator/v1/projects/$project/oobCodes'))).body)['oobCodes'] as List;
    final oob = codes.lastWhere((c) => c['email'] == 'khac@thu.vn' && c['requestType'] == 'PASSWORD_RESET')['oobCode'];
    final reset = await http.post(Uri.parse('${FirebaseConfig.authUrl}/accounts:resetPassword?key=${FirebaseConfig.apiKey}'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'oobCode': oob, 'newPassword': 'mat-khau-moi-456'}));
    expect(reset.statusCode, 200);
    expect((await AuthService.login(email: 'khac@thu.vn', password: _password)).success, isFalse, reason: 'mật khẩu cũ hết dùng');
    expect((await AuthService.login(email: 'khac@thu.vn', password: 'mat-khau-moi-456')).success, isTrue);
    AuthService.logout();
    final back = await http.post(Uri.parse('${FirebaseConfig.authUrl}/accounts:resetPassword?key=${FirebaseConfig.apiKey}'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'oobCode': oob, 'newPassword': 'lan-hai-789'}));
    expect(back.statusCode, 400, reason: 'mã trong thư chỉ dùng được một lần');
    // đặt lại mật khẩu chung của bài thử cho các bước sau
    expect((await AuthService.sendPasswordReset('khac@thu.vn')).success, isTrue);
    final codes2 = jsonDecode((await http.get(Uri.parse('http://$host:9099/emulator/v1/projects/$project/oobCodes'))).body)['oobCodes'] as List;
    await http.post(Uri.parse('${FirebaseConfig.authUrl}/accounts:resetPassword?key=${FirebaseConfig.apiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'oobCode': codes2.lastWhere((c) => c['email'] == 'khac@thu.vn')['oobCode'], 'newPassword': _password}));

    // Chủ sân đăng sân (chờ duyệt), không tự duyệt được; quản trị viên duyệt
    final venue = _venue(7, ownerId, status: 'pending');
    await _login('chusan@thu.vn');
    expect(await FirestoreService.addVenue(venue), isTrue);
    expect(await FirestoreService.updateVenueApproval(7, 'approved'), isFalse, reason: 'chủ sân không tự duyệt');
    await _login('admin@thu.vn');
    expect(await FirestoreService.updateVenueApproval(7, 'approved', '', DateTime.now()), isTrue);

    // Khách đặt: một sân, rồi hai sân chung một mã (hai lần ghi như màn đặt sân làm)
    await _login('khach@thu.vn');
    expect(await _book('BK-111111', venue, customerId), isTrue);
    expect(await _book('BK-222222-1', venue, customerId, field: 'Cầu lông 2'), isTrue);
    expect(await _book('BK-222222-2', venue, customerId, field: 'Cầu lông 3'), isTrue);
    expect((await FirestoreService.getBookings()).map((b) => b.id).toSet(), {'BK-111111', 'BK-222222-1', 'BK-222222-2'});
    expect(await FirestoreService.getBookingStatuses(['BK-111111']), ['Chờ xác nhận']);
    expect((await FirestoreService.getPayments()).length, 3);
    expect(await FirestoreService.updateBookingStatus('BK-111111', 'Đã hủy'), isFalse, reason: 'khách không tự hủy');
    expect(await FirestoreService.updateBookingStatus('BK-111111', 'Đã xác nhận'), isFalse, reason: 'khách không tự xác nhận');
    expect(await FirestoreService.addReview(ReviewItem(id: 'RV1', venueId: 7, userId: customerId, userName: 'Khách A', stars: 5, comment: 'Tốt')), isTrue);

    // Lịch bận công khai: người chưa đăng nhập thấy ô đã đặt nhưng không đọc được đơn
    AuthService.logout();
    final day = DateTime(2030, 12, 1);
    expect(await BookingSlots.bookedSlots(venue, day, 8), hasLength(3));
    expect((await FirestoreService.getSlots()).every((s) => s.customer.isEmpty && s.phone.isEmpty && s.amount.isEmpty), isTrue);
    expect((await http.get(Uri.parse('${FirebaseConfig.firestoreUrl}/bookings/BK-111111'))).statusCode, 403);
    expect((await http.get(Uri.parse('${FirebaseConfig.firestoreUrl}/users/$customerId'))).statusCode, 403);

    // Khách khác không thấy đơn
    await _login('khac@thu.vn');
    expect(await FirestoreService.getBookings(), isEmpty);
    expect(await FirestoreService.getPayments(), isEmpty);

    // Chủ sân: thấy đơn sân mình, nhận thông báo, xác nhận một đơn, hủy một đơn (ô giờ trống lại)
    await _login('chusan@thu.vn');
    final mine = await FirestoreService.getBookings();
    expect(mine, hasLength(3));
    expect(FirestoreService.customersFromBookings(mine).single.bookingsCount, 3);
    final notifications = await FirestoreService.getNotifications();
    expect(notifications, hasLength(3));
    expect(await FirestoreService.markNotificationAsRead(notifications.first.id), isTrue);
    expect(await FirestoreService.confirmBooking('BK-111111'), isTrue);
    expect((await FirestoreService.getPayments()).singleWhere((p) => p.bookingId == 'BK-111111').status, 'Thành công');
    expect(await FirestoreService.updateBookingStatus('BK-222222-1', 'Đã hủy'), isTrue);
    expect(await BookingSlots.bookedSlots(venue, day, 8), hasLength(2));
    expect(await FirestoreService.updateVenue(venue.copyWith(approvalStatus: 'pending', price: '90k - 110k/h')), isTrue);

    // Quản trị viên: thấy tất cả, đăng tin
    await _login('admin@thu.vn');
    expect(await FirestoreService.getBookings(), hasLength(3));
    expect((await FirestoreService.getCustomers()).map((c) => c.email), containsAll(['khach@thu.vn', 'khac@thu.vn']));
    FirestoreService.lastLoadFailed = false;
    expect(await FirestoreService.getPayments(), hasLength(3));
    expect(FirestoreService.lastLoadFailed, isFalse);
  }, skip: onEmulator ? false : 'Cần chạy với bộ mô phỏng Firebase', timeout: const Timeout(Duration(minutes: 3)));
}
