/// Địa chỉ các dịch vụ Firebase mà ứng dụng gọi bằng REST.
///
/// `--dart-define=FIREBASE_EMULATOR=localhost` chuyển sang bộ mô phỏng chạy trên máy
/// (`firebase emulators:start`) để thử mà không đụng dữ liệu thật.
class FirebaseConfig {
  FirebaseConfig._();

  /// Đổi bằng `--dart-define=FIREBASE_PROJECT=...` khi chạy với bộ mô phỏng (dự án `demo-*`).
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT', defaultValue: 'alobooking-b2484');

  static const String _emulator = String.fromEnvironment('FIREBASE_EMULATOR');

  /// Khóa API của web app trong Firebase. Khai trong `dart_defines.json`; bộ mô phỏng nhận khóa bất kỳ.
  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: _emulator == '' ? '' : 'khoa-mo-phong');

  static const String documentsPath = 'projects/$projectId/databases/(default)/documents';

  static const String firestoreUrl = _emulator == ''
      ? 'https://firestore.googleapis.com/v1/$documentsPath'
      : 'http://$_emulator:8080/v1/$documentsPath';

  static const String authUrl = _emulator == ''
      ? 'https://identitytoolkit.googleapis.com/v1'
      : 'http://$_emulator:9099/identitytoolkit.googleapis.com/v1';

  static const String tokenUrl = _emulator == ''
      ? 'https://securetoken.googleapis.com/v1/token'
      : 'http://$_emulator:9099/securetoken.googleapis.com/v1/token';
}
