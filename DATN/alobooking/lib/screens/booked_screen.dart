import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../services/auth_service.dart';

/// Màn hình SÂN ĐÃ ĐẶT — lịch sử và danh sách đặt sân của người dùng
class BookedScreen extends StatefulWidget {
  final List<Venue> allVenues;
  const BookedScreen({super.key, this.allVenues = const []});

  @override
  State<BookedScreen> createState() => _BookedScreenState();
}

class _BookedScreenState extends State<BookedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _bookings = [
    {
      'id': 'BK-20261028-01',
      'venueName': 'Sân Cầu Lông Long Viên',
      'type': 'badminton',
      'date': '28/10/2026',
      'slot': '17:00 - 19:00',
      'price': '150.000đ',
      'status': 'upcoming',
      'field': 'Sân số 2',
      'address': 'Ba Đình, Hà Nội',
    },
    {
      'id': 'BK-20261025-02',
      'venueName': 'Sân Pickleball Sunrise',
      'type': 'pickleball',
      'date': '25/10/2026',
      'slot': '07:00 - 09:00',
      'price': '180.000đ',
      'status': 'completed',
      'field': 'Sân số 1',
      'address': 'Quận 7, TP.HCM',
    },
    {
      'id': 'BK-20261020-03',
      'venueName': 'Sân Bóng Đá Mini Ba Đình',
      'type': 'football',
      'date': '20/10/2026',
      'slot': '19:00 - 21:00',
      'price': '350.000đ',
      'status': 'completed',
      'field': 'Sân cỏ nhân tạo A',
      'address': 'Ba Đình, Hà Nội',
    },
    {
      'id': 'BK-20261030-04',
      'venueName': 'Sân Tennis Vạn Phúc',
      'type': 'tennis',
      'date': '30/10/2026',
      'slot': '08:00 - 09:30',
      'price': '330.000đ',
      'status': 'upcoming',
      'field': 'Sân C (Mặt cứng)',
      'address': 'Ba Đình, Hà Nội',
    },
    {
      'id': 'BK-20261015-05',
      'venueName': 'Sân Cầu Lông Bình Lợi',
      'type': 'badminton',
      'date': '15/10/2026',
      'slot': '18:00 - 19:30',
      'price': '135.000đ',
      'status': 'cancelled',
      'field': 'Sân số 5',
      'address': 'Bình Thạnh, TP.HCM',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filteredList(int tabIndex) {
    if (AuthService.isGuest) return [];
    switch (tabIndex) {
      case 1:
        return _bookings.where((b) => b['status'] == 'upcoming').toList();
      case 2:
        return _bookings.where((b) => b['status'] == 'completed').toList();
      case 3:
        return _bookings.where((b) => b['status'] == 'cancelled').toList();
      default:
        return _bookings;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'football':
        return const Color(0xFF16A34A);
      case 'tennis':
        return const Color(0xFF0EA5E9);
      case 'pickleball':
        return const Color(0xFF8B5CF6);
      case 'basketball':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF059669);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'football':
        return Icons.sports_soccer;
      case 'tennis':
        return Icons.sports_tennis;
      case 'pickleball':
        return Icons.sports_tennis;
      case 'basketball':
        return Icons.sports_basketball;
      default:
        return Icons.sports;
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;
    IconData icon;

    switch (status) {
      case 'upcoming':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        text = 'Sắp diễn ra';
        icon = Icons.schedule_rounded;
        break;
      case 'completed':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        text = 'Đã hoàn thành';
        icon = Icons.check_circle_outline_rounded;
        break;
      default:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        text = 'Đã hủy';
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15803D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Lịch sử đặt sân',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: 'Sắp diễn ra'),
            Tab(text: 'Đã hoàn tất'),
            Tab(text: 'Đã hủy'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingList(_filteredList(0)),
          _buildBookingList(_filteredList(1)),
          _buildBookingList(_filteredList(2)),
          _buildBookingList(_filteredList(3)),
        ],
      ),
    );
  }

  Widget _buildBookingList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      final isGuest = AuthService.isGuest;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isGuest ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGuest ? Icons.visibility_outlined : Icons.event_busy_rounded,
                  size: 48,
                  color: isGuest ? const Color(0xFFD97706) : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isGuest ? 'Chế độ Khách xem sân' : 'Chưa có lịch đặt sân nào',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                isGuest
                    ? 'Tài khoản của bạn chỉ có quyền xem sân, không thể đặt và lưu lịch đặt sân. Vui lòng chuyển sang tài khoản Khách Hàng để đặt sân.'
                    : 'Các lịch đặt sân của bạn sẽ xuất hiện tại đây',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              if (isGuest) ...[
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () {
                    AuthService.switchToCustomer();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã chuyển sang tài khoản Khách Hàng (User)!'),
                        backgroundColor: Color(0xFF16A34A),
                      ),
                    );
                  },
                  icon: const Icon(Icons.switch_account, size: 16),
                  label: const Text('Đổi sang tài khoản Khách Hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _buildBookingCard(items[i]),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> b) {
    final color = _typeColor(b['type'] as String);
    final icon = _typeIcon(b['type'] as String);
    final isUpcoming = b['status'] == 'upcoming';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Type Icon + Name + Status Badge
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b['venueName'] as String,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        b['field'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(b['status'] as String),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),

            // Middle rows: Date, Slot, Address
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    Icons.calendar_today_outlined,
                    'Ngày',
                    b['date'] as String,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.access_time_rounded,
                    'Khung giờ',
                    b['slot'] as String,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              Icons.location_on_outlined,
              'Địa chỉ',
              b['address'] as String,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),

            // Bottom row: Price + Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng tiền',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    Text(
                      b['price'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
                if (isUpcoming)
                  OutlinedButton(
                    onPressed: () => _showCancelDialog(b),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: const Text(
                      'Hủy đặt sân',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đang tạo yêu cầu đặt lại sân...'),
                          backgroundColor: Color(0xFF16A34A),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Đặt lại sân',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showCancelDialog(Map<String, dynamic> b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xác nhận hủy đặt sân',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'Bạn có chắc chắn muốn hủy lượt đặt tại "${b['venueName']}" vào lúc ${b['slot']} ngày ${b['date']} không? Phí cọc sẽ được hoàn theo chính sách hoàn tiền.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Giữ lại', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                b['status'] = 'cancelled';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã hủy lịch đặt sân thành công'),
                  backgroundColor: Color(0xFF16A34A),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
  }
}
