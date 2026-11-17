import 'dart:convert';
import 'package:http/http.dart' as http;

/// Dự báo mưa của một ngày: xác suất tối đa (%) và tổng lượng mưa (mm).
class DayRain {
  final double prob;
  final double mm;
  const DayRain(this.prob, this.mm);
}

/// Model dữ liệu thời tiết ngoại cảnh cho AloBooking
class WeatherData {
  final double temperature; // °C
  final double rainMm; // mm lượng mưa
  final int humidity; // %
  final String condition; // Trạng thái: Nắng, Mưa, Mát mẻ, Âm u...
  final String description;
  final String emoji;
  final bool isOutdoorFavorable;
  final DateTime updatedAt;

  /// false = không lấy được dữ liệu thật (đang dùng giá trị tạm, không được trình bày như thật)
  final bool isLive;
  final double? feelsLike;
  final double? windKmh;

  /// Dự báo dạng chữ: từng ngày và từng buổi (sáng/chiều/tối) hôm nay + ngày mai
  final List<String> forecast;

  /// Dự báo mưa theo ngày (khóa dạng yyyy-MM-dd) cho các mô hình dự đoán nhu cầu/hủy sân
  final Map<String, DayRain> rainByDate;

  WeatherData({
    required this.temperature,
    required this.rainMm,
    required this.humidity,
    required this.condition,
    required this.description,
    required this.emoji,
    required this.isOutdoorFavorable,
    DateTime? updatedAt,
    this.isLive = true,
    this.feelsLike,
    this.windKmh,
    this.forecast = const [],
    this.rainByDate = const {},
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    if (!isLive) {
      return {
        'emoji': '🌤️',
        'nhiet_do': 'N/A',
        'trang_thai': 'Chưa cập nhật được thời tiết trực tuyến',
        'luu_y': 'Không có dữ liệu thời tiết thật lúc này. Đừng khẳng định thời tiết; nếu khách hỏi, nói chưa lấy được dữ liệu thời tiết.',
      };
    }
    return {
      'emoji': emoji,
      'nhiet_do': '${temperature.toStringAsFixed(1)}°C',
      if (feelsLike != null) 'cam_giac_nhu': '${feelsLike!.toStringAsFixed(1)}°C',
      'trang_thai': condition,
      'do_am': '$humidity%',
      'luong_mua': '${rainMm.toStringAsFixed(1)} mm',
      if (windKmh != null) 'gio': '${windKmh!.round()} km/h',
      'thuan_loi_ngoai_troi': isOutdoorFavorable,
      'mo_ta': description,
      'cap_nhat_luc': '${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}',
      if (forecast.isNotEmpty) 'du_bao': forecast,
    };
  }

  /// Giá trị tạm khi không gọi được API (isLive = false nên không bị hiển thị như dữ liệu thật)
  factory WeatherData.defaultHanoi() {
    return WeatherData(
      temperature: 25.5,
      rainMm: 0.0,
      humidity: 65,
      condition: 'Chưa cập nhật được thời tiết',
      description: 'Không lấy được dữ liệu thời tiết trực tuyến',
      emoji: '🌤️',
      isOutdoorFavorable: true,
      isLive: false,
    );
  }
}

// Giữ lại WeatherInfo để tương thích các component cũ nếu có
typedef WeatherInfo = WeatherData;

/// Dịch vụ thời tiết Hà Nội: dữ liệu thật từ Open-Meteo (miễn phí, không cần key).
class WeatherService {
  static String openWeatherMapKey = '';

  static WeatherData? _cache;
  static DateTime? _cachedAt;

