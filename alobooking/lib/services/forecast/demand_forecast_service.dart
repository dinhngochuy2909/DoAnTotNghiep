import 'dart:math';
import '../booking_slots.dart';
import '../firestore_service.dart' show BookingItem;
import '../weather/weather_service.dart' show DayRain;

/// Dự đoán nhu cầu đặt sân và tỉ lệ hủy theo khung giờ, ngày nghỉ/lễ và thời tiết.
///
/// Nguyên tắc: minh bạch, không giả vờ chính xác.
///  - Yếu tố HỌC TỪ DỮ LIỆU đặt sân thật: cách thanh toán, cuối tuần, buổi tối, đặt trước bao lâu
///    (hồi quy logistic có điều chuẩn L2), hệ số cuối tuần của nhu cầu, tỉ trọng theo buổi.
///  - Yếu tố GIẢ ĐỊNH chuyên môn (chưa có lịch sử để học): mưa, ngày lễ/Tết. Các hằng số nằm
///    ở [ForecastAssumptions] để dễ chỉnh khi có thêm dữ liệu.
///  - Luôn kèm độ tin cậy theo số đơn lịch sử.

// ───────────────────────── Lịch ngày nghỉ Việt Nam ─────────────────────────

class HolidayInfo {
  final String name;

  /// Nhân hệ số nhu cầu (>1 tăng, <1 giảm so với ngày thường cùng loại).
  final double demandFactor;

  /// Cộng thêm vào log-odds hủy (giả định).
  final double cancelLogit;

  /// Có phải ngày nghỉ làm việc không.
  final bool dayOff;
  const HolidayInfo(this.name, this.demandFactor, this.cancelLogit, this.dayOff);
}

class VnCalendar {
  // Mùng 1 Tết Nguyên Đán và ngày Giỗ Tổ Hùng Vương (10/3 âm lịch) theo dương lịch.
  // Danh sách này cần cập nhật hằng năm theo thông báo chính thức.
  static final Map<int, DateTime> _tet = {
    2026: DateTime(2026, 2, 17),
    2027: DateTime(2027, 2, 6),
  };
  static final Map<int, DateTime> _gioTo = {
    2026: DateTime(2026, 4, 26),
    2027: DateTime(2027, 4, 16),
  };

  static HolidayInfo? holidayOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);

    for (final t in _tet.values) {
      final diff = d.difference(t).inDays;
      if (diff >= -7 && diff <= -4) return const HolidayInfo('Cận Tết Nguyên Đán', 0.75, 0.2, false);
      if (diff >= -3 && diff <= -1) return const HolidayInfo('Giáp Tết (những ngày cuối năm âm lịch)', 0.5, 0.4, true);
      if (diff >= 0 && diff <= 3) return const HolidayInfo('Tết Nguyên Đán', 0.3, 0.5, true);
      if (diff >= 4 && diff <= 6) return const HolidayInfo('Sau Tết Nguyên Đán', 0.6, 0.3, true);
    }
    for (final g in _gioTo.values) {
      if (d == g) return const HolidayInfo('Giỗ Tổ Hùng Vương', 1.2, 0.0, true);
    }

    if (d.month == 1 && d.day == 1) return const HolidayInfo('Tết Dương lịch', 1.2, 0.0, true);
    if (d.month == 4 && d.day == 30) return const HolidayInfo('Giải phóng miền Nam (30/4)', 1.2, 0.0, true);
    if (d.month == 5 && d.day == 1) return const HolidayInfo('Quốc tế Lao động (1/5)', 1.2, 0.0, true);
    if (d.month == 9 && d.day == 2) return const HolidayInfo('Quốc khánh (2/9)', 1.2, 0.0, true);
    if (d.month == 11 && d.day == 20) return const HolidayInfo('Ngày Nhà giáo Việt Nam (20/11)', 1.1, 0.0, false);
    if (d.month == 12 && d.day == 24) return const HolidayInfo('Đêm Giáng sinh', 1.1, 0.0, false);
    return null;
  }

  static bool isWeekend(DateTime d) => d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  /// Ngày nghỉ làm: cuối tuần hoặc ngày lễ nghỉ.
  static bool isDayOff(DateTime d) => isWeekend(d) || (holidayOn(d)?.dayOff ?? false);

  static const dayNames = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
  static String dayName(DateTime d) => dayNames[d.weekday - 1];
  static String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ───────────────────────── Giả định chuyên môn (không học từ dữ liệu) ─────────────────────────

