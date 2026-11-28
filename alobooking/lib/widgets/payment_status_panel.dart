import 'dart:async';

import 'package:flutter/material.dart';

/// Trạng thái của lần thanh toán đang theo dõi.
enum PaymentState { waiting, paid, cancelled, timedOut }

/// Đọc trạng thái các đơn theo mã; trả về null nếu chưa đọc được (mất mạng...).
typedef StatusFetcher = Future<List<String>?> Function(List<String> bookingIds);

/// Theo dõi đơn vừa đặt cho tới khi được xác nhận đã nhận tiền.
///
/// Ứng dụng không tự khẳng định đã thanh toán: chỉ khi trạng thái đơn trên cơ sở dữ liệu chuyển sang
/// "Đã xác nhận" (máy nhận thông báo SePay, hoặc chủ sân/quản trị viên xác nhận) mới báo thành công.
class PaymentStatusPanel extends StatefulWidget {
  final List<String> bookingIds;
  final StatusFetcher fetch;
  final VoidCallback onPaid;
  final Duration interval;
  final Duration timeout;

  const PaymentStatusPanel({
    super.key,
    required this.bookingIds,
    required this.fetch,
    required this.onPaid,
    this.interval = const Duration(seconds: 4),
    this.timeout = const Duration(minutes: 10),
  });

  /// Từ danh sách trạng thái: tất cả đã xác nhận thì xong; có đơn bị hủy thì dừng.
  static PaymentState stateOf(List<String> statuses, int expected) {
    if (statuses.any((s) => s == 'Đã hủy')) return PaymentState.cancelled;
    final done = statuses.where((s) => s == 'Đã xác nhận' || s == 'Hoàn thành').length;
    return expected > 0 && done == expected ? PaymentState.paid : PaymentState.waiting;
  }

  @override
  State<PaymentStatusPanel> createState() => _PaymentStatusPanelState();
}

class _PaymentStatusPanelState extends State<PaymentStatusPanel> {
  Timer? _timer;
  PaymentState _state = PaymentState.waiting;
  Duration _waited = Duration.zero;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    _waited += widget.interval;
    if (_busy) return;
    _busy = true;
    List<String>? statuses;
    try {
      statuses = await widget.fetch(widget.bookingIds);
    } catch (_) {
      statuses = null;
    }
    _busy = false;
    if (!mounted || _state != PaymentState.waiting) return;

    var next = statuses == null ? PaymentState.waiting : PaymentStatusPanel.stateOf(statuses, widget.bookingIds.length);
    if (next == PaymentState.waiting && _waited >= widget.timeout) next = PaymentState.timedOut;
    if (next == PaymentState.waiting) return;

    _timer?.cancel();
    setState(() => _state = next);
    if (next == PaymentState.paid) widget.onPaid();
  }

  @override
  Widget build(BuildContext context) {
    final (Color color, Widget leading, String text) = switch (_state) {
      PaymentState.waiting => (
          const Color(0xFF38BDF8),
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF38BDF8))),
          'Đang chờ tiền về… Màn hình tự báo thành công khi nhận được, không cần bấm gì.',
        ),
      PaymentState.paid => (
          const Color(0xFF22C55E),
          const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 22),
          'Đã nhận được thanh toán.',
        ),
      PaymentState.cancelled => (
          const Color(0xFFF87171),
          const Icon(Icons.cancel_outlined, color: Color(0xFFF87171), size: 20),
          'Đơn đã bị hủy. Nếu bạn đã chuyển tiền, hãy liên hệ chủ sân.',
        ),
      PaymentState.timedOut => (
          const Color(0xFFFBBF24),
          const Icon(Icons.schedule_rounded, color: Color(0xFFFBBF24), size: 20),
          'Chưa nhận được thanh toán. Đơn vẫn ở trạng thái "Chờ xác nhận"; xem lại trong mục Sân đã đặt.',
        ),
    };
    return Container(
      key: ValueKey('payment-${_state.name}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, height: 1.35))),
        ],
      ),
    );
  }
}

/// Màn báo thành công: dấu tích xanh lớn.
class PaymentSuccessView extends StatelessWidget {
  final String code;
  final String amount;

  const PaymentSuccessView({super.key, required this.code, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('payment-success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: const Icon(Icons.check_circle_rounded, size: 96, color: Color(0xFF22C55E)),
        ),
        const SizedBox(height: 14),
        const Text('Đặt sân thành công!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF22C55E))),
        const SizedBox(height: 8),
        Text('Đã nhận $amount cho đơn $code.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Đang chuyển đến lịch đã đặt…', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      ],
    );
  }
}