  /// Lấy thời tiết hiện tại + dự báo 3 ngày khu vực Hà Nội (cache 10 phút).
  static Future<WeatherData> getCurrentWeather() async {
    final c = _cache;
    if (c != null && c.isLive && _cachedAt != null && DateTime.now().difference(_cachedAt!) < const Duration(minutes: 10)) {
      return c;
    }

    // 1. Open-Meteo theo tọa độ Hà Nội, múi giờ Asia/Bangkok (UTC+7 như Việt Nam)
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=21.0285&longitude=105.8542&timezone=Asia%2FBangkok'
        '&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m'
        '&hourly=temperature_2m,precipitation_probability,precipitation'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max'
        '&forecast_days=7',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final current = data['current'];
        if (current != null) {
          final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 25.5;
          final rain = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
          final humidity = (current['relative_humidity_2m'] as num?)?.toInt() ?? 65;
          final code = (current['weather_code'] as num?)?.toInt() ?? 0;
          final feels = (current['apparent_temperature'] as num?)?.toDouble();
          final wind = (current['wind_speed_10m'] as num?)?.toDouble();

          final condition = _mapWmoCodeToCondition(code, rain);
          final w = WeatherData(
            temperature: temp,
            rainMm: rain,
            humidity: humidity,
            condition: condition,
            description: rain > 0.5
                ? 'Đang mưa (${rain.toStringAsFixed(1)} mm), sân ngoài trời trơn trượt, sân trong nhà sẽ đông đúc'
                : 'Hiện tạnh ráo (${temp.toStringAsFixed(1)}°C), thuận lợi cho người chơi ra sân',
            emoji: _mapConditionToEmoji(code, rain),
            isOutdoorFavorable: rain < 0.5 && temp >= 18 && temp <= 34,
            feelsLike: feels,
            windKmh: wind,
            forecast: _buildForecast(data),
            rainByDate: _buildRainByDate(data),
          );
          _cache = w;
          _cachedAt = DateTime.now();
          return w;
        }
      }
    } catch (_) {}

