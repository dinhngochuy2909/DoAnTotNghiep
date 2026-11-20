import '../models/venue.dart';
import 'firestore_service.dart';

/// Tiện ích đọc/ghi khung giờ đặt sân. Dữ liệu đơn đặt trong Firestore có nhiều
/// định dạng (ngày dd/MM/yyyy hoặc yyyy-MM-dd, giờ "06:00 - 07:30" hoặc nhiều ca
/// nối bằng dấu phẩy), nên mọi nơi cần đọc lịch phải đi qua đây.
class BookingSlots {
  /// Ngày dạng dd/MM/yyyy hoặc yyyy-MM-dd -> DateTime (null nếu sai định dạng).
  static DateTime? parseDate(String s) {
    final t = s.trim();
    final a = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(t);
    if (a != null) {
      return DateTime(int.parse(a.group(3)!), int.parse(a.group(2)!), int.parse(a.group(1)!));
    }
    final b = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(t);
    if (b != null) {
      return DateTime(int.parse(b.group(1)!), int.parse(b.group(2)!), int.parse(b.group(3)!));
    }
    return null;
  }

  static bool sameDay(String s, DateTime d) {
    final p = parseDate(s);
    return p != null && p.year == d.year && p.month == d.month && p.day == d.day;
  }

  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// "18:00 - 19:30, 20:00 - 21:00" -> [(1080,1170), (1200,1260)] (phút trong ngày).
  static List<(int, int)> parseRanges(String time) {
    final out = <(int, int)>[];
    for (final part in time.split(',')) {
      final m = RegExp(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})').firstMatch(part);
      if (m == null) continue;
      final s = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
      final e = int.parse(m.group(3)!) * 60 + int.parse(m.group(4)!);
      if (e > s) out.add((s, e));
    }
    return out;
  }

  /// Các giờ nguyên bị chiếm bởi một chuỗi giờ (ca 18:30-20:00 chiếm giờ 18 và 19).
  static Set<int> occupiedHours(String time) {
    final hours = <int>{};
    for (final (s, e) in parseRanges(time)) {
      for (var h = s ~/ 60; h * 60 < e; h++) {
        hours.add(h);
      }
    }
    return hours;
  }

  /// "Sân #2", "Pickleball 3", "Sân Kim Long 1" -> chỉ số sân con (0-based) trong [courtCount].
  static int courtIndex(String field, int courtCount) {
    final m = RegExp(r'(\d+)\s*$').firstMatch(field.trim()) ?? RegExp(r'(\d+)').firstMatch(field);
    final n = int.tryParse(m?.group(1) ?? '') ?? 1;
    return (n - 1).abs() % courtCount;
  }

  static bool isCancelled(String status) {
    final s = status.toLowerCase();
    return s.contains('hủy') || s.contains('huỷ') || s.contains('huy');
  }

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Các ô đã đặt của [venue] trong [date]: tập khoá "courtIdx-hour".
  static Future<Set<String>> bookedSlots(Venue venue, DateTime date, int courtCount) async {
    final bookings = await FirestoreService.getBookings();
    final key = _norm(venue.name);
    final slots = <String>{};
    for (final b in bookings) {
      if (_norm(b.venueName) != key) continue;
      if (isCancelled(b.status)) continue;
      if (!sameDay(b.date, date)) continue;
      final court = courtIndex(b.field, courtCount);
      for (final h in occupiedHours(b.time)) {
        slots.add('$court-$h');
      }
    }
    return slots;
  }

  /// Gộp các giờ liên tiếp thành ca: [18,19,21] -> ["18:00 - 20:00", "21:00 - 22:00"].
  static List<String> mergeHours(List<int> hours) {
    final sorted = [...hours]..sort();
    final out = <String>[];
    int? start;
    int? prev;
    String fmt(int h) => '${h.toString().padLeft(2, '0')}:00';
    for (final h in sorted) {
      if (start == null) {
        start = h;
      } else if (h != prev! + 1) {
        out.add('${fmt(start)} - ${fmt(prev + 1)}');
        start = h;
      }
      prev = h;
    }
    if (start != null) out.add('${fmt(start)} - ${fmt(prev! + 1)}');
    return out;
  }

  /// Ca giờ vàng: 16:00 – 22:00 (các giờ bắt đầu từ 16 đến 21). Ngoài ca này tính giá thường.
  static const int goldenStartHour = 16;
  static const int goldenEndHour = 22;
  static const String goldenLabel = '16:00 – 22:00';

  /// Giờ bắt đầu [hour] có thuộc ca giờ vàng không.
  static bool isGolden(int hour) => hour >= goldenStartHour && hour < goldenEndHour;

  /// Giá một giờ: ngoài ca vàng lấy giá thấp, trong ca vàng (16:00 – 22:00) lấy giá cao
  /// trong khoảng giá của sân ("80k - 100k/h"). Trả về đồng.
  static int priceForHour(Venue v, int hour) {
    final m = RegExp(r'(\d+)\s*k\s*-\s*(\d+)\s*k').firstMatch(v.price.toLowerCase());
    if (m == null) return 150000;
    final a = int.parse(m.group(1)!) * 1000;
    final b = int.parse(m.group(2)!) * 1000;
    // Chủ sân nhập ngược ("160k - 80k") vẫn cho giờ vàng là mức cao hơn
    final low = a < b ? a : b;
    final high = a < b ? b : a;
    return isGolden(hour) ? high : low;
  }
}
