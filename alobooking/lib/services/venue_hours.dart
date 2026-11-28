/// Trạng thái mở cửa của một sân tại một thời điểm, tính từ chuỗi giờ hoạt động ("05:30 – 23:00").
enum OpenStatus { open, closed, unknown }

class VenueHours {
  VenueHours._();

  static final _range = RegExp(r'(\d{1,2}):(\d{2})\s*[–—-]\s*(\d{1,2}):(\d{2})');

  /// Đang mở, đã đóng, hoặc không rõ (chuỗi giờ không đọc được: không đoán).
  /// Hỗ trợ sân mở qua nửa đêm (ví dụ 18:00 – 02:00); mở và đóng cùng một giờ thì coi là mở cả ngày.
  static OpenStatus statusAt(String hours, DateTime now) {
    final m = _range.firstMatch(hours);
    if (m == null) return OpenStatus.unknown;
    final open = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
    final close = int.parse(m.group(3)!) * 60 + int.parse(m.group(4)!);
    if (open > 24 * 60 || close > 24 * 60) return OpenStatus.unknown;
    if (close == open) return OpenStatus.open;
    final t = now.hour * 60 + now.minute;
    final isOpen = close > open ? (t >= open && t < close) : (t >= open || t < close);
    return isOpen ? OpenStatus.open : OpenStatus.closed;
  }
}
