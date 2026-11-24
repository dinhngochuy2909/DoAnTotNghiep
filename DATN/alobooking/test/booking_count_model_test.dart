import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alobooking/services/booking_count_model.dart';
import 'package:alobooking/services/firestore_service.dart';
import 'package:alobooking/services/weather_history_service.dart';

/// Poisson ngẫu nhiên có hạt giống cố định (Knuth cho λ nhỏ, xấp xỉ chuẩn cho λ lớn).
int _poisson(Random r, double lambda) {
  if (lambda > 30) {
    // xấp xỉ chuẩn
    final u1 = max(1e-12, r.nextDouble()), u2 = r.nextDouble();
    final z = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
    return max(0, (lambda + sqrt(lambda) * z).round());
  }
  final l = exp(-lambda);
  var k = 0;
  var p = 1.0;
  do {
    k++;
    p *= r.nextDouble();
  } while (p > l);
  return k - 1;
}

/// Sinh dữ liệu theo "sự thật" đã biết: nền 8 đơn/ngày, thứ Bảy ×e^0.5, Chủ Nhật ×e^0.6, mưa ×e^-0.9 (mưa to), ...
List<DayObs> _simulate({
  int days = 400,
  int seed = 1,
  double base = 8,
  double sat = 0.5,
  double sun = 0.6,
  double rain = -0.9,
  DateTime? start,
}) {
  final r = Random(seed);
  final out = <DayObs>[];
  final s = start ?? DateTime(2025, 1, 6); // thứ Hai
  for (var i = 0; i < days; i++) {
    final d = DateTime(s.year, s.month, s.day + i);
    final mm = r.nextDouble() < 0.35 ? r.nextDouble() * 14 : 0.0;
    final tmax = 24 + r.nextDouble() * 12, tmin = tmax - 6;
    final w = WeatherInput(tempMax: tmax, tempMin: tmin, rainMm: mm);
    var eta = log(base);
    if (d.weekday == DateTime.saturday) eta += sat;
    if (d.weekday == DateTime.sunday) eta += sun;
    eta += rain * w.rainIndex;
    out.add(DayObs(d, _poisson(r, exp(eta)), w));
  }
  return out;
}

BookingItem _booking(String date, {String status = 'Đã xác nhận', String id = 'b'}) => BookingItem(
      id: id,
      customer: 'Khách',
      phone: '0900000000',
      venueName: 'Sân A',
      field: 'Sân 1',
      time: '18:00 - 19:00',
      date: date,
      amount: '100.000đ',
      status: status,
      paymentMethod: 'VietQR',
      createdAt: DateTime(2026, 10, 1),
    );

const _json = {'content-type': 'application/json; charset=utf-8'};

