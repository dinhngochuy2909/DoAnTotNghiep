import 'booking_count_model.dart';
import 'demand_forecast_service.dart';
import '../firestore_service.dart' show BookingItem;
import '../weather/weather_history_service.dart';
import '../weather/weather_service.dart' show DayWeather;

/// Kết quả huấn luyện mô hình đếm đơn: mô hình, kiểm định chéo và cách đọc ra cho người dùng/chatbot.
class BookingCountReport {
  final BookingCountModel model;
  final CountCv? cv;

  /// Số ngày dữ liệu có đủ thời tiết thật để học tác động của mưa/nhiệt độ.
  int get weatherDays => model.weatherDays;

  const BookingCountReport(this.model, this.cv);

  /// Dự đoán một ngày. [weather] là dự báo thời tiết của ngày đó (null nếu ngoài tầm dự báo).
  CountForecast forecast(DateTime date, {WeatherInput? weather}) => model.predict(date, weather: weather);

  /// So với ngày điển hình trong lịch sử (số đơn trung bình mỗi ngày).
  double multiplierOf(CountForecast f) => model.meanPerDay <= 0 ? 1 : f.expected / model.meanPerDay;

  /// Dạng dùng chung với [DemandModel.forecastDay]. Trả null nếu hoàn toàn không có đơn lịch sử:
  /// khi đó giữ ước lượng cũ thay vì đưa ra con số chỉ dựa trên giả định.
  VolumeOverride? volumeFor(DateTime date, {WeatherInput? weather}) {
    if (!model.hasData) return null;
    final f = forecast(date, weather: weather);
    return VolumeOverride(
      expected: f.expected,
      low: f.low,
      high: f.high,
      multiplier: multiplierOf(f),
      factorLines: [
        'Số đơn dự kiến ~${f.expected.round()} (khoảng ${f.rangeText}); mức nền ${f.baseline.toStringAsFixed(1)} đơn/ngày của ${Seasons.label(f.season).toLowerCase()}',
        for (final x in f.factors) x.line,
        if (f.weatherMissing) 'Chưa có dự báo thời tiết cho ngày này: không điều chỉnh theo mưa/nhiệt độ',
      ],
      confidence: model.confidenceText,
    );
  }

  /// Câu nói thật về chất lượng mô hình (số ngày học, thời tiết, so với cách đoán đơn giản).
  String get honestyNote {
    final b = StringBuffer('Mô hình học từ ${model.days} ngày có dữ liệu');
    b.write(model.weatherDays == 0 ? ' (chưa ghép được thời tiết thật).' : ', ${model.weatherDays} ngày có thời tiết thật.');
    final c = cv;
    if (c == null) {
      b.write(' Chưa đủ ngày để kiểm định chéo, xem là ước lượng tham khảo.');
    } else if (c.beatsMean) {
      b.write(' Kiểm định chéo: sai số trung bình ${c.mae.toStringAsFixed(1)} đơn/ngày, ít hơn cách luôn đoán trung bình '
          '${c.maeMean.toStringAsFixed(1)} (giảm ${(c.improvementOverMean * 100).round()}%).');
    } else {
      b.write(' Kiểm định chéo: chưa tốt hơn cách luôn đoán trung bình (sai số ${c.mae.toStringAsFixed(1)} so với ${c.maeMean.toStringAsFixed(1)} đơn/ngày), '
          'nên chưa chứng minh được các yếu tố đang giúp dự đoán.');
    }
    return b.toString();
  }
}

class BookingCountService {
  static BookingCountReport? _cachedReport;
  static String? _cachedKey;

  static void clearCache() {
    _cachedReport = null;
    _cachedKey = null;
  }

  /// Chữ ký của dữ liệu để biết khi nào cần huấn luyện lại (đổi số đơn, trạng thái hoặc sang ngày mới).
  static String _signature(List<BookingItem> bookings, DateTime today) {
    var h = bookings.length;
    for (final b in bookings) {
      h = (h * 31 + b.id.hashCode + b.date.hashCode + b.status.hashCode) & 0x3fffffff;
    }
    return '$h|${today.year}-${today.month}-${today.day}';
  }

  /// Huấn luyện mô hình từ các đơn đã có: lấy thời tiết thật của các ngày đó rồi ghép với số đơn từng ngày.
  /// Thời tiết không lấy được thì vẫn huấn luyện (bỏ qua yếu tố thời tiết), không bịa số liệu.
  static Future<BookingCountReport> build(List<BookingItem> bookings, {DateTime? today, bool useWeather = true}) async {
    final now = today ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final key = '${_signature(bookings, day)}|$useWeather';
    if (_cachedReport != null && _cachedKey == key) return _cachedReport!;

    // Lần đầu chỉ cần biết khoảng ngày để xin thời tiết
    final dry = BookingCountModel.observationsFromBookings(bookings, const {}, today: day);
    var weather = <String, WeatherInput>{};
    if (useWeather && dry.isNotEmpty) {
      weather = await WeatherHistoryService.load(dry.first.date, dry.last.date, today: day);
    }
    final obs = weather.isEmpty ? dry : BookingCountModel.observationsFromBookings(bookings, weather, today: day);
    final report = BookingCountReport(BookingCountModel.fit(obs), BookingCountModel.crossValidate(obs));
    // Lấy thời tiết thất bại (mất mạng) thì không nhớ kết quả, lần sau thử lại để có đủ yếu tố thời tiết
    if (!useWeather || dry.isEmpty || weather.isNotEmpty) {
      _cachedReport = report;
      _cachedKey = key;
    }
    return report;
  }

  /// Dự báo thời tiết các ngày tới theo khóa yyyy-MM-dd, để đưa vào [BookingCountReport.forecast].
  static Map<String, WeatherInput> forecastWeather(List<DayWeather> days) =>
      {for (final d in days) VnCalendar.key(d.date): WeatherInput.fromDay(d)};
}
