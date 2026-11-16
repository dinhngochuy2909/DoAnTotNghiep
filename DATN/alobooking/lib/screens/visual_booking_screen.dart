import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/booking_slots.dart';
import '../widgets/booking_bottom_sheet.dart';
import 'booked_screen.dart';
import 'home_screen.dart';
import 'chatbot_screen.dart';

class VisualBookingScreen extends StatefulWidget {
  final Venue venue;

  const VisualBookingScreen({
    super.key,
    required this.venue,
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

  // Danh sách các sân con: chuẩn xác 3 sân Pickleball như trong ảnh
  late final List<String> _subCourts;

  // Set lưu các slot đang được chọn: mặc định chọn sẵn ca 18h - 20h ở Sân 1 giống hệt ảnh của bạn
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
    _selectedDate = DateTime(now.year, now.month, now.day);
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
    // Chuẩn xác 100% theo ảnh giao diện mẫu người dùng yêu cầu: 3 sân Pickleball
    _subCourts = ['Pickleball 1', 'Pickleball 2', 'Pickleball 3'];
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.sell_outlined, color: Color(0xFF15803D)),
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
              _buildPriceRow('Khung giờ thường (trước 17:00)', _formatCurrency(_priceForHour(10))),
              const SizedBox(height: 6),
              _buildPriceRow('Khung giờ vàng (từ 17:00)', _formatCurrency(_priceForHour(18))),
              const Divider(height: 20),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
            child: const Text('Đã hiểu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
          Text(price, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF15803D), fontSize: 13)),
        ],
      ),
    );
  }

  void _showBookingConfirmationSheet() {
    final user = AuthService.currentUser;
    final nameCtrl = TextEditingController(text: user?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    final noteCtrl = TextEditingController();
    String paymentMethod = 'Chuyển khoản VietQR';

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
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
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
                      color: const Color(0xFFCBD5E1),
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
                        color: Color(0xFF0F172A),
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
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.venue.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF15803D)),
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
                              color: const Color(0xFF15803D),
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
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
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

                const Text('Phương thức thanh toán:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => paymentMethod = 'Chuyển khoản VietQR'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: paymentMethod == 'Chuyển khoản VietQR' ? const Color(0xFFDCFCE7) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: paymentMethod == 'Chuyển khoản VietQR' ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                              width: paymentMethod == 'Chuyển khoản VietQR' ? 2 : 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_2, size: 18, color: Color(0xFF15803D)),
                              SizedBox(width: 4),
                              Text('VietQR / Momo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => paymentMethod = 'Tiền mặt tại sân'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: paymentMethod == 'Tiền mặt tại sân' ? const Color(0xFFDCFCE7) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: paymentMethod == 'Tiền mặt tại sân' ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                              width: paymentMethod == 'Tiền mặt tại sân' ? 2 : 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payments_outlined, size: 18, color: Color(0xFF15803D)),
                              SizedBox(width: 4),
                              Text('Tiền mặt tại sân', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
                              ScaffoldMessenger.of(context).showSnackBar(
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
                            var allSaved = true;
                            for (final e in byCourt.entries) {
                              final ok = await FirestoreService.createBooking(
                                customer: nameCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                venueName: widget.venue.name,
                                field: _subCourts[e.key],
                                time: BookingSlots.mergeHours(e.value).join(', '),
                                date: bookingDate,
                                amount: _formatCurrency(_totalPrice(e.value)),
                                paymentMethod: paymentMethod,
                              );
                              if (!ok) allSaved = false;
                            }

                            if (!mounted) return;
                            setState(() => _isLoading = false);

                            if (!allSaved) {
                              ScaffoldMessenger.of(context).showSnackBar(
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
                              _showSuccessBookingDialog(
                                courtSummary: courtSummary,
                                timeSummary: timeSummary,
                                dateStr: dateStr,
                                totalPrice: _formatCurrency(totalPrice),
                                paymentMethod: paymentMethod,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEAB308),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'XÁC NHẬN ĐẶT SÂN NGAY',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
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

  void _showSuccessBookingDialog({
    required String courtSummary,
    required String timeSummary,
    required String dateStr,
    required String totalPrice,
    required String paymentMethod,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 54),
            SizedBox(height: 8),
            Text(
              'ĐẶT SÂN THÀNH CÔNG! 🎉',
              style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF15803D), fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yêu cầu đặt sân của bạn đã được lưu lên máy chủ AloBooking và gửi tới ban quản lý sân.',
              style: TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🏟️ Sân: ${widget.venue.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('📍 Khu vực: $courtSummary', style: const TextStyle(fontSize: 12)),
                  Text('⏰ Ca giờ: $timeSummary', style: const TextStyle(fontSize: 12)),
                  Text('📅 Ngày: $dateStr', style: const TextStyle(fontSize: 12)),
                  Text('💰 Tổng tiền: $totalPrice', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  Text('💳 Hình thức: $paymentMethod', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
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
            child: const Text('Xem danh sách sân đã đặt', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedSlots.clear();
              });
              _loadExistingBookings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
            child: const Text('Tiếp tục xem lịch', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 750;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // 1. TOP GREEN APPBAR & HEADER
            // ==========================================
            _buildTopAppBar(isMobile),

            // ==========================================
            // 2. HORIZONTAL DATE PICKER & STATUS LEGEND
            // ==========================================
            _buildDateStripAndLegend(isMobile),

            // ==========================================
            // 3. NOTICE BOX (Lưu ý chuẩn xác theo ảnh mới)
            // ==========================================
            _buildNoticesBox(isMobile),

            // ==========================================
            // 4. THE CORE VISUAL TIMELINE MATRIX (5:00 -> 24:00)
            // ==========================================
            Expanded(
              child: _buildSynchronizedTimelineMatrix(isMobile),
            ),

            // ==========================================
            // 5. SLIDER ZOOM TRỰC QUAN
            // ==========================================
            _buildZoomSliderRow(),

            // ==========================================
            // 6. BOTTOM GREEN BAR VỚI TỔNG GIỜ & TIẾP THEO
            // ==========================================
            _buildEmeraldBottomBar(isMobile),
          ],
        ),
      ),
    );
  }

  // ─── 1. TOP APP BAR ───────────────────────────────────────
  Widget _buildTopAppBar(bool isMobile) {
    return Container(
      color: const Color(0xFF0D6A38),
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
                    colors: [Color(0xFF15803D), Color(0xFF16A34A)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE047), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
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
      color: const Color(0xFF0D6A38),
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
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.25),
                        width: 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]
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
                            color: isSelected ? const Color(0xFF0D6A38) : Colors.white70,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
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
                _buildLegendItem(const Color(0xFFFFFFFF), 'Trống', hasBorder: true),
                const SizedBox(width: 14),
                _buildLegendItem(const Color(0xFFF87171), 'Đã đặt'),
                const SizedBox(width: 14),
                _buildLegendItem(const Color(0xFF64748B), 'Khoá'),
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
          color: Colors.white.withOpacity(0.18),
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
            border: hasBorder ? Border.all(color: Colors.grey.shade400, width: 1) : null,
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
      color: Colors.white,
      child: Center(
        child: Column(
          children: [
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                children: [
                  TextSpan(
                    text: 'Lưu ý: ',
                    style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: 'Nếu bạn cần đặt lịch cố định vui lòng liên hệ: '),
                  TextSpan(
                    text: '0364059999',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  TextSpan(text: ' để được hỗ trợ'),
                ],
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Lịch đã đặt KHÔNG hỗ trợ Huỷ',
              style: TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── 4. MA TRẬN ĐỒNG BỘ 100% GIỮA HEADER GIỜ VÀ CÁC Ô SÂN ──
  Widget _buildSynchronizedTimelineMatrix(bool isMobile) {
    const double courtColWidth = 72.0;
    const double rowHeight = 44.0;
    final int totalSlots = _endHour - _startHour; // 19 ca giờ: 5:00 -> 24:00
    final double totalWidth = courtColWidth + totalSlots * _hourColumnWidth + 30.0;
    final dateKey = _formatDateKey(_selectedDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: SingleChildScrollView(
        controller: _timelineScrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: SizedBox(
          width: totalWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HÀNG TIÊU ĐỀ THỜI GIAN (XANH CYAN NHẸ) CHUẨN XÁC 100% ẢNH MẪU
              _buildTimeHeaderRow(totalSlots, courtColWidth, totalWidth),

              // DANH SÁCH 3 HÀNG SÂN PICKLEBALL
              for (int courtIdx = 0; courtIdx < _subCourts.length; courtIdx++)
                _buildCourtRow(courtIdx, totalSlots, dateKey, courtColWidth, totalWidth, rowHeight),
            ],
          ),
        ),
      ),
    );
  }

  /// Tiêu đề giờ: Khung xanh cyan, mốc 5:00 nằm CHÍNH XÁC trên vạch ngăn giữa Cột Sân và Ca 0
  /// Mỗi mốc giờ tiếp theo 6:00, 7:00, ..., 24:00 nằm CHÍNH XÁC trên từng vạch ngăn cách ca giờ
  Widget _buildTimeHeaderRow(int totalSlots, double courtColWidth, double totalWidth) {
    return Container(
      width: totalWidth,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFFBAE6FD), // Light cyan header
        border: Border(bottom: BorderSide(color: Color(0xFF94A3B8), width: 1)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 20 mốc giờ: 5:00, 6:00, ..., 24:00
          for (int idx = 0; idx <= totalSlots; idx++) ...[
            Positioned(
              left: (courtColWidth + idx * _hourColumnWidth) - 25.0,
              width: 50.0,
              top: 2,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${_startHour + idx}:00',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0369A1),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  // Vạch cam nhỏ tại chính xác điểm mốc giờ như ảnh mẫu
                  Container(
                    width: 1.5,
                    height: 4.5,
                    color: const Color(0xFFF59E0B),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Hàng ca giờ của từng sân: Cột tên sân (Pickleball 1, 2, 3) + 19 ca giờ
  Widget _buildCourtRow(
    int courtIdx,
    int totalSlots,
    String dateKey,
    double courtColWidth,
    double totalWidth,
    double rowHeight,
  ) {
    return Container(
      width: totalWidth,
      height: rowHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
      ),
      child: Row(
        children: [
          // 1. Ô TÊN SÂN CỐ ĐỊNH PHÍA BÊN TRÁI (Pickleball 1, Pickleball 2, Pickleball 3)
          Container(
            width: courtColWidth,
            height: rowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Colors.grey.shade400, width: 1), // Vạch dọc thẳng mốc 5:00
              ),
            ),
            child: Text(
              _subCourts[courtIdx],
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF15803D), // Màu xanh lá cây đậm chuẩn ảnh
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 2. 19 CA GIỜ (TỪ 5:00 ĐẾN 24:00)
          for (int hourIdx = 0; hourIdx < totalSlots; hourIdx++)
            _buildSlotCell(courtIdx, hourIdx, totalSlots, dateKey, rowHeight),

          // 3. KHOẢNG ĐỆM CUỐI DÒNG
          Container(
            width: 30.0,
            height: rowHeight,
            color: Colors.white,
          ),
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
      // ĐANG CHỌN (18:00 - 20:00 ở Sân 1): Xanh bạc hà nhạt với viền đen sắc nét như ảnh mẫu
      cellColor = const Color(0xFFD4EDDA);
      cellBorder = Border(
        top: const BorderSide(color: Color(0xFF1E293B), width: 1.5),
        bottom: const BorderSide(color: Color(0xFF1E293B), width: 1.5),
        left: prevSelected
            ? BorderSide.none
            : const BorderSide(color: Color(0xFF1E293B), width: 1.5),
        right: nextSelected
            ? BorderSide.none
            : const BorderSide(color: Color(0xFF1E293B), width: 1.5),
      );
    } else if (status == 'booked') {
      // ĐÃ ĐẶT (14:00 - 17:00 ở Sân 1 & 2): Đỏ san hô liền mạch
      cellColor = const Color(0xFFF87171);
      cellBorder = Border(
        top: BorderSide(color: Colors.grey.shade300, width: 0.5),
        bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
        left: prevBooked ? BorderSide.none : BorderSide(color: Colors.grey.shade300, width: 1),
        right: nextBooked ? BorderSide.none : BorderSide(color: Colors.grey.shade300, width: 1),
      );
    } else if (status == 'locked') {
      cellColor = const Color(0xFF64748B);
      cellBorder = Border.all(color: Colors.grey.shade300, width: 0.5);
    } else {
      // TRỐNG (MÀU TRẮNG TINH): Có vạch dọc xám mỏng trùng khớp chuẩn xác với mốc giờ bên trên
      cellColor = Colors.white;
      cellBorder = Border(
        right: BorderSide(color: Colors.grey.shade300, width: 1),
      );
    }

    return InkWell(
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.zoom_out, size: 16, color: Color(0xFF94A3B8)),
          SizedBox(
            width: 120,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: const Color(0xFF16A34A),
                inactiveTrackColor: const Color(0xFFE2E8F0),
                thumbColor: const Color(0xFF16A34A),
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
          const Icon(Icons.zoom_in, size: 16, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  // ─── 6. BOTTOM GREEN BAR (TỔNG GIỜ & NÚT TIẾP THEO) ────────
  Widget _buildEmeraldBottomBar(bool isMobile) {
    final selectedCount = _selectedSlots.length;
    final totalPrice = _totalPrice(_selectedHours());

    return Container(
      color: const Color(0xFF0D6A38),
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
                backgroundColor: const Color(0xFFEAB308),
                foregroundColor: Colors.white,
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
