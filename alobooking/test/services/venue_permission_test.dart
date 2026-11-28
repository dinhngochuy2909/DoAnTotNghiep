import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/models/user.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/services/venue_permission.dart';

Venue _venue({required String ownerId, String district = 'Cầu Giấy', String name = 'Sân thử'}) => Venue(
      id: 1,
      name: name,
      type: 'badminton',
      district: district,
      distance: '',
      address: 'Hà Nội',
      hours: '06:00 – 22:00',
      tags: const [],
      rating: 0,
      price: '80k - 100k/h',
      lat: 21,
      lng: 105.8,
      image: '',
      logo: '',
      ownerId: ownerId,
    );

bool _can(String role, String uid, Venue v) => VenuePermission.canManage(role: role, uid: uid, venue: v);

void main() {
  group('Quyền sửa, xóa cụm sân', () {
    test('chủ sân chỉ quản lý sân có ownerId là mình', () {
      expect(_can('owner', 'o1', _venue(ownerId: 'o1')), isTrue);
      expect(_can('owner', 'o1', _venue(ownerId: 'o2')), isFalse);
    });

    test('sân ở quận Đống Đa hoặc tên có chữ Đống Đa của người khác thì không được sửa', () {
      expect(_can('owner', 'o1', _venue(ownerId: 'o2', district: 'Đống Đa')), isFalse);
      expect(_can('owner', 'o1', _venue(ownerId: 'o2', name: 'Cụm sân Đống Đa')), isFalse);
    });

    test('mã tài khoản rỗng không khớp với sân chưa có chủ', () {
      expect(_can('owner', '', _venue(ownerId: '')), isFalse);
    });

    test('quản trị viên quản lý mọi sân; khách hàng và khách xem thì không', () {
      expect(_can('admin', 'a', _venue(ownerId: 'o2')), isTrue);
      expect(_can('customer', 'o2', _venue(ownerId: 'o2')), isFalse);
      expect(_can('guest', 'o2', _venue(ownerId: 'o2')), isFalse);
      expect(_can('', 'o2', _venue(ownerId: 'o2')), isFalse);
    });
  });

  group('AppUser.fromJson không đoán vai trò từ email', () {
    test('thiếu trường role thì là khách hàng, dù email có chữ admin hay chusan', () {
      for (final email in ['admin@x.com', 'chusan@x.com', 'khachxem@x.com', 'a@x.com']) {
        expect(AppUser.fromJson({'uid': 'u', 'email': email}).role, 'customer', reason: email);
        expect(AppUser.fromJson({'uid': 'u', 'email': email, 'role': ''}).role, 'customer', reason: email);
      }
    });

    test('có trường role thì dùng đúng giá trị đã lưu', () {
      expect(AppUser.fromJson({'uid': 'u', 'email': 'a@x.com', 'role': 'owner'}).role, 'owner');
    });
  });
}
