import 'dart:math';

import '../booking_slots.dart';
import 'demand_forecast_service.dart' show VnCalendar;
import '../firestore_service.dart' show BookingItem;
import '../weather/weather_service.dart' show DayWeather;

/// Dự đoán SỐ ĐƠN ĐẶT SÂN mỗi ngày theo thứ trong tuần, ngày lễ/Tết, mùa, mưa và nhiệt độ.
///
/// Mô hình: hồi quy Poisson (số đơn là số đếm không âm) với log liên kết:
///   log(số đơn kỳ vọng) = nền + Σ hệ số × yếu tố
/// Huấn luyện bằng IRLS (Newton–Raphson) có điều chuẩn L2 KÉO VỀ GIÁ TRỊ CHUYÊN MÔN (prior):
/// mỗi hệ số khởi đầu bằng mức giả định hợp lý và chỉ rời khỏi mức đó khi dữ liệu thật đủ nhiều và có biến thiên.
/// Nhờ vậy ít dữ liệu thì mô hình không "học bậy", nhiều dữ liệu thì dữ liệu quyết định.
///
/// Trung thực về chất lượng:
///  - Mỗi yếu tố ghi rõ bao nhiêu phần trăm bằng chứng đến từ dữ liệu (còn lại là giả định).
///  - Kiểm định chéo "bỏ một ngày" so với 2 đường cơ sở (luôn đoán trung bình; chỉ dùng giả định).
///  - Khoảng dự đoán 80% có tính phân tán quá mức (overdispersion).

/// Thời tiết một ngày dùng làm đầu vào cho mô hình (cả lịch sử lẫn dự báo, cùng định nghĩa).
class WeatherInput {
  final double tempMax;
  final double tempMin;
  final double rainMm;

  /// Khả năng mưa (%) nếu có (chỉ có ở dự báo), chỉ dùng để hiển thị.
  final double? rainProb;

  const WeatherInput({required this.tempMax, required this.tempMin, required this.rainMm, this.rainProb});

  /// Từ dự báo một ngày của [WeatherService].
  factory WeatherInput.fromDay(DayWeather d) =>
      WeatherInput(tempMax: d.tempMax, tempMin: d.tempMin, rainMm: d.rainMm, rainProb: d.rainProb.toDouble());

  double get tempMean => (tempMax + tempMin) / 2;

  /// Mức mưa 0..1: 10 mm trở lên là mưa rất to. Dùng lượng mưa (có cả trong lịch sử lẫn dự báo) để hai bên cùng thước đo.
  double get rainIndex => (rainMm / 10).clamp(0.0, 1.0).toDouble();

  /// Nắng nóng: số "bậc 4°C" vượt quá 32°C của nhiệt độ cao nhất.
  double get heat => max(0, tempMax - 32) / 4;

  /// Lạnh: số "bậc 4°C" dưới 18°C của nhiệt độ thấp nhất.
  double get cold => max(0, 18 - tempMin) / 4;
}

/// Bốn mùa ở Hà Nội (giả định theo khí hậu): xuân 2–4, hạ 5–8, thu 9–11, đông 12–1.
enum Season { spring, summer, autumn, winter }

class Seasons {
  static Season of(DateTime d) {
    final m = d.month;
    if (m >= 2 && m <= 4) return Season.spring;
    if (m >= 5 && m <= 8) return Season.summer;
    if (m >= 9 && m <= 11) return Season.autumn;
    return Season.winter;
  }

  static String label(Season s) => const {
        Season.spring: 'Mùa xuân',
        Season.summer: 'Mùa hè',
        Season.autumn: 'Mùa thu',
        Season.winter: 'Mùa đông',
      }[s]!;
}

/// Một ngày đã quan sát: số đơn đặt cho ngày chơi đó và thời tiết thật của ngày đó (nếu lấy được).
class DayObs {
  final DateTime date;
  final int count;
  final WeatherInput? weather;
  const DayObs(this.date, this.count, [this.weather]);
}

class _Ctx {
  final DateTime date;
  final WeatherInput? weather;
  final HolidayKind holiday;

  /// Cường độ dịp Tết 0..1 (1 = mùng 1–4 Tết; cận Tết nhẹ hơn), theo lịch ngày nghỉ [VnCalendar].
  final double tetIntensity;
  _Ctx(this.date, this.weather)
      : holiday = _holidayKind(date),
        tetIntensity = _tetIntensity(date);
}

enum HolidayKind { none, off, tet }

