import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/services/admin_stats.dart';
import 'package:alobooking/services/firestore_service.dart';

BookingItem b(String id, String date, String time, String status, String amount,
    {String venue = 'Sân Cầu Lông A', String phone = '0900000001', String pay = 'Ví MoMo', String field = 'Sân 1'}) {
  return BookingItem(
    id: id,
    customer: 'Khách $id',
    phone: phone,
    venueName: venue,
    field: field,
    time: time,
    date: date,
    amount: amount,
    status: status,
    paymentMethod: pay,
  );
}

String d(DateTime t) => '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';

void main() {
  final now = DateTime(2026, 11, 17, 10, 0);
  final today = DateTime(2026, 11, 17);

  test('parseMoney / fmtMoney / fmtCompact', () {
    expect(AdminStats.parseMoney('150,000đ'), 150000);
    expect(AdminStats.parseMoney('1.250.000đ'), 1250000);
    expect(AdminStats.parseMoney(''), 0);
    expect(AdminStats.fmtMoney(1250000), '1.250.000đ');
    expect(AdminStats.fmtMoney(0), '0đ');
    expect(AdminStats.fmtCompact(1250000), '1,25 tr');
    expect(AdminStats.fmtCompact(85000), '85k');
  });

  test('doanh thu chỉ tính đơn đã xác nhận/hoàn thành, không tính hủy và chờ xác nhận', () {
    final bookings = [
      b('1', d(today), '18:00 - 19:00', 'Đã xác nhận', '100,000đ'),
      b('2', d(today), '19:00 - 20:00', 'Hoàn thành', '200,000đ'),
      b('3', d(today), '20:00 - 21:00', 'Chờ xác nhận', '400,000đ'),
      b('4', d(today), '21:00 - 22:00', 'Đã hủy', '800,000đ'),
    ];
    final s = AdminStats.compute(bookings: bookings, venues: const [], period: AdminPeriod.today, now: now);
    expect(s.revenue, 300000);
    expect(s.orders, 3); // không tính đơn hủy
    expect(s.cancelled, 1);
    expect(s.cancelRate, closeTo(0.25, 1e-9));
    expect(s.pending, 1);
  });

  test('so với kỳ trước: không có dữ liệu kỳ trước thì không trả phần trăm', () {
    final bookings = [b('1', d(today), '18:00 - 19:00', 'Đã xác nhận', '100,000đ')];
    final s = AdminStats.compute(bookings: bookings, venues: const [], period: AdminPeriod.week, now: now);
    expect(s.prevRevenue, isNull);
    expect(AdminStats.change(s.revenue, s.prevRevenue), isNull);
  });

  test('so với kỳ trước: có dữ liệu thì tính đúng', () {
    final bookings = [
      b('1', d(today), '18:00 - 19:00', 'Đã xác nhận', '150,000đ'),
      b('2', d(today.subtract(const Duration(days: 8))), '18:00 - 19:00', 'Đã xác nhận', '100,000đ'),
    ];
    final s = AdminStats.compute(bookings: bookings, venues: const [], period: AdminPeriod.week, now: now);
    expect(s.revenue, 150000);
    expect(s.prevRevenue, 100000);
    expect(AdminStats.change(s.revenue, s.prevRevenue), closeTo(50, 1e-9));
  });

  test('đơn ngoài kỳ và đơn tương lai không tính vào doanh thu kỳ', () {
    final bookings = [
      b('1', d(today.subtract(const Duration(days: 40))), '18:00 - 19:00', 'Đã xác nhận', '100,000đ'),
      b('2', d(today.add(const Duration(days: 3))), '18:00 - 19:00', 'Đã xác nhận', '100,000đ'),
    ];
    final s = AdminStats.compute(bookings: bookings, venues: const [], period: AdminPeriod.month, now: now);
    expect(s.revenue, 0);
    expect(s.upcoming, 1);
  });

  test('chuỗi biểu đồ: 7 cột cho 7 ngày, đúng tổng doanh thu', () {
    final bookings = [
      b('1', d(today), '18:00 - 19:00', 'Đã xác nhận', '100,000đ'),
      b('2', d(today.subtract(const Duration(days: 2))), '18:00 - 19:00', 'Hoàn thành', '50,000đ'),
    ];
    final s = AdminStats.compute(bookings: bookings, venues: const [], period: AdminPeriod.week, now: now);
    expect(s.series.length, 7);
    expect(s.series.fold<int>(0, (a, e) => a + e.revenue), 150000);
    expect(s.series.last.revenue, 100000);
  });

  test('phân loại môn theo sân đã biết rồi mới đoán theo tên', () {
    final venue = Venue(
      id: 1,
      name: 'Cụm Sân X',
      type: 'tennis',
      district: 'Cầu Giấy',
      distance: '',
      address: '',
      hours: '',
      tags: const [],
      rating: 4.5,
      price: '',
      lat: 0,
      lng: 0,
      image: '',
      logo: '',
      ownerId: '',
      ownerName: '',
    );
    final bookings = [
      b('1', d(today), '18:00 - 19:30', 'Đã xác nhận', '300,000đ', venue: 'Cụm Sân X'),
      b('2', d(today), '18:00 - 19:00', 'Đã xác nhận', '100,000đ', venue: 'Sân Cầu Lông Lạ'),
    ];
    final s = AdminStats.compute(bookings: bookings, venues: [venue], period: AdminPeriod.today, now: now);
    expect(s.revenueBySport['Tennis'], 300000);
    expect(s.revenueBySport['Cầu lông'], 100000);
    expect(s.hoursBySport['Tennis'], 2); // 18:00-19:30 chiếm giờ 18 và 19
  });

  test('top sân xếp theo doanh thu giảm dần và CSV có đủ số liệu', () {
    final bookings = [
      b('1', d(today), '18:00 - 19:00', 'Đã xác nhận', '100,000đ', venue: 'A'),
      b('2', d(today), '19:00 - 20:00', 'Đã xác nhận', '300,000đ', venue: 'B'),
      b('3', d(today), '20:00 - 21:00', 'Đã xác nhận', '50,000đ', venue: 'A'),
    ];
    final s = AdminStats.compute(bookings: bookings, venues: const [], period: AdminPeriod.today, now: now);
    expect(s.topVenues.first.name, 'B');
    expect(s.topVenues.map((v) => v.revenue).toList(), [300000, 150000]);
    final csv = s.toCsv();
    expect(csv, contains('Doanh thu (đ),450000'));
    expect(csv, contains('"B",300000,1'));
  });

  test('không có đơn nào thì mọi số liệu bằng 0, không lỗi chia cho 0', () {
    final s = AdminStats.compute(bookings: const [], venues: const [], period: AdminPeriod.month, now: now);
    expect(s.revenue, 0);
    expect(s.cancelRate, isNull);
    expect(s.avgOrderValue, 0);
    expect(s.hasData, isFalse);
  });
}
