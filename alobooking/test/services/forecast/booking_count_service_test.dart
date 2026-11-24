import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alobooking/services/forecast/booking_count_service.dart';
import 'package:alobooking/services/forecast/demand_forecast_service.dart';
import 'package:alobooking/services/firestore_service.dart';
import 'package:alobooking/services/weather/weather_history_service.dart';
import 'package:alobooking/services/weather/weather_service.dart';

final _today = DateTime(2026, 11, 24);

BookingItem _b(String id, DateTime day, {String status = 'Đã xác nhận'}) => BookingItem(
      id: id,
      customer: 'Khách',
      phone: '0900000000',
      venueName: 'Sân A',
      field: 'Sân 1',
      time: '18:00 - 19:00',
      date: '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}',
      amount: '100.000đ',
      status: status,
      paymentMethod: 'VietQR',
      createdAt: day.subtract(const Duration(days: 3)),
    );

/// 60 ngày liền trước hôm nay: cuối tuần đông gấp đôi, ngày mưa vắng hơn.
List<BookingItem> _history() {
  final r = Random(5);
  final out = <BookingItem>[];
  for (var i = 1; i <= 60; i++) {
    final d = _today.subtract(Duration(days: i));
    final n = d.weekday >= 6 ? 8 + r.nextInt(3) : 3 + r.nextInt(3);
    for (var k = 0; k < n; k++) {
      out.add(_b('$i-$k', d));
    }
  }
  return out;
}

Map<String, dynamic> _weatherJson(int days, {double rainOn = 0}) {
  final dates = [for (var i = days; i >= 1; i--) VnCalendar.key(_today.subtract(Duration(days: i)))];
  return {
    'daily': {
      'time': dates,
      'temperature_2m_max': [for (final _ in dates) 30.0],
      'temperature_2m_min': [for (final _ in dates) 24.0],
      'precipitation_sum': [for (var i = 0; i < dates.length; i++) i % 7 == 3 ? rainOn : 0.0],
    }
  };
}

const _json = {'content-type': 'application/json; charset=utf-8'};

