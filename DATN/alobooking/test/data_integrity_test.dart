import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/models/customer.dart';
import 'package:alobooking/models/user.dart';
import 'package:alobooking/services/firestore_service.dart';

BookingItem b(String id, String status, String amount,
    {String phone = '0901234567', String customer = 'Khách', String userId = ''}) {
  return BookingItem(
    id: id,
    customer: customer,
    phone: phone,
    venueName: 'Sân A',
    field: 'Sân 1',
    time: '18:00 - 19:00',
    date: '10/11/2026',
    amount: amount,
    status: status,
    paymentMethod: 'Ví MoMo',
    userId: userId,
  );
}

void main() {
  // Kích hoạt môi trường test của Flutter: mọi yêu cầu mạng trả mã 400 (mô phỏng lỗi máy chủ)
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phân quyền chỉ theo vai trò, không theo email', () {
    test('email chứa "admin" nhưng role customer thì không phải admin', () {
      final u = AppUser(uid: 'u1', fullName: 'A', email: 'admin123@gmail.com', phone: '', role: 'customer');
      expect(u.isAdmin, isFalse);
      expect(u.isOwner, isFalse);
      expect(u.isGuest, isFalse);
    });

    test('email chứa "guest"/"chusan" không đổi quyền', () {
      expect(AppUser(uid: 'u', fullName: 'A', email: 'chusan@x.com', phone: '', role: 'customer').isOwner, isFalse);
      expect(AppUser(uid: 'u', fullName: 'A', email: 'guest@x.com', phone: '', role: 'customer').isGuest, isFalse);
    });

    test('role đúng thì có quyền', () {
      expect(AppUser(uid: 'u', fullName: 'A', email: 'x@x.com', phone: '', role: 'admin').isAdmin, isTrue);
      expect(AppUser(uid: 'u', fullName: 'A', email: 'x@x.com', phone: '', role: 'owner').isOwner, isTrue);
      expect(AppUser(uid: 'u', fullName: 'A', email: 'x@x.com', phone: '', role: 'guest').isGuest, isTrue);
    });
  });

  group('Đơn đặt thuộc về ai', () {
    test('ưu tiên uid, kể cả khi trùng số điện thoại người khác', () {
      final bk = b('1', 'Đã xác nhận', '100,000đ', userId: 'u-khac', phone: '0901234567');
      expect(bk.belongsTo(uid: 'u1', phone: '0901234567', name: 'Khách'), isFalse);
      expect(bk.belongsTo(uid: 'u-khac', phone: '', name: ''), isTrue);
    });

    test('đơn cũ chưa có uid thì khớp số điện thoại (bỏ ký tự thừa)', () {
      final bk = b('1', 'Đã xác nhận', '100,000đ', phone: '0901 234 567');
      expect(bk.belongsTo(uid: 'u1', phone: '0901234567', name: 'ai đó'), isTrue);
      expect(bk.belongsTo(uid: 'u1', phone: '0999999999', name: 'Khách'), isFalse);
    });

    test('thiếu số điện thoại thì khớp theo tên', () {
      final bk = b('1', 'Đã xác nhận', '100,000đ', phone: '', customer: 'Nguyễn Văn An');
      expect(bk.belongsTo(uid: 'u1', phone: '', name: 'nguyễn văn an'), isTrue);
      expect(bk.belongsTo(uid: 'u1', phone: '', name: 'Người Khác'), isFalse);
    });
  });

  group('Khách hàng: số đơn và chi tiêu tính từ đơn thật', () {
    test('chỉ tính đơn không hủy; chi tiêu chỉ gồm đơn đã xác nhận/hoàn thành', () {
      final c = CustomerItem(id: 'c1', name: 'An', phone: '0901234567', email: '', joinDate: '');
      final other = CustomerItem(id: 'c2', name: 'Bình', phone: '0911111111', email: '', joinDate: '');
      FirestoreService.enrichCustomers([c, other], [
        b('1', 'Đã xác nhận', '150,000đ'),
        b('2', 'Hoàn thành', '250,000đ'),
        b('3', 'Chờ xác nhận', '999,000đ'),
        b('4', 'Đã hủy', '500,000đ'),
      ]);
      expect(c.bookingsCount, 3); // xác nhận + hoàn thành + chờ (không tính hủy)
      expect(c.totalSpent, '400.000đ'); // không tính đơn chờ và đơn hủy
      expect(other.bookingsCount, 0);
      expect(other.totalSpent, '0đ');
    });
  });

  group('Không còn dữ liệu mẫu khi không tải được', () {
    // Trong flutter test mọi yêu cầu mạng trả mã 400 -> mô phỏng lỗi máy chủ
    test('đơn, sân, khách, thanh toán, thông báo đều rỗng và báo lỗi tải', () async {
      FirestoreService.lastLoadFailed = false;
      expect(await FirestoreService.getBookings(), isEmpty);
      expect(await FirestoreService.getVenues(), isEmpty);
      expect(await FirestoreService.getCustomers(), isEmpty);
      expect(await FirestoreService.getPayments(), isEmpty);
      expect(await FirestoreService.getNotifications(), isEmpty);
      expect(FirestoreService.lastLoadFailed, isTrue);
    });
  });
}
