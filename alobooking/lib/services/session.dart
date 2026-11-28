import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import 'firebase_config.dart';

/// Token đăng nhập của Firebase Authentication, chỉ giữ trong bộ nhớ (tải lại trang là phải đăng nhập lại).
///
/// Mọi yêu cầu tới Firestore gắn token này qua [headers] để luật bảo mật biết người gọi là ai.
class Session {
  Session._();

  static String? _idToken;
  static String? _refreshToken;
  static DateTime _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);

  static bool get hasToken => _idToken != null;

  static void set({required String idToken, required String refreshToken, required int expiresInSeconds}) {
    _idToken = idToken;
    _refreshToken = refreshToken;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresInSeconds));
  }

  static void clear() {
    _idToken = null;
    _refreshToken = null;
  }

  /// Header cho một yêu cầu: kèm `Authorization` nếu đã đăng nhập, `Content-Type` nếu có thân JSON.
  static Future<Map<String, String>> headers({bool json = false}) async {
    // Token sống 1 giờ: còn dưới 1 phút thì đổi token mới trước khi gọi.
    if (_refreshToken != null && DateTime.now().isAfter(_expiresAt.subtract(const Duration(minutes: 1)))) {
      await _refresh();
    }
    return {
      if (json) 'Content-Type': 'application/json',
      if (_idToken != null) 'Authorization': 'Bearer $_idToken',
    };
  }

  static Future<void> _refresh() async {
    try {
      final res = await http.post(
        Uri.parse('${FirebaseConfig.tokenUrl}?key=${FirebaseConfig.apiKey}'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'grant_type=refresh_token&refresh_token=${Uri.encodeQueryComponent(_refreshToken!)}',
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        set(
          idToken: data['id_token'] as String,
          refreshToken: data['refresh_token'] as String,
          expiresInSeconds: int.tryParse('${data['expires_in']}') ?? 3600,
        );
      }
    } catch (_) {
      // Mất mạng: giữ token cũ, yêu cầu tiếp theo sẽ thử lại.
    }
  }

  @visibleForTesting
  static String? get idTokenForTest => _idToken;
}
