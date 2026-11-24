import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/services/booking_slots.dart';
import 'package:alobooking/services/firestore_service.dart';

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
    test('ca giờ vàng 16:00 – 22:00 tính giá cao, ngoài ca tính giá thường', () {
      final v = _venue('80k - 100k/h');
      expect(BookingSlots.priceForHour(v, 10), 80000);
      expect(BookingSlots.priceForHour(v, 15), 80000);
      expect(BookingSlots.priceForHour(v, 16), 100000);
      expect(BookingSlots.priceForHour(v, 20), 100000);
      expect(BookingSlots.priceForHour(v, 21), 100000);
      expect(BookingSlots.priceForHour(v, 22), 80000);
    });
    test('isGolden đúng biên ca vàng', () {
      expect([15, 16, 21, 22].map(BookingSlots.isGolden), [false, true, true, false]);
    });
    test('khoảng giá nhập ngược vẫn cho giờ vàng là mức cao hơn', () {
      final v = _venue('100k - 80k/h');
      expect(BookingSlots.priceForHour(v, 10), 80000);
      expect(BookingSlots.priceForHour(v, 18), 100000);
    });
    test('giá không đọc được thì dùng mặc định', () {
      expect(BookingSlots.priceForHour(_venue('liên hệ'), 10), 150000);
    });
  });

  group('Lịch trống của nhiều sân (trang Khám phá)', () {
    BookingItem b(String venue, String field, String time, String date, {String status = 'Đã đặt'}) => BookingItem(
          id: '$venue$field$time$date',
          customer: 'Khách',
          phone: '0900000000',
          venueName: venue,
          field: field,
          time: time,
          date: date,
          amount: '100000',
          status: status,
          paymentMethod: 'Chuyển khoản',
        );

    test('openRange: đọc giờ mở cửa, làm tròn giờ đóng lên và kẹp trong 05:00 - 24:00', () {
      expect(BookingSlots.openRange('06:00 – 23:00'), (6, 23));
      expect(BookingSlots.openRange('05:00 - 22:30'), (5, 23));
      expect(BookingSlots.openRange('04:00 – 24:00'), (5, 24));
      expect(BookingSlots.openRange('18:00 – 02:00'), (18, 24));
      expect(BookingSlots.openRange('không rõ'), (5, 23));
      expect(BookingSlots.openRange(''), (5, 23));
    });

    test('bookedIndex chỉ lấy đúng ngày, bỏ đơn đã hủy, nhận cả hai định dạng ngày', () {
      final day = DateTime(2026, 11, 21);
      final idx = BookingSlots.bookedIndex([
        b('Sân Test', 'Cầu lông 1', '18:00 - 19:30', '21/11/2026'),
        b('Sân Test', 'Cầu lông 2', '20:00 - 21:00', '2026-11-21'),
        b('Sân Test', 'Cầu lông 1', '09:00 - 10:00', '22/11/2026'),
        b('Sân Test', 'Cầu lông 1', '12:00 - 13:00', '21/11/2026', status: 'Đã hủy'),
        b('Sân Khác', 'Sân 1', '07:00 - 08:00', '21/11/2026'),
      ], day);
      final slots = BookingSlots.slotsFromIndex(idx, _venue('80k - 100k/h'), 8);
      expect(slots, {'0-18', '0-19', '1-20'});
      expect(BookingSlots.slotsFromIndex(idx, _venue('80k - 100k/h').copyWith(name: 'sân   test'), 8), slots,
          reason: 'tên sân so khớp không phân biệt hoa thường/khoảng trắng');
      expect(BookingSlots.slotsFromIndex(idx, _venue('80k - 100k/h').copyWith(name: 'Chưa có đơn'), 8), isEmpty);
    });

    test('freeCourts đếm số sân con còn trống trong một giờ', () {
      final booked = {'0-18', '1-18', '2-19'};
      expect(BookingSlots.freeCourts(booked, 4, 18), 2);
      expect(BookingSlots.freeCourts(booked, 4, 19), 3);
      expect(BookingSlots.freeCourts(booked, 2, 18), 0);
      expect(BookingSlots.freeCourts(booked, 4, 10), 4);
    });
  });
}
