import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/admin_stats.dart';
import '../services/booking_slots.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../widgets/venue_image_view.dart';
import '../services/image_picker_service.dart';

class OwnerScreen extends StatefulWidget {
  final List<Venue> initialVenues;
  final int initialTabIndex;

  const OwnerScreen({
    super.key,
    required this.initialVenues,
    this.initialTabIndex = 0,
  });

  @override
  State<OwnerScreen> createState() => _OwnerScreenState();
}

class _OwnerScreenState extends State<OwnerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Venue> _allVenues = [];
  List<BookingItem> _allBookings = [];
  List<CustomerItem> _allCustomers = [];
  List<PaymentItem> _allPayments = [];
  bool _isLoading = false;

  // Lọc
  String _searchVenueQuery = '';
  String _selectedStatusFilter = 'all'; // 'all' | 'approved' | 'pending' | 'rejected'
  String _searchBookingQuery = '';
  String _searchCustomerQuery = '';

  // Chủ sân hiện tại
  String get _currentOwnerId => AuthService.currentUser?.uid ?? '';
  String get _currentOwnerName => AuthService.currentUser?.fullName ?? 'Chủ sân';

  // Chỉ các sân do chính chủ sân này đăng ký (theo ownerId), không suy đoán theo quận hay tên.
  List<Venue> get _myVenues {
    final id = _currentOwnerId;
    if (id.isEmpty) return [];
    return _allVenues.where((v) => v.ownerId == id).toList();
  }

  // Danh sách tên sân của tôi để lọc đơn đặt & doanh thu
  Set<String> get _myVenueNames => _myVenues.map((v) => v.name.trim().toLowerCase()).toSet();

  // Đơn đặt sân chỉ thuộc các sân của chủ sân này (khớp đúng tên sân)
  List<BookingItem> get _myBookings {
    final names = _myVenueNames;
    return _allBookings.where((b) => names.contains(b.venueName.trim().toLowerCase())).toList();
  }

  // Khách hàng đã từng đặt tại sân của tôi (khớp số điện thoại, nếu thiếu thì theo tên)
  List<CustomerItem> get _myCustomers {
    String digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
    final bookings = _myBookings;
    return _allCustomers.where((c) {
      final cp = digits(c.phone);
      return bookings.any((b) {
        final bp = digits(b.phone);
        return (cp.isNotEmpty && bp == cp) ||
            ((cp.isEmpty || bp.isEmpty) && b.customer.trim().toLowerCase() == c.name.trim().toLowerCase());
      });
    }).toList();
  }

  // Giao dịch thanh toán thuộc đơn đặt của sân tôi
  List<PaymentItem> get _myPayments {
    final myBookingIds = _myBookings.map((b) => b.id).toSet();
    return _allPayments.where((p) => myBookingIds.contains(p.bookingId)).toList();
  }

  final List<String> _districts = [
    'Đống Đa', 'Cầu Giấy', 'Ba Đình', 'Hoàn Kiếm', 'Hai Bà Trưng',
    'Thanh Xuân', 'Tây Hồ', 'Nam Từ Liêm', 'Bắc Từ Liêm', 'Hà Đông',
    'Hoàng Mai', 'Long Biên', 'Gia Lâm', 'Đông Anh', 'Thanh Trì', 'Hoài Đức'
  ];

  final Map<String, List<String>> _sampleImages = {
    'pickleball': [
      'https://images.unsplash.com/photo-1622279457486-62dcc4a431d6?w=600&h=320&fit=crop&q=80',
      'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=600&h=320&fit=crop&q=80',
    ],
    'badminton': [
      'https://images.unsplash.com/photo-1521537634581-0dced2fee2ef?w=600&h=320&fit=crop&q=80',
      'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=600&h=320&fit=crop&q=80',
    ],
    'football': [
      'https://images.unsplash.com/photo-1529900241451-93b9423c9604?w=600&h=320&fit=crop&q=80',
      'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=600&h=320&fit=crop&q=80',
    ],
    'tennis': [
      'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=600&h=320&fit=crop&q=80',
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: (widget.initialTabIndex >= 0 && widget.initialTabIndex < 4)
          ? widget.initialTabIndex
          : 0,
    );
    _allVenues = List.from(widget.initialVenues);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        _allVenues = fetchedVenues;
      }
      _allBookings = fetchedBookings;
      _allCustomers = fetchedCustomers;
      _allPayments = fetchedPayments;
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF34D399),
          surface: Color(0xFF1E293B),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Dark slate premium theme
        appBar: _buildOwnerAppBar(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildMyVenuesTab(),
                  _buildRevenueTab(),
                  _buildBookingsTab(),
                  _buildCustomersTab(),
                ],
              ),
      ),
    );
  }

  PreferredSizeWidget _buildOwnerAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E293B),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
        tooltip: 'Quay lại App',
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
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.stadium_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cổng Quản Trị Chủ Sân',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'Chủ sân: $_currentOwnerName',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8), size: 20),
          tooltip: 'Tải lại',
          onPressed: _loadData,
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 20),
          tooltip: 'Đăng xuất',
          onPressed: () {
            AuthService.logout();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
        const SizedBox(width: 8),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: const Color(0xFF38BDF8),
        indicatorWeight: 3,
        labelColor: const Color(0xFF38BDF8),
        unselectedLabelColor: const Color(0xFF94A3B8),
        labelStyle: const TextStyle(fontFamily: 'Be Vietnam Pro', fontWeight: FontWeight.bold, fontSize: 13.5),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Be Vietnam Pro', fontWeight: FontWeight.w500, fontSize: 13.5),
        tabs: [
          Tab(icon: const Icon(Icons.sports_tennis, size: 18), text: 'Sân Của Tôi (${_myVenues.length})'),
          const Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'Doanh Thu & Thống Kê'),
          Tab(icon: const Icon(Icons.calendar_month, size: 18), text: 'Đơn Đặt (${_myBookings.length})'),
          Tab(icon: const Icon(Icons.people_alt_outlined, size: 18), text: 'Khách Quen (${_myCustomers.length})'),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: QUẢN LÝ SÂN CỦA TÔI (CRUD + TRẠNG THÁI DUYỆT)
  // ==========================================
  Widget _buildMyVenuesTab() {
    final filtered = _myVenues.where((v) {
      final q = _searchVenueQuery.toLowerCase().trim();
      final matchQuery = q.isEmpty ||
          v.name.toLowerCase().contains(q) ||
          v.address.toLowerCase().contains(q) ||
          v.district.toLowerCase().contains(q);

      final matchStatus = _selectedStatusFilter == 'all' || v.approvalStatus == _selectedStatusFilter;
      return matchQuery && matchStatus;
    }).toList();

    final approvedCount = _myVenues.where((v) => v.isApproved).length;
    final pendingCount = _myVenues.where((v) => v.isPending).length;
    final rejectedCount = _myVenues.where((v) => v.isRejected).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. BANNER THÔNG BÁO VỀ QUY TRÌNH DUYỆT BÀI CỦA ADMIN
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0284C7).withOpacity(0.2),
                  const Color(0xFF1E293B),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Color(0xFF38BDF8), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chính Sách Kiểm Duyệt Bài Đăng Sân Thể Thao',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Khi bạn thêm mới hoặc cập nhật sân, bài đăng sẽ ở trạng thái "Chờ duyệt". Super Admin sẽ kiểm duyệt trong vòng 2-4 giờ để đảm bảo tính xác thực trước khi hiển thị công khai trên ứng dụng cho khách hàng.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. KPI THỐNG KÊ NHANH SÂN BÃI
          Row(
            children: [
              Expanded(
                child: _buildOwnerKpiCard(
                  'Tổng Cụm Sân',
                  '${_myVenues.length}',
                  Icons.stadium_outlined,
                  const Color(0xFF38BDF8),
                  'Thuộc quyền quản lý',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildOwnerKpiCard(
                  'Đã Duyệt (Công Khai)',
                  '$approvedCount',
                  Icons.check_circle_outline,
                  const Color(0xFF10B981),
                  'Khách đang đặt được',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildOwnerKpiCard(
                  'Chờ Admin Duyệt',
                  '$pendingCount',
                  Icons.hourglass_top,
                  const Color(0xFFFBBF24),
                  'Đang xử lý hồ sơ',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. SEARCH & BUTTON THÊM SÂN
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
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
                                onChanged: (val) => setState(() => _searchVenueQuery = val),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Tìm trong danh sách sân của bạn...',
                                  hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            if (_searchVenueQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(() => _searchVenueQuery = ''),
                                child: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 16),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _openVenueDialog(null),
                      icon: const Icon(Icons.add_circle, size: 18),
                      label: const Text('ĐĂNG KÝ SÂN MỚI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Lọc theo trạng thái kiểm duyệt
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilterChip('Tất cả (${_myVenues.length})', 'all'),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('Đã duyệt ($approvedCount)', 'approved'),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('Chờ duyệt ($pendingCount)', 'pending'),
                      if (rejectedCount > 0) ...[
                        const SizedBox(width: 6),
                        _buildStatusFilterChip('Bị từ chối ($rejectedCount)', 'rejected'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. DANH SÁCH SÂN
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.sports_tennis, color: Color(0xFF64748B), size: 48),
                  SizedBox(height: 12),
                  Text('Chưa có sân nào phù hợp với bộ lọc', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final v = filtered[i];
                return _buildOwnerVenueCard(v);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOwnerVenueCard(Venue v) {
    Color statusBg = const Color(0xFF10B981).withOpacity(0.15);
    Color statusColor = const Color(0xFF10B981);
    String statusText = '🟢 Đã duyệt • Công khai';
    IconData statusIcon = Icons.check_circle;

    if (v.isPending) {
      statusBg = const Color(0xFFFBBF24).withOpacity(0.15);
      statusColor = const Color(0xFFFBBF24);
      statusText = '🟡 Chờ Admin duyệt';
      statusIcon = Icons.hourglass_top;
    } else if (v.isRejected) {
      statusBg = const Color(0xFFEF4444).withOpacity(0.15);
      statusColor = const Color(0xFFEF4444);
      statusText = '🔴 Bị từ chối duyệt';
      statusIcon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: v.isPending ? const Color(0xFFFBBF24).withOpacity(0.5) : const Color(0xFF334155),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ảnh sân
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: VenueImageView(
                  imageUrl: v.image,
                  width: 90,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),

              // Thông tin sân
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            v.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 12),
                              const SizedBox(width: 4),
                              Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${v.address} • Quận ${v.district}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('Giá thuê: ${v.price}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12.5)),
                        const SizedBox(width: 12),
                        Text('Giờ mở: ${v.hours}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (v.isRejected && v.rejectReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFEF4444), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Lý do Admin từ chối: ${v.rejectReason}',
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11.5)),
                  ),
                ],
              ),
            ),
          ],

          const Divider(color: Color(0xFF334155), height: 16),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mã sân: #${v.id} • Thể loại: ${v.type.toUpperCase()}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _openVenueDialog(v),
                    icon: const Icon(Icons.edit, size: 14, color: Color(0xFF38BDF8)),
                    label: const Text('Chỉnh sửa', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _confirmDeleteVenue(v),
                    icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
                    label: const Text('Xóa sân', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: DOANH THU & THỐNG KÊ SÂN CỦA TÔI
  // ==========================================
  Widget _buildRevenueTab() {
    final mine = _myBookings;
    final totalRev = mine
        .where((b) => AdminStats.countsAsRevenue(b.status))
        .fold<int>(0, (a, b) => a + AdminStats.parseMoney(b.amount));
    final month = AdminStats.compute(bookings: mine, venues: _myVenues, period: AdminPeriod.month);
    final change = AdminStats.change(month.revenue, month.prevRevenue);
    final activeOrders = mine.where((b) => !BookingSlots.isCancelled(b.status)).length;
    final cancelledOrders = mine.length - activeOrders;
    final revenueByVenue = <String, int>{};
    for (final b in mine.where((b) => AdminStats.countsAsRevenue(b.status))) {
      final k = b.venueName.trim().toLowerCase();
      revenueByVenue[k] = (revenueByVenue[k] ?? 0) + AdminStats.parseMoney(b.amount);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_myVenues.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Text(
                'Bạn chưa có cụm sân nào. Thêm sân ở tab "Sân của tôi"; sau khi quản trị viên duyệt, đơn đặt và doanh thu sẽ hiển thị tại đây.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _buildOwnerKpiCard(
                  'Doanh Thu Sân Của Tôi',
                  AdminStats.fmtMoney(totalRev),
                  Icons.monetization_on_outlined,
                  const Color(0xFF10B981),
                  change == null
                      ? '30 ngày qua: ${AdminStats.fmtMoney(month.revenue)}'
                      : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% so với 30 ngày trước',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildOwnerKpiCard(
                  'Tổng Lượt Đặt',
                  '$activeOrders lượt',
                  Icons.receipt_long_outlined,
                  const Color(0xFF38BDF8),
                  mine.isEmpty ? 'Chưa có đơn' : '$cancelledOrders đơn đã hủy',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildOwnerKpiCard(
                  'Khách Đã Đặt Sân',
                  '${_myCustomers.length} khách',
                  Icons.people_outline,
                  const Color(0xFFFBBF24),
                  'Có hồ sơ trong hệ thống',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bảng thống kê theo từng sân
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Báo Cáo Hiệu Quả Từng Cụm Sân',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5)),
                    Text('Đơn vị: VNĐ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 14),
                ..._myVenues.map((v) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(v.name,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                        Text(
                          v.isApproved ? 'Đang hoạt động' : 'Chờ duyệt',
                          style: TextStyle(
                            color: v.isApproved ? const Color(0xFF10B981) : const Color(0xFFFBBF24),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(AdminStats.fmtMoney(revenueByVenue[v.name.trim().toLowerCase()] ?? 0),
                            style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lịch sử thu ngân của sân tôi
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Giao Dịch Thu Ngân Gần Đây',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5)),
                const SizedBox(height: 12),
                ..._myPayments.map((p) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${p.customer} • ${p.method}', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                            Text('Mã: ${p.id} • ${p.time}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                          ],
                        ),
                        Text(p.amount, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13.5)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: ĐƠN ĐẶT SÂN CỦA TÔI
  // ==========================================
  Widget _buildBookingsTab() {
    final filtered = _myBookings.where((b) {
      final q = _searchBookingQuery.toLowerCase().trim();
      return q.isEmpty ||
          b.id.toLowerCase().contains(q) ||
          b.customer.toLowerCase().contains(q) ||
          b.venueName.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchBookingQuery = val),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Tìm theo mã đơn BK, tên khách, tên sân...',
                      hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: const Text('Chưa có đơn đặt sân nào cho các sân của bạn',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final b = filtered[i];
                Color statusColor = const Color(0xFF10B981);
                if (b.status == 'Chờ xác nhận') statusColor = const Color(0xFFFBBF24);
                if (b.status == 'Đã hủy') statusColor = const Color(0xFFEF4444);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.event_available, color: Color(0xFF38BDF8), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(b.id, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13.5)),
                                const SizedBox(width: 8),
                                Text('• ${b.venueName}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text('${b.customer} (${b.phone}) • ${b.time} - ${b.date}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(b.amount, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(b.status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      if (b.status == 'Chờ xác nhận') ...[
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22),
                          tooltip: 'Xác nhận đơn',
                          onPressed: () async {
                            await FirestoreService.confirmBooking(b.id);
                            setState(() => b.status = 'Đã xác nhận');
                            _showToast('Đã xác nhận đơn ${b.id} (đã nhận tiền chuyển khoản)!');
                          },
                        ),
                      ],
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
  // TAB 4: KHÁCH HÀNG CỦA SÂN TÔI
  // ==========================================
  Widget _buildCustomersTab() {
    final filtered = _myCustomers.where((c) {
      final q = _searchCustomerQuery.toLowerCase().trim();
      return q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.phone.contains(q) ||
          c.email.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
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
                      hintText: 'Tìm khách hàng theo tên, SĐT...',
                      hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final c = filtered[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF38BDF8),
                      child: Text(c.name.isNotEmpty ? c.name[0] : 'K', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('SĐT: ${c.phone} • Môn: ${c.favoriteSport}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(c.totalSpent, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text('${c.bookingsCount} lượt đặt', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
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

  Widget _buildOwnerKpiCard(String title, String val, IconData icon, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String label, String key) {
    final selected = _selectedStatusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedStatusFilter = key),
      selectedColor: const Color(0xFF38BDF8),
      backgroundColor: const Color(0xFF0F172A),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF94A3B8),
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: selected ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
    );
  }

  // ==========================================
  // DIALOG THÊM / SỬA SÂN CHO CHỦ SÂN
  // ==========================================
  void _openVenueDialog(Venue? existing) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String selectedType = existing?.type ?? 'pickleball';
    String selectedDist = existing?.district ?? 'Đống Đa';
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final priceCtrl = TextEditingController(text: existing?.price ?? '120k - 220k/h');
    final hoursCtrl = TextEditingController(text: existing?.hours ?? '06:00 – 23:00');
    final courtsCtrl = TextEditingController(text: (existing?.courts ?? Venue.defaultCourtCount(selectedType)).toString());
    final tagsCtrl = TextEditingController(
        text: existing?.tags.join(', ') ?? 'Mái che cao, Đèn LED, Thảm chuẩn, Chỗ đỗ xe');
    final imageCtrl = TextEditingController(
      text: existing?.image ?? _sampleImages['pickleball']![0],
    );
    bool isUploadingImage = false;
    bool showUrlField = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(isEdit ? Icons.edit : Icons.add_circle, color: const Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                Text(
                  isEdit ? 'Chỉnh Sửa Sân Của Tôi' : 'Đăng Ký Cụm Sân Mới (Chờ Duyệt)',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isEdit)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFFBBF24), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sân tạo mới sẽ gửi yêu cầu kiểm duyệt tới Super Admin trước khi được mở bán chính thức.',
                                style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _dialogField('Tên Cụm Sân *', nameCtrl, 'VD: Cụm Sân Pickleball & Badminton Chùa Bộc'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Môn Thể Thao *', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
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
                                    dropdownColor: const Color(0xFF0F172A),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(value: 'pickleball', child: Text('🏓 Pickleball')),
                                      DropdownMenuItem(value: 'badminton', child: Text('🏸 Cầu lông')),
                                      DropdownMenuItem(value: 'football', child: Text('⚽ Bóng đá')),
                                      DropdownMenuItem(value: 'tennis', child: Text('🎾 Tennis')),
                                      DropdownMenuItem(value: 'basketball', child: Text('🏀 Bóng rổ')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() {
                                          selectedType = val;
                                          final list = _sampleImages[val] ?? _sampleImages['pickleball']!;
                                          imageCtrl.text = list[0];
                                          if (!isEdit) courtsCtrl.text = Venue.defaultCourtCount(val).toString();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Quận/Huyện *', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
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
                                    dropdownColor: const Color(0xFF0F172A),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: {..._districts, selectedDist}.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setDialogState(() => selectedDist = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _dialogField('Địa Chỉ Cụ Thể *', addressCtrl, 'VD: 18 Chùa Bộc, Đống Đa, Hà Nội'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _dialogField('Giá Thuê/Giờ *', priceCtrl, '120k - 220k/h')),
                        const SizedBox(width: 10),
                        Expanded(child: _dialogField('Giờ Mở Cửa', hoursCtrl, '06:00 – 23:00')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _dialogField('Số Sân Con Trong Cụm (1–30) *', courtsCtrl, 'VD: 8'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Hình Ảnh Sân *', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        if (imageCtrl.text.startsWith('data:image'))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('✓ Đã tải từ máy', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Container(
                            height: 120,
                            width: double.infinity,
                            color: const Color(0xFF0F172A),
                            child: VenueImageView(
                              imageUrl: imageCtrl.text,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (isUploadingImage)
                            Container(
                              height: 120,
                              width: double.infinity,
                              color: Colors.black.withOpacity(0.55),
                              alignment: Alignment.center,
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 2),
                                  SizedBox(height: 6),
                                  Text('Đang tải và tối ưu ảnh...', style: TextStyle(color: Colors.white, fontSize: 11)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Hàng nút chọn ảnh
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isUploadingImage
                                ? null
                                : () async {
                                    setDialogState(() => isUploadingImage = true);
                                    try {
                                      final picked = await pickAndProcessImage();
                                      if (picked != null && picked.isNotEmpty) {
                                        setDialogState(() => imageCtrl.text = picked);
                                      }
                                    } catch (e) {
                                      debugPrint('Error picking image: $e');
                                    } finally {
                                      setDialogState(() => isUploadingImage = false);
                                    }
                                  },
                            icon: const Icon(Icons.upload_file, size: 16),
                            label: const Text(
                              '📁 TẢI ẢNH TỪ MÁY TÍNH',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => setDialogState(() => showUrlField = !showUrlField),
                          icon: Icon(showUrlField ? Icons.close : Icons.link, size: 14),
                          label: Text(showUrlField ? 'Ẩn URL' : 'Dán URL', style: const TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF94A3B8),
                            side: const BorderSide(color: Color(0xFF475569)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),

                    if (showUrlField) ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: imageCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Dán đường dẫn URL ảnh...',
                          hintStyle: const TextStyle(color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ],

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Chọn mẫu: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                        ...(_sampleImages[selectedType] ?? _sampleImages['pickleball']!).asMap().entries.map((entry) {
                          final idx = entry.key;
                          final url = entry.value;
                          final isSelected = imageCtrl.text == url;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text('Mẫu ${idx + 1}', style: TextStyle(
                                fontSize: 10,
                                color: isSelected ? const Color(0xFF38BDF8) : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              )),
                              onPressed: () => setDialogState(() => imageCtrl.text = url),
                              backgroundColor: isSelected ? const Color(0xFF0284C7).withOpacity(0.3) : const Color(0xFF0F172A),
                            ),
                          );
                        }),
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
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty || addressCtrl.text.trim().isEmpty) {
                    _showToast('Vui lòng nhập tên cụm sân và địa chỉ!', isError: true);
                    return;
                  }

                  final tagsList = tagsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  final courtCount = (int.tryParse(courtsCtrl.text.trim()) ?? Venue.defaultCourtCount(selectedType)).clamp(1, 30);

                  if (isEdit) {
                    final updated = existing.copyWith(
                      name: nameCtrl.text.trim(),
                      type: selectedType,
                      district: selectedDist,
                      address: addressCtrl.text.trim(),
                      price: priceCtrl.text.trim(),
                      hours: hoursCtrl.text.trim(),
                      tags: tagsList.isNotEmpty ? tagsList : existing.tags,
                      image: imageCtrl.text.trim().isNotEmpty ? imageCtrl.text.trim() : existing.image,
                      courtCount: courtCount,
                      // Sửa sân cũng chuyển về pending để Admin duyệt lại nếu cần
                      approvalStatus: 'pending',
                    );
                    await FirestoreService.updateVenue(updated);
                    final idx = _allVenues.indexWhere((v) => v.id == updated.id);
                    if (idx != -1) {
                      setState(() => _allVenues[idx] = updated);
                    }
                    _showToast('Đã cập nhật sân. Đang chờ Admin duyệt lại thông tin!');
                  } else {
                    final newId = DateTime.now().millisecondsSinceEpoch % 100000;
                    final newVenue = Venue(
                      id: newId,
                      name: nameCtrl.text.trim(),
                      type: selectedType,
                      district: selectedDist,
                      distance: '1.2km',
                      address: addressCtrl.text.trim(),
                      hours: hoursCtrl.text.trim(),
                      tags: tagsList.isNotEmpty ? tagsList : ['Sân chuẩn', 'Có đèn đêm'],
                      rating: 4.8,
                      price: priceCtrl.text.trim(),
                      lat: 21.0180,
                      lng: 105.8250,
                      image: imageCtrl.text.trim().isNotEmpty ? imageCtrl.text.trim() : _sampleImages['pickleball']![0],
                      logo: _sampleImages['pickleball']![0],
                      ownerId: _currentOwnerId,
                      ownerName: _currentOwnerName,
                      courtCount: courtCount,
                      approvalStatus: 'pending', // Yêu cầu admin duyệt
                    );
                    await FirestoreService.addVenue(newVenue);
                    setState(() => _allVenues.insert(0, newVenue));
                    _showToast('Đăng ký sân thành công! Hồ sơ đang chờ Super Admin phê duyệt.');
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                child: Text(isEdit ? 'Lưu & Gửi Duyệt' : 'Gửi Đăng Ký Sân'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteVenue(Venue v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Xác Nhận Xóa Sân', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('Bạn có chắc chắn muốn xóa "${v.name}" khỏi danh sách sân của mình?',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirestoreService.deleteVenue(v.id);
              setState(() => _allVenues.removeWhere((item) => item.id == v.id));
              Navigator.pop(ctx);
              _showToast('Đã xóa sân ${v.name}!', isError: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Xóa Sân', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        const SizedBox(height: 4),
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
            ),
          ),
        ),
      ],
    );
  }

}
