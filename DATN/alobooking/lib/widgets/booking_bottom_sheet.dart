import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';

class BookingBottomSheet extends StatefulWidget {
  final Venue venue;

  const BookingBottomSheet({super.key, required this.venue});

  /// Hiển thị thông báo khi tài khoản Khách chỉ có quyền xem sân, bắt buộc đăng nhập để đặt
  static void showGuestRestrictionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_outline, color: Color(0xFF15803D), size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Yêu Cầu Đăng Nhập',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.visibility_outlined, color: Color(0xFF16A34A), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bạn đang ở chế độ Khách xem sân',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'AloBooking cho phép bạn xem thông tin sân, bảng giá và bản đồ hoàn toàn tự do.\n\nTuy nhiên, để chọn khung giờ và đặt giữ chỗ, bạn cần Đăng nhập hoặc Đăng ký tài khoản.',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.45),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: const Text('Đăng ký mới', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  icon: const Icon(Icons.login, size: 16),
                  label: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tiếp tục xem sân (Để sau)', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  static void show(BuildContext context, Venue venue) {
    if (AuthService.isGuest) {
      showGuestRestrictionDialog(context);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookingBottomSheet(venue: venue),
    );
  }

  @override
  State<BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<BookingBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  String _selectedSlot = '17:00 - 19:00';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Auto-fill thông tin từ tài khoản đang đăng nhập
    final user = AuthService.currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  final List<String> _slots = [
    '05:00 - 07:00',
    '07:00 - 09:00',
    '09:00 - 11:00',
    '11:00 - 13:00',
    '13:00 - 15:00',
    '15:00 - 17:00',
    '17:00 - 19:00',
    '19:00 - 21:00',
    '21:00 - 23:00',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }  Future<void> _submitBooking() async {
    if (AuthService.isGuest) {
      BookingBottomSheet.showGuestRestrictionDialog(context);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    final success = await FirestoreService.createBooking(
      customer: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      venueName: widget.venue.name,
      field: widget.venue.type == 'football'
          ? 'Sân 7 người Cỏ FIFA'
          : (widget.venue.type == 'badminton'
              ? 'Sân Thảm Yonex #1'
              : 'Sân Chuẩn Thi Đấu'),
      time: _selectedSlot,
      date: dateStr,
      amount: widget.venue.price,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  success
                      ? 'Đặt sân thành công! Đã lưu lên Firestore alobooking-b2484.'
                      : 'Đã gửi yêu cầu đặt sân thành công!',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đặt sân trực tuyến',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.venue.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),

              // Customer Name
              const Text(
                'Họ và tên khách hàng',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Nhập họ tên', Icons.person_outline),
                validator: (val) => val == null || val.isEmpty ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 14),

              // Phone Number
              const Text(
                'Số điện thoại',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Nhập số điện thoại', Icons.phone_outlined),
                validator: (val) => val == null || val.isEmpty ? 'Vui lòng nhập SĐT' : null,
              ),
              const SizedBox(height: 14),

              // Date Picker
              const Text(
                'Ngày đặt sân',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 10),
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Time Slots Chips (Từ 5h sáng đến 23h đêm, mỗi ca 2 tiếng)
              Row(
                children: [
                  const Text(
                    'Chọn khung giờ (Mỗi ca 2 tiếng)',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                    ),
                    child: const Text('5h00 – 23h00', style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _slots.map((slot) {
                  final isSelected = _selectedSlot == slot;
                  final isPeakHour = slot == '17:00 - 19:00' || slot == '19:00 - 21:00';
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPeakHour) ...[
                          const Text('🔥 ', style: TextStyle(fontSize: 11)),
                        ],
                        Text(slot),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedSlot = slot);
                    },
                    selectedColor: const Color(0xFF16A34A),
                    backgroundColor: const Color(0xFF0F172A),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isPeakHour ? const Color(0xFFFDE047) : Colors.white70),
                      fontWeight: isSelected || isPeakHour ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF16A34A)
                            : (isPeakHour ? const Color(0xFFEAB308).withOpacity(0.5) : Colors.white24),
                        width: isSelected || isPeakHour ? 1.2 : 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Price & Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Giá thuê dự kiến:', style: TextStyle(color: Colors.white70)),
                    Text(
                      widget.venue.price,
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Firebase notice hoặc Cảnh báo vai trò Khách Xem
              if (AuthService.isGuest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: Color(0xFFF87171)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tài khoản Khách chỉ xem: Không được quyền tạo đơn đặt sân',
                          style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_done, size: 16, color: Color(0xFFF59E0B)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Đơn đặt lưu trực tiếp lên Firebase Firestore alobooking-b2484',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (AuthService.isGuest) {
                            BookingBottomSheet.showGuestRestrictionDialog(context);
                          } else {
                            _submitBooking();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuthService.isGuest ? const Color(0xFF64748B) : const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          AuthService.isGuest
                              ? 'KHÁCH XEM (KHÔNG ĐẶT SÂN)'
                              : 'XÁC NHẬN ĐẶT SÂN',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 18),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
      ),
    );
  }
}
