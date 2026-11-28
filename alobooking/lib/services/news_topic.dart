import 'ai/rag_service.dart' show RagText;

/// Nhận ra tin thể thao thuộc môn nào từ tiêu đề, để chọn ảnh minh họa cho đúng chủ đề.
///
/// Chỉ dùng những từ khóa rõ nghĩa. Tin không khớp môn nào (đua xe đạp, điền kinh, bơi lội...) thì trả về null
/// và giữ nền chuyển sắc, không gán đại một môn khác để tránh ảnh minh họa lệch nội dung.
class NewsTopic {
  NewsTopic._();

  /// Từ khóa đã bỏ dấu, thường hóa, ký tự lạ thành khoảng trắng ("V-League" thành "v league").
  /// Thứ tự kiểm tra: môn đặc thù trước, bóng đá sau cùng vì cụm "bóng đá" xuất hiện ở nhiều loại tin.
  static const Map<String, List<String>> _keywords = {
    'tennis': ['quan vot', 'tennis', 'wimbledon', 'roland garros', 'atp', 'wta', 'davis cup'],
    'pickleball': ['pickleball'],
    'badminton': ['cau long', 'badminton'],
    'basketball': ['bong ro', 'nba'],
    'football': [
      'bong da',
      'v league',
      'vleague',
      'premier league',
      'champions league',
      'world cup',
      'la liga',
      'serie a',
      'bundesliga',
      'asian cup',
      'aff cup',
    ],
  };

  /// Môn thể thao ('tennis', 'pickleball', 'badminton', 'basketball', 'football') mà [text] nhắc tới, hoặc null.
  static String? sportOf(String text) {
    final t = ' ${RagText.norm(text)} ';
    for (final e in _keywords.entries) {
      for (final k in e.value) {
        if (t.contains(' $k ')) return e.key;
      }
    }
    return null;
  }
}
