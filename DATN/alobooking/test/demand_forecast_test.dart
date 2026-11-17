import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/services/demand_forecast_service.dart';
import 'package:alobooking/services/firestore_service.dart';
import 'package:alobooking/services/weather_service.dart';

String d(DateTime t) => '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';

/// Dữ liệu tổng hợp có quy luật rõ ràng: đơn tiền mặt hủy nhiều, trả trước hiếm khi hủy.
List<BookingItem> synthetic({int days = 30}) {
  final out = <BookingItem>[];
  final rnd = Random(42); // hạt giống cố định: kết quả lặp lại được
  final start = DateTime(2026, 10, 1);
  var id = 0;
  for (var i = 0; i < days; i++) {
    final day = start.add(Duration(days: i));
    final weekend = day.weekday >= 6;
    final perDay = weekend ? 8 : 5;
    for (var k = 0; k < perDay; k++) {
      id++;
      final cash = k % 3 == 0;
      // Tiền mặt: hủy 70%; trả trước: hủy 5%
      final cancelled = rnd.nextDouble() < (cash ? 0.7 : 0.05);
      out.add(BookingItem(
        id: 'B$id',
        customer: 'K$id',
        phone: '09$id',
        venueName: 'Sân A',
        field: 'Sân 1',
        time: '${17 + (k % 4)}:00 - ${18 + (k % 4)}:00',
        date: d(day),
        amount: '150,000đ',
        status: cancelled ? 'Đã hủy' : 'Đã xác nhận',
        paymentMethod: cash ? 'Tiền mặt tại sân' : 'Ví MoMo',
        createdAt: day.subtract(Duration(days: k % 4)),
      ));
    }
  }
  return out;
}

void main() {
  group('Lịch ngày nghỉ', () {
    test('ngày lễ cố định', () {
      expect(VnCalendar.holidayOn(DateTime(2027, 1, 1))?.name, 'Tết Dương lịch');
      expect(VnCalendar.holidayOn(DateTime(2026, 9, 2))?.dayOff, isTrue);
      expect(VnCalendar.holidayOn(DateTime(2026, 11, 20))?.dayOff, isFalse); // 20/11 không nghỉ
      expect(VnCalendar.holidayOn(DateTime(2026, 11, 18)), isNull);
    });

    test('Tết Nguyên Đán làm giảm nhu cầu', () {
      expect(VnCalendar.holidayOn(DateTime(2027, 2, 6))!.demandFactor, lessThan(0.5));
      expect(VnCalendar.holidayOn(DateTime(2027, 2, 6))!.dayOff, isTrue);
      expect(VnCalendar.holidayOn(DateTime(2027, 2, 1))!.demandFactor, lessThan(1)); // cận Tết
    });

    test('cuối tuần là ngày nghỉ', () {
      expect(VnCalendar.isDayOff(DateTime(2026, 11, 21)), isTrue); // thứ Bảy
      expect(VnCalendar.isDayOff(DateTime(2026, 11, 18)), isFalse);
    });
  });

  group('Mô hình hủy', () {
    final data = synthetic();
    final model = DemandModel.fit(data);

    test('học được tiền mặt hủy nhiều hơn trả trước', () {
      expect(model.oddsRatios['thanh toán tiền mặt tại sân']!, greaterThan(5));
      final cash = model.cancelProbabilityForBooking(date: DateTime(2026, 11, 18), startHour: 18, cash: true, leadDays: 1);
      final prepaid = model.cancelProbabilityForBooking(date: DateTime(2026, 11, 18), startHour: 18, cash: false, leadDays: 1);
      expect(cash, greaterThan(0.4));
      expect(prepaid, lessThan(0.2));
      expect(cash, greaterThan(prepaid * 3));
    });

    test('xác suất luôn nằm trong [0,1]', () {
      for (final cash in [true, false]) {
        for (final h in [6, 12, 19, 22]) {
          final p = model.cancelProbabilityForBooking(
              date: DateTime(2027, 2, 6), startHour: h, cash: cash, leadDays: 5, rain: const DayRain(100, 50), sport: 'football');
          expect(p, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('mưa to làm tăng xác suất hủy (giả định), sân ngoài trời nhạy hơn sân trong nhà', () {
      DateTime day = DateTime(2026, 11, 18);
      double p(DayRain? r, String? sport) =>
          model.cancelProbabilityForBooking(date: day, startHour: 18, cash: false, leadDays: 1, rain: r, sport: sport);
      const storm = DayRain(95, 35);
      expect(p(storm, 'football'), greaterThan(p(null, 'football')));
      expect(p(storm, 'football') - p(null, 'football'), greaterThan(p(storm, 'badminton') - p(null, 'badminton')));
    });

    test('kiểm định chéo: tốt hơn đoán theo tỉ lệ chung', () {
      final cv = DemandModel.crossValidate(data);
      expect(cv.brier, lessThan(cv.brierBaseline));
      expect(cv.auc, greaterThan(0.8));
    });
  });

  group('Mô hình nhu cầu', () {
    final model = DemandModel.fit(synthetic());

    test('cuối tuần đông hơn ngày thường', () {
      final sat = model.forecastDay(DateTime(2026, 11, 21));
      final wed = model.forecastDay(DateTime(2026, 11, 18));
      expect(sat.demandMultiplier, greaterThan(wed.demandMultiplier));
      expect(sat.expectedBookings!, greaterThan(wed.expectedBookings!));
    });

    test('mưa lớn làm giảm nhu cầu, Tết giảm mạnh', () {
      final dry = model.forecastDay(DateTime(2026, 11, 18), rain: const DayRain(0, 0));
      final storm = model.forecastDay(DateTime(2026, 11, 18), rain: const DayRain(95, 35));
      expect(storm.demandMultiplier, lessThan(dry.demandMultiplier));
      final tet = model.forecastDay(DateTime(2027, 2, 6));
      expect(tet.demandMultiplier, lessThan(0.5));
      expect(tet.level, anyOf('RẤT THẤP', 'THẤP'));
    });

    test('dự báo tương lai tính theo nhóm trả trước (đã bỏ tiền mặt), thấp hơn nhóm tiền mặt cũ', () {
      final f = model.forecastDay(DateTime(2026, 11, 18));
      expect(f.cancelRate, closeTo(f.cancelRatePrepaid, 1e-9));
      expect(f.cancelRate, lessThan(f.cancelRateCash));
    });

    test('văn bản dự đoán nói rõ là ước lượng và nêu độ tin cậy', () {
      final text = DemandForecastService.buildPromptSection(
        synthetic(),
        DateTime(2026, 11, 21),
        today: DateTime(2026, 11, 17),
      );
      expect(text, contains('DỰ ĐOÁN'));
      expect(text, contains('Độ tin cậy'));
      expect(text, contains('TỔNG QUAN 7 NGÀY TỚI'));
      expect(text, isNot(contains('trả tiền mặt tại sân')));
      expect(text, contains('chuyển khoản'));
    });
  });

  test('không có dữ liệu: không lỗi, không bịa số đơn, cảnh báo độ tin cậy rất thấp', () {
    final model = DemandModel.fit(const []);
    final f = model.forecastDay(DateTime(2026, 11, 18));
    expect(f.expectedBookings, isNull);
    expect(f.cancelRate, inInclusiveRange(0.0, 1.0));
    expect(f.confidence, contains('RẤT THẤP'));
  });
}
