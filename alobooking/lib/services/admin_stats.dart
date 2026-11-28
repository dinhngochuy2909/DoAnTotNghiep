import '../models/venue.dart';
import 'booking_slots.dart';
import 'firestore_service.dart' show BookingItem;

/// Số liệu dashboard quản trị, tính từ dữ liệu đặt sân THẬT (không có số mẫu).
///
/// Quy ước:
///  - Doanh thu = tổng tiền các đơn không bị hủy và đã được xác nhận/hoàn thành
///    (đơn "Chờ xác nhận" chưa tính vì chưa chắc phát sinh).
///  - Kỳ thống kê tính theo NGÀY CHƠI của đơn, kết thúc ở hôm nay.
///  - So với kỳ trước: nếu kỳ trước không có dữ liệu thì không hiện % (trả về null).

class AdminPeriod {
  final String key;
  final String label;
  final int days;
  const AdminPeriod(this.key, this.label, this.days);

  static const today = AdminPeriod('today', 'Hôm nay', 1);
  static const week = AdminPeriod('week', '7 ngày', 7);
  static const month = AdminPeriod('month', '30 ngày', 30);
  static const year = AdminPeriod('year', '12 tháng', 365);
  static const all = [today, week, month, year];

  static AdminPeriod byKey(String k) => all.firstWhere((p) => p.key == k, orElse: () => month);
}

class ChartBucket {
  final String label;
  final String tooltip;
  final int revenue;
  final int orders;
  const ChartBucket(this.label, this.tooltip, this.revenue, this.orders);
}

class VenueRevenue {
  final String name;
  final String? district;
  final int revenue;
  final int orders;
  const VenueRevenue(this.name, this.district, this.revenue, this.orders);
}

class SlotShare {
  final String label;
  final int orders;
  const SlotShare(this.label, this.orders);
}

class AdminStats {
  final AdminPeriod period;
  final DateTime from;
  final DateTime to;

  final int revenue;
  final int? prevRevenue;
  final int orders; // đơn không hủy trong kỳ
  final int? prevOrders;
  final int cancelled;
  final int totalOrdersIncludingCancelled;
  final double? cancelRate; // 0..1, null nếu chưa có đơn
  final double? prevCancelRate;
  final int customers;
  final int? prevCustomers;
  final int avgOrderValue;

  final int pending; // đơn chờ xác nhận (toàn bộ, mọi ngày)
  final int overduePending; // chờ xác nhận nhưng ngày chơi đã qua
  final int upcoming; // đơn không hủy có ngày chơi sau hôm nay

  final List<ChartBucket> series;
  final Map<String, int> revenueBySport;
  final Map<String, int> hoursBySport;
  final List<SlotShare> slots;
  final List<VenueRevenue> topVenues;
  final Map<String, int> paymentMethods;

  const AdminStats({
    required this.period,
    required this.from,
    required this.to,
    required this.revenue,
    required this.prevRevenue,
    required this.orders,
    required this.prevOrders,
    required this.cancelled,
    required this.totalOrdersIncludingCancelled,
    required this.cancelRate,
    required this.prevCancelRate,
    required this.customers,
    required this.prevCustomers,
    required this.avgOrderValue,
    required this.pending,
    required this.overduePending,
    required this.upcoming,
    required this.series,
    required this.revenueBySport,
    required this.hoursBySport,
    required this.slots,
    required this.topVenues,
    required this.paymentMethods,
  });

  bool get hasData => totalOrdersIncludingCancelled > 0;

  /// Thay đổi % so với kỳ trước; null nếu kỳ trước bằng 0 (không có cơ sở so sánh).
  static double? change(num cur, num? prev) {
    if (prev == null || prev == 0) return null;
    return (cur - prev) / prev * 100;
  }

  // ───────── Tiện ích ─────────

  /// "150,000đ" / "1.250.000đ" / "200000" -> 150000
  static int parseMoney(String s) {
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? 0 : int.parse(digits);
  }

  static bool isPending(String status) => status.toLowerCase().contains('chờ');

  /// Có tính vào doanh thu không.
  static bool countsAsRevenue(String status) => !BookingSlots.isCancelled(status) && !isPending(status);

  static const sportNames = {
    'pickleball': 'Pickleball',
    'badminton': 'Cầu lông',
    'football': 'Bóng đá',
    'tennis': 'Tennis',
    'basketball': 'Bóng rổ',
  };

