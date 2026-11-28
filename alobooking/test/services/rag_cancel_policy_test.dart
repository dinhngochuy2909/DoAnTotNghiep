import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alobooking/services/ai/rag_service.dart';

void main() {
  test('Chatbot được cung cấp đúng cách hủy lịch như ứng dụng đang làm', () async {
    // Firestore giả, trả danh sách rỗng: chỉ cần phần chính sách trong ngữ cảnh gửi cho chatbot
    final fake = MockClient((request) async => http.Response('{}', 200));
    final result = await http.runWithClient(() => RagService.retrieve('Tôi muốn hủy sân đã đặt thì làm sao?'), () => fake);
    final context = result.augmentedPromptText;

    expect(context, contains('khi còn cách giờ chơi từ 2 tiếng trở lên'));
    expect(context, contains('Còn dưới 2 tiếng tới giờ chơi thì không hủy được nữa'));
    expect(context, isNot(contains('bảo lưu 100% tiền cọc')));
    expect(context, contains('"Sân đã đặt"'));
    expect(context, contains('"Hủy đặt sân"'));
    expect(context, isNot(contains('KHÔNG tự hủy')));
  });
}
