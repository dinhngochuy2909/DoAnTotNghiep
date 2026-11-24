import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/services/booking_count_model.dart';
import 'package:alobooking/services/booking_slots.dart';
import 'package:alobooking/services/simulated_bookings.dart';

/// Thời tiết thật đã tải sẵn (tool/crawl_weather.py) để test không cần mạng.
Map<String, WeatherInput> _weatherFromCsv() {
  final out = <String, WeatherInput>{};
  final lines = File('data/hanoi_weather_daily.csv').readAsLinesSync().skip(1);
  for (final l in lines) {
    final p = l.split(',');
    if (p.length < 4) continue;
    out[p[0]] = WeatherInput(tempMax: double.parse(p[1]), tempMin: double.parse(p[2]), rainMm: double.parse(p[3]));
  }
  return out;
}

void main() {
  late SimulatedBookings sim;
  late Map<String, WeatherInput> wx;
  setUpAll(() {
    sim = SimulatedBookings.parse(File('assets/demo/simulated_bookings.json').readAsStringSync())!;
    wx = _weatherFromCsv();
  });

  group('Đọc file mô phỏng', () {
    test('Có cờ mô phỏng, đáp án, và mọi mã đơn mang tiền tố SIM-', () {
      expect(sim.warning, contains('KHÔNG phải đơn đặt sân thật'));
      expect(sim.truth.keys, containsAll(['intercept', 'sat', 'sun', 'rain', 'tet', 'summer']));
      expect(sim.bookings, isNotEmpty);
      expect(sim.bookings.every(SimulatedBookings.isSimulated), isTrue);
      expect(sim.days, 319);
      expect(sim.retained, greaterThan(1500));
      expect(sim.bookings.any((b) => BookingSlots.isCancelled(b.status)), isTrue, reason: 'có đơn hủy để mô hình bỏ qua');
    });

    test('Mỗi đơn đọc ra đủ trường hợp lệ (ngày, giờ, tiền, ngày đặt trước ngày chơi)', () {
      for (final b in sim.bookings.take(300)) {
        final d = BookingSlots.parseDate(b.date);
        expect(d, isNotNull, reason: b.id);
        expect(BookingSlots.parseRanges(b.time), isNotEmpty, reason: b.time);
        expect(b.amount, matches(RegExp(r'^\d{2,3}\.000đ$')));
        expect(b.createdAt.isAfter(d!), isFalse, reason: 'không đặt sau ngày chơi');
        expect(b.venueName, startsWith('Sân mô phỏng'));
      }
    });

    test('Từ chối file không có cờ mô phỏng hoặc sai định dạng (không coi file lạ là dữ liệu mô phỏng)', () {
      expect(SimulatedBookings.parse('{"meta":{"simulated":false},"bookings":[]}'), isNull);
      expect(SimulatedBookings.parse('{"bookings":[]}'), isNull);
      expect(SimulatedBookings.parse('không phải json'), isNull);
    });

    test('Mỗi ngày mô phỏng đều có thời tiết thật tương ứng', () {
      final obs = BookingCountModel.observationsFromBookings(sim.bookings, wx, today: DateTime(2026, 11, 24));
      expect(obs.length, 319, reason: 'không có ngày trống kéo dài trong giai đoạn mô phỏng');
      expect(obs.every((o) => o.weather != null), isTrue);
    });
  });

  group('Mô hình tìm lại đáp án đã gài', () {
    late BookingCountModel model;
    late CountCv cv;
    setUpAll(() {
      final obs = BookingCountModel.observationsFromBookings(sim.bookings, wx, today: DateTime(2026, 11, 24));
      model = BookingCountModel.fit(obs);
      cv = BookingCountModel.crossValidate(obs)!;
      // ignore: avoid_print
      print('Đối chiếu đáp án (mô hình / đáp án / giả định ban đầu / % dữ liệu):');
      for (final c in model.coefficientInfo) {
        // ignore: avoid_print
        print('  ${c.key.padRight(8)} ${c.learned.toStringAsFixed(2).padLeft(6)} / ${sim.truth[c.key]!.toStringAsFixed(2).padLeft(6)} / ${c.prior.toStringAsFixed(2).padLeft(6)} / ${(c.dataShare * 100).round()}%');
      }
      // ignore: avoid_print
      print('  nền ${model.intercept.toStringAsFixed(2)} (đáp án ${_exp(sim.truth['intercept']!).toStringAsFixed(2)}) | $cv');
    });

    test('Thứ Bảy và mưa (giả định ban đầu lệch xa đáp án) được dữ liệu kéo về gần đáp án hơn hẳn', () {
      final byKey = {for (final c in model.coefficientInfo) c.key: c};
      for (final k in ['sat', 'rain']) {
        final c = byKey[k]!;
        final truth = sim.truth[k]!;
        expect((c.learned - truth).abs(), lessThan((c.prior - truth).abs() * 0.7), reason: '$k: gần đáp án hơn giả định ít nhất 30%');
        expect(c.dataShare, greaterThan(0.8), reason: '$k có nhiều bằng chứng từ dữ liệu');
      }
    });

    test('Mọi hệ số nhiều bằng chứng đều đúng chiều ảnh hưởng so với đáp án (không đảo dấu)', () {
      for (final c in model.coefficientInfo) {
        final truth = sim.truth[c.key]!;
        if (c.dataShare > 0.8 && truth.abs() > 0.15) {
          expect(c.learned.sign, truth.sign, reason: '${c.key}: học ${c.learned}, đáp án $truth');
        }
      }
    });

    test('Sai lệch nhỏ với thứ Bảy, Chủ Nhật, mưa và mức nền', () {
      final c = model.coefficients;
      expect(c['sat'], closeTo(sim.truth['sat']!, 0.2));
      expect(c['sun'], closeTo(sim.truth['sun']!, 0.2));
      expect(c['rain'], closeTo(sim.truth['rain']!, 0.25));
      expect(model.intercept, closeTo(8.0, 1.5));
    });

    test('Yếu tố ít bằng chứng (Tết: chỉ một dịp) vẫn bị kéo về giả định, không học bậy', () {
      final tet = model.coefficientInfo.firstWhere((c) => c.key == 'tet');
      expect(tet.dataShare, lessThan(0.9), reason: 'chỉ có một kỳ Tết trong dữ liệu');
      expect(tet.learned, lessThan(0), reason: 'vẫn đúng chiều: Tết giảm nhu cầu');
    });

    test('Kiểm định chéo: tốt hơn rõ rệt cách luôn đoán trung bình và cách chỉ dùng giả định', () {
      expect(cv.beatsMean, isTrue, reason: cv.toString());
      expect(cv.improvementOverMean, greaterThan(0.15), reason: cv.toString());
      expect(cv.mae, lessThan(cv.maePrior), reason: cv.toString());
      expect(cv.coverage, inInclusiveRange(0.7, 0.95), reason: 'khoảng 80% phải phủ khoảng 80% ngày thật: ${cv.coverage}');
    });

    test('Dự đoán một thứ Bảy mưa to thấp hơn thứ Bảy đẹp trời cùng mùa', () {
      const fine = WeatherInput(tempMax: 28, tempMin: 20, rainMm: 0);
      const wet = WeatherInput(tempMax: 28, tempMin: 20, rainMm: 12);
      final a = model.predict(DateTime(2026, 3, 7), weather: fine);
      final b = model.predict(DateTime(2026, 3, 7), weather: wet);
      expect(b.expected, lessThan(a.expected * 0.7));
      expect(a.expected, greaterThan(model.predict(DateTime(2026, 3, 4), weather: fine).expected * 1.3));
    });
  });
}

double _exp(double x) => double.parse(_e(x));
String _e(double x) {
  var v = 1.0, term = 1.0;
  for (var i = 1; i < 40; i++) {
    term *= x / i;
    v += term;
  }
  return v.toString();
}
