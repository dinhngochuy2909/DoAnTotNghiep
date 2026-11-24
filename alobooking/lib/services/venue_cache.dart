import 'dart:convert';

import '../models/venue.dart';
import 'platform/venue_cache_store.dart';

/// Bộ nhớ đệm danh sách sân. Mỗi sân là một lượt đọc trong hạn mức Firestore miễn phí (50.000 lượt mỗi ngày),
/// mà app có hơn một nghìn sân, nên đọc lại toàn bộ mỗi lần mở trang chủ hay mỗi câu hỏi của trợ lý AI sẽ cạn hạn mức rất nhanh.
///
/// Danh sách được giữ trong bộ nhớ và (trên web) lưu vào localStorage nên tải lại trang vẫn dùng được.
/// Bản còn mới ([freshFor]) được dùng thẳng; bản cũ hơn chỉ dùng khi tải từ máy chủ bị lỗi (tối đa [keepFor]).
/// Khi chính app ghi sân (thêm, sửa, xóa, duyệt) thì bản đệm được sửa tại chỗ, không phải đọc lại.
class VenueCache {
  VenueCache._();

  static const storageKey = 'alobooking.venues.v1';

  /// Bản đệm còn "mới" trong khoảng này: dùng thẳng, không hỏi máy chủ.
  static const freshFor = Duration(minutes: 30);

  /// Bản đệm quá cũ (quá khoảng này) thì bỏ hẳn, kể cả khi máy chủ đang lỗi.
  static const keepFor = Duration(days: 3);

  /// Danh sách lớn hơn mức này (ký tự) thì không lưu vào trình duyệt (vd sân có ảnh nhúng dạng base64), chỉ giữ trong bộ nhớ.
  static const maxStoredChars = 3000000;

  /// Đồng hồ, để kiểm thử đổi giờ.
  static DateTime Function() clock = DateTime.now;

  static List<Venue>? _venues;
  static DateTime? _savedAt;

  /// Bản đệm hiện có (có thể đã cũ) hoặc null nếu chưa có / hỏng / quá cũ.
  static ({List<Venue> venues, DateTime savedAt})? read() {
    if (_venues == null) _loadFromStorage();
    final v = _venues;
    final t = _savedAt;
    if (v == null || t == null) return null;
    if (clock().difference(t) > keepFor) {
      clear();
      return null;
    }
    return (venues: List<Venue>.of(v), savedAt: t);
  }

  /// Bản đệm còn mới: đã lưu chưa quá [freshFor]. Giờ máy chạy lùi (tuổi âm) thì coi là không mới để đọc lại cho chắc.
  static bool isFresh(DateTime savedAt) {
    final age = clock().difference(savedAt);
    return !age.isNegative && age <= freshFor;
  }

  /// Lưu một danh sách vừa tải đầy đủ từ máy chủ.
  static void write(List<Venue> venues) {
    _venues = List<Venue>.of(venues);
    _savedAt = clock();
    _persist();
  }

  /// Thêm sân mới hoặc thay sân cùng mã (sau khi ghi thành công lên Firestore). Không đổi thời điểm lưu.
  static void upsert(Venue venue) {
    final v = _venues ?? _ensureLoaded();
    if (v == null) return;
    final i = v.indexWhere((x) => x.id == venue.id);
    if (i >= 0) {
      v[i] = venue;
    } else {
      v.add(venue);
      v.sort((a, b) => a.id.compareTo(b.id));
    }
    _persist();
  }

  /// Sửa một sân trong bản đệm bằng [change] (ví dụ đổi trạng thái duyệt). Không có sân đó thì bỏ qua.
  static void update(int id, Venue Function(Venue) change) {
    final v = _venues ?? _ensureLoaded();
    if (v == null) return;
    final i = v.indexWhere((x) => x.id == id);
    if (i < 0) return;
    v[i] = change(v[i]);
    _persist();
  }

  /// Bỏ một sân khỏi bản đệm (sau khi xóa thành công trên Firestore).
  static void removeId(int id) {
    final v = _venues ?? _ensureLoaded();
    if (v == null) return;
    v.removeWhere((x) => x.id == id);
    _persist();
  }

  /// Xóa sạch bản đệm (bộ nhớ và trình duyệt).
  static void clear() {
    _venues = null;
    _savedAt = null;
    removeStoredText(storageKey);
  }

  static List<Venue>? _ensureLoaded() {
    if (_venues == null) _loadFromStorage();
    return _venues;
  }

  static void _loadFromStorage() {
    final raw = readStoredText(storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      if (data['v'] != 1) throw const FormatException('phiên bản lạ');
      final at = DateTime.parse(data['savedAt'] as String);
      final list = [for (final e in data['venues'] as List<dynamic>) Venue.fromJson(e as Map<String, dynamic>)];
      if (list.isEmpty) throw const FormatException('rỗng');
      _venues = list;
      _savedAt = at;
    } catch (_) {
      // Bản lưu hỏng hoặc của phiên bản cũ: bỏ đi để lần sau đọc lại từ máy chủ
      removeStoredText(storageKey);
    }
  }

  static void _persist() {
    final v = _venues;
    final t = _savedAt;
    if (v == null || t == null) return;
    final text = json.encode({'v': 1, 'savedAt': t.toIso8601String(), 'venues': [for (final x in v) x.toJson()]});
    if (text.length > maxStoredChars) {
      removeStoredText(storageKey);
      return;
    }
    writeStoredText(storageKey, text);
  }

  /// Chỉ dùng khi kiểm thử: quên hết trạng thái trong bộ nhớ (không xóa bản lưu trong trình duyệt).
  static void forgetMemoryForTest() {
    _venues = null;
    _savedAt = null;
  }
}
