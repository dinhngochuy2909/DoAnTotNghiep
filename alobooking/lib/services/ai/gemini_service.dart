import 'dart:convert';
import 'package:http/http.dart' as http;
import 'rag_service.dart';

/// Một lượt hội thoại gửi cho LLM.
class ChatTurn {
  final bool isUser;
  final String text;
  const ChatTurn(this.isUser, this.text);
}

/// Sinh câu trả lời theo mô hình RAG: chỉ dựa trên dữ liệu đã truy xuất.
class GeminiService {
  /// Khóa API lấy từ biến build: flutter run --dart-define-from-file=dart_defines.json
  /// (không ghi trực tiếp vào code). Có thể nhập tạm lúc chạy ở màn hình dự báo.
  static String apiKey = const String.fromEnvironment('GEMINI_API_KEY');

  static bool get hasApiKey => apiKey.trim().isNotEmpty;

  /// Model ưu tiên, đặt bằng --dart-define=GEMINI_MODEL=ten-model (trong dart_defines.json).
  static const String _preferredModel = String.fromEnvironment('GEMINI_MODEL');

  /// Danh sách thử lần lượt: model ưu tiên trước, các model còn lại làm dự phòng khi quá tải.
  static List<String> models = [
    if (_preferredModel.isNotEmpty) _preferredModel,
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite-preview',
    'gemini-3-flash-preview',
    'gemini-flash-latest',
  ];

  static const _systemPrompt = '''
Bạn là trợ lý đặt sân của ứng dụng AloBooking (sân Pickleball, Cầu lông, Bóng đá, Tennis tại Hà Nội).

QUY TẮC:
1. Chỉ trả lời dựa trên phần "TRI THỨC ALOBOOKING" và "NGỮ CẢNH" trong tin nhắn. Tuyệt đối không bịa tên sân, địa chỉ, giá, giờ, khuyến mãi hay chính sách.
2. Nếu dữ liệu không có thông tin khách hỏi, nói thẳng là hệ thống chưa có thông tin này và gợi ý liên hệ Hotline/Zalo 0364059999. Nếu không có sân khớp, nói rõ và đề xuất nới tiêu chí (đổi quận, môn, mức giá).
3. Khi nhắc sân: nêu tên, địa chỉ, giá, giờ mở cửa, đánh giá. Với câu hỏi về lịch trống, dùng đúng dòng "Lịch ..." trong dữ liệu; không khẳng định sân còn trống nếu dữ liệu không nói vậy.
4. Chỉ nói sân có tiện ích nào đó nếu dữ liệu ghi rõ. Không suy diễn; đặc biệt không khẳng định sân "trong nhà"/"có mái che" nếu dữ liệu không ghi. Thời tiết: chỉ dùng mục thoi_tiet_ha_noi (kể cả "du_bao") và nêu đúng số liệu/khả năng mưa theo buổi khách hỏi.
5. Khi gợi ý sân, nhắc khách bấm nút "ĐẶT SÂN" trên thẻ sân hiển thị bên dưới để chọn giờ.
6. TRẢ LỜI ĐÚNG TRỌNG TÂM câu hỏi: nếu khách hỏi giá trung bình/mặt bằng giá, nêu ngay con số trong phần "Thống kê giá" (đúng khung giờ khách hỏi: giờ vàng = ca 16:00–22:00), rồi chỉ nêu tối đa 2-3 sân làm ví dụ. Đừng liệt kê sân khi khách không hỏi tìm sân.
7. Khi có mục "DỰ ĐOÁN": đó là ước lượng thống kê. Luôn nói là dự đoán, nêu mức nhu cầu, tỉ lệ hủy dự kiến, yếu tố chính và độ tin cậy; không hứa chắc chắn.
8. Hiểu các câu hỏi nối tiếp dựa vào lịch sử hội thoại. Trả lời tiếng Việt, thân thiện, ngắn gọn (tối đa ~150 từ), dùng **in đậm** cho thông tin chính, danh sách gạch đầu dòng.
''';

  /// Gemini có thể trả câu trả lời thành NHIỀU phần (parts); phải ghép tất cả,
  /// nếu chỉ đọc phần đầu thì câu trả lời bị cụt giữa chừng. Bỏ qua phần "suy nghĩ".
  static String _joinParts(dynamic body) {
    final parts = body?['candidates']?[0]?['content']?['parts'];
    if (parts is! List) return '';
    return parts
        .where((p) => p is Map && p['thought'] != true && p['text'] is String)
        .map((p) => p['text'] as String)
        .join();
  }

