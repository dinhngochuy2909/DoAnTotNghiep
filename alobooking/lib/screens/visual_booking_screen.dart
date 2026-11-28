import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/venue.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/booking_slots.dart';
import '../services/payment_config.dart';
import '../widgets/payment_status_panel.dart';
import '../widgets/booking_bottom_sheet.dart';
import 'booked_screen.dart';
import 'home_screen.dart';
import 'chatbot_screen.dart';

/// Bảng màu nền đen của màn đặt lịch trực quan.
class _Vb {
  static const bg = Color(0xFF0A0A0B); // nền màn hình
  static const surface = Color(0xFF121214); // thanh, khung, ô trống
  static const surface2 = Color(0xFF1A1A1D); // hộp thoại, bảng xác nhận
  static const field = Color(0xFF242428); // dòng/ô nổi trên hộp thoại
  static const header = Color(0xFF17212B); // hàng và cột tiêu đề của bảng giờ
  static const border = Color(0xFF2C2C31);
  static const text = Color(0xFFF4F4F5);
  static const textDim = Color(0xFFA1A1AA);
  static const accent = Color(0xFF38BDF8); // xanh lá sáng
  static const selected = Color(0xFF075985); // ô đang chọn
  static const booked = Color(0xFFB91C1C); // ô đã đặt
  static const locked = Color(0xFF3F3F46); // ô khoá
  static const gold = Color(0xFFFACC15);
  static const warn = Color(0xFFFBBF24);
}

/// Theme tối cho màn hình và các hộp thoại/bảng mở ra từ màn hình này (giữ nguyên phông chữ của ứng dụng).
ThemeData _vbTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: const ColorScheme.dark(
      primary: _Vb.accent,
      onPrimary: Colors.black,
      secondary: _Vb.accent,
      surface: _Vb.surface2,
      onSurface: _Vb.text,
      error: Color(0xFFF87171),
    ),
    scaffoldBackgroundColor: _Vb.bg,
    canvasColor: _Vb.surface2,
    dividerColor: _Vb.border,
    dividerTheme: const DividerThemeData(color: _Vb.border),
    textTheme: base.textTheme.apply(bodyColor: _Vb.text, displayColor: _Vb.text),
    inputDecorationTheme: const InputDecorationTheme(
      labelStyle: TextStyle(color: _Vb.textDim),
      prefixIconColor: _Vb.textDim,
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _Vb.border)),
      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _Vb.accent)),
    ),
  );
}

class VisualBookingScreen extends StatefulWidget {
  final Venue venue;

  /// Ngày mở sẵn khi vào màn hình (mặc định hôm nay), ví dụ khi người dùng chọn một khung giờ ở trang Khám phá.
  final DateTime? initialDate;

  const VisualBookingScreen({
    super.key,
    required this.venue,
    this.initialDate,
  });

  @override
  State<VisualBookingScreen> createState() => _VisualBookingScreenState();
}

class _VisualBookingScreenState extends State<VisualBookingScreen> {
  // Ngày được chọn (mặc định hôm nay)
  late DateTime _selectedDate;
  late final ScrollController _dateScrollController;
  late final ScrollController _timelineScrollController;

  // Độ rộng mỗi ô giờ (mặc định 68px, có thể zoom qua slider)
  double _hourColumnWidth = 52.0;

  // Các sân con của cụm (số sân và tên gọi lấy theo từng cụm sân, không cố định)
  late final List<String> _subCourts;

  // Các ô đang chọn, khoá dạng "chỉ số sân-giờ"
  final Set<String> _selectedSlots = {};

  // Map lưu các slot đã đặt từ trước (server / mẫu)
  final Map<String, String> _slotStatusMap = {};

  bool _isLoading = false;

  // Giờ bắt đầu và kết thúc: từ 5:00 đến 24:00 (chuẩn xác 19 ca giờ theo ảnh mẫu)
  final int _startHour = 5;
  final int _endHour = 24;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final init = widget.initialDate;
    // Không mở vào ngày đã qua
    _selectedDate = (init != null && !DateTime(init.year, init.month, init.day).isBefore(today))
        ? DateTime(init.year, init.month, init.day)
        : today;
    _dateScrollController = ScrollController();
    _timelineScrollController = ScrollController();

