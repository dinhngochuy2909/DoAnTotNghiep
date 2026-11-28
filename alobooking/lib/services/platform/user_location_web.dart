// TODO: chuyển sang package:web + dart:js_interop (dart:html đã bị đánh dấu lỗi thời)
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Xin vị trí hiện tại qua trình duyệt. Trả về null nếu người dùng từ chối hoặc trình duyệt không lấy được vị trí.
Future<({double lat, double lng})?> requestUserLocation() async {
  try {
    final pos = await html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: false,
      timeout: const Duration(seconds: 10),
      maximumAge: const Duration(minutes: 5),
    );
    final lat = pos.coords?.latitude;
    final lng = pos.coords?.longitude;
    if (lat == null || lng == null) return null;
    return (lat: lat.toDouble(), lng: lng.toDouble());
  } catch (_) {
    return null;
  }
}
