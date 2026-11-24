import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alobooking/data/venues_data.dart';
import 'package:alobooking/screens/admin_screen.dart';
import 'package:alobooking/services/admin_stats.dart' show VnWeekday;
import 'package:alobooking/services/booking_count_service.dart';
import 'package:alobooking/services/weather_history_service.dart';

Future<void> _loadRealFont() async {
  final f = File('C:/Windows/Fonts/segoeui.ttf');
  if (!f.existsSync()) return;
  final loader = FontLoader('Be Vietnam Pro')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
}

const _json = {'content-type': 'application/json; charset=utf-8'};

String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> _bookingDoc(String id, DateTime day) => {
      'name': 'projects/x/databases/(default)/documents/bookings/$id',
      'fields': {
        'id': {'stringValue': id},
        'customer': {'stringValue': 'Khách $id'},
        'phone': {'stringValue': '0900000000'},
        'venueName': {'stringValue': 'Sân A'},
        'field': {'stringValue': 'Sân 1'},
        'time': {'stringValue': '18:00 - 19:00'},
        'date': {'stringValue': '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}'},
        'amount': {'stringValue': '100.000đ'},
        'status': {'stringValue': 'Đã xác nhận'},
        'paymentMethod': {'stringValue': 'VietQR'},
        'createdAt': {'stringValue': day.subtract(const Duration(days: 3)).toIso8601String()},
      },
    };

/// Phản hồi Open-Meteo cho cả lịch sử (past_days) lẫn dự báo hiện tại.
Map<String, dynamic> _weather(DateTime from, int days, {bool withCurrent = true}) {
  final dates = [for (var i = 0; i < days; i++) _key(DateTime(from.year, from.month, from.day + i))];
  return {
    if (withCurrent)
      'current': {
        'temperature_2m': 29.0,
        'apparent_temperature': 31.0,
        'relative_humidity_2m': 70,
        'precipitation': 0.0,
        'weather_code': 1,
        'wind_speed_10m': 8.0,
      },
    'daily': {
      'time': dates,
      'weather_code': [for (final _ in dates) 1],
      'temperature_2m_max': [for (final _ in dates) 33.0],
      'temperature_2m_min': [for (final _ in dates) 25.0],
      'precipitation_sum': [for (var i = 0; i < dates.length; i++) i == 2 ? 12.0 : 0.0],
      'precipitation_probability_max': [for (var i = 0; i < dates.length; i++) i == 2 ? 80 : 10],
    },
    'hourly': {'time': <String>[], 'temperature_2m': <double>[], 'precipitation_probability': <int>[], 'precipitation': <double>[]},
  };
}

MockClient _client() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final r = Random(3);
  final docs = <Map<String, dynamic>>[];
  for (var i = 1; i <= 45; i++) {
    final d = today.subtract(Duration(days: i));
    final n = d.weekday >= 6 ? 8 + r.nextInt(3) : 3 + r.nextInt(3);
    for (var k = 0; k < n; k++) {
      docs.add(_bookingDoc('b$i-$k', d));
    }
  }
  return MockClient((req) async {
    if (req.url.host == 'firestore.googleapis.com') {
      if (req.method == 'GET' && req.url.path.endsWith('/bookings')) {
        return http.Response(jsonEncode({'documents': docs}), 200, headers: _json);
      }
      return http.Response(jsonEncode({'documents': []}), 200, headers: _json);
    }
    if (req.url.host == 'api.open-meteo.com') {
      if (req.url.queryParameters.containsKey('current')) {
        return http.Response(jsonEncode(_weather(today, 7)), 200, headers: _json);
      }
      final past = int.parse(req.url.queryParameters['past_days'] ?? '0');
      return http.Response(jsonEncode(_weather(today.subtract(Duration(days: past)), past + 1, withCurrent: false)), 200, headers: _json);
    }
    return http.Response('{}', 404);
  });
}

void main() {
  setUpAll(_loadRealFont);
  setUp(() {
    WeatherHistoryService.clearCache();
    BookingCountService.clearCache();
  });

  for (final size in const [Size(1440, 2600), Size(390, 4200)])
  testWidgets('Thẻ dự báo Admin ${size.width.toInt()}px: hiện số đơn theo mô hình đếm, bấm ngày thấy lý do, chú thích trung thực', (tester) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: AdminScreen(initialVenues: sampleVenues)));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.text('Dự báo 7 ngày tới'), findsOneWidget);
      expect(find.textContaining('Số đơn dự kiến theo thứ, ngày lễ, mùa, mưa, nhiệt độ'), findsOneWidget, reason: 'đã chuyển sang mô hình đếm đơn');
      expect(find.textContaining('đơn', findRichText: true), findsWidgets);
      expect(find.textContaining('Mô hình học từ 45 ngày'), findsOneWidget);
      expect(find.textContaining('ngày có thời tiết thật'), findsOneWidget);
      expect(find.textContaining('Kiểm định chéo'), findsOneWidget);
      expect(find.textContaining('theo giả định chuyên môn'), findsOneWidget, reason: 'nói rõ phần nào còn là giả định');

      // chưa bấm: chưa hiện dòng lý do
      expect(find.textContaining('Số đơn dự kiến ~'), findsNothing);
      // bấm vào dòng ngày đầu tiên của bảng dự báo
      final today = DateTime.now();
      final label = '${VnWeekday.name(today)} ${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}';
      final row = find.text(label);
      expect(row, findsOneWidget, reason: 'hàng của hôm nay trong thẻ dự báo');
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Số đơn dự kiến ~'), findsOneWidget);
      expect(find.textContaining('[học từ dữ liệu', findRichText: true).evaluate().length + find.textContaining('giả định chuyên môn]').evaluate().length, greaterThan(0));

      // bấm lần nữa thì thu lại
      await tester.tap(row);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Số đơn dự kiến ~'), findsNothing);
      expect(tester.takeException(), isNull);
    }, _client);
  });
}
