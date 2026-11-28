import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../screens/chatbot_screen.dart';
import '../services/navigator_key.dart';

/// Nút chat AI nổi. Chạm để mở chatbot, nhấn giữ rồi kéo để di chuyển tới bất kỳ chỗ nào trên màn hình
/// (chuột trên máy tính hoặc ngón tay trên điện thoại). Thả tay thì nút hít vào mép trái/phải gần nhất.
///
/// Đặt trong một [Stack] bằng `Positioned.fill`: nút tự quản vị trí trong toàn vùng đó, còn chỗ trống
/// xung quanh không chặn thao tác với ứng dụng phía dưới.
class FloatingChatButton extends StatefulWidget {
  /// Khoảng cách mặc định tới mép phải / mép dưới khi người dùng chưa kéo lần nào
  final double defaultRight;
  final double defaultBottom;

  const FloatingChatButton({super.key, this.defaultRight = 16, this.defaultBottom = 86});

  /// Quên vị trí đã kéo (dùng cho test).
  @visibleForTesting
  static void resetSavedPosition() {
    _savedLeftSide = null;
    _savedVertical = null;
  }

  // Vị trí đã chọn được nhớ trong phiên chạy, dùng chung giữa bản máy tính và khung điện thoại.
  // Phía (trái/phải) và vị trí dọc theo tỉ lệ chiều cao nên vẫn hợp lý khi vùng hiển thị đổi cỡ.
  static bool? _savedLeftSide;
  static double? _savedVertical; // 0 = sát trên, 1 = sát dưới

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton> with SingleTickerProviderStateMixin {
  static const double _size = 56;
  static const double _margin = 8;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _hasNew = true;

  Offset? _drag; // vị trí (góc trên trái) khi đang kéo
  bool _dragging = false;
  Size _area = Size.zero;

  static const Color _primaryGreen = Color(0xFF075985);
  static const Color _lightGreen = Color(0xFF0284C7);

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

  double get _maxX => math.max(_margin, _area.width - _size - _margin);
  double get _maxY => math.max(_margin, _area.height - _size - _margin);

  Offset _clamp(Offset o) => Offset(o.dx.clamp(_margin, _maxX).toDouble(), o.dy.clamp(_margin, _maxY).toDouble());

  /// Vị trí hiện tại của nút (góc trên trái) trong vùng [_area].
  Offset _position() {
    if (_drag != null) return _clamp(_drag!);
    final left = FloatingChatButton._savedLeftSide;
    final v = FloatingChatButton._savedVertical;
    if (left != null && v != null) {
      return _clamp(Offset(left ? _margin : _maxX, _margin + v * (_maxY - _margin)));
    }
    return _clamp(Offset(_area.width - _size - widget.defaultRight, _area.height - _size - widget.defaultBottom));
  }

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _dragging = true;
      _drag = _position();
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _drag = _clamp((_drag ?? _position()) + d.delta));
  }

  void _onPanEnd([DragEndDetails? d]) {
    final p = _drag ?? _position();
    setState(() {
      FloatingChatButton._savedLeftSide = p.dx + _size / 2 < _area.width / 2;
      FloatingChatButton._savedVertical =
          _maxY > _margin ? ((p.dy - _margin) / (_maxY - _margin)).clamp(0.0, 1.0).toDouble() : 1.0;
      _drag = null;
      _dragging = false;
    });
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
    return LayoutBuilder(
      builder: (context, constraints) {
        _area = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : MediaQuery.of(context).size.width,
          constraints.hasBoundedHeight ? constraints.maxHeight : MediaQuery.of(context).size.height,
        );
        final pos = _position();
        return Stack(
          children: [
            AnimatedPositioned(
              // Đang kéo thì bám sát tay; thả tay thì lướt êm vào mép
              duration: _dragging ? Duration.zero : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: pos.dx,
              top: pos.dy,
              width: _size,
              height: _size,
              child: _buildButton(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildButton() {
    return Semantics(
      button: true,
      label: 'Trợ lý AI. Chạm để mở, nhấn giữ rồi kéo để di chuyển',
      child: MouseRegion(
        cursor: _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.click,
        child: GestureDetector(
          key: const ValueKey('chat-fab'),
          behavior: HitTestBehavior.opaque,
          onTap: _openChatbot,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanEnd,
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
                              color: _primaryGreen.withValues(alpha: 0.3 + _pulseController.value * 0.25),
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
                  width: _size,
                  height: _size,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_primaryGreen, _lightGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x66075985),
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
      ),
    );
  }
}
