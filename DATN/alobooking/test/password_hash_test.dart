import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/services/auth_service.dart';

void main() {
  test('băm có salt: cùng mật khẩu cho hai chuỗi khác nhau nhưng đều xác thực đúng', () {
    final a = AuthService.hashPasswordForTest('matkhau123');
    final b = AuthService.hashPasswordForTest('matkhau123');
    expect(a, isNot(b));
    expect(a.startsWith(r'sha256$'), isTrue);
    expect(a.contains('matkhau123'), isFalse);
    expect(AuthService.verifyPasswordForTest('matkhau123', a), isTrue);
    expect(AuthService.verifyPasswordForTest('matkhau123', b), isTrue);
  });

  test('sai mật khẩu bị từ chối', () {
    final h = AuthService.hashPasswordForTest('matkhau123');
    expect(AuthService.verifyPasswordForTest('sai', h), isFalse);
    expect(AuthService.verifyPasswordForTest('', h), isFalse);
  });

  test('chuỗi băm hỏng không ném lỗi', () {
    expect(AuthService.verifyPasswordForTest('x', r'sha256$chi-hai-phan'), isFalse);
    expect(AuthService.verifyPasswordForTest('x', ''), isFalse);
  });

  test('vẫn đọc được mật khẩu định dạng cũ (base64 hai lần) để nâng cấp', () {
    final legacy = base64Encode(utf8.encode(base64Encode(utf8.encode('cu123'))));
    expect(AuthService.verifyPasswordForTest('cu123', legacy), isTrue);
    expect(AuthService.verifyPasswordForTest('khac', legacy), isFalse);
  });
}