HolidayKind _holidayKind(DateTime d) {
  final h = VnCalendar.holidayOn(d);
  if (h == null) return HolidayKind.none;
  if (h.demandFactor < 1) return HolidayKind.tet; // Tết: người dân nghỉ, đi xa
  if (h.dayOff) return HolidayKind.off; // lễ nghỉ làm
  return HolidayKind.none; // ngày kỷ niệm không nghỉ (20/11, 24/12): bỏ qua
}

/// Mức "đậm" của dịp Tết: log(hệ số nhu cầu của lịch) / log(hệ số mùng 1 Tết), nên cận Tết nhẹ, mùng 1–4 là 1.
double _tetIntensity(DateTime d) {
  final h = VnCalendar.holidayOn(d);
  if (h == null || h.demandFactor >= 1) return 0;
  return (log(h.demandFactor) / log(_tetDemandFactor)).clamp(0.0, 1.0).toDouble();
}

/// Hệ số nhu cầu của mùng 1–4 Tết trong lịch (giả định chuyên môn của [VnCalendar]).
const double _tetDemandFactor = 0.3;

class _Feature {
  final String key;
  final String label;

  /// Hệ số (log) giả định chuyên môn khi chưa có dữ liệu.
  final double prior;

  /// Độ lệch chuẩn của giả định: càng nhỏ càng "cứng", dữ liệu càng khó kéo đi.
  final double sigma;
  final double Function(_Ctx) value;
  const _Feature(this.key, this.label, this.prior, this.sigma, this.value);
}

double _wd(_Ctx c, int weekday) => c.date.weekday == weekday ? 1 : 0;

final List<_Feature> _features = [
  _Feature('sat', 'Thứ Bảy', 0.22, 0.35, (c) => _wd(c, DateTime.saturday)),
  _Feature('sun', 'Chủ Nhật', 0.26, 0.35, (c) => _wd(c, DateTime.sunday)),
  _Feature('fri', 'Thứ Sáu', 0.08, 0.35, (c) => _wd(c, DateTime.friday)),
  _Feature('holiday', 'Ngày lễ nghỉ', 0.15, 0.35, (c) => c.holiday == HolidayKind.off ? 1 : 0),
  // giả định: mùng 1–4 Tết còn ~30% nhu cầu (ln 0.3 ≈ -1.2); cận Tết/sau Tết nhẹ hơn theo cường độ
  _Feature('tet', 'Dịp Tết', -1.2, 0.5, (c) => c.tetIntensity),
  _Feature('rain', 'Mưa', -0.35, 0.35, (c) => c.weather?.rainIndex ?? 0),
  _Feature('heat', 'Nắng nóng', -0.12, 0.3, (c) => c.weather?.heat ?? 0),
  _Feature('cold', 'Trời lạnh', -0.15, 0.3, (c) => c.weather?.cold ?? 0),
  _Feature('summer', 'Mùa hè', -0.05, 0.3, (c) => Seasons.of(c.date) == Season.summer ? 1 : 0),
  _Feature('autumn', 'Mùa thu', 0.08, 0.3, (c) => Seasons.of(c.date) == Season.autumn ? 1 : 0),
  _Feature('winter', 'Mùa đông', -0.1, 0.3, (c) => Seasons.of(c.date) == Season.winter ? 1 : 0),
];

/// Một hệ số (log) của mô hình: [prior] là giả định chuyên môn ban đầu, [learned] là giá trị sau khi học,
/// [dataShare] là tỉ lệ bằng chứng đến từ dữ liệu (0 = hoàn toàn giả định).
class CoefficientInfo {
  final String key;
  final String label;
  final double prior;
  final double learned;
  final double dataShare;
  const CoefficientInfo(this.key, this.label, this.prior, this.learned, this.dataShare);
}

/// Nguồn gốc của một yếu tố trong dự đoán.
enum FactorSource { assumption, mixed, data }

/// Tác động của một yếu tố lên số đơn của một ngày.
class CountFactor {
  final String key;
  final String label;
  final String detail;

  /// Nhân lên số đơn: 1.25 = nhiều hơn 25% so với ngày bình thường.
  final double multiplier;

  /// Tỉ lệ bằng chứng đến từ dữ liệu (0..1), phần còn lại là giả định chuyên môn.
  final double dataShare;

  const CountFactor(this.key, this.label, this.detail, this.multiplier, this.dataShare);

  FactorSource get source => dataShare >= 0.6 ? FactorSource.data : (dataShare >= 0.2 ? FactorSource.mixed : FactorSource.assumption);