class ForecastAssumptions {
  /// Hệ số nhu cầu cuối tuần khi chưa đủ dữ liệu để học.
  static const double weekendDemandPrior = 1.3;

  /// Mưa làm giảm nhu cầu: nhân (1 - k × mức mưa). Sân ngoài trời nhạy hơn sân trong nhà.
  static const double rainDemandOutdoor = 0.5;
  static const double rainDemandIndoor = 0.15;
  static const double rainDemandUnknown = 0.3;

  /// Mưa làm tăng log-odds hủy (nhân với xác suất mưa).
  static const double rainCancelOutdoor = 0.8;
  static const double rainCancelIndoor = 0.3;
  static const double rainCancelUnknown = 0.5;

  /// Tỉ trọng nhu cầu theo buổi khi dữ liệu còn ít (sáng, chiều, tối).
  static const List<double> periodSharePrior = [0.2, 0.25, 0.55];

  static bool isOutdoor(String? sport) => sport == 'football' || sport == 'tennis';
  static bool isIndoorish(String? sport) => sport == 'badminton' || sport == 'pickleball';
}

// ───────────────────────── Mô hình ─────────────────────────

const _periods = [
  (name: 'Sáng (5h–11h)', from: 5, to: 11, evening: false),
  (name: 'Chiều (11h–17h)', from: 11, to: 17, evening: false),
  (name: 'Tối (17h–23h)', from: 17, to: 23, evening: true),
];

/// Một đơn đặt đã được rút đặc trưng.
class _Row {
  final bool cash, weekend, evening, longLead, cancelled;
  final DateTime date;
  final int startHour;
  _Row(this.cash, this.weekend, this.evening, this.longLead, this.cancelled, this.date, this.startHour);

  List<double> get x => [cash ? 1 : 0, weekend ? 1 : 0, evening ? 1 : 0, longLead ? 1 : 0];
}

class CvReport {
  final int n;
  final double brier; // càng thấp càng tốt
  final double brierBaseline; // luôn đoán bằng tỉ lệ hủy chung
  final double accuracy;
  final double auc;
  const CvReport(this.n, this.brier, this.brierBaseline, this.accuracy, this.auc);

  @override
  String toString() =>
      'CV n=$n | Brier ${brier.toStringAsFixed(3)} (cơ sở ${brierBaseline.toStringAsFixed(3)}) | '
      'độ chính xác ${(accuracy * 100).toStringAsFixed(0)}% | AUC ${auc.toStringAsFixed(2)}';
}

class PeriodForecast {
  final String name;
  final double? bookings;
  final double cancelRate;
  const PeriodForecast(this.name, this.bookings, this.cancelRate);
}

/// Số đơn của một ngày do mô hình đếm đơn (BookingCountModel) tính, dùng thay cho ước lượng nhân hệ số của [DemandModel]
/// để cả thẻ dự báo ở Admin lẫn chatbot cùng một con số.
class VolumeOverride {
  final double expected, low, high;

  /// So với một ngày điển hình trong lịch sử (1.0 = bình thường).
  final double multiplier;

  /// Các dòng giải thích yếu tố (đã ghi rõ học từ dữ liệu hay giả định).
  final List<String> factorLines;

  /// Độ tin cậy của riêng phần số đơn (ví dụ "THẤP (học từ 12 ngày…)").
  final String? confidence;
  const VolumeOverride({
    required this.expected,
    required this.low,
    required this.high,
    required this.multiplier,
    this.factorLines = const [],
    this.confidence,
  });
}

