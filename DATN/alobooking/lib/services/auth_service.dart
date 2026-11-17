import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:http/http.dart' as http;
import '../models/user.dart';

/// Service xác thực người dùng qua Firestore REST API
/// Dữ liệu lưu trong collection "users" trên Firestore alobooking-b2484
/// Mật khẩu được hash bằng SHA-256 trước khi lưu
class AuthService {
  static const String projectId = 'alobooking-b2484';
  static const String baseUrl =
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  // In-memory session — null nghĩa là chưa đăng nhập (mặc định là Khách xem sân)
  static AppUser? _currentUser;

  /// Lấy user hiện tại (null nếu chưa đăng nhập)
  static AppUser? get currentUser => _currentUser;

  /// Kiểm tra đã đăng nhập thành viên chưa (không tính khách vãng lai)
  static bool get isLoggedIn => _currentUser != null && !_currentUser!.isGuest;

  /// Kiểm tra có phải khách chỉ xem sân không (chưa đăng nhập HOẶC có role guest)
  static bool get isGuest => _currentUser == null || _currentUser!.isGuest;

  /// Kiểm tra tài khoản có quyền đặt sân hay không (chỉ thành viên đã đăng nhập)
  static bool get canBook => isLoggedIn;

  /// ============================================================
  /// ĐĂNG KÝ - Tạo tài khoản mới lưu lên Firestore
  /// ============================================================
  static Future<({bool success, String message})> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      // 1. Kiểm tra email đã tồn tại chưa (query Firestore)
      final existing = await _findUserByEmail(email);
      if (existing != null) {
        return (success: false, message: 'Email này đã được đăng ký!');
      }

      // 2. Tạo document ID từ email (thay @ và . bằng _)
      final docId = email.replaceAll('@', '_at_').replaceAll('.', '_dot_');

      // 3. Hash mật khẩu (SHA-256 đơn giản, production nên dùng bcrypt)
      final hashedPassword = _hashPassword(password);

      // 4. Build payload
      final payload = {
        'fields': {
          'fullName': {'stringValue': fullName},
          'email': {'stringValue': email},
          'phone': {'stringValue': phone},
          'password': {'stringValue': hashedPassword},
          'avatarUrl': {'stringValue': ''},
          'role': {'stringValue': 'customer'},
          'createdAt': {'stringValue': DateTime.now().toIso8601String()},
        }
      };