  String get sourceText => switch (source) {
        FactorSource.data => 'học từ dữ liệu ${(dataShare * 100).round()}%',
        FactorSource.mixed => 'dữ liệu ${(dataShare * 100).round()}% + giả định',
        FactorSource.assumption => 'giả định chuyên môn',
      };

  /// Một dòng giải thích: "Thứ Bảy: ×1.25 (học từ dữ liệu 62%)".
  String get line => '$label${detail.isEmpty ? '' : ' ($detail)'}: ×${multiplier.toStringAsFixed(2)} [$sourceText]';
}

/// Số đơn dự đoán cho một ngày.
class CountForecast {
  final DateTime date;
  final double expected;
  final double low;
  final double high;

  /// Số đơn của một ngày "bình thường" cùng mùa (thứ hai–thứ năm, không lễ, thời tiết dễ chịu).
  final double baseline;
  final List<CountFactor> factors;
  final bool weatherMissing;
  final Season season;

  const CountForecast({
    required this.date,
    required this.expected,
    required this.low,
    required this.high,
    required this.baseline,
    required this.factors,
    required this.weatherMissing,
    required this.season,
  });

  double get multiplier => baseline <= 0 ? 1 : expected / baseline;

  String get rangeText => '${low.round()}–${high.round()}';
}

/// Kết quả kiểm định chéo "bỏ một ngày".
class CountCv {
  final int days;

  /// Sai số tuyệt đối trung bình (đơn/ngày) của mô hình, của đường cơ sở "luôn đoán trung bình"
  /// và của đường cơ sở "chỉ dùng giả định chuyên môn".
  final double mae;
  final double maeMean;
  final double maePrior;
  final double rmse;

  /// Tỉ lệ ngày thật nằm trong khoảng dự đoán 80% (lý tưởng ~80%).
  final double coverage;

  const CountCv({
    required this.days,
    required this.mae,
    required this.maeMean,
    required this.maePrior,
    required this.rmse,
    required this.coverage,
  });

  /// Mô hình tốt hơn đường cơ sở "luôn đoán trung bình" bao nhiêu (0.2 = giảm 20% sai số). Âm nghĩa là tệ hơn.
  double get improvementOverMean => maeMean <= 0 ? 0 : 1 - mae / maeMean;
  double get improvementOverPrior => maePrior <= 0 ? 0 : 1 - mae / maePrior;
  bool get beatsMean => mae < maeMean;

  @override
  String toString() => 'CV $days ngày | MAE ${mae.toStringAsFixed(2)} (trung bình ${maeMean.toStringAsFixed(2)}, '
      'giả định ${maePrior.toStringAsFixed(2)}) | RMSE ${rmse.toStringAsFixed(2)} | phủ 80%: ${(coverage * 100).round()}%';
}

class BookingCountModel {
  final List<DayObs> _obs;
  final double _b0;
  final List<double> _beta;
  final List<double> _shares;
  final double phi;
  final bool hasData;

  BookingCountModel._(this._obs, this._b0, this._beta, this._shares, this.phi, this.hasData);

  int get days => _obs.length;
  double get meanPerDay => _obs.isEmpty ? 0 : _obs.fold<int>(0, (s, o) => s + o.count) / _obs.length;
  int get weatherDays => _obs.where((o) => o.weather != null).length;

  /// Hệ số (log) đã học của từng yếu tố, theo khóa.
  Map<String, double> get coefficients => {for (var j = 0; j < _features.length; j++) _features[j].key: _beta[j]};

  /// Tỉ lệ bằng chứng đến từ dữ liệu của từng yếu tố (0 = hoàn toàn giả định), theo khóa.
  Map<String, double> get dataShares => {for (var j = 0; j < _features.length; j++) _features[j].key: _shares[j]};

  /// Mức nền (đơn/ngày) ở mốc tham chiếu: thứ hai–thứ năm, mùa xuân, không lễ, thời tiết dễ chịu.
  double get intercept => exp(_b0);

  /// Bảng hệ số để hiển thị/đối chiếu: giả định ban đầu, giá trị đã học, và tỉ lệ bằng chứng từ dữ liệu.
  List<CoefficientInfo> get coefficientInfo => [
        for (var j = 0; j < _features.length; j++)
          CoefficientInfo(_features[j].key, _features[j].label, _features[j].prior, _beta[j], _shares[j]),
      ];