  /// Môn thể thao của đơn: ưu tiên tra theo tên sân, nếu không khớp thì đoán theo chữ trong tên.
  static String sportOf(BookingItem b, Map<String, String> venueTypeByName) {
    final byName = venueTypeByName[b.venueName.trim().toLowerCase()];
    if (byName != null && sportNames.containsKey(byName)) return sportNames[byName]!;
    final t = '${b.venueName} ${b.field}'.toLowerCase();
    if (t.contains('pickle')) return 'Pickleball';
    if (t.contains('cầu lông') || t.contains('badminton')) return 'Cầu lông';
    if (t.contains('bóng đá') || t.contains('football') || t.contains('sân 7') || t.contains('sân 5')) return 'Bóng đá';
    if (t.contains('tennis')) return 'Tennis';
    if (t.contains('bóng rổ') || t.contains('basketball')) return 'Bóng rổ';
    return 'Khác';
  }

  static String fmtMoney(num v) {
    final n = v.round();
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${n < 0 ? '-' : ''}$bufđ';
  }

  /// 1.250.000 -> "1,25 tr"; 85.000 -> "85k"
  static String fmtCompact(num v) {
    final n = v.abs();
    if (n >= 1e9) return '${_trim(v / 1e9)} tỷ';
    if (n >= 1e6) return '${_trim(v / 1e6)} tr';
    if (n >= 1e3) return '${_trim(v / 1e3)}k';
    return '${v.round()}';
  }

