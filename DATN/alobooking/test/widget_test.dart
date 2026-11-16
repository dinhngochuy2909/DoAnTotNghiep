import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/main.dart';

void main() {
  testWidgets('App mở thẳng màn đặt sân với 3 sân con và thanh tổng tiền', (WidgetTester tester) async {
    await tester.pumpWidget(const AlobookingApp());
    // Không dùng pumpAndSettle: màn hình có gọi mạng (trong test luôn trả 400 và rơi về dữ liệu mẫu)
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Pickleball 1'), findsWidgets);
    expect(find.text('Pickleball 2'), findsWidgets);
    expect(find.text('Pickleball 3'), findsWidgets);
    expect(find.textContaining('Tổng giờ'), findsWidgets);
    // Chưa chọn ô nào -> tổng 0 giờ
    expect(find.textContaining('Tổng giờ: 0h00'), findsWidgets);
  });
}