class DayForecast {
  final DateTime date;
  final HolidayInfo? holiday;
  final bool weekend;
  final DayRain? rain;
  final double demandMultiplier;
  final String level;
  final double? expectedBookings;
  final double? low, high;
  final double cancelRate;
  final double cancelRateCash;
  final double cancelRatePrepaid;
  final List<PeriodForecast> periods;
  final String confidence;
  final List<String> factors;
  const DayForecast({
    required this.date,
    required this.holiday,
    required this.weekend,
    required this.rain,
    required this.demandMultiplier,
    required this.level,
    required this.expectedBookings,
    required this.low,
    required this.high,
    required this.cancelRate,
    required this.cancelRateCash,
    required this.cancelRatePrepaid,
    required this.periods,
    required this.confidence,
    required this.factors,
  });

  static String _pct(double v) => '${(v * 100).round()}%';

  String get title => '${VnCalendar.dayName(date)} ${BookingSlots.formatDate(date)}';

  /// Một dòng tóm tắt (dùng cho bảng tổng quan nhiều ngày).
  String get oneLine {
    final vol = expectedBookings == null ? '' : ', ~${expectedBookings!.round()} đơn';
    final tag = holiday != null ? ' [${holiday!.name}]' : (weekend ? ' [cuối tuần]' : '');
    final r = rain == null ? '' : ', mưa ${rain!.prob.round()}%';
    return '$title$tag: nhu cầu $level$vol, hủy dự kiến ${_pct(cancelRate)}$r';
  }

  String toPromptText() {
    final b = StringBuffer();
    b.writeln('## DỰ ĐOÁN cho $title (mô hình thống kê, không phải số liệu thật của tương lai)');
    b.writeln('- Mức nhu cầu: **$level** (so với ngày thường = ${demandMultiplier.toStringAsFixed(2)}x)');
    if (expectedBookings != null) {
      b.writeln('- Số đơn đặt dự kiến toàn hệ thống: ~${expectedBookings!.round()} đơn (khoảng ${low!.round()}–${high!.round()} đơn)');
    }
    b.writeln('- Tỉ lệ hủy dự kiến: **${_pct(cancelRate)}** (mọi đơn đều chuyển khoản trước, ứng dụng không còn nhận tiền mặt)');
    if (expectedBookings != null) {
      b.writeln('- Số đơn có thể bị hủy: ~${(expectedBookings! * cancelRate).round()} đơn');
    }
    b.writeln('- Theo buổi:');
    for (final p in periods) {
      final vol = p.bookings == null ? '' : ', ~${p.bookings!.round()} đơn';
      b.writeln('  • ${p.name}$vol, hủy ${_pct(p.cancelRate)}');
    }
    b.writeln('- Các yếu tố đã xét:');
    for (final f in factors) {
      b.writeln('  • $f');
    }
    b.writeln('- Độ tin cậy: $confidence');
    return b.toString();
  }
}

class DemandModel {
  final List<_Row> _rows;
  final List<double> _w; // [bias, cash, weekend, evening, longLead]
  final double weekendMult;
  final bool weekendMultLearned;
  final double? baseWeekdayPerDay; // số đơn/ngày điển hình (ngày thường), null nếu thiếu dữ liệu
  final int daysObserved;
  final List<double> periodShare;

  DemandModel._(this._rows, this._w, this.weekendMult, this.weekendMultLearned, this.baseWeekdayPerDay,
      this.daysObserved, this.periodShare);

  int get n => _rows.length;
  int get cancelled => _rows.where((r) => r.cancelled).length;
  double get globalRate => n == 0 ? 0.12 : (cancelled + 1) / (n + 2);
  bool get hasEnoughForRates => n >= 20;
  bool get hasEnoughForVolume => n >= 8 && daysObserved >= 3;