void main() {
  setUp(() {
    WeatherHistoryService.clearCache();
    BookingCountService.clearCache();
  });

  group('BookingCountService.build', () {
    test('Ghép thời tiết thật, huấn luyện và kiểm định chéo', () async {
      var calls = 0;
      final client = MockClient((r) async {
        calls++;
        return http.Response(jsonEncode(_weatherJson(60, rainOn: 9)), 200, headers: _json);
      });
      await http.runWithClient(() async {
        final report = await BookingCountService.build(_history(), today: _today);
        expect(report.model.days, 60);
        expect(report.weatherDays, greaterThan(50));
        expect(report.cv, isNotNull);
        expect(report.model.hasData, isTrue);
        // dữ liệu có cuối tuần đông gấp ~2: hệ số thứ Bảy phải dương rõ và có phần lớn từ dữ liệu
        expect(report.model.coefficients['sat']!, greaterThan(0.4));
        expect(report.model.dataShares['sat']!, greaterThan(0.5));

        // lần gọi thứ hai cùng dữ liệu: dùng bản nhớ, không gọi thêm API
        final again = await BookingCountService.build(_history(), today: _today);
        expect(identical(again, report), isTrue);
        expect(calls, 1);
      }, () => client);
    });

    test('Thời tiết lỗi: vẫn huấn luyện được, báo chưa ghép thời tiết, không nhớ kết quả để thử lại', () async {
      await http.runWithClient(() async {
        final report = await BookingCountService.build(_history(), today: _today);
        expect(report.model.hasData, isTrue);
        expect(report.weatherDays, 0);
        expect(report.honestyNote, contains('chưa ghép được thời tiết thật'));
        expect(report.model.dataShares['rain'], 0, reason: 'không có thời tiết thì không học được tác động của mưa');
      }, () => MockClient((r) async => throw Exception('mất mạng')));

      // mạng trở lại: lần sau phải thử lấy thời tiết lại
      await http.runWithClient(() async {
        final report = await BookingCountService.build(_history(), today: _today);
        expect(report.weatherDays, greaterThan(50));
      }, () => MockClient((r) async => http.Response(jsonEncode(_weatherJson(60)), 200, headers: _json)));
    });

    test('Không có đơn nào: mô hình không có dữ liệu, không đưa ra số đơn thay thế', () async {
      final report = await BookingCountService.build(const [], today: _today, useWeather: false);
      expect(report.model.hasData, isFalse);
      expect(report.volumeFor(DateTime(2026, 11, 28)), isNull);
      expect(report.cv, isNull);
    });

    test('Thêm đơn mới thì huấn luyện lại', () async {
      final a = await BookingCountService.build(_history(), today: _today, useWeather: false);
      final b = await BookingCountService.build([..._history(), _b('x', _today.subtract(const Duration(days: 1)))], today: _today, useWeather: false);
      expect(identical(a, b), isFalse);
    });

    test('forecastWeather lập bản đồ theo ngày từ dự báo', () {
      final m = BookingCountService.forecastWeather([
        DayWeather(date: DateTime(2026, 11, 25), emoji: '☀️', condition: 'Quang', tempMax: 31, tempMin: 22, rainProb: 20, rainMm: 0.4),
      ]);
      expect(m['2026-11-25']!.tempMax, 31);
      expect(m['2026-11-25']!.rainProb, 20);
    });
  });

  group('Nối vào thẻ dự báo và chatbot', () {
    test('VolumeOverride thay số đơn, mức nhu cầu và dòng giải thích của ngày', () async {
      final report = await BookingCountService.build(_history(), today: _today, useWeather: false);
      final dm = DemandModel.fit(_history());
      final sat = DateTime(2026, 11, 28); // thứ Bảy
      final tue = DateTime(2026, 11, 24 + 1); // thứ Tư
      final vSat = report.volumeFor(sat)!;
      final vWed = report.volumeFor(tue)!;
      expect(vSat.expected, greaterThan(vWed.expected * 1.4));

      final f = dm.forecastDay(sat, volume: vSat);
      expect(f.expectedBookings, vSat.expected);
      expect(f.low, vSat.low);
      expect(f.high, vSat.high);
      expect(f.demandMultiplier, vSat.multiplier);
      expect(f.factors.first, contains('Số đơn dự kiến'));
      expect(f.factors.any((x) => x.contains('Thứ Bảy')), isTrue);
      expect(f.confidence, contains('số đơn:'));
      expect(f.cancelRate, inInclusiveRange(0, 1), reason: 'tỉ lệ hủy vẫn do mô hình cũ tính');
    });

    test('Không truyền volume thì kết quả giống hệt trước đây', () {
      final dm = DemandModel.fit(_history());
      final a = dm.forecastDay(DateTime(2026, 11, 28));
      final b = dm.forecastDay(DateTime(2026, 11, 28), volume: null);
      expect(a.expectedBookings, b.expectedBookings);
      expect(a.factors, b.factors);
    });

    test('buildPromptSection dùng số đơn của mô hình đếm và nói rõ độ tin cậy', () async {
      final report = await BookingCountService.build(_history(), today: _today, useWeather: false);
      final text = DemandForecastService.buildPromptSection(
        _history(),
        DateTime(2026, 11, 28),
        today: _today,
        volumeFor: (d) => report.volumeFor(d),
        volumeNote: report.honestyNote,
      );
      final expected = report.volumeFor(DateTime(2026, 11, 28))!.expected.round();
      expect(text, contains('~$expected đơn'));
      expect(text, contains('hồi quy Poisson'));
      expect(text, contains('Kiểm định chéo'));
      expect(text, contains('TỔNG QUAN 7 NGÀY TỚI'));
    });

    test('buildPromptSection không có mô hình đếm: giữ nguyên lời nhắc cũ', () {
      final text = DemandForecastService.buildPromptSection(_history(), DateTime(2026, 11, 28), today: _today);
      expect(text, contains('giả định chuyên môn về mưa/ngày lễ'));
      expect(text, isNot(contains('hồi quy Poisson')));
    });
  });
}
