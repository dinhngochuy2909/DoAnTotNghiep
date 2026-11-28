// Kiểm thử tích hợp: gọi Gemini THẬT. Tự bỏ qua khi không truyền khóa, nên `flutter test` bình thường không tốn lượt gọi.
//
//   flutter test test/integration/gemini_live_test.dart --dart-define-from-file=dart_defines.json
//
// Firestore được thay bằng bản giả có một sân mẫu nên không tốn lượt đọc.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:alobooking/services/ai/gemini_service.dart';
import 'package:alobooking/services/ai/rag_service.dart';

const _venue = {
  'name': 'projects/p/databases/(default)/documents/venues/1',
  'fields': {
    'id': {'integerValue': '1'},
    'name': {'stringValue': 'Sân Cầu Lông Kiểm Thử'},
    'type': {'stringValue': 'badminton'},
    'district': {'stringValue': 'Cầu Giấy'},
    'address': {'stringValue': '1 Phố Thử, Cầu Giấy, Hà Nội'},
    'price': {'stringValue': '70k - 90k/h'},
    'hours': {'stringValue': '05:00 – 23:00'},
  },
};

/// Yêu cầu tới Firestore được trả bằng dữ liệu giả; mọi yêu cầu khác (Gemini) đi ra mạng thật.
class _FakeFirestore extends http.BaseClient {
  _FakeFirestore(this._real);
  final http.Client _real;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.host != 'firestore.googleapis.com') return _real.send(request);
    final body = request.url.path.endsWith('/venues') ? {'documents': [_venue]} : <String, Object>{};
    return Future.value(http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), 200,
        headers: {'content-type': 'application/json; charset=utf-8'}));
  }
}

/// Mã HTTP khi gọi một model; 0 nếu quá 40 giây không trả lời.
Future<int> _call(String model) async {
  try {
    final response = await http
        .post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
          headers: {'Content-Type': 'application/json', 'x-goog-api-key': GeminiService.apiKey},
          body: jsonEncode({
            'contents': [
              {'parts': [{'text': 'Trả lời đúng một từ: chào'}]}
            ],
            'generationConfig': {'maxOutputTokens': 50},
          }),
        )
        .timeout(const Duration(seconds: 40));
    return response.statusCode;
  } on TimeoutException {
    return 0;
  }
}

void main() {
  final skip = GeminiService.hasApiKey ? false : 'Cần --dart-define GEMINI_API_KEY để gọi Gemini thật';

  test('mọi model ứng dụng khai báo đều tồn tại (không 404)', () async {
    final results = <String, int>{};
    for (final model in GeminiService.models) {
      results[model] = await _call(model);
      // ignore: avoid_print
      print('Model $model: ${results[model] == 0 ? 'quá 40 giây' : 'HTTP ${results[model]}'}');
    }
    // 404/400/403 nghĩa là tên model hoặc khóa sai; 429, 503 hay chậm là tạm thời
    expect(results.entries.where((e) => const [400, 401, 403, 404].contains(e.value)), isEmpty, reason: '$results');
    // model đứng đầu (được dùng khi demo) phải trả lời ngay
    expect(results[GeminiService.models.first], 200, reason: '$results');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 4)));

  test('luồng chatbot RAG: Gemini hiểu câu hỏi và sinh câu trả lời (không rơi về phương án dự phòng)', () async {
    final real = http.Client();
    addTearDown(real.close);
    await http.runWithClient(() async {
      const question = 'Sân cầu lông ở Cầu Giấy giá bao nhiêu?';
      final intent = await GeminiService.understand(question);
      expect(intent, isNotNull, reason: 'bước hiểu câu hỏi bằng LLM thất bại');
      final rag = await RagService.retrieve(question, llmIntent: intent);
      expect(rag.matchedVenues, isNotEmpty);
      final answer = await GeminiService.answer(question, rag: rag);
      expect(answer, isNot(GeminiService.localAnswer(rag)), reason: 'câu trả lời đang là phương án dự phòng');
      // ignore: avoid_print
      print('Trả lời: ${answer.replaceAll('\n', ' ').substring(0, answer.length > 160 ? 160 : answer.length)}');
    }, () => _FakeFirestore(real));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));
}