  /// Bước 1 của RAG: nhờ LLM hiểu câu hỏi (kèm lịch sử) và trả về bộ lọc có cấu trúc.
  /// Trả về null nếu không gọi được; khi đó dùng luật cứng trong RagService.
  static Future<Map<String, dynamic>?> understand(
    String userMessage, {
    List<ChatTurn> history = const [],
  }) async {
    if (!hasApiKey) return null;
    try {
      await RagService.ensureLoaded();
      final now = DateTime.now();
      String d(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
      final recent = history.reversed.take(6).toList().reversed.map((t) => '${t.isUser ? 'Khách' : 'Bot'}: ${t.text.replaceAll('\n', ' ')}').join('\n');
      final prompt = '''
Hôm nay là ${d(now)} (thứ ${now.weekday == 7 ? 'CN' : now.weekday + 1}). Khu vực có sân: ${RagService.coverageText()}.

Lịch sử gần nhất:
${recent.isEmpty ? '(chưa có)' : recent}

Câu hỏi mới của khách: "$userMessage"

Phân tích câu hỏi MỚI (dùng lịch sử để hiểu câu nối tiếp như "còn quận khác thì sao", "rẻ hơn thì sao", "sân đó mấy giờ mở"; nếu khách đổi chủ đề thì bỏ điều kiện cũ). Câu nối tiếp chỉ kế thừa môn, quận hoặc tên sân của lượt trước; KHÔNG kế thừa giá, giờ, ngày, tiện ích, giờ vàng nếu khách không nhắc lại. Trả về JSON đúng các khóa:
{
 "sport": "pickleball|badminton|football|tennis|null",
 "districts": ["tên quận/huyện Hà Nội khách nhắc tới, tiếng Việt có dấu"],
 "other_area": "tỉnh/thành ngoài Hà Nội khách nhắc tới hoặc null",
 "max_price_k": số nghìn đồng/giờ tối đa hoặc null,
 "hour": giờ muốn chơi 0-23 hoặc null,
 "date": "YYYY-MM-DD" hoặc null,
 "wants_price_stats": true nếu hỏi mặt bằng giá/giá trung bình/bao nhiêu tiền,
 "golden_hour": true nếu hỏi giờ vàng/cao điểm/buổi tối,
 "cheapest": bool, "top_rated": bool, "nearest": bool,
 "amenities": ["den_dem","gui_xe","may_ban_bong","mai_che"],
 "topics": ["cancel","fixed","payment","promo","guide","weather","contact","forecast"],  // forecast = hỏi dự đoán độ đông/nhu cầu/tỉ lệ hủy đặt sân
 "venue_name": "tên sân cụ thể khách nhắc (kể cả đã nhắc ở lượt trước) hoặc null"
}''';
      final body = json.encode({
        'systemInstruction': {
          'parts': [
            {'text': 'Bạn là bộ phân tích câu hỏi cho chatbot đặt sân thể thao. Chỉ trả về JSON hợp lệ, không giải thích.'}
          ]
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {'temperature': 0, 'maxOutputTokens': 400, 'responseMimeType': 'application/json'},
      });
      // Thử tối đa 2 model: model đầu bị quá tải/lỗi thì dùng model kế tiếp
      for (final model in models.take(2)) {
        try {
          final res = await http
              .post(
                Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
                headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
                body: body,
              )
              .timeout(const Duration(seconds: 6));
          if (res.statusCode != 200) continue;
          final text = _joinParts(json.decode(res.body));
          if (text.trim().isEmpty) continue;
          final m = json.decode(text);
          if (m is Map<String, dynamic>) return m;
        } catch (_) {}
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Trả lời một câu hỏi của khách bằng RAG.
  static Future<String> answer(
    String userMessage, {
    required RagRetrievalResult rag,
    List<ChatTurn> history = const [],
    Map<String, dynamic> liveContext = const {},
  }) async {
    final prompt = '''
NGỮ CẢNH THỜI GIAN THỰC:
${const JsonEncoder.withIndent('  ').convert(liveContext)}

${rag.augmentedPromptText}

CÂU HỎI CỦA KHÁCH: $userMessage''';

    if (hasApiKey) {
      final contents = <Map<String, dynamic>>[
        for (final t in history.reversed.take(8).toList().reversed)
          {
            'role': t.isUser ? 'user' : 'model',
            'parts': [
              {'text': t.text}
            ],
          },
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ],
        },
      ];
      for (final model in models) {
        try {
          final res = await http
              .post(
                Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
                headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
                body: json.encode({
                  'systemInstruction': {
                    'parts': [
                      {'text': _systemPrompt}
                    ]
                  },
                  'contents': contents,
                  'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 2500},
                }),
              )
              .timeout(const Duration(seconds: 12));
          if (res.statusCode == 200) {
            final text = _joinParts(json.decode(res.body));
            if (text.trim().isNotEmpty) return text.trim();
          }
        } catch (_) {}
      }
    }
    return localAnswer(rag);
  }

  /// Phương án dự phòng khi không gọi được LLM: trình bày trực tiếp dữ liệu đã truy xuất.
  static String localAnswer(RagRetrievalResult rag) {
    final b = StringBuffer();
    final it = rag.intent;

    for (final c in rag.chunks.where((c) => c.category != 'venue')) {
      b.writeln('**${c.title}**');
      b.writeln(c.content);
      b.writeln();
    }

    final st = rag.stats;
    if (st != null) {
      // Trả lời thẳng câu hỏi về giá trước, ví dụ sân chỉ để tham khảo
      String k(num v) => '${v.round()}k';
      for (final g in [st, ...rag.moreStats]) {
        final u = g.unit;
        b.writeln('💵 **Giá ${g.label}** (${g.count} sân):\n');
        if (it.goldenHour) {
          b.writeln('• **Ca giờ vàng (16:00–22:00): trung bình ${k(g.avgHigh)}/$u**');
          b.writeln('• Khung giờ thường (ngoài ca vàng): trung bình ${k(g.avgLow)}/$u');
        } else {
          b.writeln('• **Khung giờ thường (ngoài ca vàng): trung bình ${k(g.avgLow)}/$u**');
          b.writeln('• Ca giờ vàng (16:00–22:00): trung bình ${k(g.avgHigh)}/$u');
        }
        b.writeln('• Thấp nhất ${k(g.minLow)}/$u • Cao nhất ${k(g.maxHigh)}/$u');
        b.writeln();
      }
    }

    if (rag.forecastText != null) {
      b.writeln(rag.forecastText!.replaceAll('## ', '').replaceAll('**', '').trim());
      b.writeln();
    }

    if (rag.matchedVenues.isNotEmpty) {
      final shown = st != null ? rag.matchedVenues.take(3).toList() : rag.matchedVenues;
      b.writeln(st != null
          ? '🎯 **Một số sân tham khảo:**\n'
          : '🎯 **Tìm thấy ${rag.matchedVenues.length} sân phù hợp:**\n');
      for (final v in shown) {
        b.writeln('• **${v.name}** (${RagService.sportLabel(v.type)} • ${v.district})');
        b.writeln('  📍 ${v.address}');
        b.writeln('  💵 **${v.price}** • ⏰ ${v.hours} • ⭐ ${v.rating}');
        if (st == null) b.writeln('  ${RagService.availabilityText(v, it.date, hour: it.hour)}');
        b.writeln();
      }
      b.writeln('👉 Bấm **"ĐẶT SÂN"** trên thẻ sân bên dưới để chọn giờ.');
    } else if (it.unknownArea != null) {
      b.writeln('😕 Hiện AloBooking **chưa có sân tại ${it.unknownArea}**. Hệ thống đang có sân ở **Hà Nội**: ${RagService.coverageText()}.');
      b.writeln('\n👉 Bạn thử hỏi theo quận/huyện gần nhất, ví dụ "sân cầu lông Gia Lâm" hoặc "sân bóng đá Long Biên".');
    } else if (it.wantsVenues) {
      b.writeln('😕 Hiện hệ thống **chưa có sân khớp** với yêu cầu của bạn. Thử đổi quận, môn thể thao hoặc mức giá, hoặc gọi Hotline/Zalo **0364059999** để được hỗ trợ.');
    }

    if (b.isEmpty) {
      return 'Mình có thể giúp bạn tìm sân (theo môn, quận, giá, giờ), xem lịch đã đặt, hướng dẫn đặt sân, thanh toán, khuyến mãi và chính sách hủy/dời lịch. Bạn muốn hỏi gì? Hỗ trợ trực tiếp: **0364059999**.';
    }
    return b.toString().trim();
  }

}
