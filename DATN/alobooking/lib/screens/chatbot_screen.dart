import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/weather_service.dart';
import '../services/firestore_service.dart';

// ─── MODEL TIN NHẮN ───
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

// ─── CHATBOT SCREEN ───
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // Context data được cache lại để không phải load lại mỗi lần gửi
  Map<String, dynamic> _cachedContext = {};
  bool _contextLoaded = false;

  static const Color _primaryGreen = Color(0xFF0D6A38);
  static const Color _lightGreen = Color(0xFF16A34A);
  static const Color _userBubbleColor = Color(0xFF1A5276);
  static const Color _aiBubbleColor = Color(0xFF1E8449);

  final List<Map<String, String>> _quickReplies = [
    {'emoji': '📊', 'text': 'Phân tích hôm nay'},
    {'emoji': '🌤️', 'text': 'Dự báo cuối tuần'},
    {'emoji': '📈', 'text': 'Sân nào đang hot?'},
    {'emoji': '💡', 'text': 'Giờ nào nên khuyến mãi?'},
    {'emoji': '📅', 'text': 'Dự báo 7 ngày tới'},
  ];

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    // Hiển thị tin chào ngay lập tức
    _addAIMessage('⏳ Đang tải dữ liệu hệ thống và thời tiết Hà Nội...');

    // Load context
    await _loadContext();

    // Gửi lời chào thông minh
    _messages.clear();
    if (mounted) setState(() {});

    await _sendWelcomeMessage();
  }

  Future<void> _loadContext() async {
    try {
      final results = await Future.wait([
        FirestoreService.getBookings(),
        WeatherService.getCurrentWeather(),
      ]);

      final bookings = results[0] as List<BookingItem>;
      final weather = results[1] as WeatherData;

      _cachedContext = _buildContext(bookings, weather);
      _contextLoaded = true;
    } catch (_) {
      _cachedContext = _buildContext([], null);
      _contextLoaded = true;
    }
  }

  Map<String, dynamic> _buildContext(List<BookingItem> bookings, WeatherData? weather) {
    final now = DateTime.now();
    final todayStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year}';

    // Thống kê đặt sân
    final todayBookings = bookings.where((b) => b.date == todayStr).toList();
    final yesterdayBookings = bookings.where((b) => b.date == yesterdayStr).toList();

    // Giờ cao điểm
    final hourCount = <int, int>{};
    for (final b in bookings) {
      try {
        final timeParts = b.time.split(' - ');
        if (timeParts.isNotEmpty) {
          final hour = int.tryParse(timeParts[0].split(':')[0]) ?? 0;
          hourCount[hour] = (hourCount[hour] ?? 0) + 1;
        }
      } catch (_) {}
    }
    final sortedHours = hourCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final peakHours = sortedHours.take(3).map((e) => '${e.key}h (${e.value} lượt)').toList();

    // Thống kê theo loại sân
    final venueTypeCount = <String, int>{};
    final cancelledCount = bookings.where((b) => b.status.contains('Hủy')).length;

    for (final b in bookings) {
      final type = _detectVenueType(b.venueName + ' ' + b.field);
      venueTypeCount[type] = (venueTypeCount[type] ?? 0) + 1;
    }
    final sortedTypes = venueTypeCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final popularSport = sortedTypes.isNotEmpty ? sortedTypes.first.key : 'Chưa có dữ liệu';

    // Thống kê tuần
    final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeekBookings = bookings.where((b) {
      try {
        final parts = b.date.split('/');
        if (parts.length == 3) {
          final d = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          return d.isAfter(thisWeekStart.subtract(const Duration(days: 1))) && d.isBefore(now.add(const Duration(days: 1)));
        }
      } catch (_) {}
      return false;
    }).length;

    // Tỷ lệ hủy
    final cancelRate = bookings.isNotEmpty
        ? (cancelledCount / bookings.length * 100).toStringAsFixed(1)
        : '0';

    // Thứ trong tuần
    const weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    final weekday = weekdays[now.weekday - 1];
    final isWeekend = now.weekday == 6 || now.weekday == 7;

    // Ngày lễ
    final holiday = _detectHoliday(now);

    return {
      'thoi_gian_hien_tai': {
        'ngay': todayStr,
        'gio': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'thu': weekday,
        'cuoi_tuan': isWeekend,
        'ngay_le': holiday,
      },
      'thoi_tiet_ha_noi': weather?.toMap() ?? {
        'trang_thai': 'Không lấy được dữ liệu thời tiết',
        'nhiet_do': 'N/A',
        'do_am': 'N/A',
      },
      'thong_ke_dat_san': {
        'tong_don_hom_nay': todayBookings.length,
        'tong_don_hom_qua': yesterdayBookings.length,
        'tong_don_tuan_nay': thisWeekBookings,
        'tong_don_toan_he_thong': bookings.length,
        'ty_le_huy': '$cancelRate%',
        'gio_cao_diem': peakHours,
        'loai_san_pho_bien': popularSport,
        'phan_loai_theo_san': sortedTypes.take(4).map((e) => '${e.key}: ${e.value} lượt').toList(),
      },
      'trang_thai_dat_san_hom_nay': todayBookings.take(5).map((b) => {
        'khach': b.customer,
        'san': b.venueName,
        'gio': b.time,
        'trang_thai': b.status,
      }).toList(),
    };
  }

  String _detectVenueType(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('pickleball')) return 'Pickleball';
    if (lower.contains('cầu lông') || lower.contains('badminton')) return 'Cầu lông';
    if (lower.contains('bóng đá') || lower.contains('football') || lower.contains('soccer')) return 'Bóng đá';
    if (lower.contains('tennis')) return 'Tennis';
    if (lower.contains('bóng rổ') || lower.contains('basketball')) return 'Bóng rổ';
    return 'Khác';
  }

  String _detectHoliday(DateTime date) {
    // Ngày lễ dương lịch
    if (date.month == 1 && date.day == 1) return 'Tết Dương Lịch 🎊';
    if (date.month == 4 && date.day == 30) return 'Ngày Giải Phóng Miền Nam 🇻🇳';
    if (date.month == 5 && date.day == 1) return 'Quốc Tế Lao Động 👷';
    if (date.month == 9 && date.day == 2) return 'Quốc Khánh Việt Nam 🇻🇳';
    if (date.month == 12 && date.day == 25) return 'Giáng Sinh 🎄';

    // Kiểm tra gần lễ (trong vòng 3 ngày)
    final upcoming = [
      DateTime(date.year, 1, 1),
      DateTime(date.year, 4, 30),
      DateTime(date.year, 5, 1),
      DateTime(date.year, 9, 2),
    ];
    for (final holiday in upcoming) {
      final diff = holiday.difference(date).inDays;
      if (diff > 0 && diff <= 3) {
        return 'Sắp đến ngày lễ (còn $diff ngày)';
      }
    }

    return 'Không có ngày lễ';
  }

  Future<void> _sendWelcomeMessage() async {
    final now = DateTime.now();
    const weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    final weekday = weekdays[now.weekday - 1];
    final isWeekend = now.weekday >= 6;

    final todayBookings = _cachedContext['thong_ke_dat_san']?['tong_don_hom_nay'] ?? 0;
    final weather = _cachedContext['thoi_tiet_ha_noi'] ?? {};
    final weatherEmoji = weather['emoji'] ?? '🌤️';
    final temp = weather['nhiet_do'] ?? 'N/A';
    final weatherDesc = weather['trang_thai'] ?? 'không xác định';

    final greeting = _buildGreeting(now.hour);

    final welcomeMsg = '''$greeting 👋 Tôi là **AI Dự Báo AloBooking**!

📍 **Hôm nay:** $weekday, ${now.day}/${now.month}/${now.year}
$weatherEmoji **Thời tiết HN:** $temp | $weatherDesc
📋 **Đặt sân hôm nay:** **$todayBookings đơn**${isWeekend ? '\n🎉 Cuối tuần! Dự kiến nhu cầu tăng cao.' : ''}

Tôi có thể giúp bạn:
• 📊 Phân tích xu hướng đặt sân
• 🔮 Dự báo nhu cầu theo ngày/giờ
• 💡 Đề xuất chiến lược khuyến mãi

Bạn muốn phân tích điều gì hôm nay?''';

    _addAIMessage(welcomeMsg);
  }

  String _buildGreeting(int hour) {
    if (hour < 6) return 'Chào đêm khuya';
    if (hour < 12) return 'Chào buổi sáng';
    if (hour < 14) return 'Chào buổi trưa';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  void _addAIMessage(String text) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: false));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    final userMsg = text.trim();
    _textController.clear();

    setState(() {
      _messages.add(ChatMessage(text: userMsg, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    // Load context nếu chưa có
    if (!_contextLoaded) {
      await _loadContext();
    }

    final aiResponse = await GeminiService.analyzeAndPredict(userMsg, _cachedContext);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _messages.add(ChatMessage(text: aiResponse, isUser: false));
      });
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
              ),
              child: const Center(
                child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Dự Báo Nhu Cầu Sân 🤖',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'AloBooking Analytics · Hà Nội',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Làm mới dữ liệu',
            onPressed: () async {
              setState(() {
                _messages.clear();
                _contextLoaded = false;
                _cachedContext = {};
                _isLoading = false;
              });
              await _initChat();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── QUICK REPLY CHIPS ───
          _buildQuickReplies(),

          // ─── CHAT MESSAGES ───
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // ─── INPUT BAR ───
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _quickReplies.map((qr) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _sendMessage('${qr['emoji']} ${qr['text']}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _primaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _primaryGreen.withOpacity(0.35), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(qr['emoji']!, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                      Text(
                        qr['text']!,
                        style: TextStyle(
                          color: _primaryGreen,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final timeStr = '${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 6, bottom: 2),
              decoration: const BoxDecoration(
                color: _aiBubbleColor,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? _userBubbleColor : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: isUser
                        ? null
                        : Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
                  ),
                  child: _buildMessageText(message.text, isUser),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 2, right: 2),
                  child: Text(
                    timeStr,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 6, bottom: 2),
              decoration: const BoxDecoration(
                color: _userBubbleColor,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageText(String text, bool isUser) {
    // Xử lý markdown đơn giản: **bold**
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF1E293B),
            fontSize: 13.5,
            height: 1.5,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          color: isUser ? Colors.white : const Color(0xFF0D6A38),
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(
          color: isUser ? Colors.white : const Color(0xFF1E293B),
          fontSize: 13.5,
          height: 1.5,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: _aiBubbleColor,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(150),
                const SizedBox(width: 4),
                _buildDot(300),
                const SizedBox(width: 8),
                Text(
                  'AI đang phân tích...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + delayMs),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _primaryGreen.withOpacity(0.4 + value * 0.6),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: TextField(
                controller: _textController,
                enabled: !_isLoading,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  hintText: 'Hỏi AI về nhu cầu đặt sân...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.5),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isLoading ? null : () => _sendMessage(_textController.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: _isLoading
                    ? null
                    : const LinearGradient(
                        colors: [_primaryGreen, _lightGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: _isLoading ? Colors.grey[300] : null,
                shape: BoxShape.circle,
                boxShadow: _isLoading
                    ? []
                    : [
                        BoxShadow(
                          color: _primaryGreen.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(
                _isLoading ? Icons.hourglass_top_rounded : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