    // Khởi tạo danh sách sân con
    _initSubCourts();

    // Nạp dữ liệu các slot mẫu và Firestore
    _loadExistingBookings();
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    _timelineScrollController.dispose();
    super.dispose();
  }

  void _initSubCourts() {
    _subCourts = widget.venue.courtNames;
  }

  String _formatDateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadExistingBookings() async {
    final date = _selectedDate;
    final dateKey = _formatDateKey(date);
    _slotStatusMap.clear();

    // Đọc các ca đã đặt thật từ Firestore (bỏ đơn đã hủy), nhận cả hai định dạng ngày
    try {
      final booked = await BookingSlots.bookedSlots(widget.venue, date, _subCourts.length);
      // Người dùng đã đổi sang ngày khác trong lúc đang tải -> bỏ kết quả cũ
      if (!mounted || _formatDateKey(_selectedDate) != dateKey) return;
      for (final k in booked) {
        _slotStatusMap['$dateKey-$k'] = 'booked';
      }
      // Bỏ chọn các ô vừa bị người khác đặt
      _selectedSlots.removeWhere((s) => booked.contains(s));
    } catch (_) {}

    if (mounted) setState(() {});
  }

  /// Giá một giờ theo khoảng giá của sân: khung thường = giá thấp, từ 17h = giá cao.
  int _priceForHour(int hour) => BookingSlots.priceForHour(widget.venue, hour);

  int _totalPrice(Iterable<int> hours) => hours.fold(0, (sum, h) => sum + _priceForHour(h));

  /// Các giờ đang chọn (bỏ trùng sân).
  List<int> _selectedHours() =>
      _selectedSlots.map((s) => int.parse(s.split('-')[1])).toList();

  String _formatCurrency(int amount) {
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
  }

  void _toggleSlot(int courtIndex, int hour) {
    if (widget.venue.isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đây là sân demo (dữ liệu minh họa, không phải cơ sở có thật) nên không đặt được.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    if (!widget.venue.hasListedPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cụm sân này chưa niêm yết giá trên AloBooking nên chưa đặt online được. Vui lòng liên hệ trực tiếp cơ sở.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    final dateKey = _formatDateKey(_selectedDate);
    final slotKey = '$courtIndex-$hour';
    final fullKey = '$dateKey-$courtIndex-$hour';

    final status = _slotStatusMap[fullKey];
    if (status == 'booked') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Khung giờ này đã có khách đặt trước! Vui lòng chọn khung giờ trống (màu trắng).'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }
    if (status == 'locked') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Khung giờ này đang khoá hoặc bảo trì.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (status == 'event') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🟪 Khung giờ này đang diễn ra Sự kiện / Giải đấu thi đấu.'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFFD946EF),
        ),
      );
      return;
    }

    setState(() {
      if (_selectedSlots.contains(slotKey)) {
        _selectedSlots.remove(slotKey);
      } else {
        _selectedSlots.add(slotKey);
      }
    });
  }

  void _onDateSelected(DateTime dt) {
    setState(() {
      _selectedDate = dt;
      _selectedSlots.clear();
    });
    _loadExistingBookings();
  }

  void _onNextStep() {
    if (AuthService.isGuest) {
      BookingBottomSheet.showGuestRestrictionDialog(context);
      return;
    }

    if (_selectedSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('👉 Vui lòng chạm vào các ô màu trắng trên bảng để chọn sân và khung giờ bạn muốn đặt!'),
          backgroundColor: Color(0xFFD97706),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    _showBookingConfirmationSheet();
  }

  void _showPriceInfoDialog() {
    final v = widget.venue;
    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: _vbTheme(ctx),
        child: AlertDialog(
        backgroundColor: _Vb.surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.sell_outlined, color: _Vb.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bảng Giá & Chi Tiết Sân\n${widget.venue.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPriceRow('Khung giờ thường (trước 16:00, sau 22:00)', v.hasListedPrice ? _formatCurrency(_priceForHour(10)) : 'Chưa niêm yết'),
              const SizedBox(height: 6),
              _buildPriceRow('Ca giờ vàng (${BookingSlots.goldenLabel})', v.hasListedPrice ? _formatCurrency(_priceForHour(18)) : 'Chưa niêm yết'),
              const Divider(height: 20),
              Text('🏟️ Số sân: ${_subCourts.length} sân (${_subCourts.first} … ${_subCourts.last})', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text('⏰ Giờ mở cửa: ${v.hours}', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text('📍 ${v.address}', style: const TextStyle(fontSize: 13)),
              if (v.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('✨ Tiện ích:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                for (final t in v.tags) Text('• $t'),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0369A1)),
            child: const Text('Đã hiểu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _Vb.field,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
          Text(price, style: const TextStyle(fontWeight: FontWeight.bold, color: _Vb.accent, fontSize: 13)),
        ],
      ),
    );
  }

  void _showBookingConfirmationSheet() {
    final user = AuthService.currentUser;
    final nameCtrl = TextEditingController(text: user?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    final noteCtrl = TextEditingController();
    const paymentMethod = 'Chuyển khoản VietQR';

    final List<Map<String, dynamic>> parsedSlots = [];
    for (final s in _selectedSlots) {
      final parts = s.split('-');
      final courtIdx = int.parse(parts[0]);
      final hour = int.parse(parts[1]);
      parsedSlots.add({
        'courtName': _subCourts[courtIdx],
        'courtIndex': courtIdx,
        'hour': hour,
        'timeStr': '${hour.toString().padLeft(2, '0')}:00 - ${(hour + 1).toString().padLeft(2, '0')}:00',
      });
    }

    parsedSlots.sort((a, b) {
      final cCmp = (a['courtIndex'] as int).compareTo(b['courtIndex'] as int);
      if (cCmp != 0) return cCmp;
      return (a['hour'] as int).compareTo(b['hour'] as int);
    });

    final totalHours = parsedSlots.length;
    final totalPrice = _totalPrice(parsedSlots.map((s) => s['hour'] as int));
    final dateStr = _formatDateKey(_selectedDate);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Theme(
        data: _vbTheme(ctx),
        // BottomSheet đặt Material theo theme SÁNG của ứng dụng nên phải đặt lại màu chữ mặc định cho nền tối
        child: DefaultTextStyle.merge(
        style: const TextStyle(color: _Vb.text),
        child: StatefulBuilder(
        builder: (context, _) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: _Vb.surface2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF52525B),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Xác Nhận Đặt Sân',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _Vb.text,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C2A45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF075985)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.venue.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _Vb.accent),
                      ),
                      const SizedBox(height: 4),
                      Text('📅 Ngày đặt: $dateStr', style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 6),
                      const Text('🏟️ Các ca giờ đã chọn:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: parsedSlots.map((s) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0369A1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${s['courtName']}: ${s['timeStr']}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tổng số giờ: ${totalHours}h00', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            _formatCurrency(totalPrice),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFF87171)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên người đặt *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại nhận mã sân *',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú thêm (thuê thêm vợt, bóng...)',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Thanh toán:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C2A45),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF075985)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.qr_code_2, size: 22, color: _Vb.accent),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Chuyển khoản ngân hàng bằng mã VietQR, không nhận tiền mặt. '
                          'Sau khi xác nhận, bạn sẽ nhận mã QR kèm nội dung chuyển khoản; '
                          'đơn được xác nhận khi nhận được tiền.',
                          style: TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFFBAE6FD)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Vui lòng điền đầy đủ họ tên và số điện thoại!')),
                              );
                              return;
                            }

                            Navigator.pop(ctx);
                            setState(() => _isLoading = true);

                            final courtSummary = parsedSlots.map((s) => s['courtName']).toSet().join(', ');
                            final timeSummary = parsedSlots.map((s) => s['timeStr']).join(', ');

                            // Kiểm tra lại ngay trước khi lưu: có ai vừa đặt trùng giờ không
                            final latest = await BookingSlots.bookedSlots(
                                widget.venue, _selectedDate, _subCourts.length);
                            final clash = _selectedSlots.where(latest.contains).toList();
                            if (clash.isNotEmpty) {
                              await _loadExistingBookings();
                              if (!mounted) return;
                              setState(() => _isLoading = false);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFFDC2626),
                                  content: Text('⚠️ Có khung giờ vừa được người khác đặt. Vui lòng chọn lại giờ trống.'),
                                ),
                              );
                              return;
                            }

                            // Mỗi sân con một đơn để lịch đọc lại chính xác
                            final bookingDate = BookingSlots.formatDate(_selectedDate);
                            final byCourt = <int, List<int>>{};
                            for (final s in parsedSlots) {
                              byCourt.putIfAbsent(s['courtIndex'] as int, () => []).add(s['hour'] as int);
                            }
                            // Các đơn của cùng một lần thanh toán dùng chung một mã để khách chuyển khoản một lần
                            final baseCode = 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                            final bookingIds = [
                              for (var i = 1; i <= byCourt.length; i++) byCourt.length == 1 ? baseCode : '$baseCode-$i',
                            ];
                            var allSaved = true;
                            var seq = 0;
                            for (final e in byCourt.entries) {
                              seq++;
                              final ok = await FirestoreService.createBooking(
                                id: bookingIds[seq - 1],
                                customer: nameCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                venueName: widget.venue.name,
                                field: _subCourts[e.key],
                                time: BookingSlots.mergeHours(e.value).join(', '),
                                date: bookingDate,
                                amount: _formatCurrency(_totalPrice(e.value)),
                                paymentMethod: paymentMethod,
                                ownerId: widget.venue.ownerId,
                                venueId: widget.venue.id,
                                userId: AuthService.currentUser?.uid ?? '',
                              );
                              if (!ok) allSaved = false;
                            }

                            if (!mounted) return;
                            setState(() => _isLoading = false);

                            if (!allSaved) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFFDC2626),
                                  content: Text('Không lưu được đơn đặt sân. Vui lòng kiểm tra mạng và thử lại.'),
                                ),
                              );
                              await _loadExistingBookings();
                              return;
                            }

                            _selectedSlots.clear();
                            await _loadExistingBookings();

                            if (mounted) {
                              _showPaymentDialog(
                                code: baseCode,
                                bookingIds: bookingIds,
                                courtSummary: courtSummary,
                                timeSummary: timeSummary,
                                dateStr: dateStr,
                                totalPrice: totalPrice,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _Vb.gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text(
                            'XÁC NHẬN & THANH TOÁN',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
      ),
    );
  }

  Widget _copyRow(BuildContext ctx, String label, String value, {String? copyValue}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(label, style: const TextStyle(fontSize: 12, color: _Vb.textDim))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          if (copyValue != null)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: copyValue));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã sao chép $label'), duration: const Duration(seconds: 1)),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.copy_rounded, size: 16, color: _Vb.accent),
              ),
            ),
        ],
      ),
    );
  }

  /// Sau khi giữ chỗ: hướng dẫn chuyển khoản (mã QR VietQR dựng sẵn đúng số tiền và nội dung).
  void _showPaymentDialog({
    required String code,
    required List<String> bookingIds,
    required String courtSummary,
    required String timeSummary,
    required String dateStr,
    required int totalPrice,
  }) {
    final content = PaymentConfig.transferContent(code);
    final payload = PaymentConfig.qrPayload(amount: totalPrice, content: content);
    var paid = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: _vbTheme(ctx),
        child: StatefulBuilder(builder: (ctx, setDialog) {
        if (paid) {
          return AlertDialog(
            backgroundColor: _Vb.surface2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SizedBox(width: 340, child: PaymentSuccessView(code: code, amount: _formatCurrency(totalPrice))),
          );
        }
        return AlertDialog(
        backgroundColor: _Vb.surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.account_balance_outlined, color: _Vb.accent, size: 44),
            SizedBox(height: 8),
            Text(
              'CHUYỂN KHOẢN ĐỂ GIỮ SÂN',
              style: TextStyle(fontWeight: FontWeight.w900, color: _Vb.accent, fontSize: 17),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đơn $code đã được ghi nhận ở trạng thái "Chờ xác nhận". '
                  'Hãy chuyển khoản đúng số tiền và nội dung dưới đây; khi nhận được tiền, đơn được xác nhận.',
                  style: const TextStyle(fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 12),
                if (payload != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: QrImageView(data: payload, size: 200, backgroundColor: Colors.white),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2410),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF854D0E)),
                    ),
                    child: Text(
                      'Hệ thống chưa khai báo tài khoản nhận tiền nên chưa tạo được mã QR. '
                      'Vui lòng liên hệ hotline 0364059999 để nhận thông tin chuyển khoản cho đơn $code.',
                      style: const TextStyle(fontSize: 12.5, height: 1.4, color: _Vb.warn),
                    ),
                  ),
                const SizedBox(height: 10),
                if (payload != null) ...[
                  PaymentStatusPanel(
                    bookingIds: bookingIds,
                    fetch: FirestoreService.getBookingStatuses,
                    onPaid: () {
                      setDialog(() => paid = true);
                      // Giữ dấu tích một lát rồi tự chuyển sang lịch đã đặt
                      Future.delayed(const Duration(seconds: 3), () {
                        if (!mounted || !ctx.mounted) return;
                        Navigator.pop(ctx);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => BookedScreen(allVenues: [widget.venue])),
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _copyRow(ctx, 'Ngân hàng', PaymentConfig.bankName.isEmpty ? 'BIN ${PaymentConfig.bankBin}' : PaymentConfig.bankName),
                  _copyRow(ctx, 'Số tài khoản', PaymentConfig.accountNo, copyValue: PaymentConfig.accountNo),
                  if (PaymentConfig.accountName.isNotEmpty) _copyRow(ctx, 'Chủ tài khoản', PaymentConfig.accountName),
                ],
                _copyRow(ctx, 'Số tiền', _formatCurrency(totalPrice), copyValue: totalPrice.toString()),
                _copyRow(ctx, 'Nội dung', content, copyValue: content),
                const Divider(height: 20),
                Text('🏟️ ${widget.venue.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text('📍 $courtSummary', style: const TextStyle(fontSize: 12)),
                Text('⏰ $timeSummary', style: const TextStyle(fontSize: 12)),
                Text('📅 $dateStr', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => BookedScreen(allVenues: [widget.venue])),
              );
            },
            child: const Text('Xem lịch đã đặt', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedSlots.clear());
              _loadExistingBookings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0369A1)),
            child: const Text('Đóng', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
      }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final screenWidth = media.width;
    final isMobile = screenWidth < 750;
    // Màn hình thấp (điện thoại xoay ngang): các khối phía trên không đủ chỗ nếu xếp cố định
    final isShort = media.height < 520;

    return Theme(
      data: _vbTheme(context),
      child: Scaffold(
      backgroundColor: _Vb.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // 1. TOP GREEN APPBAR & HEADER
            // ==========================================
            _buildTopAppBar(isMobile),

            // ==========================================
            // 2. HORIZONTAL DATE PICKER & STATUS LEGEND
            // 3. NOTICE BOX (Lưu ý chuẩn xác theo ảnh mới)
            // ==========================================
            if (isShort)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: media.height * 0.38),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildDateStripAndLegend(isMobile),
                      _buildNoticesBox(isMobile),
                    ],
                  ),
                ),
              )
            else ...[
              _buildDateStripAndLegend(isMobile),
              _buildNoticesBox(isMobile),
            ],

            // ==========================================
            // 4. THE CORE VISUAL TIMELINE MATRIX (5:00 -> 24:00)
            // ==========================================
            Expanded(
              child: _buildSynchronizedTimelineMatrix(isMobile),
            ),

            // ==========================================
            // 5. SLIDER ZOOM TRỰC QUAN (ẩn khi màn hình thấp để dành chỗ cho bảng giờ)
            // ==========================================
            if (!isShort) _buildZoomSliderRow(),

            // ==========================================
            // 6. BOTTOM GREEN BAR VỚI TỔNG GIỜ & TIẾP THEO
            // ==========================================
            _buildEmeraldBottomBar(isMobile),
          ],
        ),
      ),
      ),
    );
  }

  // ─── 1. TOP APP BAR ───────────────────────────────────────
  Widget _buildTopAppBar(bool isMobile) {
    return Container(
      color: _Vb.surface,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              }
            },
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            splashRadius: 20,
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'ĐẶT LỊCH THEO SÂN - TRỰC QUAN',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Nút AI Dự Báo góc phải AppBar
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0369A1), Color(0xFF0284C7)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE047), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🤖', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 4),
                    Text(
                      'AI Dự Báo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. DATE STRIP & STATUS LEGEND ─────────────────────────
  Widget _buildDateStripAndLegend(bool isMobile) {
    return Container(
      color: _Vb.surface,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    builder: (ctx, child) => Theme(data: _vbTheme(ctx), child: child!),
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 7)),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) _onDateSelected(picked);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Tháng ${_selectedDate.month}, ${_selectedDate.year}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),

              Row(
                children: [
                  _buildNavArrow(Icons.chevron_left, () {
                    _dateScrollController.animateTo(
                      (_dateScrollController.offset - 180).clamp(0, _dateScrollController.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }),
                  const SizedBox(width: 6),
                  _buildNavArrow(Icons.chevron_right, () {
                    _dateScrollController.animateTo(
                      (_dateScrollController.offset + 180).clamp(0, _dateScrollController.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          SizedBox(
            height: 48,
            child: ListView.builder(
              controller: _dateScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: 30,
              itemBuilder: (context, idx) {
                final date = DateTime.now().add(Duration(days: idx));
                final isSelected = date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;

                String dayOfWeek;
                if (idx == 0) {
                  dayOfWeek = 'Hôm nay';
                } else {
                  const days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
                  dayOfWeek = days[date.weekday % 7];
                }

                final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

                return GestureDetector(
                  onTap: () => _onDateSelected(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 58,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? _Vb.accent : Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? _Vb.accent : _Vb.border,
                        width: 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayOfWeek,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF082F49) : _Vb.textDim,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: isSelected ? Colors.black : _Vb.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLegendItem(_Vb.surface, 'Trống', hasBorder: true),
                const SizedBox(width: 14),
                _buildLegendItem(_Vb.booked, 'Đã đặt'),
                const SizedBox(width: 14),
                _buildLegendItem(_Vb.locked, 'Khoá'),
                const SizedBox(width: 14),
                _buildLegendItem(const Color(0xFFD946EF), 'Sự kiện', isEvent: true),
                const SizedBox(width: 18),
                InkWell(
                  onTap: _showPriceInfoDialog,
                  child: const Text(
                    'Xem sân & bảng giá',
                    style: TextStyle(
                      color: Color(0xFFFDE047),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
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

  Widget _buildNavArrow(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool hasBorder = false, bool isEvent = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: hasBorder ? Border.all(color: const Color(0xFF52525B), width: 1) : null,
          ),
          child: isEvent
              ? const Center(
                  child: Text('!', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              : null,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ─── 3. NOTICE BOX (LƯU Ý CHUẨN XÁC THEO ẢNH MẪU) ──────────
  Widget _buildNoticesBox(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: _Vb.surface,
      child: Center(
        child: Column(
          children: [
            Text(
              '${widget.venue.name} · ${_subCourts.length} sân',
              style: const TextStyle(fontSize: 13, color: _Vb.text, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            if (widget.venue.isDemo) ...[
              const SizedBox(height: 3),
              const Text(
                'SÂN DEMO: dữ liệu minh họa, không phải cơ sở có thật. Chỉ xem lịch và bảng giá, không đặt hoặc thanh toán được.',
                key: ValueKey('demo-venue-notice'),
                style: TextStyle(fontSize: 12, color: _Vb.warn, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ],
            if (widget.venue.isImportedListing && widget.venue.hasListedPrice) ...[
              const SizedBox(height: 3),
              const Text(
                'Giá và giờ mở cửa là mức tham khảo, cơ sở chưa xác nhận trên AloBooking.',
                style: TextStyle(fontSize: 12, color: _Vb.warn, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ],
            if (!widget.venue.hasListedPrice) ...[
              const SizedBox(height: 3),
              const Text(
                'Cụm sân chưa niêm yết giá trên AloBooking: chưa đặt online được, vui lòng liên hệ trực tiếp cơ sở.',
                style: TextStyle(fontSize: 12, color: _Vb.warn, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 3),
            // Text.rich (không phải RichText) để nhận phông chữ của ứng dụng
            Text.rich(
              const TextSpan(
                style: TextStyle(fontSize: 12, color: _Vb.textDim),
                children: [
                  TextSpan(
                    text: 'Lưu ý: ',
                    style: TextStyle(color: Color(0xFFFB923C), fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: 'Nếu bạn cần đặt lịch cố định vui lòng liên hệ: '),
                  TextSpan(
                    text: '0364059999',
                    style: TextStyle(fontWeight: FontWeight.bold, color: _Vb.text),
                  ),
                  TextSpan(text: ' để được hỗ trợ'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            const Text(
              'Thanh toán bằng chuyển khoản VietQR, không nhận tiền mặt',
              style: TextStyle(fontSize: 12, color: _Vb.textDim, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            const Text(
              'Lịch đã đặt không hỗ trợ hủy trên ứng dụng',
              style: TextStyle(fontSize: 12, color: _Vb.textDim, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── 4. MA TRẬN GIỜ x SÂN (cột tên sân cố định, cuộn dọc khi cụm có nhiều sân) ──
  static const double _courtColWidth = 96.0;
  static const double _headerHeight = 32.0;
  static const double _rowHeight = 44.0;

  Widget _buildSynchronizedTimelineMatrix(bool isMobile) {
    final int totalSlots = _endHour - _startHour; // 19 ca giờ: 5:00 -> 24:00
    final double gridWidth = totalSlots * _hourColumnWidth + 30.0;
    final dateKey = _formatDateKey(_selectedDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _Vb.surface,
        border: Border.all(color: _Vb.border, width: 1),
      ),
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cột tên sân: đứng yên khi cuộn ngang theo giờ
            SizedBox(
              width: _courtColWidth,
              child: Column(
                children: [
                  Container(
                    height: _headerHeight,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: _Vb.header,
                      border: const Border(
                        bottom: BorderSide(color: _Vb.border, width: 1),
                        right: BorderSide(color: _Vb.border, width: 1),
                      ),
                    ),
                    child: Text(
                      '${_subCourts.length} sân',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7DD3FC)),
                    ),
                  ),
                  for (int i = 0; i < _subCourts.length; i++)
                    Container(
                      height: _rowHeight,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: _Vb.surface,
                        border: const Border(
                          bottom: BorderSide(color: _Vb.border, width: 1),
                          right: BorderSide(color: _Vb.border, width: 1),
                        ),
                      ),
                      child: Text(
                        _subCourts[i],
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _Vb.accent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            // Lưới giờ: cuộn ngang
            Expanded(
              child: SingleChildScrollView(
                controller: _timelineScrollController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: gridWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTimeHeaderRow(totalSlots, gridWidth),
                      for (int courtIdx = 0; courtIdx < _subCourts.length; courtIdx++)
                        _buildCourtRow(courtIdx, totalSlots, dateKey, gridWidth),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tiêu đề giờ: mốc 5:00, 6:00, ..., 24:00 nằm đúng trên vạch ngăn giữa các ca giờ.
  Widget _buildTimeHeaderRow(int totalSlots, double gridWidth) {
    return Container(
      width: gridWidth,
      height: _headerHeight,
      decoration: const BoxDecoration(
        color: _Vb.header,
        border: Border(bottom: BorderSide(color: _Vb.border, width: 1)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int idx = 0; idx <= totalSlots; idx++)
            Positioned(
              left: idx == 0 ? 2.0 : idx * _hourColumnWidth - 25.0,
              width: 50.0,
              top: 2,
              bottom: 0,
              child: Column(
                crossAxisAlignment: idx == 0 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${_startHour + idx}:00',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF7DD3FC)),
                      ),
                    ),
                  ),
                  Container(width: 1.5, height: 4.5, color: const Color(0xFFF59E0B)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Hàng ca giờ của một sân con.
  Widget _buildCourtRow(int courtIdx, int totalSlots, String dateKey, double gridWidth) {
    return Container(
      width: gridWidth,
      height: _rowHeight,
      decoration: const BoxDecoration(
        color: _Vb.surface,
        border: Border(bottom: BorderSide(color: _Vb.border, width: 1)),
      ),
      child: Row(
        children: [
          for (int hourIdx = 0; hourIdx < totalSlots; hourIdx++)
            _buildSlotCell(courtIdx, hourIdx, totalSlots, dateKey, _rowHeight),
          const SizedBox(width: 30.0),
        ],
      ),
    );
  }

  Widget _buildSlotCell(int courtIdx, int hourIdx, int totalSlots, String dateKey, double rowHeight) {
    final int h = _startHour + hourIdx;
    final String slotKey = '$courtIdx-$h';
    final String fullKey = '$dateKey-$courtIdx-$h';

    final bool isSelected = _selectedSlots.contains(slotKey);
    final String? status = _slotStatusMap[fullKey];

    final bool prevSelected = _selectedSlots.contains('$courtIdx-${h - 1}');
    final bool nextSelected = _selectedSlots.contains('$courtIdx-${h + 1}');

    final bool prevBooked = _slotStatusMap['$dateKey-$courtIdx-${h - 1}'] == 'booked';
    final bool nextBooked = _slotStatusMap['$dateKey-$courtIdx-${h + 1}'] == 'booked';

    Color cellColor;
    Border cellBorder;

    if (isSelected) {
      // ĐANG CHỌN: xanh lá đậm, viền xanh lá sáng
      cellColor = _Vb.selected;
      cellBorder = Border(
        top: const BorderSide(color: _Vb.accent, width: 1.5),
        bottom: const BorderSide(color: _Vb.accent, width: 1.5),
        left: prevSelected ? BorderSide.none : const BorderSide(color: _Vb.accent, width: 1.5),
        right: nextSelected ? BorderSide.none : const BorderSide(color: _Vb.accent, width: 1.5),
      );
    } else if (status == 'booked') {
      // ĐÃ ĐẶT: đỏ liền mạch
      cellColor = _Vb.booked;
      const edge = Color(0xFF7F1D1D);
      cellBorder = Border(
        top: const BorderSide(color: edge, width: 0.5),
        bottom: const BorderSide(color: edge, width: 0.5),
        left: prevBooked ? BorderSide.none : const BorderSide(color: edge, width: 1),
        right: nextBooked ? BorderSide.none : const BorderSide(color: edge, width: 1),
      );
    } else if (status == 'locked') {
      cellColor = _Vb.locked;
      cellBorder = Border.all(color: _Vb.border, width: 0.5);
    } else {
      // TRỐNG: ô tối, vạch dọc mảnh trùng với mốc giờ bên trên
      cellColor = _Vb.surface;
      cellBorder = const Border(
        right: BorderSide(color: _Vb.border, width: 1),
      );
    }

    return InkWell(
      key: ValueKey('slot-$courtIdx-$h'),
      mouseCursor: SystemMouseCursors.click,
      onTap: () => _toggleSlot(courtIdx, h),
      child: Container(
        width: _hourColumnWidth,
        height: rowHeight,
        decoration: BoxDecoration(
          color: cellColor,
          border: cellBorder,
        ),
      ),
    );
  }

  // ─── 5. THANH SLIDER ZOOM ──────────────────────────────────
  Widget _buildZoomSliderRow() {
    return Container(
      color: _Vb.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.zoom_out, size: 16, color: _Vb.textDim),
          SizedBox(
            width: 120,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: _Vb.accent,
                inactiveTrackColor: _Vb.locked,
                thumbColor: _Vb.accent,
              ),
              child: Slider(
                value: _hourColumnWidth,
                min: 45.0,
                max: 110.0,
                onChanged: (val) {
                  setState(() => _hourColumnWidth = val);
                },
              ),
            ),
          ),
          const Icon(Icons.zoom_in, size: 16, color: _Vb.textDim),
        ],
      ),
    );
  }

  // ─── 6. BOTTOM GREEN BAR (TỔNG GIỜ & NÚT TIẾP THEO) ────────
  Widget _buildEmeraldBottomBar(bool isMobile) {
    final selectedCount = _selectedSlots.length;
    final totalPrice = _totalPrice(_selectedHours());

    return Container(
      decoration: const BoxDecoration(
        color: _Vb.surface,
        border: Border(top: BorderSide(color: _Vb.border, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
          const SizedBox(height: 2),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng giờ: ${selectedCount}h00',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                'Tổng tiền: ${_formatCurrency(totalPrice)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _onNextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: _Vb.gold,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'TIẾP THEO',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
