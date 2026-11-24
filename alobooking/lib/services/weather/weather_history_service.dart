import 'dart:convert';

import 'package:http/http.dart' as http;

import '../forecast/booking_count_model.dart' show WeatherInput;
import '../forecast/demand_forecast_service.dart' show VnCalendar;

/// Thời tiết THẬT của những ngày đã qua ở Hà Nội (Open-Meteo, miễn phí, không cần key),
/// dùng để ghép với số đơn đặt sân từng ngày khi huấn luyện mô hình dự đoán.
///
/// Ngày cũ hơn ~3 tháng lấy từ kho lưu trữ (archive), ngày gần đây lấy từ API dự báo với `past_days`
/// (kho lưu trữ trễ vài ngày). Không lấy được thì trả về bản đồ rỗng: mô hình vẫn chạy,
/// chỉ là bỏ qua các yếu tố thời tiết (không bao giờ bịa số liệu thay thế).
class WeatherHistoryService {
  static const _lat = 21.0285;
  static const _lon = 105.8542;
  static const _daily = 'temperature_2m_max,temperature_2m_min,precipitation_sum';

  /// Số ngày quá khứ tối đa mà API dự báo của Open-Meteo trả về.
  static const maxPastDays = 92;

  /// Ngày đã qua hoàn toàn thì không đổi nữa nên giữ lại trong phiên làm việc.
  static final Map<String, WeatherInput> _cache = {};

  static void clearCache() => _cache.clear();

  /// Đọc phản hồi `daily` của Open-Meteo thành bản đồ yyyy-MM-dd -> thời tiết.
  /// Ngày nào thiếu một trong ba số liệu thì bỏ qua, không điền số đoán.
  static Map<String, WeatherInput> parseDaily(Map<String, dynamic> data) {
    final out = <String, WeatherInput>{};
    try {
      final daily = data['daily'] as Map<String, dynamic>;
      final dates = (daily['time'] as List).cast<String>();
      final tmax = daily['temperature_2m_max'] as List;
      final tmin = daily['temperature_2m_min'] as List;
      final rain = daily['precipitation_sum'] as List;
      for (var i = 0; i < dates.length; i++) {
        final hi = (tmax[i] as num?)?.toDouble();
        final lo = (tmin[i] as num?)?.toDouble();
        final mm = (rain[i] as num?)?.toDouble();
        if (hi == null || lo == null || mm == null) continue;
        out[dates[i]] = WeatherInput(tempMax: hi, tempMin: lo, rainMm: mm);
      }
    } catch (_) {}
    return out;
  }

  /// Thời tiết thật từ ngày [from] đến [to] (gồm cả hai đầu, chỉ những ngày lấy được).
  static Future<Map<String, WeatherInput>> load(DateTime from, DateTime to, {DateTime? today}) async {
    final now = today ?? DateTime.now();
    final todayDay = DateTime(now.year, now.month, now.day);
    var a = DateTime(from.year, from.month, from.day);
    var b = DateTime(to.year, to.month, to.day);
    if (b.isAfter(todayDay)) b = todayDay; // tương lai không có "lịch sử"
    if (a.isAfter(b)) return {};

    bool need() {
      for (var d = a; !d.isAfter(b); d = DateTime(d.year, d.month, d.day + 1)) {
        if (!_cache.containsKey(VnCalendar.key(d))) return true;
      }
      return false;
    }

    if (need()) {
      final recentFrom = todayDay.subtract(const Duration(days: maxPastDays - 1));
      // 1) phần cũ hơn API dự báo: kho lưu trữ
      if (a.isBefore(recentFrom)) {
        final archiveTo = b.isBefore(recentFrom) ? b : recentFrom.subtract(const Duration(days: 1));
        await _fetchArchive(a, archiveTo, todayDay);
      }
      // 2) phần gần đây: API dự báo kèm past_days
      if (!b.isBefore(recentFrom)) {
        final start = a.isBefore(recentFrom) ? recentFrom : a;
        await _fetchRecent(start, b, todayDay);
      }
    }

    final out = <String, WeatherInput>{};
    for (var d = a; !d.isAfter(b); d = DateTime(d.year, d.month, d.day + 1)) {
      final k = VnCalendar.key(d);
      final w = _cache[k];
      if (w != null) out[k] = w;
    }
    return out;
  }

  static Future<void> _fetchArchive(DateTime a, DateTime b, DateTime today) async {
    try {
      final url = Uri.parse(
        'https://archive-api.open-meteo.com/v1/archive?latitude=$_lat&longitude=$_lon&timezone=Asia%2FBangkok'
        '&start_date=${VnCalendar.key(a)}&end_date=${VnCalendar.key(b)}&daily=$_daily',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) _store(parseDaily(json.decode(res.body) as Map<String, dynamic>), today);
    } catch (_) {}
  }

  static Future<void> _fetchRecent(DateTime a, DateTime b, DateTime today) async {
    try {
      final past = today.difference(a).inDays.clamp(0, maxPastDays);
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$_lat&longitude=$_lon&timezone=Asia%2FBangkok'
        '&daily=$_daily&past_days=$past&forecast_days=1',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) _store(parseDaily(json.decode(res.body) as Map<String, dynamic>), today);
    } catch (_) {}
  }

  static void _store(Map<String, WeatherInput> days, DateTime today) {
    final todayKey = VnCalendar.key(today);
    days.forEach((k, v) {
      if (k.compareTo(todayKey) < 0) _cache[k] = v; // hôm nay chưa hết ngày nên chưa chốt
    });
  }
}
