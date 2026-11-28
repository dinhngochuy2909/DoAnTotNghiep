import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import '../models/user.dart';
import 'firebase_config.dart';
import 'session.dart';

/// Đăng ký và đăng nhập qua Firebase Authentication (REST).
///
/// Mật khẩu do Firebase giữ; Firestore collection "users" (mã tài liệu = uid) chỉ lưu hồ sơ và vai trò.
class AuthService {
  static const String projectId = FirebaseConfig.projectId;
  static const String baseUrl = FirebaseConfig.firestoreUrl;

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

  /// Kiểm tra có phải quản trị viên không
  static bool get isAdmin => _currentUser?.isAdmin ?? false;

  /// Kiểm tra có phải chủ sân không
  static bool get isOwner => _currentUser?.isOwner ?? false;

  /// ============================================================
  /// ĐĂNG KÝ - tạo tài khoản Firebase Authentication rồi lưu hồ sơ khách hàng
  /// ============================================================
  static Future<({bool success, String message})> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final auth = await _identity('accounts:signUp', email.trim().toLowerCase(), password);
      if (auth.data == null) return (success: false, message: auth.error);
      final uid = _startSession(auth.data!);
      final user = AppUser(uid: uid, fullName: fullName, email: email.trim().toLowerCase(), phone: phone);
      if (!await _createProfile(user)) {
        Session.clear();
        return (success: false, message: 'Đã tạo tài khoản nhưng chưa lưu được hồ sơ. Hãy đăng nhập lại.');
      }
      _currentUser = user;
      return (success: true, message: 'Đăng ký thành công!');
    } catch (e) {
      return (success: false, message: 'Lỗi kết nối: $e');
    }
  }

  /// ============================================================
  /// ĐĂNG NHẬP
  /// ============================================================
  static Future<({bool success, String message})> login({
    required String email,
    required String password,
  }) async {
    try {
      final trimmedEmail = email.trim().toLowerCase();
      final auth = await _identity('accounts:signInWithPassword', trimmedEmail, password);
      if (auth.data == null) return (success: false, message: auth.error);
      final uid = _startSession(auth.data!);

      final response = await http.get(Uri.parse('$baseUrl/users/${Uri.encodeComponent(uid)}'), headers: await Session.headers());
      if (response.statusCode == 200) {
        final fields = (json.decode(response.body) as Map<String, dynamic>)['fields'] as Map<String, dynamic>? ?? {};
        _currentUser = AppUser.fromFirestoreFields(uid, fields);
        return (success: true, message: 'Đăng nhập thành công!');
      }
      if (response.statusCode == 404) {
        // Có tài khoản nhưng thiếu hồ sơ (đăng ký dở dang): tạo hồ sơ khách hàng.
        final user = AppUser(uid: uid, fullName: trimmedEmail.split('@').first, email: trimmedEmail, phone: '');
        if (await _createProfile(user)) {
          _currentUser = user;
          return (success: true, message: 'Đăng nhập thành công!');
        }
      }
      Session.clear();
      return (success: false, message: 'Lỗi server. Vui lòng thử lại.');
    } catch (e) {
      Session.clear();
      return (success: false, message: 'Lỗi kết nối: $e');
    }
  }

  /// ============================================================
  /// QUÊN MẬT KHẨU - Firebase gửi thư chứa đường dẫn đặt mật khẩu mới
  /// ============================================================
  /// Câu trả lời không cho biết email đã đăng ký hay chưa.
  static Future<({bool success, String message})> sendPasswordReset(String email) async {
    const sent = 'Nếu email này đã đăng ký, thư đặt lại mật khẩu sẽ được gửi tới đó. Hãy kiểm tra cả mục Thư rác.';
    try {
      final response = await http.post(
        Uri.parse('${FirebaseConfig.authUrl}/accounts:sendOobCode?key=${FirebaseConfig.apiKey}'),
        headers: {'Content-Type': 'application/json', 'X-Firebase-Locale': 'vi'},
        body: json.encode({'requestType': 'PASSWORD_RESET', 'email': email.trim().toLowerCase()}),
      );
      if (response.statusCode == 200) return (success: true, message: sent);
      final code = '${((json.decode(response.body) as Map<String, dynamic>)['error'] as Map<String, dynamic>?)?['message'] ?? ''}';
      if (code.startsWith('EMAIL_NOT_FOUND')) return (success: true, message: sent);
      if (code.startsWith('RESET_PASSWORD_EXCEED_LIMIT') || code.startsWith('TOO_MANY_ATTEMPTS')) {
        return (success: false, message: 'Bạn yêu cầu quá nhiều lần. Vui lòng thử lại sau.');
      }
      return (success: false, message: _message(code));
    } catch (e) {
      return (success: false, message: 'Lỗi kết nối: $e');
    }
  }

  /// ============================================================
  /// ĐĂNG XUẤT
  /// ============================================================
  static void logout() {
    _currentUser = null;
    Session.clear();
  }

  static Future<({Map<String, dynamic>? data, String error})> _identity(String method, String email, String password) async {
    final response = await http.post(
      Uri.parse('${FirebaseConfig.authUrl}/$method?key=${FirebaseConfig.apiKey}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password, 'returnSecureToken': true}),
    );
    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return (data: body, error: '');
    return (data: null, error: _message('${(body['error'] as Map<String, dynamic>?)?['message'] ?? ''}'));
  }

  /// Mã lỗi của Firebase -> câu cho người dùng.
  static String _message(String code) {
    if (code.contains('API key') || code.contains('unregistered callers')) {
      return 'Ứng dụng chưa được cấu hình khóa Firebase (FIREBASE_API_KEY).';
    }
    if (code.startsWith('EMAIL_EXISTS')) return 'Email này đã được đăng ký!';
    if (code.startsWith('INVALID_LOGIN_CREDENTIALS') || code.startsWith('INVALID_PASSWORD') || code.startsWith('EMAIL_NOT_FOUND')) {
      return 'Email hoặc mật khẩu không đúng!';
    }
    if (code.startsWith('INVALID_EMAIL')) return 'Địa chỉ email không hợp lệ!';
    if (code.startsWith('WEAK_PASSWORD')) return 'Mật khẩu cần ít nhất 6 ký tự.';
    if (code.startsWith('TOO_MANY_ATTEMPTS')) return 'Thử sai quá nhiều lần. Vui lòng đợi ít phút rồi thử lại.';
    if (code.startsWith('USER_DISABLED')) return 'Tài khoản đã bị khóa.';
    return 'Lỗi server. Vui lòng thử lại.';
  }

  static String _startSession(Map<String, dynamic> data) {
    Session.set(
      idToken: data['idToken'] as String,
      refreshToken: data['refreshToken'] as String,
      expiresInSeconds: int.tryParse('${data['expiresIn']}') ?? 3600,
    );
    return data['localId'] as String;
  }

  /// Hồ sơ mới luôn là khách hàng; luật Firestore không cho tự đặt vai trò khác.
  static Future<bool> _createProfile(AppUser user) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users?documentId=${Uri.encodeComponent(user.uid)}'),
      headers: await Session.headers(json: true),
      body: json.encode({'fields': user.toFirestoreFields()}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  @visibleForTesting
  static void setCurrentUserForTest(AppUser? user) => _currentUser = user;

  /// Giả lập đã đăng nhập quản trị viên (không có token, chỉ dùng trong kiểm thử).
  @visibleForTesting
  static void loginAsAdminDemo() {
    _currentUser = AppUser(
      uid: 'admin_super_01',
      fullName: 'Đinh Ngọc Huy (Super Admin)',
      email: 'admin@alobooking.com',
      phone: '0988889999',
      role: 'admin',
    );
  }

  /// Giả lập đã đăng nhập chủ sân (không có token, chỉ dùng trong kiểm thử).
  @visibleForTesting
  static void loginAsOwnerDemo() {
    _currentUser = AppUser(
      uid: 'owner_chuan_01',
      fullName: 'Trần Văn Chủ Sân (Cụm Sân Đống Đa & Chùa Bộc)',
      email: 'chusan@alobooking.com',
      phone: '0977112233',
      role: 'owner',
    );
  }
}
