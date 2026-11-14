import 'package:flutter/material.dart';
import '../screens/chatbot_screen.dart';
import '../services/navigator_key.dart';

/// Nút ChatBot AI nổi thông minh ở góc phải màn hình
/// Hiển thị trên tất cả các màn hình, có hiệu ứng phát sáng lấp lánh
class FloatingChatBotButton extends StatefulWidget {
  const FloatingChatBotButton({super.key});

  @override
  State<FloatingChatBotButton> createState() => _FloatingChatBotButtonState();
}

class _FloatingChatBotButtonState extends State<FloatingChatBotButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _openChatbot(BuildContext context) {
    // Sử dụng rootNavigatorKey để đảm bảo mở được màn hình từ bất kỳ vị trí nào
    final nav = rootNavigatorKey.currentState ?? Navigator.maybeOf(context);
    if (nav != null) {
      nav.push(
        MaterialPageRoute(builder: (_) => const ChatbotScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openChatbot(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D6A38), Color(0xFF16A34A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16A34A).withOpacity(0.45),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0xFFFDE047), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Robot
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 8),

                // Nhãn chữ
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI DỰ BÁO',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Nhu cầu đặt sân 24/7',
                      style: TextStyle(
                        color: Color(0xFFFDE047),
                        fontWeight: FontWeight.bold,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),

                // Chấm xanh online
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