void main() {
  group('Yếu tố đầu vào', () {
    test('rainIndex, heat, cold tính đúng và bị chặn', () {
      const w = WeatherInput(tempMax: 38, tempMin: 28, rainMm: 25);
      expect(w.rainIndex, 1.0, reason: 'trên 10 mm thì chặn ở 1');
      expect(w.heat, closeTo(1.5, 1e-9));
      expect(w.cold, 0);
      const c = WeatherInput(tempMax: 16, tempMin: 10, rainMm: 0);
      expect(c.cold, closeTo(2.0, 1e-9));
      expect(c.heat, 0);
      expect(c.rainIndex, 0);
    });

    test('Mùa theo tháng', () {
      expect(Seasons.of(DateTime(2026, 1, 15)), Season.winter);
      expect(Seasons.of(DateTime(2026, 2, 1)), Season.spring);
      expect(Seasons.of(DateTime(2026, 6, 1)), Season.summer);
      expect(Seasons.of(DateTime(2026, 10, 31)), Season.autumn);
      expect(Seasons.of(DateTime(2026, 12, 25)), Season.winter);
    });
  });

  group('Gom đơn thành số đơn theo ngày', () {
    final today = DateTime(2026, 11, 24);

    test('Đếm đúng theo ngày chơi, không tính đơn hủy và bỏ hôm nay trở đi', () {
      final obs = BookingCountModel.observationsFromBookings([
        _booking('10/11/2026', id: '1'),
        _booking('10/11/2026', id: '2'),
        _booking('2026-11-11', id: '3'),
        _booking('11/11/2026', status: 'Đã hủy', id: '4'),
        _booking('24/11/2026', id: '5'), // hôm nay: chưa đủ ngày
        _booking('30/11/2026', id: '6'), // tương lai
        _booking('không phải ngày', id: '7'),
      ], {}, today: today);
      expect(obs.map((o) => o.count).toList(), [2, 1]);
      expect(obs.first.date, DateTime(2026, 11, 10));
    });

    test('Có thể đếm cả đơn hủy khi yêu cầu', () {
      final obs = BookingCountModel.observationsFromBookings(
        [_booking('10/11/2026', id: '1'), _booking('10/11/2026', status: 'Đã hủy', id: '2')],
        {},
        today: today,
        countCancelled: true,
      );
      expect(obs.single.count, 2);
    });

    test('Ngày trống ngắn trong giai đoạn hoạt động tính là 0 đơn, khoảng trống dài bị bỏ', () {
      final obs = BookingCountModel.observationsFromBookings([
        _booking('01/10/2026', id: '1'),
        _booking('03/10/2026', id: '2'), // trống 02/10 -> 0 đơn thật
        _booking('20/10/2026', id: '3'), // cách 17 ngày: giai đoạn mới
        _booking('21/10/2026', id: '4'),
      ], {}, today: today);
      expect(obs.map((o) => o.date.day).toList(), [1, 2, 3, 20, 21], reason: '4–19/10 là khoảng hệ thống không dùng, không phải nhu cầu = 0');
      expect(obs.map((o) => o.count).toList(), [1, 0, 1, 1, 1]);
    });

    test('Ghép thời tiết đúng ngày, thiếu thì để trống', () {
      const w = WeatherInput(tempMax: 30, tempMin: 24, rainMm: 5);
      final obs = BookingCountModel.observationsFromBookings(
        [_booking('10/11/2026', id: '1'), _booking('11/11/2026', id: '2')],
        {'2026-11-10': w},
        today: today,
      );
      expect(obs[0].weather, same(w));
      expect(obs[1].weather, isNull);
    });

    test('Không có đơn nào thì rỗng', () {
      expect(BookingCountModel.observationsFromBookings(const [], {}, today: today), isEmpty);
    });
  });

  group('Huấn luyện', () {
    test('Không có dữ liệu: dùng giả định, báo hasData=false', () {
      final m = BookingCountModel.fit(const []);
      expect(m.hasData, isFalse);
      expect(m.days, 0);
      final f = m.predict(DateTime(2026, 12, 5)); // thứ Bảy
      expect(f.expected, greaterThan(0));
      expect(m.confidenceText, startsWith('RẤT THẤP'));
      expect(m.dataShares.values.every((v) => v == 0), isTrue);
    });

    test('Nhiều dữ liệu: học lại được thứ Bảy, Chủ Nhật, mưa gần với sự thật', () {
      final m = BookingCountModel.fit(_simulate(days: 700, seed: 7));
      final c = m.coefficients;
      expect(c['sat'], closeTo(0.5, 0.12));
      expect(c['sun'], closeTo(0.6, 0.12));
      expect(c['rain'], closeTo(-0.9, 0.2));
      expect(m.intercept, closeTo(8, 1.2));
      expect(m.dataShares['sat']!, greaterThan(0.9));
      expect(m.dataShares['rain']!, greaterThan(0.9));
    });

    test('Ít dữ liệu: hệ số bị giữ gần giả định thay vì học bậy', () {
      final few = _simulate(days: 6, seed: 3);
      final m = BookingCountModel.fit(few);
      final prior = BookingCountModel.fit(const []).coefficients;
      for (final k in ['sat', 'sun', 'rain', 'heat', 'cold']) {
        expect((m.coefficients[k]! - prior[k]!).abs(), lessThan(0.45), reason: '$k không được lệch xa giả định khi chỉ có 6 ngày');
      }
      expect(m.confidenceText, startsWith('RẤT THẤP'));
    });

    test('Yếu tố không đổi trong dữ liệu (không có thứ Bảy) giữ nguyên giả định và share = 0', () {
      // chỉ thứ Hai–Thứ Sáu trong 60 ngày
      final obs = _simulate(days: 120, seed: 5).where((o) => o.date.weekday <= 5).toList();
      final m = BookingCountModel.fit(obs);
      final prior = BookingCountModel.fit(const []).coefficients;
      expect(m.dataShares['sat'], 0);
      expect(m.dataShares['sun'], 0);
      expect(m.coefficients['sat'], closeTo(prior['sat']!, 0.02));
      expect(m.coefficients['sun'], closeTo(prior['sun']!, 0.02));
    });

    test('Không có thời tiết: yếu tố thời tiết giữ giả định, không crash', () {
      final noWx = [for (final o in _simulate(days: 200, seed: 9)) DayObs(o.date, o.count)];
      final m = BookingCountModel.fit(noWx);
      expect(m.weatherDays, 0);
      expect(m.dataShares['rain'], 0);
      expect(m.dataShares['heat'], 0);
      expect(m.coefficients['sat']!, greaterThan(0.2));
    });

    test('Toàn số 0 hoặc số rất lớn vẫn ổn định (không NaN/Infinity)', () {
      final zeros = [for (var i = 0; i < 40; i++) DayObs(DateTime(2026, 3, 1 + i), 0)];
      final mz = BookingCountModel.fit(zeros);
      final fz = mz.predict(DateTime(2026, 4, 20));
      expect(fz.expected.isFinite, isTrue);
      expect(fz.expected, lessThan(1));

      final huge = [for (var i = 0; i < 40; i++) DayObs(DateTime(2026, 3, 1 + i), 5000 + i * 10)];
      final mh = BookingCountModel.fit(huge);
      final fh = mh.predict(DateTime(2026, 4, 20));
      expect(fh.expected.isFinite, isTrue);
      expect(fh.expected, greaterThan(1000));
      for (final v in mh.coefficients.values) {
        expect(v.isFinite, isTrue);
      }
    });

    test('Phân tán quá mức làm khoảng dự đoán rộng hơn', () {
      final r = Random(11);
      // số đơn dao động mạnh hơn Poisson: mỗi ngày nhân ngẫu nhiên 0.3..2.2
      final noisy = <DayObs>[
        for (var i = 0; i < 200; i++)
          DayObs(DateTime(2025, 1, 6 + i), _poisson(r, 8 * (0.3 + r.nextDouble() * 1.9))),
      ];
      final calm = _simulate(days: 200, seed: 11, sat: 0, sun: 0, rain: 0);
      final a = BookingCountModel.fit(noisy), b = BookingCountModel.fit(calm);
      expect(a.phi, greaterThan(b.phi));
      final fa = a.predict(DateTime(2026, 2, 3)), fb = b.predict(DateTime(2026, 2, 3));
      expect(fa.high - fa.low, greaterThan(fb.high - fb.low));
    });
  });

  group('Dự đoán', () {
    final model = BookingCountModel.fit(_simulate(days: 500, seed: 21));

    test('Cuối tuần > ngày thường, mưa to < trời đẹp', () {
      final mon = model.predict(DateTime(2026, 3, 2), weather: const WeatherInput(tempMax: 28, tempMin: 22, rainMm: 0));
      final sat = model.predict(DateTime(2026, 3, 7), weather: const WeatherInput(tempMax: 28, tempMin: 22, rainMm: 0));
      final satRain = model.predict(DateTime(2026, 3, 7), weather: const WeatherInput(tempMax: 28, tempMin: 22, rainMm: 12));
      expect(sat.expected, greaterThan(mon.expected * 1.3));
      expect(satRain.expected, lessThan(sat.expected * 0.6));
    });

    test('Khoảng dự đoán hợp lệ: 0 <= thấp <= kỳ vọng <= cao', () {
      for (var i = 0; i < 14; i++) {
        final f = model.predict(DateTime(2026, 5, 1 + i), weather: const WeatherInput(tempMax: 33, tempMin: 26, rainMm: 2));
        expect(f.low, greaterThanOrEqualTo(0));
        expect(f.low, lessThanOrEqualTo(f.expected));
        expect(f.expected, lessThanOrEqualTo(f.high));
      }
    });

    test('Ngày Tết giảm mạnh, ngày lễ nghỉ tăng nhẹ so với giả định', () {
      final fresh = BookingCountModel.fit(const []);
      final tet = fresh.predict(DateTime(2026, 2, 17)); // mùng 1 Tết Bính Ngọ
      final canTet = fresh.predict(DateTime(2026, 2, 10)); // 7 ngày trước Tết: chỉ giảm nhẹ
      final normal = fresh.predict(DateTime(2026, 2, 3)); // thứ Ba thường
      expect(tet.factors.any((f) => f.key == 'tet'), isTrue);
      expect(tet.expected, closeTo(normal.expected * 0.3, normal.expected * 0.03), reason: 'mùng 1 Tết còn ~30% theo lịch');
      expect(canTet.expected, lessThan(normal.expected));
      expect(canTet.expected, greaterThan(tet.expected), reason: 'cận Tết nhẹ hơn mùng 1');
      final qt = fresh.predict(DateTime(2026, 9, 2)); // Quốc khánh
      expect(qt.factors.any((f) => f.key == 'holiday'), isTrue);
    });

    test('Thiếu thời tiết: đánh dấu weatherMissing và không có chip mưa/nóng/lạnh', () {
      final f = model.predict(DateTime(2026, 3, 7));
      expect(f.weatherMissing, isTrue);
      expect(f.factors.any((x) => x.key == 'rain' || x.key == 'heat' || x.key == 'cold'), isFalse);
    });

    test('Có thời tiết cực đoan thì liệt kê đúng yếu tố, kèm số liệu', () {
      final f = model.predict(DateTime(2026, 1, 10), weather: const WeatherInput(tempMax: 36, tempMin: 12, rainMm: 8));
      final keys = f.factors.map((x) => x.key).toSet();
      expect(keys, containsAll(['sat', 'rain', 'heat', 'cold', 'winter']));
      expect(f.factors.firstWhere((x) => x.key == 'rain').detail, contains('8.0 mm'));
      expect(f.season, Season.winter);
    });

    test('Nhãn nguồn: yếu tố học từ nhiều dữ liệu ghi "học từ dữ liệu", giả định thì ghi rõ', () {
      final f = model.predict(DateTime(2026, 3, 7), weather: const WeatherInput(tempMax: 28, tempMin: 22, rainMm: 5));
      expect(f.factors.firstWhere((x) => x.key == 'sat').sourceText, startsWith('học từ dữ liệu'));
      final fresh = BookingCountModel.fit(const []).predict(DateTime(2026, 3, 7));
      expect(fresh.factors.firstWhere((x) => x.key == 'sat').sourceText, 'giả định chuyên môn');
    });
  });

  group('Kiểm định chéo', () {
    test('Quá ít ngày thì không kiểm định', () {
      expect(BookingCountModel.crossValidate(_simulate(days: 5)), isNull);
    });

    test('Dữ liệu có quy luật rõ: tốt hơn đường cơ sở "luôn đoán trung bình"', () {
      final cv = BookingCountModel.crossValidate(_simulate(days: 200, seed: 31))!;
      expect(cv.days, 200);
      expect(cv.mae, lessThan(cv.maeMean), reason: cv.toString());
      expect(cv.beatsMean, isTrue);
      expect(cv.improvementOverMean, greaterThan(0.1));
      expect(cv.coverage, inInclusiveRange(0.6, 1.0));
    });

    test('Dữ liệu không có quy luật: không tuyên bố mô hình tốt hơn một cách vô lý', () {
      final r = Random(41);
      final flat = [for (var i = 0; i < 120; i++) DayObs(DateTime(2025, 1, 6 + i), _poisson(r, 6), const WeatherInput(tempMax: 30, tempMin: 24, rainMm: 0))];
      final cv = BookingCountModel.crossValidate(flat)!;
      // mô hình chỉ được hơn đường cơ sở một chút hoặc kém không đáng kể
      expect(cv.improvementOverMean, lessThan(0.15), reason: cv.toString());
    });

    test('Nhiều ngày (>40) dùng 10 phần và vẫn chạy', () {
      final cv = BookingCountModel.crossValidate(_simulate(days: 300, seed: 51))!;
      expect(cv.days, 300);
      expect(cv.mae.isFinite, isTrue);
    });
  });

  group('Lịch sử thời tiết Open-Meteo', () {
    setUp(WeatherHistoryService.clearCache);

    Map<String, dynamic> daily(List<String> dates) => <String, dynamic>{
          'daily': <String, dynamic>{
            'time': dates,
            'temperature_2m_max': <double?>[for (var i = 0; i < dates.length; i++) 30.0 + i],
            'temperature_2m_min': <double?>[for (var i = 0; i < dates.length; i++) 24.0 + i],
            'precipitation_sum': <double?>[for (var i = 0; i < dates.length; i++) i == 1 ? 6.5 : 0.0],
          }
        };

    test('parseDaily bỏ ngày thiếu số liệu', () {
      final data = daily(['2026-11-10', '2026-11-11', '2026-11-12']);
      (data['daily'] as Map<String, dynamic>)['temperature_2m_max'] = <double?>[30.0, null, 32.0];
      final out = WeatherHistoryService.parseDaily(data);
      expect(out.keys, ['2026-11-10', '2026-11-12']);
      expect(out['2026-11-12']!.tempMax, 32);
    });

    test('parseDaily với dữ liệu hỏng trả về rỗng, không ném lỗi', () {
      expect(WeatherHistoryService.parseDaily({'foo': 1}), isEmpty);
      expect(WeatherHistoryService.parseDaily({'daily': 'x'}), isEmpty);
    });

    test('Ngày gần đây lấy từ API dự báo với past_days, lần sau dùng bản nhớ', () async {
      var calls = 0;
      Uri? last;
      final client = MockClient((r) async {
        calls++;
        last = r.url;
        return http.Response(jsonEncode(daily(['2026-11-20', '2026-11-21', '2026-11-22', '2026-11-23'])), 200, headers: _json);
      });
      await http.runWithClient(() async {
        final w = await WeatherHistoryService.load(DateTime(2026, 11, 20), DateTime(2026, 11, 23), today: DateTime(2026, 11, 24));
        expect(w.length, 4);
        expect(w['2026-11-21']!.rainMm, 6.5);
        expect(last!.host, 'api.open-meteo.com');
        expect(last!.queryParameters['past_days'], '4');
        final again = await WeatherHistoryService.load(DateTime(2026, 11, 21), DateTime(2026, 11, 22), today: DateTime(2026, 11, 24));
        expect(again.length, 2);
        expect(calls, 1, reason: 'ngày đã qua không đổi nên không gọi lại');
      }, () => client);
    });

    test('Ngày rất cũ lấy từ kho lưu trữ (archive)', () async {
      final hosts = <String>[];
      final client = MockClient((r) async {
        hosts.add(r.url.host);
        return http.Response(jsonEncode(daily(['2025-01-10', '2025-01-11'])), 200, headers: _json);
      });
      await http.runWithClient(() async {
        final w = await WeatherHistoryService.load(DateTime(2025, 1, 10), DateTime(2025, 1, 11), today: DateTime(2026, 11, 24));
        expect(w.length, 2);
        expect(hosts, ['archive-api.open-meteo.com']);
      }, () => client);
    });

    test('Lỗi mạng hoặc 500: trả bản đồ rỗng, không ném lỗi', () async {
      await http.runWithClient(() async {
        expect(await WeatherHistoryService.load(DateTime(2026, 11, 20), DateTime(2026, 11, 23), today: DateTime(2026, 11, 24)), isEmpty);
      }, () => MockClient((r) async => throw Exception('mất mạng')));
      await http.runWithClient(() async {
        expect(await WeatherHistoryService.load(DateTime(2026, 11, 20), DateTime(2026, 11, 23), today: DateTime(2026, 11, 24)), isEmpty);
      }, () => MockClient((r) async => http.Response('{}', 500)));
    });

    test('Hôm nay và tương lai không được coi là lịch sử', () async {
      var calls = 0;
      final client = MockClient((r) async {
        calls++;
        return http.Response('{}', 200);
      });
      await http.runWithClient(() async {
        final w = await WeatherHistoryService.load(DateTime(2026, 11, 25), DateTime(2026, 11, 30), today: DateTime(2026, 11, 24));
        expect(w, isEmpty);
        expect(calls, 0);
      }, () => client);
    });
  });
}
