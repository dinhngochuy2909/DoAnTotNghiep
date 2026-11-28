import '../models/venue.dart';

/// Ai được sửa, xóa một cụm sân trên giao diện.
class VenuePermission {
  VenuePermission._();

  /// Quản trị viên quản lý mọi sân; chủ sân chỉ quản lý sân có `ownerId` đúng bằng mã tài khoản của mình.
  /// Không suy quyền từ quận hay tên sân.
  static bool canManage({required String role, required String uid, required Venue venue}) {
    switch (role) {
      case 'admin':
        return true;
      case 'owner':
        return uid.isNotEmpty && venue.ownerId == uid;
      default:
        return false;
    }
  }
}
