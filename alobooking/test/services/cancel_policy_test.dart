import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/services/cancel_policy.dart';

void main() {
  final start = DateTime(2026, 12, 1, 18, 0);
  bool can(DateTime now) => CancelPolicy.canCustomerCancel(start, now);

  test('còn cách giờ chơi từ 2 tiếng trở lên thì được hủy, đúng 2 tiếng vẫn được', () {
    expect(can(DateTime(2026, 11, 30, 18, 0)), isTrue);
    expect(can(DateTime(2026, 12, 1, 15, 59)), isTrue);
    expect(can(DateTime(2026, 12, 1, 16, 0)), isTrue);
  });

  test('còn dưới 2 tiếng, đang chơi hoặc đã qua giờ thì không được hủy', () {
    expect(can(DateTime(2026, 12, 1, 16, 1)), isFalse);
    expect(can(DateTime(2026, 12, 1, 17, 59)), isFalse);
    expect(can(DateTime(2026, 12, 1, 18, 30)), isFalse);
    expect(can(DateTime(2026, 12, 2)), isFalse);
  });

  test('không đọc được giờ chơi thì không cho tự hủy', () {
    expect(CancelPolicy.canCustomerCancel(null, DateTime(2026, 12, 1)), isFalse);
  });
}