  String get confidenceText {
    if (days < 10) return 'RẤT THẤP (chỉ có $days ngày dữ liệu, kết quả chủ yếu theo giả định chuyên môn)';
    if (days < 30) return 'THẤP (học từ $days ngày; xem là ước lượng tham khảo)';
    if (days < 90) return 'TRUNG BÌNH (học từ $days ngày)';
    return 'KHÁ (học từ $days ngày)';
  }

  // ───────────────────────── Dữ liệu huấn luyện ─────────────────────────

  /// Gom đơn đặt thành số đơn theo NGÀY CHƠI.
  ///
  /// Chỉ tính những ngày thuộc "giai đoạn hệ thống có hoạt động": các ngày liên tiếp có đơn, cho phép
  /// khoảng trống tối đa [gapDays] ngày (ngày trong khoảng đó không có đơn được tính là 0 đơn).
  /// Khoảng trống dài hơn coi là hệ thống không dùng (không phải khách không muốn đặt) nên bị bỏ qua,
  /// tránh dạy mô hình rằng nhu cầu bằng 0. Ngày hôm nay trở về sau cũng bị bỏ vì đơn còn đang đến.
  ///
  /// Mặc định KHÔNG tính đơn đã hủy: cái cần dự đoán là số sân thực sự được giữ (ảnh hưởng doanh thu),
  /// nên tác động của mưa lên việc hủy sân đã nằm sẵn trong con số. Đặt [countCancelled] để đếm cả đơn hủy (tổng nhu cầu ban đầu).
  static List<DayObs> observationsFromBookings(
    List<BookingItem> bookings,
    Map<String, WeatherInput> weatherByDate, {
    DateTime? today,
    int gapDays = 3,
    bool countCancelled = false,
  }) {
    final now = today ?? DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final perDay = <DateTime, int>{};
    for (final b in bookings) {
      if (!countCancelled && BookingSlots.isCancelled(b.status)) continue;
      final d = BookingSlots.parseDate(b.date);
      if (d == null) continue;
      final day = DateTime(d.year, d.month, d.day);
      if (!day.isBefore(end)) continue;
      perDay[day] = (perDay[day] ?? 0) + 1;
    }
    if (perDay.isEmpty) return const [];

    final dates = perDay.keys.toList()..sort();
    final out = <DayObs>[];
    var runStart = dates.first;
    var prev = dates.first;
    void closeRun(DateTime from, DateTime to) {
      for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
        out.add(DayObs(d, perDay[d] ?? 0, weatherByDate[VnCalendar.key(d)]));
      }
    }

