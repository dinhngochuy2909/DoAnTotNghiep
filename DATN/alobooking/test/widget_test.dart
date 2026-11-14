import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/main.dart';

void main() {
  testWidgets('AlobookingApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AlobookingApp());
    expect(find.text('Hà Nội, Việt Nam'), findsOneWidget);
  });
}
