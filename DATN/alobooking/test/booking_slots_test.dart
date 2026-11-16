import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/services/booking_slots.dart';

Venue _venue(String price) => Venue(
      id: 1,
      name: 'Sân Test',
      type: 'badminton',
      district: 'Cầu Giấy',
      distance: '1km',
      address: 'Hà Nội',
      hours: '05:00 – 23:00',
      tags: const [],
      rating: 4.5,
      price: price,
      lat: 21,
      lng: 105,
      image: '',
      logo: '',
    );

void main() {
  group('parseDate', () {
    test('nhận cả dd/MM/yyyy và yyyy-MM-dd', () {
      expect(BookingSlots.parseDate('31/10/2026'), DateTime(2026, 10, 31));
      expect(BookingSlots.parseDate('2026-10-31'), DateTime(2026, 10, 31));
      expect(BookingSlots.parseDate('1/2/2026'), DateTime(2026, 2, 1));
    });
    test('sai định dạng trả về null', () {
      expect(BookingSlots.parseDate('abc'), isNull);
      expect(BookingSlots.parseDate(''), isNull);
    });
    test('sameDay so đúng ngày', () {
      expect(BookingSlots.sameDay('31/10/2026', DateTime(2026, 10, 31)), isTrue);
      expect(BookingSlots.sameDay('2026-10-31', DateTime(2026, 10, 31)), isTrue);
      expect(BookingSlots.sameDay('30/10/2026', DateTime(2026, 10, 31)), isFalse);
    });
  });

  group('occupiedHours', () {
    test('ca lẻ chiếm đủ các giờ nguyên', () {
      expect(BookingSlots.occupiedHours('18:30 - 20:00'), {18, 19});
      expect(BookingSlots.occupiedHours('06:00 - 07:30'), {6, 7});
    });
    test('nhiều ca nối bằng dấu phẩy', () {
      expect(BookingSlots.occupiedHours('18:00 - 19:00, 21:00 - 22:00'), {18, 21});
    });
    test('chuỗi rác không ném lỗi', () {
      expect(BookingSlots.occupiedHours('không rõ'), isEmpty);
    });
  });

  group('courtIndex', () {
    test('lấy số cuối làm số sân', () {
      expect(BookingSlots.courtIndex('Sân #2', 3), 1);
      expect(BookingSlots.courtIndex('Pickleball 3', 3), 2);
    });
    test('số vượt quá số sân thì quay vòng, không vượt biên', () {
      expect(BookingSlots.courtIndex('Sân 7', 3), 0);
      expect(BookingSlots.courtIndex('Sân Chuẩn Thi Đấu', 3), 0);
    });
  });

  test('mergeHours gộp giờ liền kề', () {
    expect(BookingSlots.mergeHours([19, 18, 21]), ['18:00 - 20:00', '21:00 - 22:00']);
    expect(BookingSlots.mergeHours([]), isEmpty);
  });

  test('isCancelled', () {
    expect(BookingSlots.isCancelled('Đã hủy'), isTrue);
    expect(BookingSlots.isCancelled('Đã xác nhận'), isFalse);
    expect(BookingSlots.isCancelled('Chờ xác nhận'), isFalse);
  });

  group('priceForHour', () {
    test('giá thường trước 17h, giá cao từ 17h', () {
      final v = _venue('80k - 160k/h');
      expect(BookingSlots.priceForHour(v, 10), 80000);
      expect(BookingSlots.priceForHour(v, 16), 80000);
      expect(BookingSlots.priceForHour(v, 17), 160000);
      expect(BookingSlots.priceForHour(v, 20), 160000);
    });
    test('giá không đọc được thì dùng mặc định', () {
      expect(BookingSlots.priceForHour(_venue('liên hệ'), 10), 150000);
    });
  });
}
