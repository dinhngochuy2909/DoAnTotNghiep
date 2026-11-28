import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/services/venue_hours.dart';

DateTime _at(int h, [int m = 0]) => DateTime(2026, 11, 25, h, m);

void main() {
  group('VenueHours.statusAt', () {
    test('trong giờ hoạt động thì đang mở; đúng giờ mở là mở, đúng giờ đóng là đã đóng', () {
      const h = '05:30 – 23:00';
      expect(VenueHours.statusAt(h, _at(5, 29)), OpenStatus.closed);
      expect(VenueHours.statusAt(h, _at(5, 30)), OpenStatus.open);
      expect(VenueHours.statusAt(h, _at(12)), OpenStatus.open);
      expect(VenueHours.statusAt(h, _at(22, 59)), OpenStatus.open);
      expect(VenueHours.statusAt(h, _at(23)), OpenStatus.closed);
      expect(VenueHours.statusAt(h, _at(0, 40)), OpenStatus.closed);
    });

    test('sân mở qua nửa đêm: mở từ giờ mở đến sáng hôm sau', () {
      const h = '18:00 - 02:00';
      expect(VenueHours.statusAt(h, _at(23)), OpenStatus.open);
      expect(VenueHours.statusAt(h, _at(1, 59)), OpenStatus.open);
      expect(VenueHours.statusAt(h, _at(2)), OpenStatus.closed);
      expect(VenueHours.statusAt(h, _at(12)), OpenStatus.closed);
      expect(VenueHours.statusAt(h, _at(18)), OpenStatus.open);
    });

    test('mở và đóng cùng một giờ thì coi là mở cả ngày', () {
      expect(VenueHours.statusAt('00:00 – 00:00', _at(3)), OpenStatus.open);
    });

    test('đọc được cả dấu gạch ngang thường, gạch dài và khoảng trắng tùy ý', () {
      expect(VenueHours.statusAt('06:00-22:00', _at(7)), OpenStatus.open);
      expect(VenueHours.statusAt('06:00 — 22:00', _at(7)), OpenStatus.open);
      expect(VenueHours.statusAt('6:00 – 22:00', _at(5)), OpenStatus.closed);
    });

    test('chuỗi giờ không đọc được hoặc vô lý thì không đoán (unknown)', () {
      expect(VenueHours.statusAt('', _at(9)), OpenStatus.unknown);
      expect(VenueHours.statusAt('Cả ngày', _at(9)), OpenStatus.unknown);
      expect(VenueHours.statusAt('Liên hệ', _at(9)), OpenStatus.unknown);
      expect(VenueHours.statusAt('25:00 – 30:00', _at(9)), OpenStatus.unknown);
    });
  });
}
