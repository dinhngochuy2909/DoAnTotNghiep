import 'package:flutter/material.dart';
import '../screens/chatbot_screen.dart';
import '../services/navigator_key.dart';

class FloatingChatButton extends StatefulWidget {
  const FloatingChatButton({super.key});

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _hasNew = true;

  static const Color _primaryGreen = Color(0xFF0D6A38);
  static const Color _lightGreen = Color(0xFF16A34A);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openChatbot() {
    setState(() => _hasNew = false);

    final nav = rootNavigatorKey.currentState ?? Navigator.maybeOf(context);
    if (nav == null) return;
    nav.push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ChatbotScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final begin = const Offset(0, 1.0);
          const end = Offset.zero;
          final tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    ).then((_) {
      // Sau khi đóng chatbot, hiển thị lại badge sau 10 giây
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) {
          setState(() => _hasNew = true);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Vị trí do widget cha (Positioned) quyết định
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _openChatbot,
        child: ScaleTransition(
          scale: _pulseAnimation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Hiệu ứng glow phía sau
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primaryGreen.withOpacity(
                                0.3 + _pulseController.value * 0.25),
                            blurRadius: 16 + _pulseController.value * 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Nút chính
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_primaryGreen, _lightGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x660D6A38),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),

              // Badge "NEW" đỏ
              if (_hasNew)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55EF4444),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
