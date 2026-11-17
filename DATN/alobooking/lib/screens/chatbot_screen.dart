import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../widgets/venue_image_view.dart';
import '../services/gemini_service.dart';
import '../services/rag_service.dart';
import '../services/weather_service.dart';
import '../services/firestore_service.dart';
import 'visual_booking_screen.dart';
import 'venue_detail_screen.dart';

// ─── MODEL TIN NHẮN ───
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final List<Venue> matchedVenues;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
    this.matchedVenues = const [],
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
    {'emoji': '❓', 'text': 'Chính sách hủy sân & dời lịch'},
    {'emoji': '📞', 'text': 'Đặt lịch cố định tháng giảm bao nhiêu?'},
    {'emoji': '🏓', 'text': 'Sân Pickleball nào có máy bắn bóng?'},
    {'emoji': '🏸', 'text': 'Sân Cầu Lông Đống Đa giá rẻ nhất'},
    {'emoji': '⚽', 'text': 'Sân Bóng Đá có đèn đêm Hà Đông'},
    {'emoji': '🎾', 'text': 'Sân Tennis mở cửa muộn Ba Đình'},
    {'emoji': '🌧️', 'text': 'Trời mưa thì nên chọn sân nào?'},
    {'emoji': '📅', 'text': 'Sân Pickleball nào còn trống tối nay?'},
    {'emoji': '💳', 'text': 'Thanh toán như thế nào?'},
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
        RagService.ensureLoaded(force: true),
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

    final venueCount = RagService.venueCount;
    final welcomeMsg = '''$greeting 👋 Mình là **trợ lý đặt sân AloBooking**.

📍 **Hôm nay:** $weekday, ${now.day}/${now.month}/${now.year}
$weatherEmoji **Thời tiết HN:** $temp | $weatherDesc
📋 **Đặt sân hôm nay:** **$todayBookings đơn**${isWeekend ? '\n🎉 Cuối tuần, sân thường kín nhanh — nên đặt sớm!' : ''}

Mình đọc trực tiếp dữ liệu hệ thống${venueCount > 0 ? ' (**$venueCount sân** đang hoạt động)' : ''} để trả lời về:
• 🔎 Tìm sân theo môn, quận, giá, giờ mở cửa, tiện ích
• 📅 Lịch đã đặt của từng sân
• 💳 Thanh toán, khuyến mãi
• 📋 Hủy/dời lịch, đặt cố định theo tháng

Bạn cần tìm sân nào?''';

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

    // Lịch sử hội thoại (trước tin nhắn hiện tại), bỏ lời chào đầu tiên
    final turns = _messages
        .skip(1)
        .map((m) => ChatTurn(m.isUser, m.text))
        .toList();
    final userHistory = turns.where((t) => t.isUser).map((t) => t.text).toList();

    setState(() {
      _messages.add(ChatMessage(text: userMsg, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    if (!_contextLoaded) {
      await _loadContext();
    }

    String aiResponse;
    List<Venue> matchedVenues = const [];
    try {
      // Truy xuất từ dữ liệu thật (sân đã duyệt + lịch đặt trên Firestore)
      // Bước 1: LLM hiểu câu hỏi (có lịch sử) → bộ lọc; lỗi thì dùng luật cứng
      final llmIntent = await GeminiService.understand(userMsg, history: turns);
      final rag = await RagService.retrieve(userMsg, history: userHistory, llmIntent: llmIntent);
      matchedVenues = rag.matchedVenues;
      aiResponse = await GeminiService.answer(
        userMsg,
        rag: rag,
        history: turns,
        liveContext: {
          'thoi_gian': _cachedContext['thoi_gian_hien_tai'],
          // Thời tiết mới nhất (có cache 10 phút) kèm dự báo, để trả lời "chiều mai có mưa không"
          'thoi_tiet_ha_noi': (await WeatherService.getCurrentWeather()).toMap(),
        },
      );
    } catch (_) {
      aiResponse =
          'Xin lỗi, mình chưa tải được dữ liệu lúc này. Bạn thử lại sau hoặc gọi Hotline/Zalo **0364059999** nhé.';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _messages.add(ChatMessage(
          text: aiResponse,
          isUser: false,
          matchedVenues: matchedVenues,
        ));
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
                  'Trợ Lý Đặt Sân 🤖',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'AloBooking · Hà Nội',
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
                    maxWidth: (MediaQuery.of(context).size.width * 0.75).clamp(240.0, 760.0),
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
                if (!isUser && message.matchedVenues.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _buildMatchedVenuesCarousel(message.matchedVenues),
                ],
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

  Widget _buildMatchedVenuesCarousel(List<Venue> venues) {
    final screenWidth = MediaQuery.of(context).size.width;
    final carouselWidth = (screenWidth - 70).clamp(260.0, 1000.0);

    return Container(
      width: carouselWidth,
      height: 242,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: ScrollConfiguration(
        // Cho phép kéo bằng chuột / cảm ứng trên web & desktop
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: venues.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) => _buildVenueCard(venues[index]),
        ),
      ),
    );
  }

  Widget _buildVenueCard(Venue venue) {
    String sportName = 'Thể thao';
    IconData sportIcon = Icons.sports;
    Color sportColor = const Color(0xFF1E8449);
    switch (venue.type.toLowerCase()) {
      case 'pickleball':
        sportName = 'Pickleball';
        sportIcon = Icons.sports_tennis;
        sportColor = const Color(0xFFD97706);
        break;
      case 'badminton':
        sportName = 'Cầu lông';
        sportIcon = Icons.sports_tennis_rounded;
        sportColor = const Color(0xFF2563EB);
        break;
      case 'football':
        sportName = 'Bóng đá';
        sportIcon = Icons.sports_soccer;
        sportColor = const Color(0xFF059669);
        break;
      case 'tennis':
        sportName = 'Tennis';
        sportIcon = Icons.sports_baseball;
        sportColor = const Color(0xFF7C3AED);
        break;
    }

    return Container(
      width: 236,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ảnh sân + Nhãn môn thể thao + Điểm đánh giá
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: Stack(
              children: [
                SizedBox(
                  height: 100,
                  width: 236,
                  child: VenueImageView(
                    imageUrl: venue.image,
                    fit: BoxFit.cover,
                    width: 236,
                    height: 100,
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.35),
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 7,
                  left: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: sportColor.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sportIcon, color: Colors.white, size: 11),
                        const SizedBox(width: 3),
                        Text(
                          sportName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 11),
                        const SizedBox(width: 2.5),
                        Text(
                          venue.ratingLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Thông tin sân
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 7, 9, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF64748B)),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        venue.distance.isEmpty ? venue.district : '${venue.district} • ${venue.distance}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  venue.price,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF005A36),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // 2 nút thao tác trực tiếp: ĐẶT SÂN & CHI TIẾT
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VisualBookingScreen(venue: venue),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calendar_month, size: 12, color: Colors.white),
                    label: const Text(
                      'ĐẶT SÂN',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6A38),
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                      elevation: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VenueDetailScreen(venue: venue),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: Color(0xFF0D6A38), width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    child: const Text(
                      'Chi tiết',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF0D6A38),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageText(String text, bool isUser) {
    final baseColor = isUser ? Colors.white : const Color(0xFF1E293B);
    final boldColor = isUser ? Colors.white : const Color(0xFF0D6A38);
    final base = TextStyle(color: baseColor, fontSize: 13.5, height: 1.5);
    final bold = TextStyle(color: boldColor, fontSize: 13.5, fontWeight: FontWeight.bold, height: 1.5);

    final spans = <InlineSpan>[];
    final boldRe = RegExp(r'\*\*(.+?)\*\*');
    final lines = text.split('\n');

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];

      // Gạch đầu dòng markdown (* / - / •), thụt lề theo cấp
      final m = RegExp(r'^(\s*)([*\-•])\s+(.*)$').firstMatch(line);
      if (m != null) {
        final level = (m.group(1)!.length / 2).floor().clamp(0, 3);
        final bullet = level == 0 ? '•' : '◦';
        line = '${'    ' * level}$bullet ${m.group(3)}';
      }

      var last = 0;
      for (final bm in boldRe.allMatches(line)) {
        if (bm.start > last) spans.add(TextSpan(text: _stripMd(line.substring(last, bm.start)), style: base));
        spans.add(TextSpan(text: bm.group(1), style: bold));
        last = bm.end;
      }
      if (last < line.length) spans.add(TextSpan(text: _stripMd(line.substring(last)), style: base));
      if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: base));
    }

    return SelectableText.rich(TextSpan(children: spans));
  }

  /// Bỏ các ký tự markdown còn sót (*, _, #) để không hiện dấu thô.
  String _stripMd(String s) =>
      s.replaceAll(RegExp(r'^#{1,6}\s*'), '').replaceAll('*', '').replaceAll('`', '');

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
                  'Đang tra cứu dữ liệu...',
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
                  hintText: 'Hỏi về sân, giá, lịch đặt, chính sách...',
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
