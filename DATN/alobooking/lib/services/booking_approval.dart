import '../models/venue.dart';
import 'firestore_service.dart' show BookingItem;

/// Ai được duyệt (xác nhận, hủy, hoàn thành) một đơn đặt sân.
///
/// Quy tắc: người duyệt là CHỦ CỦA SÂN được đặt. Admin không cần (và không được) duyệt đơn của sân đã có chủ riêng,
/// chỉ xem được. Sân không có chủ thật (do hệ thống/admin quản lý, ví dụ địa điểm nhập từ dữ liệu mở) thì admin là người duyệt.
///
/// Lưu ý: đây là kiểm soát ở giao diện. Luật Firestore của dự án hiện còn mở nên chưa chặn được ở phía máy chủ.
class BookingApproval {
  BookingApproval._();

  /// Mã tài khoản admin hệ thống, đồng thời là "chủ" mặc định của sân do hệ thống quản lý.
  static const adminOwnerId = 'admin_super_01';

  static String _norm(String s) => s.trim().toLowerCase();

  /// Sân được đặt (khớp đúng tên sân, không phân biệt hoa thường). Null nếu sân đã bị xóa hoặc đổi tên.
  static Venue? venueOf(BookingItem b, Iterable<Venue> venues) {
    final name = _norm(b.venueName);
    for (final v in venues) {
      if (_norm(v.name) == name) return v;
    }
    return null;
  }

  /// Mã tài khoản người duyệt đơn: chủ của sân; không rõ sân hoặc sân do hệ thống quản lý thì là admin.
  static String approverId(BookingItem b, Iterable<Venue> venues) {
    final owner = venueOf(b, venues)?.ownerId.trim() ?? '';
    return owner.isEmpty ? adminOwnerId : owner;
  }

  /// Đơn của sân đã có chủ riêng (chủ sân duyệt, admin chỉ xem).
  static bool isOwnerManaged(BookingItem b, Iterable<Venue> venues) => approverId(b, venues) != adminOwnerId;

  /// Tên người duyệt để hiển thị cho admin ("Trần Văn A"); null nếu không biết tên.
  static String? approverName(BookingItem b, Iterable<Venue> venues) {
    final v = venueOf(b, venues);
    final n = v?.ownerName.trim() ?? '';
    return n.isEmpty ? null : n;
  }

  /// Tài khoản [uid] với vai trò [role] ('admin' | 'owner' | khác) có được duyệt đơn [b] không.
  static bool canApprove({required String role, required String uid, required BookingItem b, required Iterable<Venue> venues}) {
    final approver = approverId(b, venues);
    switch (role) {
      case 'owner':
        return uid.isNotEmpty && approver == uid;
      case 'admin':
        return approver == adminOwnerId;
      default:
        return false;
    }
  }

  /// Nhãn ngắn thay cho nút duyệt khi người xem không có quyền duyệt đơn của chủ sân.
  static String viewOnlyLabel(BookingItem b, Iterable<Venue> venues) {
    final name = approverName(b, venues);
    final who = name == null ? 'chủ sân' : 'chủ sân $name';
    return switch (b.status) {
      'Chờ xác nhận' => 'Chờ $who xác nhận',
      _ => 'Do $who quản lý',
    };
  }
}
