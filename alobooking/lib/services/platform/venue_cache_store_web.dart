// TODO: chuyển sang package:web + dart:js_interop (dart:html đã bị đánh dấu lỗi thời)
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Lưu bộ nhớ đệm vào localStorage của trình duyệt để mở lại app (hoặc tải lại trang) không phải đọc lại từ Firestore.
/// Mọi thao tác đều nuốt lỗi: trình duyệt chặn lưu trữ hoặc đầy bộ nhớ thì app vẫn chạy, chỉ là không có bộ nhớ đệm.
String? readStoredText(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void writeStoredText(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

void removeStoredText(String key) {
  try {
    html.window.localStorage.remove(key);
  } catch (_) {}
}