    // 2. OpenWeatherMap nếu người dùng nhập key
    if (openWeatherMapKey.isNotEmpty && openWeatherMapKey != 'YOUR_OWM_API_KEY_HERE') {
      try {
        final url = Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?q=Hanoi,VN&appid=$openWeatherMapKey&units=metric&lang=vi',
        );
        final res = await http.get(url).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final main = data['main'] ?? {};
          final weather = (data['weather'] as List?)?.firstOrNull ?? {};
          final rain = (data['rain']?['1h'] as num?)?.toDouble() ?? 0.0;
          final temp = (main['temp'] as num?)?.toDouble() ?? 25.5;
          final humidity = (main['humidity'] as num?)?.toInt() ?? 65;
          final desc = weather['description'] ?? 'Tạnh ráo';

          return WeatherData(
            temperature: temp,
            rainMm: rain,
            humidity: humidity,
            condition: desc,
            description: 'Nhiệt độ $temp°C, độ ẩm $humidity%, mưa $rain mm',
            emoji: rain > 1.0 ? '🌧️' : (temp > 30 ? '☀️' : '🌤️'),
            isOutdoorFavorable: rain < 0.5 && temp < 35,
          );
        }
      } catch (_) {}
    }

    // 3. Không lấy được: dùng dữ liệu cũ nếu có, nếu không thì trả giá trị tạm đánh dấu isLive=false
    return _cache ?? WeatherData.defaultHanoi();
  }

  // Tương thích tên gọi hàm cũ
  static Future<WeatherData> getHanoiWeather() => getCurrentWeather();

  /// Dự báo ngắn gọn bằng chữ để đưa vào ngữ cảnh chatbot.
  static List<String> _buildForecast(Map<String, dynamic> data) {
    final out = <String>[];
    try {
      final daily = data['daily'] as Map<String, dynamic>;
      final dates = (daily['time'] as List).cast<String>();
      const names = ['Hôm nay', 'Ngày mai', 'Ngày kia'];
      for (var i = 0; i < dates.length && i < 3; i++) {
        final mm = (daily['precipitation_sum'][i] as num?)?.toDouble() ?? 0;
        final prob = (daily['precipitation_probability_max'][i] as num?)?.toInt() ?? 0;
        final code = (daily['weather_code'][i] as num?)?.toInt() ?? 0;
        final tmax = (daily['temperature_2m_max'][i] as num?)?.toDouble();
        final tmin = (daily['temperature_2m_min'][i] as num?)?.toDouble();
        out.add('${names[i]} (${_vnDate(dates[i])}): ${_dayCondition(code, mm, prob)}, '
            '${tmin?.round()}–${tmax?.round()}°C, khả năng mưa tối đa $prob%, tổng lượng mưa ${mm.toStringAsFixed(1)} mm');
      }

      // Chia buổi cho hôm nay và ngày mai
      final h = data['hourly'] as Map<String, dynamic>;
      final times = (h['time'] as List).cast<String>();
      final temps = h['temperature_2m'] as List;
      final probs = h['precipitation_probability'] as List;
      final precs = h['precipitation'] as List;
      const periods = [('Sáng', 6, 11), ('Chiều', 12, 17), ('Tối', 18, 22)];
      final nowHour = DateTime.now().toUtc().add(const Duration(hours: 7)).hour;
      for (var di = 0; di < 2 && di < dates.length; di++) {
        for (final (name, from, to) in periods) {
          if (di == 0 && to < nowHour) continue; // buổi đã qua
          double sumT = 0, sumP = 0;
          int n = 0, maxProb = 0;
          for (var i = 0; i < times.length; i++) {
            if (!times[i].startsWith(dates[di])) continue;
            final hr = int.parse(times[i].substring(11, 13));
            if (hr < from || hr > to) continue;
            sumT += (temps[i] as num?)?.toDouble() ?? 0;
            sumP += (precs[i] as num?)?.toDouble() ?? 0;
            final p = (probs[i] as num?)?.toInt() ?? 0;
            if (p > maxProb) maxProb = p;
            n++;
          }
          if (n == 0) continue;
          out.add('${di == 0 ? 'Hôm nay' : 'Ngày mai'} $name (${from}h–${to}h): ~${(sumT / n).round()}°C, '
              'khả năng mưa $maxProb%, lượng mưa ${sumP.toStringAsFixed(1)} mm');
        }
      }
    } catch (_) {}
    return out;
  }

  static Map<String, DayRain> _buildRainByDate(Map<String, dynamic> data) {
    final out = <String, DayRain>{};
    try {
      final daily = data['daily'] as Map<String, dynamic>;
      final dates = (daily['time'] as List).cast<String>();
      for (var i = 0; i < dates.length; i++) {
        out[dates[i]] = DayRain(
          (daily['precipitation_probability_max'][i] as num?)?.toDouble() ?? 0,
          (daily['precipitation_sum'][i] as num?)?.toDouble() ?? 0,
        );
      }
    } catch (_) {}
    return out;
  }

  static String _vnDate(String iso) {
    final p = iso.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}' : iso;
  }

  static String _dayCondition(int code, double mm, int prob) {
    if (code >= 95 && prob >= 40) return 'Dông, mưa rào';
    if (prob < 30 && mm < 3) return code == 0 ? 'Trời quang, không mưa' : (code == 3 ? 'Nhiều mây, ít khả năng mưa' : 'Ít mây, ít khả năng mưa');
    if (code >= 95) return 'Dông, mưa rào';
    if (mm >= 10) return 'Mưa to';
    if (mm >= 3) return 'Mưa vừa';
    if (mm >= 0.5 || (code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return 'Mưa nhẹ / mưa phùn';
    if (code == 0) return 'Trời quang';
    if (code <= 2) return 'Ít mây';
    if (code == 3) return 'Nhiều mây';
    if (code >= 45 && code <= 48) return 'Sương mù';
    return 'Tạnh ráo';
  }

  static String _mapWmoCodeToCondition(int code, double rain) {
    if (code >= 95) return 'Dông, sấm sét';
    if (rain > 5.0) return 'Mưa to';
    if (rain > 1.0) return 'Mưa vừa';
    if (rain > 0.0) return 'Mưa rào nhẹ';

    if (code == 0) return 'Trời quang';
    if (code == 1 || code == 2) return 'Ít mây';
    if (code == 3) return 'Nhiều mây, âm u';
    if (code >= 45 && code <= 48) return 'Có sương mù';
    if (code >= 51 && code <= 67) return 'Mưa phùn / mưa nhẹ';
    if (code >= 80 && code <= 82) return 'Mưa rào rải rác';
    return 'Tạnh ráo';
  }

  static String _mapConditionToEmoji(int code, double rain) {
    if (code >= 95 || rain > 5.0) return '⛈️';
    if (rain > 0.0 || (code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return '🌧️';
    if (code == 0) return '☀️';
    if (code == 1 || code == 2) return '🌤️';
    if (code == 3) return '☁️';
    if (code >= 45 && code <= 48) return '🌫️';
    return '🌤️';
  }
}
