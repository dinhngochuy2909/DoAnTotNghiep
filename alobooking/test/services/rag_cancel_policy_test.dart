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

    expect(context, contains('không tự hủy được trên ứng dụng'));
    expect(context, isNot(contains('"Hủy đặt sân"')));
    expect(context, isNot(contains('2 tiếng')));
    expect(context, isNot(contains('bảo lưu 100% tiền cọc')));
  });
}