    for (final d in dates.skip(1)) {
      if (d.difference(prev).inDays > gapDays) {
        closeRun(runStart, prev);
        runStart = d;
      }
      prev = d;
    }
    closeRun(runStart, prev);
    return out;
  }

  // ───────────────────────── Huấn luyện ─────────────────────────

  static BookingCountModel fit(List<DayObs> obs, {double priorScale = 1.0}) {
    final p = _features.length;
    final prior = [for (final f in _features) f.prior];
    final lambda = [for (final f in _features) priorScale / (f.sigma * f.sigma)];

    if (obs.isEmpty) {
      return BookingCountModel._(const [], log(4), List<double>.of(prior), List<double>.filled(p, 0), 1.5, false);
    }

    final xs = [for (final o in obs) _row(_Ctx(o.date, o.weather))];
    final ys = [for (final o in obs) o.count.toDouble()];
    final theta = _irls(xs, ys, prior, lambda);
    final b0 = theta[0];
    final beta = theta.sublist(1);

    // Mỗi yếu tố: bằng chứng từ dữ liệu so với giả định, tính trên phần biến thiên độc lập với mức nền.
    final mu = [for (final x in xs) exp(_eta(b0, beta, x))];
    final sw = mu.fold<double>(0, (s, m) => s + m);
    final shares = List<double>.filled(p, 0);
    for (var j = 0; j < p; j++) {
      var nPos = 0;
      var mean = 0.0;
      for (var i = 0; i < xs.length; i++) {
        if (xs[i][j].abs() > 1e-9) nPos++;
        mean += mu[i] * xs[i][j];
      }
      mean /= sw;
      final nZero = xs.length - nPos;
      if (nPos < 2 || nZero < 2) continue; // yếu tố gần như không đổi trong dữ liệu: không học được gì
      var info = 0.0;
      for (var i = 0; i < xs.length; i++) {
        info += mu[i] * pow(xs[i][j] - mean, 2);
      }
      shares[j] = info / (info + lambda[j]);
    }

    // Phân tán quá mức (overdispersion) theo Pearson, để khoảng dự đoán không quá hẹp.
    var chi2 = 0.0;
    for (var i = 0; i < xs.length; i++) {
      chi2 += pow(ys[i] - mu[i], 2) / max(mu[i], 1e-6);
    }
    final pEff = 1 + shares.fold<double>(0, (s, v) => s + v);
    var phi = (chi2 / max(1, xs.length - pEff)).clamp(1.0, 5.0).toDouble();
    if (xs.length < 8) phi = max(phi, 1.5);

    return BookingCountModel._(List<DayObs>.of(obs), b0, beta, shares, phi, true);
  }

  static List<double> _row(_Ctx c) => [for (final f in _features) f.value(c)];

  static double _eta(double b0, List<double> beta, List<double> x) {
    var z = b0;
    for (var j = 0; j < beta.length; j++) {
      z += beta[j] * x[j];
    }
    return z.clamp(-8.0, 8.0).toDouble();
  }

  /// IRLS cho hồi quy Poisson với điều chuẩn L2 kéo về [prior]. theta = [nền, hệ số...]; nền không bị phạt.
  static List<double> _irls(List<List<double>> xs, List<double> ys, List<double> prior, List<double> lambda,
      {int iters = 80}) {
    final p = prior.length;
    final n = xs.length;
    final meanY = ys.fold<double>(0, (s, v) => s + v) / n;
    final theta = <double>[log(max(0.2, meanY)), ...prior];

    for (var it = 0; it < iters; it++) {
      final g = List<double>.filled(p + 1, 0);
      final h = List.generate(p + 1, (_) => List<double>.filled(p + 1, 0));
      for (var i = 0; i < n; i++) {
        final x = xs[i];
        var z = theta[0];
        for (var j = 0; j < p; j++) {
          z += theta[j + 1] * x[j];
        }
        final m = exp(z.clamp(-8.0, 8.0));
        final r = ys[i] - m;
        g[0] += r;
        h[0][0] += m;
        for (var j = 0; j < p; j++) {
          final xj = x[j];
          if (xj == 0) continue;
          g[j + 1] += r * xj;
          h[0][j + 1] += m * xj;
          h[j + 1][0] += m * xj;
          for (var k = 0; k < p; k++) {
            final xk = x[k];
            if (xk == 0) continue;
            h[j + 1][k + 1] += m * xj * xk;
          }
        }
      }
      for (var j = 0; j < p; j++) {
        g[j + 1] -= lambda[j] * (theta[j + 1] - prior[j]);
        h[j + 1][j + 1] += lambda[j];
      }
      final delta = _solve(h, g);
      var big = 0.0;
      for (final d in delta) {
        big = max(big, d.abs());
      }
      final scale = big > 1.5 ? 1.5 / big : 1.0; // bước quá lớn thì thu nhỏ để ổn định
      for (var j = 0; j <= p; j++) {
        theta[j] += scale * delta[j];
      }
      if (big < 1e-9) break;
    }
    return theta;
  }

  /// Giải hệ A·x = b bằng khử Gauss có chọn trụ.
  static List<double> _solve(List<List<double>> a, List<double> b) {
    final n = b.length;
    final m = [for (var i = 0; i < n; i++) [...a[i], b[i]]];
    for (var c = 0; c < n; c++) {
      var piv = c;
      for (var r = c + 1; r < n; r++) {
        if (m[r][c].abs() > m[piv][c].abs()) piv = r;
      }
      if (m[piv][c].abs() < 1e-12) continue;
      final tmp = m[c];
      m[c] = m[piv];
      m[piv] = tmp;
      for (var r = c + 1; r < n; r++) {
        final f = m[r][c] / m[c][c];
        if (f == 0) continue;
        for (var k = c; k <= n; k++) {
          m[r][k] -= f * m[c][k];
        }
      }
    }
    final x = List<double>.filled(n, 0);
    for (var i = n - 1; i >= 0; i--) {
      var s = m[i][n];
      for (var k = i + 1; k < n; k++) {
        s -= m[i][k] * x[k];
      }
      x[i] = m[i][i].abs() < 1e-12 ? 0 : s / m[i][i];
    }
    return x;
  }

  // ───────────────────────── Dự đoán ─────────────────────────

  CountForecast predict(DateTime date, {WeatherInput? weather}) {
    final d = DateTime(date.year, date.month, date.day);
    final ctx = _Ctx(d, weather);
    final x = _row(ctx);
    final mu = exp(_eta(_b0, _beta, x));
    final sd = sqrt(phi * mu);

    final season = Seasons.of(d);
    final seasonKey = switch (season) {
      Season.summer => 'summer',
      Season.autumn => 'autumn',
      Season.winter => 'winter',
      Season.spring => '',
    };
    var seasonBeta = 0.0;
    for (var j = 0; j < _features.length; j++) {
      if (_features[j].key == seasonKey) seasonBeta = _beta[j];
    }
    final baseline = exp(_b0 + seasonBeta);

    final factors = <CountFactor>[];
    for (var j = 0; j < _features.length; j++) {
      final v = x[j];
      if (v.abs() < 1e-9) continue;
      final f = _features[j];
      if (f.key == 'summer' || f.key == 'autumn' || f.key == 'winter') continue; // đã nằm trong mức nền của mùa
      final detail = switch (f.key) {
        'rain' => '${weather!.rainMm.toStringAsFixed(1)} mm',
        'heat' => 'cao nhất ${weather!.tempMax.round()}°C',
        'cold' => 'thấp nhất ${weather!.tempMin.round()}°C',
        'holiday' || 'tet' => VnCalendar.holidayOn(d)?.name ?? '',
        _ => '',
      };
      factors.add(CountFactor(f.key, f.label, detail, exp(_beta[j] * v), _shares[j]));
    }
    // Mùa: nêu riêng một dòng cho dễ hiểu (mức nền đã gồm hiệu ứng mùa)
    if (seasonKey.isNotEmpty) {
      final j = _features.indexWhere((f) => f.key == seasonKey);
      factors.insert(0, CountFactor(seasonKey, Seasons.label(season), 'so với mùa xuân', exp(_beta[j]), _shares[j]));
    }

    return CountForecast(
      date: d,
      expected: mu,
      low: max(0, mu - 1.28 * sd),
      high: mu + 1.28 * sd,
      baseline: baseline,
      factors: factors,
      weatherMissing: weather == null,
      season: season,
    );
  }

  // ───────────────────────── Kiểm định chéo ─────────────────────────

  /// Kiểm định chéo: mỗi lần bỏ một ngày (hoặc 1/10 số ngày nếu trên 40 ngày, để chạy nhanh trên trình duyệt),
  /// huấn luyện trên phần còn lại rồi đoán ngày bị bỏ.
  /// Trả về null nếu quá ít ngày (< 6) để kiểm định có ý nghĩa.
  static CountCv? crossValidate(List<DayObs> obs, {double priorScale = 1.0}) {
    final n = obs.length;
    if (n < 6) return null;
    final folds = n <= 40 ? n : 10;
    final priorBeta = [for (final f in _features) f.prior];

    var absModel = 0.0, absMean = 0.0, absPrior = 0.0, sq = 0.0;
    var inside = 0, tested = 0;
    for (var f = 0; f < folds; f++) {
      final train = <DayObs>[], test = <DayObs>[];
      for (var i = 0; i < n; i++) {
        (i % folds == f ? test : train).add(obs[i]);
      }
      if (train.isEmpty || test.isEmpty) continue;
      final m = BookingCountModel.fit(train, priorScale: priorScale);
      final meanTrain = train.fold<int>(0, (s, o) => s + o.count) / train.length;

      // đường cơ sở "chỉ giả định": chọn nền sao cho tổng dự đoán trên tập huấn luyện khớp tổng thực tế
      var sumY = 0.0, sumExp = 0.0;
      for (final o in train) {
        final x = _row(_Ctx(o.date, o.weather));
        sumY += o.count;
        sumExp += exp(_eta(0, priorBeta, x));
      }
      final b0Prior = log(max(sumY, 0.2) / max(sumExp, 1e-9));

      for (final o in test) {
        final c = m.predict(o.date, weather: o.weather);
        final x = _row(_Ctx(o.date, o.weather));
        final priorPred = exp(_eta(b0Prior, priorBeta, x));
        absModel += (c.expected - o.count).abs();
        absMean += (meanTrain - o.count).abs();
        absPrior += (priorPred - o.count).abs();
        sq += pow(c.expected - o.count, 2);
        if (o.count >= c.low.floor() && o.count <= c.high.ceil()) inside++;
        tested++;
      }
    }
    if (tested == 0) return null;
    return CountCv(
      days: tested,
      mae: absModel / tested,
      maeMean: absMean / tested,
      maePrior: absPrior / tested,
      rmse: sqrt(sq / tested),
      coverage: inside / tested,
    );
  }
}
