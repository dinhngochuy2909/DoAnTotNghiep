/// Quy tắc khách tự hủy lịch: chỉ được hủy khi còn cách giờ chơi từ [minNoticeHours] tiếng trở lên.
/// Chủ sân và quản trị viên không bị giới hạn này.
class CancelPolicy {
  CancelPolicy._();

  static const minNoticeHours = 2;
  static const minNotice = Duration(hours: minNoticeHours);

  /// Câu hiển thị cho khách.
  static const ruleText = 'Chỉ hủy được khi còn cách giờ chơi từ $minNoticeHours tiếng trở lên.';

  /// [start] là giờ bắt đầu ca sớm nhất của đơn; không đọc được giờ thì không cho tự hủy.
  static bool canCustomerCancel(DateTime? start, DateTime now) =>
      start != null && start.difference(now) >= minNotice;
}
