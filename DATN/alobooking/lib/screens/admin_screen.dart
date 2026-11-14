import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../data/venues_data.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../widgets/venue_image_view.dart';

class AdminScreen extends StatefulWidget {
  final List<Venue> initialVenues;
  final int initialTabIndex;

  const AdminScreen({
    super.key,
    required this.initialVenues,
    this.initialTabIndex = 0,
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedNavIndex = 0;
  List<Venue> _venues = [];
  List<BookingItem> _bookings = [];
  List<CustomerItem> _customers = [];
  List<PaymentItem> _payments = [];
  bool _isLoading = false;
  String _searchVenueQuery = '';
  String _selectedSport = 'all';
  String _selectedDistrict = 'all';
  String _selectedPeriod = 'month'; // 'today' | 'week' | 'month' | 'year'
  String _selectedApprovalFilter = 'all'; // 'all' | 'pending' | 'approved' | 'rejected'

  // Bộ lọc Đặt sân
  String _searchBookingQuery = '';
  String _selectedBookingStatus = 'all'; // 'all' | 'Chờ xác nhận' | 'Đã xác nhận' | 'Hoàn thành' | 'Đã hủy'

  // Bộ lọc Khách hàng & Thanh toán
  String _searchCustomerQuery = '';
  String _selectedCustomerRank = 'all'; // 'all' | 'vip' | 'active' | 'locked'
  String _searchPaymentQuery = '';
  String _selectedPaymentMethod = 'all'; // 'all' | 'VietQR Pro' | 'Ví MoMo' | 'VNPay QR' | 'Tiền mặt'

  final List<String> _districts = [
    'Cầu Giấy', 'Đống Đa', 'Ba Đình', 'Hoàn Kiếm', 'Hai Bà Trưng',
    'Thanh Xuân', 'Tây Hồ', 'Nam Từ Liêm', 'Bắc Từ Liêm', 'Hà Đông',
    'Hoàng Mai', 'Long Biên', 'Gia Lâm', 'Đông Anh', 'Thanh Trì', 'Hoài Đức'
  ];

  final Map<String, Map<String, double>> _districtCoordinates = {
    'Cầu Giấy': {'lat': 21.0360, 'lng': 105.7905},
    'Đống Đa': {'lat': 21.0245, 'lng': 105.8350},
    'Ba Đình': {'lat': 21.0340, 'lng': 105.8230},
    'Hoàn Kiếm': {'lat': 21.0285, 'lng': 105.8542},
    'Hai Bà Trưng': {'lat': 21.0080, 'lng': 105.8520},
    'Thanh Xuân': {'lat': 20.9980, 'lng': 105.8120},
    'Tây Hồ': {'lat': 21.0710, 'lng': 105.8250},
    'Nam Từ Liêm': {'lat': 21.0160, 'lng': 105.7650},
    'Bắc Từ Liêm': {'lat': 21.0650, 'lng': 105.7580},
    'Hà Đông': {'lat': 20.9720, 'lng': 105.7750},
    'Hoàng Mai': {'lat': 20.9730, 'lng': 105.8480},
    'Long Biên': {'lat': 21.0450, 'lng': 105.8850},
    'Gia Lâm': {'lat': 21.0180, 'lng': 105.9400},
    'Đông Anh': {'lat': 21.1350, 'lng': 105.8450},
    'Thanh Trì': {'lat': 20.9480, 'lng': 105.8580},
    'Hoài Đức': {'lat': 21.0180, 'lng': 105.7100},
  };

  final Map<String, List<String>> _sampleImages = {
    'pickleball': [
      'https://images.unsplash.com/photo-1622279457486-62dcc4a431d6?w=600&h=320&fit=crop&q=80',
      'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=600&h=320&fit=crop&q=80',
      'https://images.unsplash.com/photo-1612872087720-bb876e2e67d1?w=600&h=320&fit=crop&q=80',
    ],
    'badminton': [
      'https://images.unsplash.com/photo-1521537634581-0dced2fee2ef?w=600&h=320&fit=crop&q=80',
      'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=600&h=320&fit=crop&q=80',
      'https://images.unsplash.com/photo-1544698310-74ea9d1c8258?w=600&h=320&fit=crop&q=80',
    ],
    'football': [
      'https://images.unsplash.com/photo-1529900241451-93b9423c9604?w=600&h=320&fit=crop&q=80',
      'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=600&h=320&fit=crop&q=80',
      'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=600&h=320&fit=crop&q=80',
    ],
    'tennis': [
      'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=600&h=320&fit=crop&q=80',
      'https://images.unsplash.com/photo-1595435934249-5df7ed86e1c0?w=600&h=320&fit=crop&q=80',
    ],
    'basketball': [
      'https://images.unsplash.com/photo-1519861531473-9200262188bf?w=600&h=320&fit=crop&q=80',
      'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=600&h=320&fit=crop&q=80',
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedNavIndex = (widget.initialTabIndex >= 0 && widget.initialTabIndex < 5)
        ? widget.initialTabIndex
        : 0;
    _venues = List.from(widget.initialVenues.isNotEmpty ? widget.initialVenues : sampleVenues);
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final fetchedVenues = await FirestoreService.getVenues();
    final fetchedBookings = await FirestoreService.getBookings();
    final fetchedCustomers = await FirestoreService.getCustomers();
    final fetchedPayments = await FirestoreService.getPayments();
    setState(() {
      if (fetchedVenues.isNotEmpty) {
        _venues = fetchedVenues;
      }
      _bookings = fetchedBookings;
      _customers = fetchedCustomers;
      _payments = fetchedPayments;
      _isLoading = false;
    });
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<BookingItem> get _filteredBookings {
    return _bookings.where((b) {
      final q = _searchBookingQuery.toLowerCase().trim();
      final matchQuery = q.isEmpty ||
          b.id.toLowerCase().contains(q) ||
          b.customer.toLowerCase().contains(q) ||
          b.phone.contains(q) ||
          b.venueName.toLowerCase().contains(q);

      final matchStatus = _selectedBookingStatus == 'all' || b.status == _selectedBookingStatus;
      return matchQuery && matchStatus;
    }).toList();
  }

  List<Venue> get _filteredVenues {
    return _venues.where((v) {
      final q = _searchVenueQuery.toLowerCase().trim();
      final matchQuery = q.isEmpty ||
          v.name.toLowerCase().contains(q) ||
          v.address.toLowerCase().contains(q) ||
          v.district.toLowerCase().contains(q) ||
          v.ownerName.toLowerCase().contains(q);

      final matchSport = _selectedSport == 'all' || v.type == _selectedSport;
      final matchDistrict = _selectedDistrict == 'all' || v.district == _selectedDistrict;
      final matchApproval = _selectedApprovalFilter == 'all' || v.approvalStatus == _selectedApprovalFilter;

      return matchQuery && matchSport && matchDistrict && matchApproval;
    }).toList();
  }

  // ==========================================
  // BUILD MAIN SCAFFOLD - SIDEBAR LAYOUT
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF050B18),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF34D399),
          surface: Color(0xFF0F1F35),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'Be Vietnam Pro',
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF050B18),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
            : Row(
                children: [
                  // ── SIDEBAR ──
                  _buildSidebar(),
                  // ── MAIN CONTENT ──
                  Expanded(
                    child: Column(
                      children: [
                        _buildTopBar(),
                        Expanded(
                          child: _buildContentArea(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── SIDEBAR NAVIGATION ──
  Widget _buildSidebar() {
    final pendingVenuesCount = _venues.where((v) => v.isPending).length;
    final pendingBookingsCount = _bookings.where((b) => b.status == 'Chờ xác nhận').length;

    final navSections = [
      {
        'title': 'TỔNG QUAN',
        'items': [
          {'index': 0, 'icon': Icons.insights_rounded, 'label': 'Thống Kê & KPI', 'badge': null, 'badgeColor': null},
        ],
      },
      {
        'title': 'QUẢN LÝ DỊCH VỤ',
        'items': [
          {
            'index': 1,
            'icon': Icons.sports_tennis_rounded,
            'label': 'Quản Lý Sân',
            'badge': pendingVenuesCount > 0 ? '$pendingVenuesCount chờ' : null,
            'badgeColor': const Color(0xFFFBBF24),
          },
          {
            'index': 2,
            'icon': Icons.calendar_month_rounded,
            'label': 'Đơn Đặt Sân',
            'badge': pendingBookingsCount > 0 ? '$pendingBookingsCount mới' : null,
            'badgeColor': const Color(0xFF38BDF8),
          },
          {
            'index': 3,
            'icon': Icons.people_alt_rounded,
            'label': 'Khách Hàng',
            'badge': '${_customers.length}',
            'badgeColor': const Color(0xFF94A3B8),
          },
          {
            'index': 4,
            'icon': Icons.payments_rounded,
            'label': 'Thanh Toán & Doanh Thu',
            'badge': null,
            'badgeColor': null,
          },
        ],
      },
    ];

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF070E1B),
        border: Border(
          right: BorderSide(color: const Color(0xFF1E3A5F).withOpacity(0.5), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── BRAND HEADER ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: const Color(0xFF1E3A5F).withOpacity(0.4)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.sports_tennis, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'AloBooking',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Hệ Thống Quản Trị Cấp Cao',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── ADMIN USER INFO WIDGET ──
          Container(
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0F203C).withOpacity(0.8),
                  const Color(0xFF0A1324).withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.6)),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (AuthService.currentUser?.fullName.isNotEmpty == true)
                              ? AuthService.currentUser!.fullName[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF070E1B), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AuthService.currentUser?.fullName ?? 'Đinh Ngọc Huy',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '👑 ROOT ADMIN',
                              style: TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── NAVIGATION MENU ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              children: [
                for (final section in navSections) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    child: Text(
                      section['title'] as String,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  for (final item in section['items'] as List<Map<String, dynamic>>) ...[
                    Builder(builder: (ctx) {
                      final itemIdx = item['index'] as int;
                      final isSelected = _selectedNavIndex == itemIdx;
                      final badgeText = item['badge'] as String?;
                      final badgeColor = (item['badgeColor'] as Color?) ?? const Color(0xFF10B981);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      const Color(0xFF10B981).withOpacity(0.18),
                                      const Color(0xFF10B981).withOpacity(0.04),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(color: const Color(0xFF10B981).withOpacity(0.35))
                                : null,
                          ),
                          child: InkWell(
                            onTap: () => setState(() => _selectedNavIndex = itemIdx),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  // Left accent bar
                                  if (isSelected)
                                    Container(
                                      width: 3.5,
                                      height: 18,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981).withOpacity(0.6),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  Icon(
                                    item['icon'] as IconData,
                                    color: isSelected
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF64748B),
                                    size: 19,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item['label'] as String,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (badgeText != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: badgeColor.withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        badgeText,
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ],
            ),
          ),

          // ── BOTTOM ACTIONS ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF050B15),
              border: Border(
                top: BorderSide(color: const Color(0xFF1E3A5F).withOpacity(0.5)),
              ),
            ),
            child: Column(
              children: [
                _sidebarBottomBtn(
                  icon: Icons.phone_android_rounded,
                  label: 'Xem App Người Dùng',
                  color: const Color(0xFF60A5FA),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  ),
                ),
                const SizedBox(height: 6),
                _sidebarBottomBtn(
                  icon: Icons.cloud_sync_outlined,
                  label: 'Đồng Bộ Firestore',
                  color: const Color(0xFF34D399),
                  onTap: _syncToFirestore,
                ),
                const SizedBox(height: 6),
                _sidebarBottomBtn(
                  icon: Icons.logout_rounded,
                  label: 'Đăng Xuất Admin',
                  color: const Color(0xFFF87171),
                  onTap: _confirmLogoutAdmin,
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'AloBooking Cloud Engine v2.5.0',
                    style: TextStyle(color: Color(0xFF475569), fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarBottomBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.6), size: 10),
          ],
        ),
      ),
    );
  }

  void _confirmLogoutAdmin() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1424),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFF1E3A5F).withOpacity(0.8)),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 10),
            Text('Đăng Xuất Quản Trị', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi trang quản trị Admin và quay về màn hình đăng nhập?',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              AuthService.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Đăng Xuất', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── TOP BAR ──
  Widget _buildTopBar() {
    final tabNames = [
      'Thống Kê & Báo Cáo KPI',
      'Quản Lý Cụm Sân Thể Thao',
      'Quản Lý Đơn Đặt Sân',
      'Quản Lý Khách Hàng & Hội Viên',
      'Thanh Toán & Dòng Tiền',
    ];
    final tabSubtitles = [
      'Tổng hợp chỉ số doanh thu, tỷ lệ lấp đầy sân và dự báo AI',
      'Phê duyệt bài đăng, cập nhật thông tin và bảng giá sân',
      'Theo dõi trạng thái lịch đặt sân trực tiếp và tại quầy',
      'Thông tin hội viên, phân hạng VIP và lịch sử giao dịch',
      'Theo dõi giao dịch VietQR, MoMo, VNPay và tiền mặt tại quầy',
    ];
    final tabIcons = [
      Icons.insights_rounded,
      Icons.sports_tennis_rounded,
      Icons.calendar_month_rounded,
      Icons.people_alt_rounded,
      Icons.payments_rounded,
    ];

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF070E1B),
        border: Border(
          bottom: BorderSide(color: const Color(0xFF1E3A5F).withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          // Breadcrumb & Title
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('AloBooking', style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 14),
                    const SizedBox(width: 4),
                    const Text('Quản Trị', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      tabNames[_selectedNavIndex],
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(tabIcons[_selectedNavIndex], color: const Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      tabNames[_selectedNavIndex],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '• ${tabSubtitles[_selectedNavIndex]}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right Controls: Quick Search + Live System + Refresh + Notifications
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Live System Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.8),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Cloud Sync Live',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Reload Button
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8), size: 20),
                tooltip: 'Tải lại dữ liệu Firestore',
                onPressed: _loadData,
              ),
              const SizedBox(width: 4),

              // Notification bell
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1E36),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.5)),
                    ),
                    child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF94A3B8), size: 18),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Admin Profile Dropdown Menu with Logout
              PopupMenuButton<String>(
                offset: const Offset(0, 48),
                color: const Color(0xFF0F203C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFF1E3A5F).withOpacity(0.6)),
                ),
                onSelected: (val) {
                  if (val == 'logout') {
                    _confirmLogoutAdmin();
                  } else if (val == 'home') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'info',
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AuthService.currentUser?.fullName ?? 'Đinh Ngọc Huy',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'admin@alobooking.com',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  const PopupMenuItem(
                    value: 'home',
                    child: Row(
                      children: [
                        Icon(Icons.phone_android_rounded, color: Color(0xFF60A5FA), size: 16),
                        SizedBox(width: 8),
                        Text('Xem App Khách', style: TextStyle(color: Colors.white, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 16),
                        SizedBox(width: 8),
                        Text('Đăng Xuất Hệ Thống', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1E36),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.6)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF3B82F6)]),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (AuthService.currentUser?.fullName.isNotEmpty == true)
                                ? AuthService.currentUser!.fullName[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AuthService.currentUser?.fullName ?? 'Admin',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFF94A3B8), size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── CONTENT AREA ──
  Widget _buildContentArea() {
    switch (_selectedNavIndex) {
      case 0: return _buildAnalyticsTab();
      case 1: return _buildVenuesManagementTab();
      case 2: return _buildBookingsTab();
      case 3: return _buildCustomersTab();
      case 4: return _buildPaymentsTab();
      default: return _buildAnalyticsTab();
    }
  }

  // AppBar replaced by Sidebar + TopBar layout

  // ==========================================
  // TAB 1: THỐNG KÊ & BÁO CÁO (ANALYTICS)
  // ==========================================
  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          _buildPeriodSelector(),
          const SizedBox(height: 16),

          // 4 KPI Cards
          _buildKpiGrid(),
          const SizedBox(height: 20),

          // Charts Row
          LayoutBuilder(builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildRevenueChartCard()),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildDonutChartCard()),
                ],
              );
            }
            return Column(
              children: [
                _buildRevenueChartCard(),
                const SizedBox(height: 16),
                _buildDonutChartCard(),
              ],
            );
          }),
          const SizedBox(height: 16),

          // Peak Hours & Sport Usage Row
          LayoutBuilder(builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSportUsageBarChartCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildPeakHoursChartCard()),
                ],
              );
            }
            return Column(
              children: [
                _buildSportUsageBarChartCard(),
                const SizedBox(height: 16),
                _buildPeakHoursChartCard(),
              ],
            );
          }),
          const SizedBox(height: 20),

          // Top Venues table
          _buildTopVenuesCard(),
          const SizedBox(height: 20),

          // AI Insights
          _buildAiInsightsCard(),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = [
      {'key': 'today', 'label': 'Hôm nay'},
      {'key': 'week', 'label': '7 ngày qua'},
      {'key': 'month', 'label': 'Tháng này'},
      {'key': 'year', 'label': 'Năm 2026'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF070E1B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: periods.map((p) {
              final isSelected = _selectedPeriod == p['key'];
              return InkWell(
                onTap: () => setState(() => _selectedPeriod = p['key'] as String),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    p['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showToast('Đang xuất báo cáo thống kê định dạng Excel...'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F203C),
            foregroundColor: const Color(0xFF38BDF8),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.3)),
            ),
          ),
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: const Text('Xuất Báo Cáo Excel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildKpiGrid() {
    String revenue = '128.500.000đ';
    String bookings = '984 lượt';
    String occupancy = '86.2%';
    String newUsers = '215 người';

    if (_selectedPeriod == 'today') {
      revenue = '4.850.000đ';
      bookings = '38 lượt';
      occupancy = '81.2%';
      newUsers = '14 người';
    } else if (_selectedPeriod == 'week') {
      revenue = '32.400.000đ';
      bookings = '246 lượt';
      occupancy = '84.6%';
      newUsers = '62 người';
    } else if (_selectedPeriod == 'year') {
      revenue = '582.600.000đ';
      bookings = '4.512 lượt';
      occupancy = '88.5%';
      newUsers = '1.840 người';
    }

    final kpis = [
      {
        'title': 'Tổng Doanh Thu',
        'value': revenue,
        'change': '+16.8%',
        'icon': Icons.attach_money,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Lượt Đặt Sân',
        'value': bookings,
        'change': '+11.4%',
        'icon': Icons.calendar_month,
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': 'Tỷ Lệ Lấp Đầy',
        'value': occupancy,
        'change': '+5.3%',
        'icon': Icons.bolt,
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'Khách Hàng Mới',
        'value': newUsers,
        'change': '+22.5%',
        'icon': Icons.people,
        'color': const Color(0xFFA855F7),
      },
    ];

    return LayoutBuilder(builder: (context, constraints) {
      int count = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: kpis.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: count,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.95,
        ),
        itemBuilder: (ctx, i) {
          final item = kpis[i];
          final color = item['color'] as Color;
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0F203C),
                  const Color(0xFF070E1B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.25), color.withOpacity(0.08)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.35)),
                      ),
                      child: Icon(item['icon'] as IconData, color: color, size: 22),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.trending_up_rounded, color: Color(0xFF34D399), size: 13),
                          const SizedBox(width: 3),
                          Text(
                            item['change'] as String,
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['value'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['title'] as String,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    });
  }

  // --- REVENUE LINE CHART ---
  Widget _buildRevenueChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xu Hướng Doanh Thu & Dự Báo AI',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text('Biểu đồ tăng trưởng thực tế kết hợp ML Forecast',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                ],
              ),
              Row(
                children: [
                  _chartLegend(const Color(0xFF6366F1), 'Thực tế'),
                  const SizedBox(width: 12),
                  _chartLegend(const Color(0xFF10B981), 'Dự báo AI'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: RevenueLineChartPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
      ],
    );
  }

  // --- DONUT CHART (Cơ cấu doanh thu theo môn) ---
  Widget _buildDonutChartCard() {
    final sportsShare = [
      {'label': 'Pickleball', 'percent': 42, 'color': const Color(0xFF3B82F6)},
      {'label': 'Cầu lông', 'percent': 28, 'color': const Color(0xFF10B981)},
      {'label': 'Bóng đá', 'percent': 18, 'color': const Color(0xFFF97316)},
      {'label': 'Tennis', 'percent': 12, 'color': const Color(0xFFEAB308)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cơ Cấu Doanh Thu Theo Môn',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: DonutChartPainter(
                    slices: [0.42, 0.28, 0.18, 0.12],
                    colors: [
                      const Color(0xFF3B82F6),
                      const Color(0xFF10B981),
                      const Color(0xFFF97316),
                      const Color(0xFFEAB308),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: sportsShare.map((s) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: s['color'] as Color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(s['label'] as String,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                          Text(
                            '${s['percent']}%',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SPORT USAGE BAR CHART ---
  Widget _buildSportUsageBarChartCard() {
    final bars = [
      {'name': 'Pickleball', 'hours': 420, 'max': 500, 'color': const Color(0xFF3B82F6)},
      {'name': 'Cầu lông', 'hours': 315, 'max': 500, 'color': const Color(0xFF10B981)},
      {'name': 'Bóng đá', 'hours': 240, 'max': 500, 'color': const Color(0xFFF97316)},
      {'name': 'Tennis', 'hours': 160, 'max': 500, 'color': const Color(0xFFEAB308)},
      {'name': 'Bóng rổ', 'hours': 95, 'max': 500, 'color': const Color(0xFFEC4899)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tần Suất Giờ Đặt Theo Môn Thể Thao',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          ...bars.map((b) {
            final double ratio = (b['hours'] as int) / (b['max'] as int);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(b['name'] as String,
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('${b['hours']} giờ',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: const Color(0xFF334155),
                      valueColor: AlwaysStoppedAnimation<Color>(b['color'] as Color),
                      minHeight: 7,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- PEAK HOURS CHART ---
  Widget _buildPeakHoursChartCard() {
    final slots = [
      {'slot': '06h - 09h', 'val': 65, 'isPeak': false},
      {'slot': '09h - 14h', 'val': 42, 'isPeak': false},
      {'slot': '14h - 17h', 'val': 58, 'isPeak': false},
      {'slot': '17h - 20h 🔥', 'val': 98, 'isPeak': true},
      {'slot': '20h - 23h', 'val': 88, 'isPeak': false},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Khung Giờ Đặt Sân Trong Ngày',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Giờ vàng: 17h–20h',
                    style: TextStyle(color: Color(0xFFF87171), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...slots.map((s) {
            final double ratio = (s['val'] as int) / 100.0;
            final isPeak = s['isPeak'] as bool;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(s['slot'] as String,
                          style: TextStyle(
                            color: isPeak ? const Color(0xFFF87171) : Colors.white70,
                            fontWeight: isPeak ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          )),
                      Text('${s['val']}% công suất',
                          style: TextStyle(
                            color: isPeak ? const Color(0xFFF87171) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: const Color(0xFF334155),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isPeak ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
                      ),
                      minHeight: 7,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- TOP VENUES ---
  Widget _buildTopVenuesCard() {
    final topVenues = _venues.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.emoji_events, color: Color(0xFFF59E0B), size: 20),
                  SizedBox(width: 8),
                  Text('Top Cụm Sân Doanh Thu Cao Nhất',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              TextButton(
                onPressed: () => setState(() => _selectedNavIndex = 1),
                child: const Text('Xem tất cả sân →', style: TextStyle(color: Color(0xFF34D399))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topVenues.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFF334155), height: 1),
            itemBuilder: (ctx, idx) {
              final v = topVenues[idx];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                      child: Text('${idx + 1}',
                          style: const TextStyle(
                              color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.name,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text('${v.district} • ${v.hours}',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(v.price,
                            style: const TextStyle(
                                color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 13)),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Color(0xFFF59E0B), size: 12),
                            const SizedBox(width: 2),
                            Text('${v.rating}',
                                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- AI INSIGHTS ---
  Widget _buildAiInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E293B), const Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF818CF8), size: 18),
              ),
              const SizedBox(width: 8),
              const Text('AI Insights & Đề Xuất Doanh Thu',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Dự báo thứ 7 tới nhu cầu sân Pickleball tăng 35% từ 17h–21h. Đề xuất mở thêm 2 sân dự bị.\n'
            '• Tỷ lệ đặt khung 09h–14h ngày thường chỉ đạt 42%. Nên áp dụng mã giảm giá HAPPYHOUR20 để tối ưu công suất.\n'
            '• Hệ thống phát hiện cụm sân Cầu Giấy đã kín 100% lịch tuần tới, nên gợi ý khách sang cụm sân Nam Từ Liêm lân cận.',
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: QUẢN LÝ SÂN THỂ THAO (CRUD)
  // ==========================================
  Widget _buildVenuesManagementTab() {
    return Column(
      children: [
        // Controls Bar (Search + Filter + Add Button)
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF0A1628),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF050B18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.5)),
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchVenueQuery = val),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Tìm kiếm sân theo tên, quận, địa chỉ...',
                          hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: Color(0xFF64748B), size: 18),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _openAddVenueDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm Sân', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'Tất cả môn'),
                    _filterChip('pickleball', 'Pickleball'),
                    _filterChip('badminton', 'Cầu lông'),
                    _filterChip('football', 'Bóng đá'),
                    _filterChip('tennis', 'Tennis'),
                    _filterChip('basketball', 'Bóng rổ'),
                    const SizedBox(width: 10),
                    // District dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDistrict,
                          dropdownColor: const Color(0xFF0B1424),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('Tất cả quận')),
                            ..._districts.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                          ],
                          onChanged: (val) => setState(() => _selectedDistrict = val ?? 'all'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Filter by Approval Status
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _approvalFilterChip('all', 'Tất cả (${_venues.length})'),
                    const SizedBox(width: 6),
                    _approvalFilterChip('pending', 'Chờ Duyệt ⏳ (${_venues.where((v) => v.isPending).length})'),
                    const SizedBox(width: 6),
                    _approvalFilterChip('approved', 'Đã Duyệt ✅ (${_venues.where((v) => v.isApproved).length})'),
                    const SizedBox(width: 6),
                    _approvalFilterChip('rejected', 'Từ Chối ❌ (${_venues.where((v) => v.isRejected).length})'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Venues List
        Expanded(
          child: _filteredVenues.isEmpty
              ? const Center(
                  child: Text('Không tìm thấy sân phù hợp.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredVenues.length,
                  itemBuilder: (ctx, i) => _buildVenueRowCard(_filteredVenues[i]),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String key, String label) {
    final selected = _selectedSport == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedSport = key),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF0F203C), Color(0xFF070E1B)],
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF34D399)
                  : const Color(0xFF1E3A5F).withOpacity(0.6),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _approvalFilterChip(String key, String label) {
    final selected = _selectedApprovalFilter == key;
    Color activeColor = const Color(0xFF10B981);
    Color activeColorDark = const Color(0xFF059669);
    if (key == 'pending') {
      activeColor = const Color(0xFFF59E0B);
      activeColorDark = const Color(0xFFD97706);
    } else if (key == 'rejected') {
      activeColor = const Color(0xFFEF4444);
      activeColorDark = const Color(0xFFDC2626);
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedApprovalFilter = key),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [activeColor, activeColorDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF0F203C), Color(0xFF070E1B)],
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? activeColor : const Color(0xFF1E3A5F).withOpacity(0.6),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVenueRowCard(Venue v) {
    Color statusBg = const Color(0xFF10B981).withOpacity(0.15);
    Color statusColor = const Color(0xFF10B981);
    String statusText = 'Đã duyệt';

    if (v.isPending) {
      statusBg = const Color(0xFFFBBF24).withOpacity(0.15);
      statusColor = const Color(0xFFFBBF24);
      statusText = 'Chờ duyệt';
    } else if (v.isRejected) {
      statusBg = const Color(0xFFEF4444).withOpacity(0.15);
      statusColor = const Color(0xFFEF4444);
      statusText = 'Từ chối';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: v.isPending ? const Color(0xFFFBBF24).withOpacity(0.6) : const Color(0xFF1E3A5F).withOpacity(0.5),
          width: v.isPending ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: VenueImageView(
                  imageUrl: v.image,
                  width: 75,
                  height: 75,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            v.type.toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '#${v.id}',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${v.address} (${v.district}) • Chủ: ${v.ownerName}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(v.price,
                            style: const TextStyle(
                                color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 10),
                        const Icon(Icons.access_time, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 2),
                        Text(v.hours, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons (Detail, Edit, Delete)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, color: Color(0xFF60A5FA), size: 20),
                    tooltip: 'Xem chi tiết',
                    onPressed: () => _openViewDetailDialog(v),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF818CF8), size: 20),
                    tooltip: 'Chỉnh sửa',
                    onPressed: () => _openEditVenueDialog(v),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFF87171), size: 20),
                    tooltip: 'Xóa sân',
                    onPressed: () => _openDeleteVenueDialog(v),
                  ),
                ],
              ),
            ],
          ),

          // Action bar if PENDING approval
          if (v.isPending) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFFFBBF24), size: 16),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Yêu cầu đăng bài từ Chủ sân cần bạn phê duyệt:',
                      style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await FirestoreService.updateVenueApproval(v.id, 'approved');
                      final updated = v.copyWith(approvalStatus: 'approved');
                      final idx = _venues.indexWhere((item) => item.id == v.id);
                      if (idx != -1) setState(() => _venues[idx] = updated);
                      _showToast('Đã duyệt đăng bài sân "${v.name}" thành công!');
                    },
                    icon: const Icon(Icons.check_circle, size: 14),
                    label: const Text('Duyệt Đăng', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openRejectDialog(v),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: const Text('Từ Chối', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openRejectDialog(Venue v) {
    final reasonCtrl = TextEditingController(text: 'Hình ảnh chưa rõ nét hoặc thiếu bảng giá chi tiết');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1424),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Từ Chối Bài Đăng Sân', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhập lý do từ chối để gửi phản hồi cho chủ sân "${v.name}":',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 10),
            _dialogTextField('Lý Do Từ Chối *', reasonCtrl, 'VD: Cần cập nhật giấy phép / ảnh thực tế'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim().isEmpty ? 'Chưa đáp ứng tiêu chuẩn kiểm duyệt' : reasonCtrl.text.trim();
              await FirestoreService.updateVenueApproval(v.id, 'rejected', reason);
              final updated = v.copyWith(approvalStatus: 'rejected', rejectReason: reason);
              final idx = _venues.indexWhere((item) => item.id == v.id);
              if (idx != -1) setState(() => _venues[idx] = updated);
              Navigator.pop(ctx);
              _showToast('Đã từ chối duyệt bài sân "${v.name}"!', isError: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Xác Nhận Từ Chối', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: QUẢN LÝ ĐẶT SÂN (BOOKINGS)
  // ==========================================
  Widget _buildBookingsTab() {
    final pendingCount = _bookings.where((b) => b.status == 'Chờ xác nhận').length;
    final confirmedCount = _bookings.where((b) => b.status == 'Đã xác nhận').length;
    final completedCount = _bookings.where((b) => b.status == 'Hoàn thành').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. KPI THỐNG KÊ ĐƠN ĐẶT ──
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tổng Đơn Đặt', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          Icon(Icons.calendar_month_outlined, color: Color(0xFF38BDF8), size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${_bookings.length}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Tất cả lịch đặt trên hệ thống', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFBBF24).withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Chờ Xác Nhận', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          Icon(Icons.hourglass_top_rounded, color: Color(0xFFFBBF24), size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$pendingCount', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Cần xử lý ngay', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Đã Xác Nhận / Đang Đá', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$confirmedCount', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Lịch thi đấu sẵn sàng', style: TextStyle(color: Color(0xFF10B981), fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF818CF8).withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Đã Hoàn Thành', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          Icon(Icons.task_alt, color: Color(0xFF818CF8), size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$completedCount', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Đã chơi xong & thu tiền', style: TextStyle(color: Color(0xFF818CF8), fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 2. SEARCH & ACTIONS BAR ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.5)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF050B18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Color(0xFF64748B), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: (val) => setState(() => _searchBookingQuery = val),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Tìm theo mã đơn (BK-...), tên khách, SĐT, tên sân...',
                                  hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            if (_searchBookingQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(() => _searchBookingQuery = ''),
                                child: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 16),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _openAddWalkinBookingDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Đặt Sân Tại Quầy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildGenericChip('Tất cả (${_bookings.length})', 'all', _selectedBookingStatus, (v) => setState(() => _selectedBookingStatus = v)),
                      _buildGenericChip('Chờ xác nhận ($pendingCount)', 'Chờ xác nhận', _selectedBookingStatus, (v) => setState(() => _selectedBookingStatus = v)),
                      _buildGenericChip('Đã xác nhận ($confirmedCount)', 'Đã xác nhận', _selectedBookingStatus, (v) => setState(() => _selectedBookingStatus = v)),
                      _buildGenericChip('Hoàn thành ($completedCount)', 'Hoàn thành', _selectedBookingStatus, (v) => setState(() => _selectedBookingStatus = v)),
                      _buildGenericChip('Đã hủy', 'Đã hủy', _selectedBookingStatus, (v) => setState(() => _selectedBookingStatus = v)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 3. DANH SÁCH LỊCH ĐẶT SÂN ──
          if (_filteredBookings.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.event_busy, color: Color(0xFF64748B), size: 48),
                  SizedBox(height: 12),
                  Text('Không tìm thấy lịch đặt sân phù hợp', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredBookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _buildBookingItemCard(_filteredBookings[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildBookingItemCard(BookingItem b) {
    Color statusColor = const Color(0xFFF59E0B);
    if (b.status == 'Đã xác nhận') statusColor = const Color(0xFF10B981);
    if (b.status == 'Hoàn thành') statusColor = const Color(0xFF6366F1);
    if (b.status == 'Đã hủy') statusColor = const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    b.id,
                    style: const TextStyle(
                        color: Color(0xFF818CF8), fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      b.status,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Text(
                b.amount,
                style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person, color: Color(0xFF94A3B8), size: 14),
              const SizedBox(width: 4),
              Text(b.customer,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 12),
              const Icon(Icons.phone, color: Color(0xFF94A3B8), size: 14),
              const SizedBox(width: 4),
              Text(b.phone, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.sports_tennis, color: Color(0xFF94A3B8), size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text('${b.venueName} (${b.field})',
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time, color: Color(0xFF94A3B8), size: 14),
                  const SizedBox(width: 4),
                  Text('${b.time} • ${b.date}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                ],
              ),
              // Action buttons (Approve, Complete, Cancel)
              Row(
                children: [
                  if (b.status == 'Chờ xác nhận') ...[
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 22),
                      tooltip: 'Xác nhận đơn',
                      onPressed: () async {
                        await FirestoreService.updateBookingStatus(b.id, 'Đã xác nhận');
                        setState(() => b.status = 'Đã xác nhận');
                        _showToast('Đã xác nhận đơn ${b.id}!');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 22),
                      tooltip: 'Hủy đơn',
                      onPressed: () async {
                        await FirestoreService.updateBookingStatus(b.id, 'Đã hủy');
                        setState(() => b.status = 'Đã hủy');
                        _showToast('Đã hủy đơn ${b.id}!', isError: true);
                      },
                    ),
                  ],
                  if (b.status == 'Đã xác nhận') ...[
                    IconButton(
                      icon: const Icon(Icons.done_all, color: Color(0xFF6366F1), size: 22),
                      tooltip: 'Đánh dấu hoàn thành',
                      onPressed: () async {
                        await FirestoreService.updateBookingStatus(b.id, 'Hoàn thành');
                        setState(() => b.status = 'Hoàn thành');
                        _showToast('Đơn ${b.id} đã hoàn thành!');
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: QUẢN LÝ KHÁCH HÀNG (CUSTOMERS)
  // ==========================================
  Widget _buildCustomersTab() {
    final filtered = _customers.where((c) {
      final q = _searchCustomerQuery.toLowerCase().trim();
      final matchQuery = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.phone.contains(q) ||
          c.email.toLowerCase().contains(q);

      final matchRank = _selectedCustomerRank == 'all' ||
          (_selectedCustomerRank == 'vip' && c.rank.contains('VIP')) ||
          (_selectedCustomerRank == 'active' && c.status == 'Hoạt động') ||
          (_selectedCustomerRank == 'locked' && c.status == 'Tạm khóa');

      return matchQuery && matchRank;
    }).toList();

    final vipCount = _customers.where((c) => c.rank.contains('VIP')).length;
    final activeCount = _customers.where((c) => c.status == 'Hoạt động').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. KPI THỐNG KÊ NHANH KHÁCH HÀNG
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tổng Khách Hàng', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          Icon(Icons.people_outline, color: Color(0xFF38BDF8), size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${_customers.length}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Đã đồng bộ cơ sở dữ liệu', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFBBF24).withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Hội Viên VIP', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          Icon(Icons.workspace_premium, color: Color(0xFFFBBF24), size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$vipCount', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Vàng & Kim Cương', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Đang Hoạt Động', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$activeCount', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Tài khoản khả dụng', style: TextStyle(color: Color(0xFF10B981), fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. SEARCH & ACTIONS BAR
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.5)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: (val) => setState(() => _searchCustomerQuery = val),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Tìm theo tên, số điện thoại, email...',
                                  hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            if (_searchCustomerQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(() => _searchCustomerQuery = ''),
                                child: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 16),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _openCustomerDialog(null),
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Thêm Khách', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildGenericChip('Tất cả (${_customers.length})', 'all', _selectedCustomerRank, (v) => setState(() => _selectedCustomerRank = v)),
                      const SizedBox(width: 6),
                      _buildGenericChip('Hội Viên VIP ($vipCount)', 'vip', _selectedCustomerRank, (v) => setState(() => _selectedCustomerRank = v)),
                      const SizedBox(width: 6),
                      _buildGenericChip('Đang Hoạt Động ($activeCount)', 'active', _selectedCustomerRank, (v) => setState(() => _selectedCustomerRank = v)),
                      const SizedBox(width: 6),
                      _buildGenericChip('Tạm Khóa', 'locked', _selectedCustomerRank, (v) => setState(() => _selectedCustomerRank = v)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. DANH SÁCH KHÁCH HÀNG
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.person_search, color: Color(0xFF64748B), size: 48),
                  SizedBox(height: 12),
                  Text('Không tìm thấy khách hàng phù hợp', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final c = filtered[i];
                Color rankColor = const Color(0xFFCD7F32); // Bronze
                if (c.rank.contains('Kim Cương')) rankColor = const Color(0xFF38BDF8);
                else if (c.rank.contains('Vàng')) rankColor = const Color(0xFFFBBF24);
                else if (c.rank.contains('Bạc')) rankColor = const Color(0xFF94A3B8);

                final isLocked = c.status == 'Tạm khóa';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isLocked ? const Color(0xFFEF4444).withOpacity(0.3) : const Color(0xFF1E3A5F).withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [rankColor.withOpacity(0.8), rankColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          c.name.isNotEmpty ? c.name[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Thông tin cơ bản
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  c.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: rankColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: rankColor.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    c.rank,
                                    style: TextStyle(color: rankColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (isLocked) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Tạm khóa', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.phone_outlined, color: Color(0xFF64748B), size: 13),
                                    const SizedBox(width: 4),
                                    Text(c.phone, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.email_outlined, color: Color(0xFF64748B), size: 13),
                                    const SizedBox(width: 4),
                                    Text(c.email, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.sports, color: Color(0xFF64748B), size: 13),
                                    const SizedBox(width: 4),
                                    Text('Môn: ${c.favoriteSport}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Chỉ số lượt đặt & Chi tiêu
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              c.totalSpent,
                              style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${c.bookingsCount} lượt đặt',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ),

                      // Nút hành động
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8), size: 20),
                        color: const Color(0xFF0B1424),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onSelected: (action) {
                          if (action == 'edit') {
                            _openCustomerDialog(c);
                          } else if (action == 'toggle_status') {
                            setState(() {
                              c.status = (c.status == 'Hoạt động') ? 'Tạm khóa' : 'Hoạt động';
                            });
                            FirestoreService.updateCustomer(c);
                            _showToast('Đã cập nhật trạng thái khách hàng ${c.name}!');
                          } else if (action == 'delete') {
                            setState(() {
                              _customers.removeWhere((item) => item.id == c.id);
                            });
                            FirestoreService.deleteCustomer(c.id);
                            _showToast('Đã xóa khách hàng ${c.name}!', isError: true);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Color(0xFF38BDF8), size: 16),
                                SizedBox(width: 8),
                                Text('Chỉnh sửa', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle_status',
                            child: Row(
                              children: [
                                Icon(isLocked ? Icons.lock_open : Icons.lock_outline, color: const Color(0xFFFBBF24), size: 16),
                                SizedBox(width: 8),
                                Text(isLocked ? 'Mở khóa tài khoản' : 'Tạm khóa tài khoản', style: const TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
                                SizedBox(width: 8),
                                Text('Xóa khách', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 5: THANH TOÁN & DOANH THU (PAYMENTS)
  // ==========================================
  Widget _buildPaymentsTab() {
    final filtered = _payments.where((p) {
      final q = _searchPaymentQuery.toLowerCase().trim();
      final matchQuery = q.isEmpty ||
          p.id.toLowerCase().contains(q) ||
          p.bookingId.toLowerCase().contains(q) ||
          p.customer.toLowerCase().contains(q) ||
          p.bankRef.toLowerCase().contains(q);

      final matchMethod = _selectedPaymentMethod == 'all' || p.method.contains(_selectedPaymentMethod);
      return matchQuery && matchMethod;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TỔNG QUAN TÀI CHÍNH / THU NGÂN
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Thu ngân hôm nay', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          Icon(Icons.trending_up, color: Color(0xFF10B981), size: 18),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text('4.850.000đ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('+18% so với hôm qua', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Online (VietQR/MoMo)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          Icon(Icons.qr_code_scanner, color: Color(0xFF38BDF8), size: 18),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text('3.620.000đ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('74.6% tổng giao dịch', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFBBF24).withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tiền mặt tại quầy', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          Icon(Icons.payments_outlined, color: Color(0xFFFBBF24), size: 18),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text('1.230.000đ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('25.4% tổng giao dịch', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. SEARCH & FILTER
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.5)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: (val) => setState(() => _searchPaymentQuery = val),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Tìm theo mã PAY, mã đơn BK, khách, mã ngân hàng...',
                                  hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            if (_searchPaymentQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(() => _searchPaymentQuery = ''),
                                child: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 16),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _openAddPaymentDialog,
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('Tạo Phiếu Thu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Method Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildGenericChip('Tất cả (${_payments.length})', 'all', _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v)),
                      const SizedBox(width: 6),
                      _buildGenericChip('VietQR Pro', 'VietQR', _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v)),
                      const SizedBox(width: 6),
                      _buildGenericChip('Ví MoMo', 'MoMo', _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v)),
                      const SizedBox(width: 6),
                      _buildGenericChip('Tiền Mặt', 'Tiền mặt', _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. DANH SÁCH GIAO DỊCH
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.credit_card_off, color: Color(0xFF64748B), size: 48),
                  SizedBox(height: 12),
                  Text('Không tìm thấy giao dịch nào', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final p = filtered[i];

                Color statusColor = const Color(0xFF10B981); // Success
                if (p.status == 'Đang xử lý') statusColor = const Color(0xFFFBBF24);
                else if (p.status == 'Đã hoàn tiền') statusColor = const Color(0xFFEF4444);

                IconData methodIcon = Icons.qr_code;
                if (p.method.contains('MoMo')) methodIcon = Icons.account_balance_wallet_outlined;
                else if (p.method.contains('Tiền mặt')) methodIcon = Icons.payments_outlined;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1F35), Color(0xFF0A1628)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Method icon badge
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Icon(methodIcon, color: const Color(0xFF38BDF8), size: 20),
                      ),
                      const SizedBox(width: 12),

                      // Thông tin giao dịch
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  p.id,
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF334155),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('Đơn ${p.bookingId}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${p.customer} • ${p.method}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${p.time} • Ref: ${p.bankRef}',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      ),

                      // Số tiền & Trạng thái
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            p.amount,
                            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withOpacity(0.5)),
                            ),
                            child: Text(
                              p.status,
                              style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),

                      // Actions
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8), size: 20),
                        color: const Color(0xFF0B1424),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onSelected: (action) {
                          if (action == 'success') {
                            setState(() => p.status = 'Thành công');
                            FirestoreService.updatePaymentStatus(p.id, 'Thành công');
                            _showToast('Đã xác nhận thanh toán ${p.id}!');
                          } else if (action == 'refund') {
                            setState(() => p.status = 'Đã hoàn tiền');
                            FirestoreService.updatePaymentStatus(p.id, 'Đã hoàn tiền');
                            _showToast('Đã hoàn tiền giao dịch ${p.id}!', isError: true);
                          } else if (action == 'receipt') {
                            _openPaymentReceiptDialog(p);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'receipt',
                            child: Row(
                              children: [
                                Icon(Icons.receipt_outlined, color: Color(0xFF38BDF8), size: 16),
                                SizedBox(width: 8),
                                Text('Xem biên lai', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          if (p.status != 'Thành công')
                            const PopupMenuItem(
                              value: 'success',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                                  SizedBox(width: 8),
                                  Text('Đánh dấu thành công', style: TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              ),
                            ),
                          if (p.status != 'Đã hoàn tiền')
                            const PopupMenuItem(
                              value: 'refund',
                              child: Row(
                                children: [
                                  Icon(Icons.replay, color: Color(0xFFEF4444), size: 16),
                                  SizedBox(width: 8),
                                  Text('Hoàn tiền giao dịch', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGenericChip(String label, String key, String currentSelected, ValueChanged<String> onSelected) {
    final selected = currentSelected == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => onSelected(key),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF0F203C), Color(0xFF070E1B)],
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF34D399)
                  : const Color(0xFF1E3A5F).withOpacity(0.6),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // DIALOGS: KHÁCH HÀNG & THANH TOÁN
  // ==========================================
  void _openCustomerDialog(CustomerItem? existing) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    String selectedSport = existing?.favoriteSport ?? 'Pickleball';
    String selectedRank = existing?.rank ?? 'Đồng';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0B1424),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(isEdit ? Icons.edit : Icons.person_add, color: const Color(0xFF10B981)),
                const SizedBox(width: 8),
                Text(
                  isEdit ? 'Chỉnh Sửa Khách Hàng' : 'Thêm Khách Hàng Mới',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogTextField('Họ và Tên *', nameCtrl, 'VD: Nguyễn Văn A'),
                    const SizedBox(height: 12),
                    _dialogTextField('Số Điện Thoại *', phoneCtrl, 'VD: 0987654321'),
                    const SizedBox(height: 12),
                    _dialogTextField('Email *', emailCtrl, 'VD: khach@gmail.com'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Môn Yêu Thích', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedSport,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF0F172A),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(value: 'Pickleball', child: Text('🏓 Pickleball')),
                                      DropdownMenuItem(value: 'Cầu lông', child: Text('🏸 Cầu lông')),
                                      DropdownMenuItem(value: 'Bóng đá', child: Text('⚽ Bóng đá')),
                                      DropdownMenuItem(value: 'Tennis', child: Text('🎾 Tennis')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setDialogState(() => selectedSport = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hạng Hội Viên', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedRank,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF0F172A),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(value: 'VIP Kim Cương', child: Text('💎 VIP Kim Cương')),
                                      DropdownMenuItem(value: 'VIP Vàng', child: Text('👑 VIP Vàng')),
                                      DropdownMenuItem(value: 'Bạc', child: Text('🥈 Bạc')),
                                      DropdownMenuItem(value: 'Đồng', child: Text('🥉 Đồng')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setDialogState(() => selectedRank = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                    _showToast('Vui lòng nhập họ tên và số điện thoại!', isError: true);
                    return;
                  }
                  if (isEdit) {
                    existing.name = nameCtrl.text.trim();
                    existing.phone = phoneCtrl.text.trim();
                    existing.email = emailCtrl.text.trim();
                    existing.favoriteSport = selectedSport;
                    existing.rank = selectedRank;
                    FirestoreService.updateCustomer(existing);
                    setState(() {});
                    _showToast('Đã cập nhật khách hàng ${existing.name}!');
                  } else {
                    final newCust = CustomerItem(
                      id: 'CUST-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      favoriteSport: selectedSport,
                      rank: selectedRank,
                      joinDate: '01/11/2026',
                    );
                    setState(() => _customers.insert(0, newCust));
                    FirestoreService.addCustomer(newCust);
                    _showToast('Đã thêm khách hàng ${newCust.name} thành công!');
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                child: Text(isEdit ? 'Lưu Thay Đổi' : 'Thêm Mới'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAddPaymentDialog() {
    final bkCtrl = TextEditingController(text: 'BK-1035');
    final custCtrl = TextEditingController(text: 'Nguyễn Văn Khách');
    final amountCtrl = TextEditingController(text: '250.000đ');
    final refCtrl = TextEditingController(text: 'POS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    String selectedMethod = 'VietQR Pro';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0B1424),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.add_card, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('Tạo Phiếu Thu / Thu Ngân', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogTextField('Mã Đơn Đặt Sân', bkCtrl, 'VD: BK-1029'),
                    const SizedBox(height: 12),
                    _dialogTextField('Tên Khách Hàng', custCtrl, 'VD: Trần Văn B'),
                    const SizedBox(height: 12),
                    _dialogTextField('Số Tiền Thu', amountCtrl, 'VD: 300.000đ'),
                    const SizedBox(height: 12),
                    _dialogTextField('Mã Tham Chiếu / Ghi Chú', refCtrl, 'VD: MBB-12345'),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Phương Thức Thanh Toán', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedMethod,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF0F172A),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: const [
                                DropdownMenuItem(value: 'VietQR Pro', child: Text('📱 Chuyển khoản VietQR Pro')),
                                DropdownMenuItem(value: 'Ví MoMo', child: Text('👛 Ví MoMo')),
                                DropdownMenuItem(value: 'VNPay QR', child: Text('💳 VNPay QR')),
                                DropdownMenuItem(value: 'Tiền mặt', child: Text('💵 Tiền mặt tại quầy')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedMethod = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                onPressed: () {
                  final newPay = PaymentItem(
                    id: 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                    bookingId: bkCtrl.text.trim().isEmpty ? 'BK-MANUAL' : bkCtrl.text.trim(),
                    customer: custCtrl.text.trim().isEmpty ? 'Khách lẻ' : custCtrl.text.trim(),
                    amount: amountCtrl.text.trim().isEmpty ? '0đ' : amountCtrl.text.trim(),
                    method: selectedMethod,
                    time: '01/11/2026 10:45',
                    status: 'Thành công',
                    bankRef: refCtrl.text.trim().isEmpty ? 'N/A' : refCtrl.text.trim(),
                  );
                  setState(() => _payments.insert(0, newPay));
                  FirestoreService.addPayment(newPay);
                  _showToast('Đã ghi nhận thanh toán ${newPay.id} thành công!');
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Xác Nhận Thu Tiền'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openPaymentReceiptDialog(PaymentItem p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1424),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.receipt, color: Color(0xFF38BDF8)),
            SizedBox(width: 8),
            Text('Biên Lai Thanh Toán', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    const Text('ALOBOOKING - XÁC NHẬN THANH TOÁN', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 12),
                    Text(p.amount, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(p.status, style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                    const Divider(color: Color(0xFF334155), height: 24),
                    _receiptRow('Mã GD:', p.id),
                    _receiptRow('Mã Đơn:', p.bookingId),
                    _receiptRow('Khách Hàng:', p.customer),
                    _receiptRow('Phương Thức:', p.method),
                    _receiptRow('Thời Gian:', p.time),
                    _receiptRow('Mã Ref Bank:', p.bankRef),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showToast('Đang gửi biên lai điện tử cho khách hàng...');
            },
            icon: const Icon(Icons.print, size: 16),
            label: const Text('In / Gửi Biên Lai'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOGS: ADD / EDIT / DELETE VENUES
  // ==========================================
  void _openAddVenueDialog() {
    _openVenueFormDialog(null);
  }

  void _openEditVenueDialog(Venue v) {
    _openVenueFormDialog(v);
  }

  void _openVenueFormDialog(Venue? existing) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String selectedType = existing?.type ?? 'pickleball';
    String selectedDist = existing?.district ?? 'Đống Đa';
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final priceCtrl = TextEditingController(text: existing?.price ?? '120k - 220k/h');
    final hoursCtrl = TextEditingController(text: existing?.hours ?? '06:00 – 23:00');
    final ratingCtrl = TextEditingController(text: existing?.rating.toString() ?? '4.8');
    final tagsCtrl = TextEditingController(
        text: existing?.tags.join(', ') ?? 'Mái che cao, Đèn LED, Thảm Yonex, Chỗ đỗ xe');
    final imageCtrl = TextEditingController(
      text: existing?.image ?? _sampleImages['pickleball']![0],
    );
    double lat = existing?.lat ?? _districtCoordinates['Đống Đa']!['lat']!;
    double lng = existing?.lng ?? _districtCoordinates['Đống Đa']!['lng']!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0B1424),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(isEdit ? Icons.edit : Icons.add_circle, color: const Color(0xFF10B981)),
                const SizedBox(width: 8),
                Text(isEdit ? 'Chỉnh Sửa Sân Thể Thao' : 'Thêm Sân Thể Thao Mới',
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogTextField('Tên Cụm Sân *', nameCtrl, 'VD: Cụm Sân Pickleball Đống Đa'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Môn Thể Thao *',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedType,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF0B1424),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(value: 'pickleball', child: Text('Pickleball')),
                                      DropdownMenuItem(value: 'badminton', child: Text('Cầu lông')),
                                      DropdownMenuItem(value: 'football', child: Text('Bóng đá')),
                                      DropdownMenuItem(value: 'tennis', child: Text('Tennis')),
                                      DropdownMenuItem(value: 'basketball', child: Text('Bóng rổ')),
                                    ],
                                    onChanged: (val) {
                                      setDialogState(() {
                                        selectedType = val ?? 'pickleball';
                                        final list = _sampleImages[selectedType] ?? _sampleImages['pickleball']!;
                                        imageCtrl.text = list[0];
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Quận Huyện *',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedDist,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF0B1424),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: _districts
                                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                        .toList(),
                                    onChanged: (val) {
                                      setDialogState(() {
                                        selectedDist = val ?? 'Đống Đa';
                                        final coords = _districtCoordinates[selectedDist];
                                        if (coords != null) {
                                          lat = coords['lat']!;
                                          lng = coords['lng']!;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _dialogTextField('Địa Chỉ Cụ Thể *', addressCtrl, 'VD: 18 Chùa Bộc, Đống Đa, Hà Nội'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _dialogTextField('Mức Giá Thuê/Giờ', priceCtrl, '120k - 220k/h')),
                        const SizedBox(width: 12),
                        Expanded(child: _dialogTextField('Giờ Hoạt Động', hoursCtrl, '06:00 – 23:00')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _dialogTextField('Tiện Ích & Tags', tagsCtrl, 'Mái che cao, Đèn LED, Thảm Yonex'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('URL Hình Ảnh Sân Thể Thao',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        TextButton(
                          onPressed: () {
                            final list = _sampleImages[selectedType] ?? _sampleImages['pickleball']!;
                            final next = list[math.Random().nextInt(list.length)];
                            setDialogState(() => imageCtrl.text = next);
                          },
                          child: const Text('🎨 Chọn ảnh mẫu đẹp',
                              style: TextStyle(color: Color(0xFF34D399), fontSize: 11)),
                        ),
                      ],
                    ),
                    _dialogTextField('', imageCtrl, 'https://images.unsplash.com/...'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty || addressCtrl.text.trim().isEmpty) {
                    _showToast('Vui lòng điền tên sân và địa chỉ!', isError: true);
                    return;
                  }

                  final tags = tagsCtrl.text.split(',').map((t) => t.trim()).filter((t) => t.isNotEmpty).toList();

                  if (isEdit) {
                    final updated = Venue(
                      id: existing.id,
                      name: nameCtrl.text.trim(),
                      type: selectedType,
                      district: selectedDist,
                      distance: existing.distance,
                      address: addressCtrl.text.trim(),
                      hours: hoursCtrl.text.trim(),
                      tags: tags.isNotEmpty ? tags : ['Đơn ngày'],
                      rating: double.tryParse(ratingCtrl.text) ?? 4.8,
                      price: priceCtrl.text.trim(),
                      lat: lat,
                      lng: lng,
                      image: imageCtrl.text.trim(),
                      logo: existing.logo,
                    );
                    await FirestoreService.updateVenue(updated);
                    setState(() {
                      final idx = _venues.indexWhere((x) => x.id == existing.id);
                      if (idx != -1) _venues[idx] = updated;
                    });
                    _showToast('Đã cập nhật sân "${updated.name}" thành công!');
                  } else {
                    final newId = _venues.isNotEmpty ? _venues.map((x) => x.id).reduce(math.max) + 1 : 1;
                    final created = Venue(
                      id: newId,
                      name: nameCtrl.text.trim(),
                      type: selectedType,
                      district: selectedDist,
                      distance: '1.2km',
                      address: addressCtrl.text.trim(),
                      hours: hoursCtrl.text.trim(),
                      tags: tags.isNotEmpty ? tags : ['Đơn ngày'],
                      rating: double.tryParse(ratingCtrl.text) ?? 4.8,
                      price: priceCtrl.text.trim(),
                      lat: lat,
                      lng: lng,
                      image: imageCtrl.text.trim(),
                      logo: 'https://ui-avatars.com/api/?name=PB&background=10b981&color=fff&size=40&bold=true',
                    );
                    await FirestoreService.addVenue(created);
                    setState(() {
                      _venues.insert(0, created);
                    });
                    _showToast('Đã thêm sân "${created.name}" thành công!');
                  }

                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                child: Text(isEdit ? 'Lưu Thay Đổi' : 'Thêm Mới'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dialogTextField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          const SizedBox(height: 4),
        ],
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  // --- DELETE VENUE DIALOG ---
  void _openDeleteVenueDialog(Venue v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1424),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Xác Nhận Xóa Sân', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa sân "${v.name}" (#${v.id}) khỏi hệ thống?\nHành động này không thể hoàn tác.',
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirestoreService.deleteVenue(v.id);
              setState(() => _venues.removeWhere((x) => x.id == v.id));
              Navigator.pop(ctx);
              _showToast('Đã xóa sân "${v.name}" thành công!', isError: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác Nhận Xóa'),
          ),
        ],
      ),
    );
  }

  // --- DETAIL VENUE DIALOG ---
  void _openViewDetailDialog(Venue v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1424),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: VenueImageView(
                    imageUrl: v.image,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(v.type.toUpperCase(),
                            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                            Text(' ${v.rating} / 5.0', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(v.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 4),
                    Text(v.address, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFF64748B), size: 14),
                        const SizedBox(width: 4),
                        Text(v.hours, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 16),
                        const Icon(Icons.payments_outlined, color: Color(0xFF10B981), size: 14),
                        const SizedBox(width: 4),
                        Text(v.price, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: v.tags.map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Text('✓ $t', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _openEditVenueDialog(v);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Chỉnh Sửa'),
          ),
        ],
      ),
    );
  }

  // --- ADD WALKIN BOOKING DIALOG ---
  void _openAddWalkinBookingDialog() {
    final custCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String venueName = _venues.isNotEmpty ? _venues[0].name : 'Pickleball Cổng B Ga Hà Nội';
    final amountCtrl = TextEditingController(text: '200,000đ');
    final timeCtrl = TextEditingController(text: '18:00 - 19:30');
    final dateCtrl = TextEditingController(text: '31/10/2026');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1424),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đặt Sân Tại Quầy', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogTextField('Tên Khách Hàng *', custCtrl, 'Nguyễn Văn A'),
              const SizedBox(height: 10),
              _dialogTextField('Số Điện Thoại *', phoneCtrl, '0901234567'),
              const SizedBox(height: 10),
              _dialogTextField('Khung Giờ', timeCtrl, '18:00 - 19:30'),
              const SizedBox(height: 10),
              _dialogTextField('Tổng Tiền (VNĐ)', amountCtrl, '200,000đ'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (custCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                _showToast('Vui lòng điền đủ thông tin!', isError: true);
                return;
              }
              final bookingId = 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
              final newBooking = BookingItem(
                id: bookingId,
                customer: custCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                venueName: venueName,
                field: 'Sân #1',
                time: timeCtrl.text.trim(),
                date: dateCtrl.text.trim(),
                amount: amountCtrl.text.trim(),
                status: 'Đã xác nhận',
                paymentMethod: 'Tiền mặt tại quầy',
              );
              await FirestoreService.createBooking(
                customer: newBooking.customer,
                phone: newBooking.phone,
                venueName: newBooking.venueName,
                field: newBooking.field,
                time: newBooking.time,
                date: newBooking.date,
                amount: newBooking.amount,
                paymentMethod: newBooking.paymentMethod,
              );
              setState(() => _bookings.insert(0, newBooking));
              Navigator.pop(ctx);
              _showToast('Đã tạo đơn đặt sân tại quầy $bookingId thành công!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Xác Nhận Đặt'),
          ),
        ],
      ),
    );
  }

  // --- SYNC TO FIRESTORE ---
  Future<void> _syncToFirestore() async {
    _showToast('Đang đồng bộ toàn bộ sân lên Firestore...');
    final count = await FirestoreService.syncVenues(_venues);
    _showToast('Đã đồng bộ thành công $count sân lên Firebase Firestore!');
  }
}

// ==========================================
// CUSTOM PAINTERS FOR CHARTS
// ==========================================
class RevenueLineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF334155).withOpacity(0.4)
      ..strokeWidth = 1;

    // Draw horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Actual Data points
    final actual = [0.25, 0.45, 0.38, 0.65, 0.58, 0.85, 0.78];
    // Forecast Data points
    final forecast = [0.22, 0.42, 0.40, 0.60, 0.55, 0.92, 0.88];

    final actualPath = Path();
    final forecastPath = Path();

    final stepX = size.width / (actual.length - 1);

    for (int i = 0; i < actual.length; i++) {
      final x = i * stepX;
      final yActual = size.height - (actual[i] * size.height);
      final yForecast = size.height - (forecast[i] * size.height);

      if (i == 0) {
        actualPath.moveTo(x, yActual);
        forecastPath.moveTo(x, yForecast);
      } else {
        actualPath.lineTo(x, yActual);
        forecastPath.lineTo(x, yForecast);
      }
    }

    // Fill actual area
    final fillPath = Path.from(actualPath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF6366F1).withOpacity(0.35), const Color(0xFF6366F1).withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Draw actual line
    final actualPaint = Paint()
      ..color = const Color(0xFF818CF8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(actualPath, actualPaint);

    // Draw forecast dashed line
    final forecastPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(forecastPath, forecastPaint);

    // Draw points on actual
    final dotPaint = Paint()..color = const Color(0xFF818CF8);
    final dotWhite = Paint()..color = Colors.white;
    for (int i = 0; i < actual.length; i++) {
      final x = i * stepX;
      final y = size.height - (actual[i] * size.height);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(Offset(x, y), 2, dotWhite);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DonutChartPainter extends CustomPainter {
  final List<double> slices;
  final List<Color> colors;

  DonutChartPainter({required this.slices, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    double startAngle = -math.pi / 2;

    for (int i = 0; i < slices.length; i++) {
      final sweepAngle = slices[i] * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 11),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension _IterableExt<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T) test) => where(test);
}
