import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../booking_slots.dart';
import '../firestore_service.dart' show BookingItem;

/// Đơn đặt sân MÔ PHỎNG (file assets/demo/simulated_bookings.json do tool/simulate_bookings.py sinh ra).
///
/// Không phải đơn thật: dùng để minh họa mô hình dự đoán số đơn khi dữ liệu thật còn ít. Số đơn mỗi ngày được
/// sinh từ một công thức đã biết ("đáp án") trên thời tiết thật, nên có thể đối chiếu xem mô hình có tìm lại
/// được đáp án hay không. Không bao giờ ghi vào Firestore và không tính vào số liệu doanh thu/đơn của Admin.
class SimulatedBookings {
  /// Mã đơn mô phỏng luôn bắt đầu bằng tiền tố này.
  static const idPrefix = 'SIM-';

  static bool isSimulated(BookingItem b) => b.id.startsWith(idPrefix);

  final List<BookingItem> bookings;

  /// Đáp án đã gài (log): khóa trùng với khóa yếu tố của mô hình, thêm 'intercept'.
  final Map<String, double> truth;
  final String warning;
  final String from;
  final String to;
  final int days;

  const SimulatedBookings({
    required this.bookings,
    required this.truth,
    required this.warning,
    required this.from,
    required this.to,
    required this.days,
  });

  /// Số đơn không bị hủy (cái mô hình đếm).
  int get retained => bookings.where((b) => !BookingSlots.isCancelled(b.status)).length;

  /// Đọc nội dung file JSON. Trả về null nếu sai định dạng hoặc thiếu cờ `simulated` (không dùng file lạ làm dữ liệu mô phỏng).
  static SimulatedBookings? parse(String text) {
    try {
      final root = json.decode(text) as Map<String, dynamic>;
      final meta = root['meta'] as Map<String, dynamic>;
      if (meta['simulated'] != true) return null;
      final venues = (meta['venues'] as List).cast<String>();
      final pays = (meta['payments'] as List).cast<String>();
      final out = <BookingItem>[];
      for (final r in (root['bookings'] as List)) {
        final row = r as List;
        final date = DateTime.parse(row[1] as String);
        final amount = row[7] as int;
        out.add(BookingItem(
          id: row[0] as String,
          customer: 'Khách mô phỏng',
          phone: '',
          venueName: venues[row[3] as int],
          field: 'Sân ${row[4]}',
          time: row[2] as String,
          date: BookingSlots.formatDate(date),
          amount: '${_thousands(amount)}đ',
          status: row[5] as String,
          paymentMethod: pays[row[6] as int],
          createdAt: date.subtract(Duration(days: row[8] as int)),
        ));
      }
      return SimulatedBookings(
        bookings: out,
        truth: {for (final e in (meta['truth'] as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble()},
        warning: meta['warning'] as String? ?? 'Dữ liệu mô phỏng, không phải đơn thật.',
        from: meta['from'] as String,
        to: meta['to'] as String,
        days: meta['days'] as int,
      );
    } catch (_) {
      return null;
    }
  }

  static String _thousands(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  static SimulatedBookings? _cache;

  /// Nạp từ asset (nhớ trong phiên). Null nếu không đọc được.
  static Future<SimulatedBookings?> load() async {
    if (_cache != null) return _cache;
    try {
      _cache = parse(await rootBundle.loadString('assets/demo/simulated_bookings.json'));
    } catch (_) {}
    return _cache;
  }
}
