import 'package:flutter/material.dart';
import '../services/analytics_context_service.dart';
import '../services/gemini_service.dart';
import '../services/weather_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class DemandChatBotScreen extends StatefulWidget {
  const DemandChatBotScreen({super.key});

  @override
  State<DemandChatBotScreen> createState() => _DemandChatBotScreenState();
}

class _DemandChatBotScreenState extends State<DemandChatBotScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  AnalyticsContextData? _contextData;

  // Các câu hỏi gợi ý nhanh
  final List<String> _quickPrompts = [
    '📊 Phân tích nhu cầu hôm nay',
    '🌦️ Thời tiết hôm nay ảnh hưởng gì?',
    '📈 Dự báo cuối tuần có cháy sân không?',
    '💡 Khung giờ nào nên khuyến mãi?',
    '🏓 Nhu cầu sân Pickleball thế nào?',
    '💰 Chiến lược giá giờ cao điểm?',
  ];

  @override
  void initState() {
    super.initState();
    _loadDataAndWelcome();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDataAndWelcome() async {
    setState(() => _isLoading = true);

    // Thu thập dữ liệu hệ thống + ngoại cảnh
    final data = await AnalyticsContextService.collectAnalytics();
    _contextData = data;

    // Tin nhắn chào mừng ban đầu
    final welcomeReply = await GeminiService.generateForecast(
      userQuery: 'Chào AI, hãy tóm tắt nhanh tình hình hệ thống và dự báo nhu cầu đặt sân hôm nay.',
      context: data,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _messages.add(
          ChatMessage(
            text: welcomeReply,
            isUser: false,
          ),
        );
      });
      _scrollToBottom();
    }
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

  Future<void> _handleSubmitted(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isLoading) return;

    _textController.clear();
    setState(() {
      _messages.add(ChatMessage(text: query, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    // Làm mới ngữ cảnh nếu cần
    final ctx = _contextData ?? await AnalyticsContextService.collectAnalytics();
    _contextData = ctx;

    final response = await GeminiService.generateForecast(
      userQuery: query,
      context: ctx,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _messages.add(ChatMessage(text: response, isUser: false));
      });
      _scrollToBottom();
    }
  }

  void _showApiKeyDialog() {
    final geminiCtrl = TextEditingController(text: GeminiService.apiKey);
    final owmCtrl = TextEditingController(text: WeatherService.openWeatherMapKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.key, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text('Cài Đặt API Key', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gemini API Key (Dự báo AI):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: geminiCtrl,
                decoration: InputDecoration(
                  hintText: 'Dán key AIzaSy... hoặc AQ.Ab8...',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 14),
              const Text(
                'OpenWeatherMap API Key (Thời tiết):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: owmCtrl,
                decoration: InputDecoration(
                  hintText: 'Dán key OpenWeatherMap (nếu có)',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Text(
                  '💡 Hệ thống đã tích hợp sẵn Local AI Analytics & Open-Meteo, luôn hoạt động dự báo mượt mà ngay cả khi không có key.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF166534)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () {
              GeminiService.apiKey = geminiCtrl.text.trim();
              WeatherService.openWeatherMapKey = owmCtrl.text.trim();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Đã lưu cấu hình API Key thành công!'),
                  backgroundColor: Color(0xFF16A34A),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Lưu Key', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 1. THANH TIÊU ĐỀ APPBAR CHUYÊN NGHIỆP
          _buildChatHeader(),

          // 2. DASHBOARD TÓM TẮT DỮ LIỆU THỜI GIAN THỰC
          _buildLiveContextDashboard(),

          // 3. DANH SÁCH TIN NHẮN CHAT
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildTypingIndicator();
                }
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // 4. DANH SÁCH CHIP GỢI Ý NHANH
          _buildQuickPromptsBar(),

          // 5. Ô NHẬP NỘI DUNG VÀ NÚT GỬI
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0D6A38),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          // Avatar Robot
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70, width: 1.5),
            ),
            child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 10),

          // Tên Chatbot & Trạng thái
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'AI Dự Báo Nhu Cầu Sân',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.verified, color: Color(0xFFFDE047), size: 16),
                  ],
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.circle, color: Color(0xFF4ADE80), size: 8),
                    SizedBox(width: 5),
                    Text(
                      'Trực tuyến · Phân tích dữ liệu & Ngoại cảnh',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Nút Cài đặt Key
          IconButton(
            onPressed: _showApiKeyDialog,
            icon: const Icon(Icons.key, color: Colors.white70, size: 20),
            tooltip: 'Cài đặt API Key',
          ),

          // Nút Làm mới Data
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🔄 Đang đồng bộ lại dữ liệu hệ thống & thời tiết...')),
              );
              _loadDataAndWelcome();
            },
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
            tooltip: 'Làm mới dữ liệu',
          ),

          // Nút Đóng
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveContextDashboard() {
    final ctx = _contextData;
    final weather = ctx?.weather;
    final tempStr = weather != null ? '${weather.temperature}°C' : '26°C';
    final rainStr = weather != null ? '${weather.rainMm}mm' : '0mm';
    final condStr = weather != null ? weather.condition : 'Tạnh ráo';
    final occStr = ctx != null ? '${ctx.courtOccupancyRate.toStringAsFixed(0)}%' : '78%';
    final todayBookings = ctx?.todayBookingsCount ?? 32;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: const BoxDecoration(
        color: Color(0xFFF0FDF4),
        border: Border(bottom: BorderSide(color: Color(0xFFDCFCE7))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDashboardPill('🌤️ Thời tiết', '$tempStr · $condStr'),
          Container(width: 1, height: 16, color: Colors.grey.shade300),
          _buildDashboardPill('🌧️ Mưa', rainStr),
          Container(width: 1, height: 16, color: Colors.grey.shade300),
          _buildDashboardPill('📊 Lấp đầy', occStr),
          Container(width: 1, height: 16, color: Colors.grey.shade300),
          _buildDashboardPill('🏟️ Hôm nay', '$todayBookings ca'),
        ],
      ),
    );
  }

  Widget _buildDashboardPill(String title, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF166534))),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF0D6A38),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF0D6A38) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                msg.text,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8, top: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0D6A38),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)),
                ),
                SizedBox(width: 8),
                Text(
                  'AI đang tổng hợp dữ liệu & tính toán dự báo...',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPromptsBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final prompt = _quickPrompts[idx];
          return ActionChip(
            label: Text(
              prompt,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: () => _handleSubmitted(prompt),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.analytics_outlined, color: Color(0xFF64748B), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        onSubmitted: _handleSubmitted,
                        decoration: const InputDecoration(
                          hintText: 'Hỏi AI về dự báo nhu cầu, thời tiết, giá sân...',
                          hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: () => _handleSubmitted(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

