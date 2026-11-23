import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/services/venue_cache.dart';
import 'package:alobooking/services/venue_cache_store.dart';

Venue _v(int id, {String name = '', String status = 'approved', String image = '', DateTime? approvedAt}) => Venue(
      id: id,
      name: name.isEmpty ? 'Sân $id' : name,
      type: 'badminton',
      district: 'Cầu Giấy',
      distance: '',
      address: '$id Phố Thử',
      hours: '06:00 – 22:00',
      tags: const ['Đèn LED'],
      rating: 4.5,
      price: '80k - 100k/h',
      lat: 21.0,
      lng: 105.8,
      image: image,
      logo: '',
      approvalStatus: status,
      courtCount: 6,
      source: '',
      approvedAt: approvedAt,
    );

void main() {
  var now = DateTime(2026, 11, 23, 10, 0);

  setUp(() {
    now = DateTime(2026, 11, 23, 10, 0);
    VenueCache.clock = () => now;
    VenueCache.clear();
  });

  tearDown(() {
    VenueCache.clock = DateTime.now;
    VenueCache.clear();
  });

  group('Ghi và đọc', () {
    test('chưa có gì thì read là null', () {
      expect(VenueCache.read(), isNull);
    });

    test('ghi rồi đọc lại đủ mọi trường của sân', () {
      final at = DateTime(2026, 11, 20, 9, 30);
      VenueCache.write([_v(2, approvedAt: at), _v(1, name: 'Sân Alpha')]);
      final r = VenueCache.read()!;
      expect(r.savedAt, now);
      expect(r.venues.length, 2);
      final one = r.venues.firstWhere((v) => v.id == 1);
      expect(one.name, 'Sân Alpha');
      expect(one.tags, ['Đèn LED']);
      expect(one.courtCount, 6);
      expect(r.venues.firstWhere((v) => v.id == 2).approvedAt, at);
    });

    test('sau khi quên bộ nhớ trong (tải lại trang) vẫn đọc được từ nơi lưu', () {
      VenueCache.write([_v(1), _v(2)]);
      VenueCache.forgetMemoryForTest();
      final r = VenueCache.read()!;
      expect(r.venues.map((v) => v.id), [1, 2]);
      expect(r.savedAt, now);
    });

    test('danh sách trả về là bản sao: sửa nó không làm hỏng bản nhớ', () {
      VenueCache.write([_v(1)]);
      VenueCache.read()!.venues.clear();
      expect(VenueCache.read()!.venues.length, 1);
    });

    test('clear xóa cả bộ nhớ trong lẫn nơi lưu', () {
      VenueCache.write([_v(1)]);
      VenueCache.clear();
      expect(VenueCache.read(), isNull);
      expect(readStoredText(VenueCache.storageKey), isNull);
    });
  });

  group('Độ mới', () {
    test('mới trong 30 phút, hết mới sau đó', () {
      final saved = now;
      now = saved.add(const Duration(minutes: 30));
      expect(VenueCache.isFresh(saved), isTrue, reason: 'đúng 30 phút vẫn còn mới');
      now = saved.add(const Duration(minutes: 30, seconds: 1));
      expect(VenueCache.isFresh(saved), isFalse);
    });

    test('đồng hồ máy chạy lùi (tuổi âm) thì coi là không mới', () {
      final saved = now;
      now = saved.subtract(const Duration(minutes: 5));
      expect(VenueCache.isFresh(saved), isFalse);
    });

    test('bản cũ vẫn đọc được để dùng khi máy chủ lỗi, nhưng quá 3 ngày thì bỏ hẳn', () {
      VenueCache.write([_v(1)]);
      now = now.add(const Duration(days: 2, hours: 23));
      expect(VenueCache.read(), isNotNull);
      now = now.add(const Duration(hours: 2));
      expect(VenueCache.read(), isNull);
      expect(readStoredText(VenueCache.storageKey), isNull, reason: 'bản quá cũ bị xóa luôn khỏi nơi lưu');
    });
  });

  group('Bản lưu hỏng hoặc quá lớn', () {
    test('bản lưu hỏng thì bỏ qua và xóa đi', () {
      writeStoredText(VenueCache.storageKey, '{không phải json');
      expect(VenueCache.read(), isNull);
      expect(readStoredText(VenueCache.storageKey), isNull);
    });

    test('bản lưu của phiên bản khác hoặc rỗng thì bỏ qua', () {
      writeStoredText(VenueCache.storageKey, jsonEncode({'v': 2, 'savedAt': now.toIso8601String(), 'venues': []}));
      expect(VenueCache.read(), isNull);
      writeStoredText(VenueCache.storageKey, jsonEncode({'v': 1, 'savedAt': now.toIso8601String(), 'venues': []}));
      expect(VenueCache.read(), isNull);
    });

    test('danh sách quá lớn (ảnh nhúng base64) thì chỉ giữ trong bộ nhớ, không lưu vào trình duyệt', () {
      final huge = 'data:image/png;base64,${'A' * (VenueCache.maxStoredChars + 10)}';
      VenueCache.write([_v(1, image: huge)]);
      expect(readStoredText(VenueCache.storageKey), isNull);
      expect(VenueCache.read(), isNotNull, reason: 'bộ nhớ trong vẫn dùng được trong phiên này');
      VenueCache.forgetMemoryForTest();
      expect(VenueCache.read(), isNull, reason: 'tải lại trang thì không còn');
    });
  });

  group('Sửa tại chỗ khi app ghi sân', () {
    test('upsert thêm sân mới theo thứ tự mã, và thay sân cùng mã', () {
      VenueCache.write([_v(1), _v(3)]);
      VenueCache.upsert(_v(2, name: 'Sân Mới'));
      expect(VenueCache.read()!.venues.map((v) => v.id), [1, 2, 3]);
      VenueCache.upsert(_v(3, name: 'Đã đổi tên'));
      final r = VenueCache.read()!;
      expect(r.venues.length, 3);
      expect(r.venues.firstWhere((v) => v.id == 3).name, 'Đã đổi tên');
    });

    test('sửa tại chỗ không làm mới thời điểm lưu (vẫn hết hạn đúng giờ)', () {
      VenueCache.write([_v(1)]);
      final saved = now;
      now = now.add(const Duration(minutes: 20));
      VenueCache.upsert(_v(2));
      expect(VenueCache.read()!.savedAt, saved);
    });

    test('update đổi trạng thái duyệt; sân không có thì bỏ qua', () {
      VenueCache.write([_v(1, status: 'pending')]);
      VenueCache.update(1, (v) => v.copyWith(approvalStatus: 'approved'));
      VenueCache.update(99, (v) => v.copyWith(approvalStatus: 'rejected'));
      final r = VenueCache.read()!;
      expect(r.venues.single.approvalStatus, 'approved');
    });

    test('removeId xóa đúng sân', () {
      VenueCache.write([_v(1), _v(2)]);
      VenueCache.removeId(1);
      expect(VenueCache.read()!.venues.map((v) => v.id), [2]);
    });

    test('chưa có bản nhớ thì sửa tại chỗ không tạo ra bản nhớ rỗng, thiếu sân', () {
      VenueCache.upsert(_v(1));
      VenueCache.update(1, (v) => v);
      VenueCache.removeId(1);
      expect(VenueCache.read(), isNull);
    });

    test('thay đổi được lưu xuống nơi lưu, tải lại trang vẫn thấy', () {
      VenueCache.write([_v(1)]);
      VenueCache.upsert(_v(2));
      VenueCache.forgetMemoryForTest();
      expect(VenueCache.read()!.venues.map((v) => v.id), [1, 2]);
    });
  });
}
