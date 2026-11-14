import 'dart:convert';
import 'package:http/http.dart' as http;

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

  WeatherData({
    required this.temperature,
    required this.rainMm,
    required this.humidity,
    required this.condition,
    required this.description,
    required this.emoji,
    required this.isOutdoorFavorable,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'emoji': emoji,
      'nhiet_do': '${temperature.toStringAsFixed(1)}°C',
      'trang_thai': condition,
      'do_am': '$humidity%',
      'luong_mua': '${rainMm.toStringAsFixed(1)} mm',
      'thuan_loi_ngoai_troi': isOutdoorFavorable,
      'mo_ta': description,
    };
  }

  factory WeatherData.defaultHanoi() {
    return WeatherData(
      temperature: 25.5,
      rainMm: 0.0,
      humidity: 65,
      condition: 'Nắng nhẹ, tạnh ráo',
      description: 'Thời tiết mát mẻ, rất lý tưởng cho các hoạt động thể thao ngoài trời và trong nhà',
      emoji: '🌤️',
      isOutdoorFavorable: true,
    );
  }
}

// Giữ lại WeatherInfo để tương thích các component cũ nếu có
typedef WeatherInfo = WeatherData;

/// Dịch vụ thời tiết ngoại cảnh (Nhiệt độ, Lượng mưa, Trạng thái)
class WeatherService {
  static String openWeatherMapKey = '';

  /// Lấy thời tiết hiện tại khu vực Hà Nội
  static Future<WeatherData> getCurrentWeather() async {
    // 1. Thử Open-Meteo API (100% miễn phí, không cần key, cực chuẩn xác theo tọa độ Hà Nội)
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=21.0285&longitude=105.8542'
        '&current=temperature_2m,relative_humidity_2m,precipitation,weather_code',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final current = data['current'];
        if (current != null) {
          final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 25.5;
          final rain = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
          final humidity = (current['relative_humidity_2m'] as num?)?.toInt() ?? 65;
          final code = (current['weather_code'] as num?)?.toInt() ?? 0;

          final condition = _mapWmoCodeToCondition(code, rain);
          final emoji = _mapConditionToEmoji(code, rain);
          final isFavorable = rain < 0.5 && temp >= 18 && temp <= 34;

          return WeatherData(
            temperature: temp,
            rainMm: rain,
            humidity: humidity,
            condition: condition,
            description: rain > 0.5
                ? 'Có mưa ($rain mm), sân ngoài trời trơn trượt, sân trong nhà sẽ đông đúc'
                : 'Thời tiết tạnh ráo ($temp°C), rất thuận lợi cho người chơi ra sân',
            emoji: emoji,
            isOutdoorFavorable: isFavorable,
          );
        }
      }
    } catch (_) {}

    // 2. Thử OpenWeatherMap nếu có key
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

    // 3. Fallback mặc định chuẩn xác
    return WeatherData.defaultHanoi();
  }

  // Tương thích tên gọi hàm cũ
  static Future<WeatherData> getHanoiWeather() => getCurrentWeather();

  static String _mapWmoCodeToCondition(int code, double rain) {
    if (rain > 5.0) return 'Mưa to';
    if (rain > 1.0) return 'Mưa vừa';
    if (rain > 0.0) return 'Mưa rào nhẹ';

    if (code == 0) return 'Trời quang, nắng đẹp';
    if (code == 1 || code == 2) return 'Nắng nhẹ, mát mẻ';
    if (code == 3) return 'Nhiều mây, âm u';
    if (code >= 45 && code <= 48) return 'Có sương mù nhẹ';
    if (code >= 51 && code <= 67) return 'Mưa phùn / Mưa rào';
    if (code >= 80 && code <= 82) return 'Mưa rào rải rác';
    if (code >= 95) return 'Dông lốc, sấm sét';
    return 'Thời tiết mát mẻ';
  }

  static String _mapConditionToEmoji(int code, double rain) {
    if (rain > 5.0) return '⛈️';
    if (rain > 0.0) return '🌧️';
    if (code == 0) return '☀️';
    if (code == 1 || code == 2) return '🌤️';
    if (code == 3) return '☁️';
    if (code >= 45 && code <= 48) return '🌫️';
    return '🌤️';
  }
}