  static String _trim(double d) {
    final s = d.toStringAsFixed(d.abs() >= 100 ? 0 : (d.abs() >= 10 ? 1 : 2));
    return (s.contains('.') ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '') : s).replaceAll('.', ',');
  }

  static String _dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  // ───────── Tính toán ─────────

  static AdminStats compute({
    required List<BookingItem> bookings,
    required List<Venue> venues,
    required AdminPeriod period,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final from = today.subtract(Duration(days: period.days - 1));
    final prevTo = from.subtract(const Duration(days: 1));
    final prevFrom = prevTo.subtract(Duration(days: period.days - 1));

    final venueByName = {for (final v in venues) v.name.trim().toLowerCase(): v};
    final typeByName = {for (final e in venueByName.entries) e.key: e.value.type};

    bool inRange(DateTime d, DateTime a, DateTime b) => !d.isBefore(a) && !d.isAfter(b);

    int revenue = 0, prevRevenue = 0, orders = 0, prevOrders = 0, cancelled = 0, prevCancelled = 0, total = 0, prevTotal = 0;
    final custs = <String>{}, prevCusts = <String>{};
    final revBySport = <String, int>{};
    final hoursBySport = <String, int>{};
    final slotCount = [0, 0, 0, 0, 0];
    final venueAgg = <String, List<int>>{}; // name -> [revenue, orders]
    final pay = <String, int>{};
    var pending = 0, overdue = 0, upcoming = 0;

    // Chuỗi biểu đồ
    final buckets = <String, List<int>>{}; // key -> [revenue, orders]
    final order = <String>[];
    final labelOf = <String, String>{};
    final tipOf = <String, String>{};
    if (period.days <= 1) {
      for (var h = 5; h <= 22; h++) {
        final k = h.toString();
        order.add(k);
        labelOf[k] = '${h}h';
        tipOf[k] = '${h}h–${h + 1}h';
        buckets[k] = [0, 0];
      }
    } else if (period.days <= 31) {
      for (var i = 0; i < period.days; i++) {
        final d = from.add(Duration(days: i));
        final k = _dm(d);
        order.add(k);
        labelOf[k] = k;
        tipOf[k] = '${VnWeekday.name(d)} $k';
        buckets[k] = [0, 0];
      }
    } else {
      for (var i = 11; i >= 0; i--) {
        final d = DateTime(today.year, today.month - i, 1);
        final k = '${d.year}-${d.month}';
        order.add(k);
        labelOf[k] = 'T${d.month}';
        tipOf[k] = 'Tháng ${d.month}/${d.year}';
        buckets[k] = [0, 0];
      }
    }

    for (final b in bookings) {
      final date = BookingSlots.parseDate(b.date);
      if (date == null) continue;
      final cancelledNow = BookingSlots.isCancelled(b.status);
      final pend = isPending(b.status);
      final amount = parseMoney(b.amount);
      final custKey = b.phone.trim().isNotEmpty && !b.phone.contains('x') ? b.phone.trim() : b.customer.trim().toLowerCase();

      if (pend) {
        pending++;
        if (date.isBefore(today)) overdue++;
      }
      if (!cancelledNow && date.isAfter(today)) upcoming++;

      if (inRange(date, prevFrom, prevTo)) {
        prevTotal++;
        if (cancelledNow) {
          prevCancelled++;
        } else {
          prevOrders++;
          prevCusts.add(custKey);
          if (countsAsRevenue(b.status)) prevRevenue += amount;
        }
      }

      if (!inRange(date, from, today)) continue;
      total++;
      if (cancelledNow) {
        cancelled++;
        continue;
      }
      orders++;
      custs.add(custKey);

      final sport = sportOf(b, typeByName);
      final hours = BookingSlots.occupiedHours(b.time);
      hoursBySport[sport] = (hoursBySport[sport] ?? 0) + (hours.isEmpty ? 1 : hours.length);

      final startH = BookingSlots.parseRanges(b.time).isEmpty ? 18 : BookingSlots.parseRanges(b.time).first.$1 ~/ 60;
      final si = startH < 8 ? 0 : (startH < 14 ? 1 : (startH < 17 ? 2 : (startH < 21 ? 3 : 4)));
      slotCount[si]++;

      pay[b.paymentMethod] = (pay[b.paymentMethod] ?? 0) + 1;

      if (countsAsRevenue(b.status)) {
        revenue += amount;
        revBySport[sport] = (revBySport[sport] ?? 0) + amount;
        final agg = venueAgg.putIfAbsent(b.venueName, () => [0, 0]);
        agg[0] += amount;
        agg[1]++;
      }

      // Biểu đồ: đơn tính theo ngày chơi; doanh thu chỉ cộng khi đã xác nhận
      String key;
      if (period.days <= 1) {
        key = startH.clamp(5, 22).toString();
      } else if (period.days <= 31) {
        key = _dm(date);
      } else {
        key = '${date.year}-${date.month}';
      }
      final bk = buckets[key];
      if (bk != null) {
        bk[1]++;
        if (countsAsRevenue(b.status)) bk[0] += amount;
      }
    }

    const slotLabels = ['Sáng sớm (5–8h)', 'Sáng–trưa (8–14h)', 'Chiều (14–17h)', 'Tối (17–21h)', 'Khuya (21–23h)'];
    final top = venueAgg.entries
        .map((e) => VenueRevenue(e.key, venueByName[e.key.trim().toLowerCase()]?.district, e.value[0], e.value[1]))
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    double? rate(int c, int t) => t == 0 ? null : c / t;

    return AdminStats(
      period: period,
      from: from,
      to: today,
      revenue: revenue,
      prevRevenue: prevTotal == 0 ? null : prevRevenue,
      orders: orders,
      prevOrders: prevTotal == 0 ? null : prevOrders,
      cancelled: cancelled,
      totalOrdersIncludingCancelled: total,
      cancelRate: rate(cancelled, total),
      prevCancelRate: rate(prevCancelled, prevTotal),
      customers: custs.length,
      prevCustomers: prevTotal == 0 ? null : prevCusts.length,
      avgOrderValue: orders == 0 ? 0 : (revenue / orders).round(),
      pending: pending,
      overduePending: overdue,
      upcoming: upcoming,
      series: [for (final k in order) ChartBucket(labelOf[k]!, tipOf[k]!, buckets[k]![0], buckets[k]![1])],
      revenueBySport: revBySport,
      hoursBySport: hoursBySport,
      slots: [for (var i = 0; i < 5; i++) SlotShare(slotLabels[i], slotCount[i])],
      topVenues: top.take(5).toList(),
      paymentMethods: pay,
    );
  }

  /// Xuất báo cáo CSV (UTF-8) cho kỳ đang xem.
  String toCsv() {
    final b = StringBuffer();
    b.writeln('Báo cáo AloBooking,${period.label},${_dm(from)} - ${_dm(to)}');
    b.writeln('Doanh thu (đ),$revenue');
    b.writeln('Số đơn (không hủy),$orders');
    b.writeln('Đơn hủy,$cancelled');
    b.writeln('Khách đặt,$customers');
    b.writeln('Giá trị đơn trung bình (đ),$avgOrderValue');
    b.writeln();
    b.writeln('Thời gian,Doanh thu (đ),Số đơn');
    for (final s in series) {
      b.writeln('${s.tooltip},${s.revenue},${s.orders}');
    }
    b.writeln();
    b.writeln('Môn,Doanh thu (đ),Số giờ đặt');
    for (final e in revenueBySport.entries) {
      b.writeln('${e.key},${e.value},${hoursBySport[e.key] ?? 0}');
    }
    b.writeln();
    b.writeln('Cụm sân,Doanh thu (đ),Số đơn');
    for (final v in topVenues) {
      b.writeln('"${v.name.replaceAll('"', '""')}",${v.revenue},${v.orders}');
    }
    return b.toString();
  }
}

class VnWeekday {
  static const _n = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static String name(DateTime d) => _n[d.weekday - 1];
}
