import 'dart:convert';
import 'package:http/http.dart' as http;
import 'analytics_context_service.dart';
import 'rag_service.dart';

/// Một lượt hội thoại gửi cho LLM.
class ChatTurn {
  final bool isUser;
  final String text;
  const ChatTurn(this.isUser, this.text);
}

/// Sinh câu trả lời theo mô hình RAG: chỉ dựa trên dữ liệu đã truy xuất.
class GeminiService {
  static String apiKey = 'AQ.Ab8RN6LnDr5etc_CK47vDVO-NYLSrABxVFKkef7QivNymkmtuA';

  static bool get hasApiKey => apiKey.trim().isNotEmpty;

  static const _models = [
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
4. Chỉ nói sân có tiện ích nào đó nếu dữ liệu ghi rõ. Không suy diễn.
5. Khi gợi ý sân, nhắc khách bấm nút "ĐẶT SÂN" trên thẻ sân hiển thị bên dưới để chọn giờ.
6. Hiểu các câu hỏi nối tiếp dựa vào lịch sử hội thoại. Trả lời tiếng Việt, thân thiện, ngắn gọn (tối đa ~150 từ), dùng **in đậm** cho thông tin chính, danh sách gạch đầu dòng.
''';

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
      for (final model in _models) {
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
                  'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 1000},
                }),
              )
              .timeout(const Duration(seconds: 12));
          if (res.statusCode == 200) {
            final text = json.decode(res.body)['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
            if (text != null && text.trim().isNotEmpty) return text.trim();
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

    if (rag.matchedVenues.isNotEmpty) {
      b.writeln('🎯 **Tìm thấy ${rag.matchedVenues.length} sân phù hợp:**\n');
      for (final v in rag.matchedVenues) {
        b.writeln('• **${v.name}** (${RagService.sportLabel(v.type)} • ${v.district})');
        b.writeln('  📍 ${v.address}');
        b.writeln('  💵 **${v.price}** • ⏰ ${v.hours} • ⭐ ${v.rating}');
        b.writeln('  ${RagService.availabilityText(v, it.date, hour: it.hour)}\n');
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

  /// Dùng cho màn hình phân tích nhu cầu (chủ sân): thêm thống kê hệ thống vào ngữ cảnh.
  static Future<String> generateForecast({
    required String userQuery,
    required AnalyticsContextData context,
  }) async {
    final rag = await RagService.retrieve(userQuery);
    return answer(
      userQuery,
      rag: rag,
      liveContext: {
        'thoi_gian': '${context.currentDateTimeStr} (${context.dayOfWeekStr})',
        'thoi_tiet_ha_noi': context.weather.toMap(),
        'thong_ke_dat_san': {
          'don_hom_nay': context.todayBookingsCount,
          'tong_don': context.totalBookingsCount,
          'ty_le_huy': '${context.cancellationRate.toStringAsFixed(1)}%',
          'ty_le_lap_day': '${context.courtOccupancyRate.toStringAsFixed(1)}%',
          'theo_loai_san': context.bookingsByCourtType,
          'gio_cao_diem': context.peakHoursDistribution,
        },
      },
    );
  }
}