      // 5. POST lên Firestore
      final response = await http.post(
        Uri.parse('$baseUrl/users?documentId=$docId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Auto-login sau khi đăng ký thành công
        _currentUser = AppUser(
          uid: docId,
          fullName: fullName,
          email: email,
          phone: phone,
        );
        return (success: true, message: 'Đăng ký thành công!');
      } else {
        return (success: false, message: 'Lỗi server. Vui lòng thử lại.');
      }
    } catch (e) {
      return (success: false, message: 'Lỗi kết nối: $e');
    }
  }

  /// Kiểm tra có phải quản trị viên không
  static bool get isAdmin => _currentUser?.isAdmin ?? false;

  /// Kiểm tra có phải chủ sân không
  static bool get isOwner => _currentUser?.isOwner ?? false;

  /// Đăng nhập nhanh tài khoản Admin demo
  static void loginAsAdminDemo() {
    _currentUser = AppUser(
      uid: 'admin_super_01',
      fullName: 'Đinh Ngọc Huy (Super Admin)',
      email: 'admin@alobooking.com',
      phone: '0988889999',
      role: 'admin',
    );
  }

  /// Đăng nhập nhanh tài khoản Chủ Sân demo
  static void loginAsOwnerDemo() {
    _currentUser = AppUser(
      uid: 'owner_chuan_01',
      fullName: 'Trần Văn Chủ Sân (Cụm Sân Đống Đa & Chùa Bộc)',
      email: 'chusan@alobooking.com',
      phone: '0977112233',
      role: 'owner',
    );
  }

  /// Đăng nhập nhanh tài khoản Khách Xem Sân (chỉ xem, không đặt sân)
  static void loginAsGuestDemo() {
    _currentUser = AppUser(
      uid: 'guest_viewer_01',
      fullName: 'Khách Xem Sân (Chỉ xem)',
      email: 'guest@alobooking.com',
      phone: '0900000000',
      role: 'guest',
    );
  }

  /// ============================================================
  /// ĐĂNG NHẬP - Xác thực email + password từ Firestore
  /// ============================================================
  static Future<({bool success, String message})> login({
    required String email,
    required String password,
  }) async {
    try {
      final trimmedEmail = email.trim().toLowerCase();

      // Tài khoản demo chỉ hoạt động khi chạy debug (hoặc build với --dart-define=DEMO_ACCOUNTS=true)
      if (_demoAccountsEnabled) {
      // 1. Phân quyền: Kiểm tra tài khoản Quản Trị Viên (Admin)
      if ((trimmedEmail == 'admin@alobooking.com' && password == 'admin123') ||
          (trimmedEmail == 'admin@sportai.com' && password == 'password123') ||
          (trimmedEmail == 'admin' && (password == 'admin' || password == '123456'))) {
        _currentUser = AppUser(
          uid: 'admin_super_01',
          fullName: 'Đinh Ngọc Huy (Super Admin)',
          email: 'admin@alobooking.com',
          phone: '0988889999',
          role: 'admin',
        );
        return (success: true, message: 'Đăng nhập Quản Trị Viên thành công!');
      }

      // 2. Phân quyền: Kiểm tra tài khoản Chủ Sân (Owner)
      if ((trimmedEmail == 'chusan@alobooking.com' && (password == 'chusan123' || password == '123456')) ||
          (trimmedEmail == 'owner@alobooking.com' && (password == 'owner123' || password == '123456')) ||
          (trimmedEmail == 'chusan' && (password == 'chusan' || password == '123456')) ||
          (trimmedEmail == 'owner' && (password == 'owner' || password == '123456'))) {
        _currentUser = AppUser(
          uid: 'owner_chuan_01',
          fullName: 'Trần Văn Chủ Sân (Cụm Sân Đống Đa & Chùa Bộc)',
          email: 'chusan@alobooking.com',
          phone: '0977112233',
          role: 'owner',
        );
        return (success: true, message: 'Đăng nhập Chủ Sân thành công!');
      }

      // 3. Phân quyền: Tài khoản Khách hàng đặt sân thông thường
      if ((trimmedEmail == 'user@alobooking.com' && password == '123456') ||
          (trimmedEmail == 'khach@alobooking.com' && password == '123456') ||
          (trimmedEmail == 'customer@alobooking.com' && password == '123456') ||
          (trimmedEmail == 'user' && (password == 'user' || password == '123456'))) {
        _currentUser = AppUser(
          uid: 'user_customer_01',
          fullName: 'Nguyễn Văn Khách (Khách hàng)',
          email: trimmedEmail.contains('@') ? trimmedEmail : 'user@alobooking.com',
          phone: '0912345678',
          role: 'customer',
        );
        return (success: true, message: 'Đăng nhập Khách Hàng thành công!');
      }

      // 4. Phân quyền: Tài khoản Khách Xem Sân (Guest - chỉ xem sân, không đặt sân được)
      if ((trimmedEmail == 'guest@alobooking.com' && (password == '123456' || password == 'guest123')) ||
          (trimmedEmail == 'khachxem@alobooking.com' && password == '123456') ||
          (trimmedEmail == 'viewer@alobooking.com' && password == '123456') ||
          (trimmedEmail == 'guest' && (password == 'guest' || password == '123456')) ||
          (trimmedEmail == 'khachxem' && (password == 'khachxem' || password == '123456'))) {
        _currentUser = AppUser(
          uid: 'guest_viewer_01',
          fullName: 'Khách Xem Sân (Chỉ xem)',
          email: 'guest@alobooking.com',
          phone: '0900000000',
          role: 'guest',
        );
        return (success: true, message: 'Đăng nhập Khách Xem Sân (Chỉ xem) thành công!');
      }
      }

      final docId = trimmedEmail.replaceAll('@', '_at_').replaceAll('.', '_dot_');
      final response = await http.get(Uri.parse('$baseUrl/users/$docId'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final fields = data['fields'] as Map<String, dynamic>?;

        if (fields == null) {
          return (success: false, message: 'Tài khoản không tồn tại!');
        }

        // So sánh mật khẩu đã hash
        final storedPassword = fields['password']?['stringValue'] ?? '';

        if (_verifyPassword(password, storedPassword)) {
          // Tài khoản cũ lưu mật khẩu dạng base64: nâng cấp lên băm có salt ngay lần đăng nhập này
          if (!storedPassword.startsWith(_hashPrefix)) {
            _upgradePasswordHash(docId, password);
          }
          _currentUser = AppUser.fromFirestoreFields(docId, fields);
          return (success: true, message: 'Đăng nhập thành công!');
        } else {
          return (success: false, message: 'Mật khẩu không chính xác!');
        }
      } else if (response.statusCode == 404) {
        return (success: false, message: 'Email chưa được đăng ký!');
      } else {
        return (success: false, message: 'Lỗi server. Vui lòng thử lại.');
      }
    } catch (e) {
      return (success: false, message: 'Lỗi kết nối: $e');
    }
  }

  /// ============================================================
  /// ĐĂNG XUẤT
  /// ============================================================
  static void logout() {
    _currentUser = null;
  }

  /// ============================================================
  /// HELPER: Tìm user theo email
  /// ============================================================
  static Future<Map<String, dynamic>?> _findUserByEmail(String email) async {
    try {
      final docId = email.replaceAll('@', '_at_').replaceAll('.', '_dot_');
      final response = await http.get(Uri.parse('$baseUrl/users/$docId'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {}
    return null;
  }

  /// ============================================================
  /// BẢO MẬT
  /// ============================================================
  static const bool _demoAccountsEnabled =
      kDebugMode || bool.fromEnvironment('DEMO_ACCOUNTS', defaultValue: false);

  static const String _hashPrefix = r'sha256$';

  /// Băm mật khẩu: SHA-256 với salt ngẫu nhiên 16 byte, định dạng `sha256$salt$hash`.
  static String _hashPassword(String password) {
    final rnd = Random.secure();
    final salt = base64UrlEncode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    return '$_hashPrefix$salt\$${_digest(salt, password)}';
  }

  @visibleForTesting
  static void setCurrentUserForTest(AppUser? user) => _currentUser = user;

  @visibleForTesting
  static String hashPasswordForTest(String password) => _hashPassword(password);

  @visibleForTesting
  static bool verifyPasswordForTest(String password, String stored) => _verifyPassword(password, stored);

  static String _digest(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  static bool _verifyPassword(String password, String stored) {
    if (stored.startsWith(_hashPrefix)) {
      final parts = stored.split(r'$');
      if (parts.length != 3) return false;
      return _constantTimeEquals(_digest(parts[1], password), parts[2]);
    }
    // Định dạng cũ (base64 hai lần)
    final legacy = base64Encode(utf8.encode(base64Encode(utf8.encode(password))));
    return _constantTimeEquals(legacy, stored);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static Future<void> _upgradePasswordHash(String docId, String password) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/users/$docId?updateMask.fieldPaths=password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fields': {
            'password': {'stringValue': _hashPassword(password)},
          }
        }),
      );
    } catch (_) {}
  }
}