  String get confidenceText {
    if (n < 20) return 'RẤT THẤP (chỉ có $n đơn lịch sử, phần lớn là giả định chuyên môn)';
    if (n < 150) return 'THẤP–TRUNG BÌNH (mô hình học từ $n đơn trong $daysObserved ngày; nên xem là ước lượng tham khảo)';
    return 'TRUNG BÌNH–KHÁ (học từ $n đơn trong $daysObserved ngày)';
  }

  // ── Huấn luyện ──

  static DemandModel fit(List<BookingItem> bookings, {double lambda = 2.0}) {
    final rows = _extract(bookings);
    final w = _logistic(rows, lambda: lambda);

    // Nhu cầu: số đơn theo ngày
    final perDay = <DateTime, int>{};
    for (final r in rows) {
      perDay[r.date] = (perDay[r.date] ?? 0) + 1;
    }
    final we = <int>[], wd = <int>[];
    perDay.forEach((d, c) => (VnCalendar.isDayOff(d) ? we : wd).add(c));
    double mean(List<int> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

    var mult = ForecastAssumptions.weekendDemandPrior;
    var learned = false;
    if (we.isNotEmpty && wd.isNotEmpty && mean(wd) > 0) {
      final k = min(we.length, wd.length).toDouble();
      final weight = k / (k + 6); // ít ngày quan sát -> nghiêng về giả định
      mult = (weight * (mean(we) / mean(wd)) + (1 - weight) * mult).clamp(0.8, 2.0).toDouble();
      learned = true;
    }
    double? base;
    if (rows.length >= 8 && perDay.length >= 3) {
      base = wd.isNotEmpty ? mean(wd) : (mean(we) / mult);
    }

    // Tỉ trọng theo buổi (làm mịn với giả định)
    final cnt = List<double>.filled(3, 0);
    for (final r in rows) {
      final i = r.startHour < 11 ? 0 : (r.startHour < 17 ? 1 : 2);
      cnt[i]++;
    }
    const pseudo = 10.0;
    final total = rows.length + pseudo;
    final share = [
      for (var i = 0; i < 3; i++) (cnt[i] + pseudo * ForecastAssumptions.periodSharePrior[i]) / total
    ];

    return DemandModel._(rows, w, mult, learned, base, perDay.length, share);
  }

  static List<_Row> _extract(List<BookingItem> bookings) {
    final rows = <_Row>[];
    for (final b in bookings) {
      final date = BookingSlots.parseDate(b.date);
      if (date == null) continue;
      final ranges = BookingSlots.parseRanges(b.time);
      final startH = ranges.isEmpty ? 18 : ranges.first.$1 ~/ 60;
      final pay = b.paymentMethod.toLowerCase();
      final lead = DateTime(date.year, date.month, date.day)
          .difference(DateTime(b.createdAt.year, b.createdAt.month, b.createdAt.day))
          .inDays;
      rows.add(_Row(
        pay.contains('tiền mặt') || pay.contains('tien mat') || pay.contains('cash'),
        VnCalendar.isDayOff(date),
        startH >= 17 && startH < 23,
        lead >= 2,
        BookingSlots.isCancelled(b.status),
        DateTime(date.year, date.month, date.day),
        startH,
      ));
    }
    return rows;
  }

  // ── Hồi quy logistic có điều chuẩn L2 (huấn luyện bằng gradient descent) ──

  static double _sigmoid(double z) => 1 / (1 + exp(-z));

  static List<double> _logistic(List<_Row> rows, {double lambda = 2.0, int iters = 1500, double lr = 0.5}) {
    const k = 4;
    final w = List<double>.filled(k + 1, 0);
    if (rows.isEmpty) {
      w[0] = log(0.12 / 0.88);
      return w;
    }
    final n = rows.length.toDouble();
    for (var it = 0; it < iters; it++) {
      final g = List<double>.filled(k + 1, 0);
      for (final r in rows) {
        final x = r.x;
        var z = w[0];
        for (var j = 0; j < k; j++) {
          z += w[j + 1] * x[j];
        }
        final err = _sigmoid(z) - (r.cancelled ? 1 : 0);
        g[0] += err;
        for (var j = 0; j < k; j++) {
          g[j + 1] += err * x[j];
        }
      }
      w[0] -= lr * g[0] / n;
      for (var j = 1; j <= k; j++) {
        w[j] -= lr * (g[j] / n + lambda * w[j] / n);
      }
    }
    return w;
  }

  double _predictRow(List<double> x, {double extraLogit = 0}) {
    var z = _w[0] + extraLogit;
    for (var j = 0; j < 4; j++) {
      z += _w[j + 1] * x[j];
    }
    return _sigmoid(z);
  }

  /// Tác động của từng yếu tố (tỉ số odds) để giải thích mô hình.
  Map<String, double> get oddsRatios => {
        'thanh toán tiền mặt tại sân': exp(_w[1]),
        'cuối tuần/ngày nghỉ': exp(_w[2]),
        'khung giờ tối': exp(_w[3]),
        'đặt trước từ 2 ngày': exp(_w[4]),
      };

  /// Kiểm định chéo k-fold: so với việc luôn đoán bằng tỉ lệ hủy chung.
  static CvReport crossValidate(List<BookingItem> bookings, {int folds = 10, double lambda = 2.0}) {
    final all = _extract(bookings);
    final preds = <double>[];
    final ys = <int>[];
    var bBase = 0.0;
    for (var f = 0; f < folds; f++) {
      final train = <_Row>[], test = <_Row>[];
      for (var i = 0; i < all.length; i++) {
        (i % folds == f ? test : train).add(all[i]);
      }
      if (test.isEmpty || train.isEmpty) continue;
      final w = _logistic(train, lambda: lambda);
      final base = (train.where((r) => r.cancelled).length + 1) / (train.length + 2);
      for (final r in test) {
        var z = w[0];
        final x = r.x;
        for (var j = 0; j < 4; j++) {
          z += w[j + 1] * x[j];
        }
        final p = _sigmoid(z);
        final y = r.cancelled ? 1 : 0;
        preds.add(p);
        ys.add(y);
        bBase += pow(base - y, 2).toDouble();
      }
    }
    final m = preds.length;
    if (m == 0) return const CvReport(0, 0, 0, 0, 0.5);
    var brier = 0.0, correct = 0;
    for (var i = 0; i < m; i++) {
      brier += pow(preds[i] - ys[i], 2).toDouble();
      if ((preds[i] >= 0.5 ? 1 : 0) == ys[i]) correct++;
    }
    // AUC: xác suất một đơn hủy được chấm điểm cao hơn một đơn không hủy
    double pos = 0, tot = 0;
    for (var i = 0; i < m; i++) {
      if (ys[i] != 1) continue;
      for (var j = 0; j < m; j++) {
        if (ys[j] != 0) continue;
        tot++;
        if (preds[i] > preds[j]) {
          pos++;
        } else if (preds[i] == preds[j]) {
          pos += 0.5;
        }
      }
    }
    return CvReport(m, brier / m, bBase / m, correct / m, tot == 0 ? 0.5 : pos / tot);
  }

  // ── Dự đoán ──

  double _weatherCancelLogit(DayRain? r, String? sport) {
    if (r == null) return 0;
    var sev = r.prob / 100;
    if (r.mm >= 10) sev = max(sev, 0.9);
    final k = ForecastAssumptions.isOutdoor(sport)
        ? ForecastAssumptions.rainCancelOutdoor
        : ForecastAssumptions.isIndoorish(sport)
            ? ForecastAssumptions.rainCancelIndoor
            : ForecastAssumptions.rainCancelUnknown;
    return k * sev;
  }

  double _weatherDemandFactor(DayRain? r, String? sport) {
    if (r == null) return 1;
    var sev = r.prob / 100;
    if (r.mm >= 10) sev = max(sev, 0.9);
    final k = ForecastAssumptions.isOutdoor(sport)
        ? ForecastAssumptions.rainDemandOutdoor
        : ForecastAssumptions.isIndoorish(sport)
            ? ForecastAssumptions.rainDemandIndoor
            : ForecastAssumptions.rainDemandUnknown;
    return 1 - k * sev;
  }

  /// Tỉ lệ hủy kỳ vọng: lấy cơ cấu thanh toán + thời gian đặt trước THẬT trong lịch sử,
  /// đặt lại cờ cuối tuần/buổi tối theo ngày cần dự đoán.
  double _expectedCancel({
    required bool offDay,
    required bool evening,
    required double extraLogit,
    bool? onlyCash,
  }) {
    if (_rows.isEmpty) {
      return _sigmoid(log(0.12 / 0.88) + extraLogit);
    }
    var sum = 0.0;
    var cnt = 0;
    for (final r in _rows) {
      if (onlyCash != null && r.cash != onlyCash) continue;
      sum += _predictRow([r.cash ? 1 : 0, offDay ? 1 : 0, evening ? 1 : 0, r.longLead ? 1 : 0], extraLogit: extraLogit);
      cnt++;
    }
    if (cnt == 0) {
      // không có mẫu thuộc nhóm này: dùng đặc trưng điển hình
      return _predictRow([onlyCash == true ? 1 : 0, offDay ? 1 : 0, evening ? 1 : 0, 0], extraLogit: extraLogit);
    }
    return sum / cnt;
  }

  /// [volume]: số đơn đã tính bằng mô hình đếm đơn; có thì thay cho ước lượng nhu cầu nhân hệ số bên dưới
  /// (phần tỉ lệ hủy vẫn do mô hình này tính).
  DayForecast forecastDay(DateTime day, {DayRain? rain, String? sport, VolumeOverride? volume}) {
    final date = DateTime(day.year, day.month, day.day);
    final holiday = VnCalendar.holidayOn(date);
    final weekend = VnCalendar.isWeekend(date);
    final offDay = VnCalendar.isDayOff(date);
    final demandFactors = <String>[];
    final factors = <String>[];

    // ── Nhu cầu ──
    var dayMult = 1.0;
    if (offDay && (holiday == null || holiday.demandFactor >= 1)) {
      dayMult *= weekendMult;
      demandFactors.add(
          '${weekend ? 'Cuối tuần' : 'Ngày nghỉ lễ'}: nhu cầu x${weekendMult.toStringAsFixed(2)} '
          '[${weekendMultLearned ? 'học từ dữ liệu, kết hợp giả định' : 'giả định chuyên môn'}]');
    }
    if (holiday != null) {
      if (holiday.demandFactor < 1) {
        dayMult *= holiday.demandFactor;
        demandFactors.add('${holiday.name}: nhu cầu x${holiday.demandFactor.toStringAsFixed(2)} [giả định, người dân nghỉ Tết/du lịch]');
      } else if (!holiday.dayOff) {
        dayMult *= holiday.demandFactor;
        demandFactors.add('${holiday.name}: phong trào tăng nhẹ x${holiday.demandFactor.toStringAsFixed(2)} [giả định]');
      } else if (!weekend) {
        dayMult *= 1.05;
        demandFactors.add('${holiday.name} (nghỉ lễ): thêm x1.05 [giả định]');
      }
    }
    final wFactor = _weatherDemandFactor(rain, sport);
    if (rain != null) {
      demandFactors.add('Dự báo mưa ${rain.prob.round()}% (${rain.mm.toStringAsFixed(1)} mm): nhu cầu x${wFactor.toStringAsFixed(2)} '
          '[giả định${ForecastAssumptions.isOutdoor(sport) ? ', sân ngoài trời nhạy hơn' : ''}]');
    } else {
      demandFactors.add('Chưa có dự báo thời tiết cho ngày này (quá 7 ngày hoặc lỗi mạng): không điều chỉnh theo mưa');
    }
    factors.addAll(volume != null ? volume.factorLines : demandFactors);
    final mult = volume?.multiplier ?? dayMult * wFactor;

    String level;
    if (mult >= 1.4) {
      level = 'RẤT CAO';
    } else if (mult >= 1.1) {
      level = 'CAO';
    } else if (mult >= 0.85) {
      level = 'BÌNH THƯỜNG';
    } else if (mult >= 0.6) {
      level = 'THẤP';
    } else {
      level = 'RẤT THẤP';
    }

    double? total, lo, hi;
    if (volume != null) {
      total = volume.expected;
      lo = volume.low;
      hi = volume.high;
    } else if (hasEnoughForVolume && baseWeekdayPerDay != null) {
      total = baseWeekdayPerDay! * mult;
      final sd = sqrt(total);
      lo = max(0, total - 1.28 * sd);
      hi = total + 1.28 * sd;
    }

    // ── Hủy ──
    final extra = _weatherCancelLogit(rain, sport) + (holiday?.cancelLogit ?? 0);
    if (hasEnoughForRates) {
      final o = oddsRatios;
      final cashOdds = o['thanh toán tiền mặt tại sân']!;
      if (cashOdds > 1.2) {
        factors.add('Mọi đơn mới đều chuyển khoản trước (không còn tiền mặt): dự báo dùng nhóm trả trước; '
            'trong lịch sử, đơn tiền mặt từng có odds hủy x${cashOdds.toStringAsFixed(1)} [học từ dữ liệu]');
      } else {
        factors.add('Mọi đơn mới đều chuyển khoản trước: dự báo dùng nhóm trả trước');
      }
      if (_eveningMatters(o)) {
        factors.add('Khung giờ tối: odds hủy x${o['khung giờ tối']!.toStringAsFixed(2)} [học từ dữ liệu, tác động nhỏ/chưa chắc]');
      }
      if (offDay) {
        factors.add('Cuối tuần/ngày nghỉ: odds hủy x${o['cuối tuần/ngày nghỉ']!.toStringAsFixed(2)} [học từ dữ liệu, tác động nhỏ/chưa chắc]');
      }
    } else {
      factors.add('Chưa đủ đơn lịch sử (<20) để học tỉ lệ hủy: dùng tỉ lệ nền ${(globalRate * 100).round()}%');
    }
    if (extra > 0) {
      factors.add('Mưa/ngày lễ làm tăng khả năng hủy (+${(extra).toStringAsFixed(2)} log-odds) [giả định]');
    }

    double rateFor(bool ev, {bool? cash}) =>
        _expectedCancel(offDay: offDay, evening: ev, extraLogit: extra, onlyCash: cash);

    // Từ nay ứng dụng chỉ nhận chuyển khoản nên mọi đơn tương lai thuộc nhóm trả trước:
    // dự báo dùng đặc trưng "trả trước" thay vì cơ cấu thanh toán cũ trong lịch sử.
    // Nếu lịch sử không có đơn trả trước nào thì rateFor tự dùng đặc trưng điển hình.
    final periodRates = [for (final p in _periods) rateFor(p.evening, cash: false)];
    var dayRate = 0.0;
    for (var i = 0; i < 3; i++) {
      dayRate += periodShare[i] * periodRates[i];
    }
    final cashRate = [for (var i = 0; i < 3; i++) periodShare[i] * rateFor(_periods[i].evening, cash: true)]
        .reduce((a, b) => a + b);
    final prepaidRate = [for (var i = 0; i < 3; i++) periodShare[i] * rateFor(_periods[i].evening, cash: false)]
        .reduce((a, b) => a + b);

    final periods = [
      for (var i = 0; i < 3; i++)
        PeriodForecast(_periods[i].name, total == null ? null : total * periodShare[i], periodRates[i]),
    ];

    return DayForecast(
      date: date,
      holiday: holiday,
      weekend: weekend,
      rain: rain,
      demandMultiplier: mult,
      level: level,
      expectedBookings: total,
      low: lo,
      high: hi,
      cancelRate: dayRate,
      cancelRateCash: cashRate,
      cancelRatePrepaid: prepaidRate,
      periods: periods,
      confidence: volume?.confidence == null ? confidenceText : 'số đơn: ${volume!.confidence}; tỉ lệ hủy: $confidenceText',
      factors: factors,
    );
  }

  bool _eveningMatters(Map<String, double> o) => (o['khung giờ tối']! - 1).abs() >= 0.05;

  /// Dự đoán một đơn cụ thể: xác suất khách sẽ hủy.
  double cancelProbabilityForBooking({
    required DateTime date,
    required int startHour,
    required bool cash,
    required int leadDays,
    DayRain? rain,
    String? sport,
  }) {
    final h = VnCalendar.holidayOn(date);
    final extra = _weatherCancelLogit(rain, sport) + (h?.cancelLogit ?? 0);
    return _predictRow(
      [cash ? 1 : 0, VnCalendar.isDayOff(date) ? 1 : 0, startHour >= 17 && startHour < 23 ? 1 : 0, leadDays >= 2 ? 1 : 0],
      extraLogit: extra,
    );
  }
}

class DemandForecastService {
  /// Dựng văn bản dự đoán cho RAG: ngày được hỏi (chi tiết) + tổng quan 7 ngày tới.
  ///
  /// [volumeFor]: nếu có, số đơn từng ngày lấy từ mô hình đếm đơn (thời tiết, thứ, mùa, lễ) thay cho ước lượng cũ;
  /// [volumeNote] là câu nói rõ độ tin cậy của mô hình đó, được đưa vào lưu ý cuối.
  static String buildPromptSection(
    List<BookingItem> bookings,
    DateTime target, {
    Map<String, DayRain> rainByDate = const {},
    String? sport,
    DateTime? today,
    VolumeOverride? Function(DateTime date)? volumeFor,
    String? volumeNote,
  }) {
    final model = DemandModel.fit(bookings);
    final now = today ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final b = StringBuffer();

    final detail = model.forecastDay(target, rain: rainByDate[VnCalendar.key(target)], sport: sport, volume: volumeFor?.call(target));
    b.writeln(detail.toPromptText());

    b.writeln('## TỔNG QUAN 7 NGÀY TỚI');
    for (var i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      b.writeln('- ${model.forecastDay(d, rain: rainByDate[VnCalendar.key(d)], sport: sport, volume: volumeFor?.call(d)).oneLine}');
    }
    b.writeln();
    if (volumeNote != null) {
      b.writeln('LƯU Ý KHI TRẢ LỜI: số đơn dự kiến lấy từ mô hình hồi quy Poisson theo thứ trong tuần, ngày lễ/Tết, mùa, mưa và nhiệt độ. $volumeNote '
          'Tỉ lệ hủy lấy từ mô hình riêng học trên ${model.n} đơn lịch sử. '
          'Phải nói rõ là "dự đoán/ước tính", nêu độ tin cậy, nêu yếu tố chính, và không hứa chắc chắn. '
          'Ứng dụng chỉ nhận chuyển khoản trước nên không gợi ý tiền mặt.');
    } else {
      b.writeln('LƯU Ý KHI TRẢ LỜI: đây là ước lượng thống kê dựa trên ${model.n} đơn lịch sử + giả định chuyên môn về mưa/ngày lễ. '
          'Phải nói rõ là "dự đoán/ước tính", nêu độ tin cậy, nêu yếu tố chính (đặc biệt cách thanh toán nếu hỏi về hủy), '
          'và không hứa chắc chắn. Ứng dụng chỉ nhận chuyển khoản trước nên không gợi ý tiền mặt.');
    }
    return b.toString();
  }
}
