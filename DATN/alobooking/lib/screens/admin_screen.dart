import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../widgets/venue_image_view.dart';
import 'package:flutter/services.dart';
import '../widgets/admin_ui.dart';
import '../services/admin_stats.dart';
import '../services/booking_slots.dart';
import '../services/demand_forecast_service.dart';
import '../services/weather_service.dart';

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
  String _selectedPaymentMethod = 'all'; // 'all' | 'VietQR' | 'Ví MoMo' | 'VNPay QR'

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, DayRain> _rainByDate = {};
  DateTime? _lastLoaded;
  String? _loadError;
  DemandModel? _model;
  List<BookingItem>? _modelFor;

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
    _venues = List.from(widget.initialVenues);
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    FirestoreService.lastLoadFailed = false;
    try {
      final results = await Future.wait<Object?>([
        FirestoreService.getVenues(),
        FirestoreService.getBookings(),
        FirestoreService.getCustomers(),
        FirestoreService.getPayments(),
        WeatherService.getCurrentWeather(),
      ]);
      if (!mounted) return;
      setState(() {
        final v = results[0] as List<Venue>;
        if (v.isNotEmpty) _venues = v;
        _bookings = results[1] as List<BookingItem>;
        _customers = FirestoreService.enrichCustomers(results[2] as List<CustomerItem>, _bookings);
        _payments = results[3] as List<PaymentItem>;
        if (FirestoreService.lastLoadFailed) {
          _loadError = 'Một số dữ liệu chưa tải được từ máy chủ nên danh sách có thể chưa đầy đủ. Bấm làm mới để thử lại.';
        }
        _rainByDate = (results[4] as WeatherData).rainByDate;
        _lastLoaded = DateTime.now();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Không tải được dữ liệu. Kiểm tra kết nối rồi bấm làm mới.';
      });
    }
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
  // KHUNG TRANG QUẢN TRỊ (sidebar + thanh trên), tự thu gọn theo độ rộng
  // ==========================================
  static const _tabTitles = ['Tổng quan', 'Quản lý sân', 'Đơn đặt sân', 'Khách hàng', 'Thanh toán'];
  static const _tabSubtitles = [
    'Doanh thu, đơn đặt sân và dự báo nhu cầu từ dữ liệu thực',
    'Duyệt sân, cập nhật thông tin và bảng giá',
    'Theo dõi và xử lý lịch đặt của khách',
    'Hồ sơ khách hàng và hạng thành viên',
    'Giao dịch và đối soát thanh toán',
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: AdminUi.bg,
        dividerColor: AdminUi.border,
        colorScheme: const ColorScheme.dark(
          primary: AdminUi.accent,
          secondary: AdminUi.accent,
          surface: AdminUi.surface,
        ),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Be Vietnam Pro'),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final mode = w >= 1100 ? 2 : (w >= 760 ? 1 : 0); // 2 = đầy đủ, 1 = chỉ biểu tượng, 0 = ngăn kéo
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AdminUi.bg,
          drawer: mode == 0
              ? Drawer(
                  width: 270,
                  backgroundColor: AdminUi.sidebar,
                  child: SafeArea(child: _buildSidebar(expanded: true, inDrawer: true)),
                )
              : null,
          body: Row(
            children: [
              if (mode != 0) _buildSidebar(expanded: mode == 2),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(showMenu: mode == 0, compact: w < 1000),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: AdminUi.accent, strokeWidth: 3))
                          : _buildContentArea(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── SIDEBAR ──
  Widget _buildSidebar({required bool expanded, bool inDrawer = false}) {
    final pendingVenues = _venues.where((v) => v.isPending).length;
    final pendingBookings = _bookings.where((b) => AdminStats.isPending(b.status)).length;
    final items = <(int, IconData, String, int)>[
      (0, Icons.space_dashboard_outlined, 'Tổng quan', 0),
      (1, Icons.stadium_outlined, 'Quản lý sân', pendingVenues),
      (2, Icons.event_note_outlined, 'Đơn đặt sân', pendingBookings),
      (3, Icons.people_outline_rounded, 'Khách hàng', 0),
      (4, Icons.account_balance_wallet_outlined, 'Thanh toán', 0),
    ];
    final user = AuthService.currentUser;
    final name = (user != null && user.fullName.trim().isNotEmpty) ? user.fullName.trim() : 'Quản trị viên';

    return Container(
      width: inDrawer ? null : (expanded ? 244 : 72),
      decoration: const BoxDecoration(
        color: AdminUi.sidebar,
        border: Border(right: BorderSide(color: AdminUi.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thương hiệu
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 18 : 0),
            alignment: expanded ? Alignment.centerLeft : Alignment.center,
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AdminUi.border))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: AdminUi.accent, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.sports_tennis_rounded, color: Colors.white, size: 18),
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AloBooking',
                          style: TextStyle(color: AdminUi.text, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                      Text('Quản trị hệ thống', style: AdminUi.caption),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Điều hướng
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 10, vertical: 14),
              children: [
                if (expanded)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(10, 0, 10, 8),
                    child: Text('VẬN HÀNH',
                        style: TextStyle(color: AdminUi.faint, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  ),
                for (final it in items)
                  _navItem(index: it.$1, icon: it.$2, label: it.$3, badge: it.$4, expanded: expanded, inDrawer: inDrawer),
              ],
            ),
          ),

          // Tài khoản
          Container(
            padding: EdgeInsets.all(expanded ? 12 : 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AdminUi.border))),
            child: Column(
              children: [
                _footerAction(
                  icon: Icons.smartphone_rounded,
                  label: 'Xem ứng dụng khách',
                  expanded: expanded,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
                ),
                const SizedBox(height: 4),
                _footerAction(
                  icon: Icons.logout_rounded,
                  label: 'Đăng xuất',
                  expanded: expanded,
                  color: AdminUi.danger,
                  onTap: _confirmLogoutAdmin,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    _avatar(name, 30),
                    if (expanded) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(color: AdminUi.text, fontSize: 12.5, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const Text('Quản trị viên', style: AdminUi.caption),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String name, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AdminUi.surfaceAlt, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'A',
        style: TextStyle(color: AdminUi.text, fontWeight: FontWeight.w700, fontSize: size * 0.42),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
    required int badge,
    required bool expanded,
    bool inDrawer = false,
  }) {
    final selected = _selectedNavIndex == index;
    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() => _selectedNavIndex = index);
          if (inDrawer) Navigator.pop(context);
        },
        child: Container(
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0),
          decoration: BoxDecoration(
            color: selected ? AdminUi.surfaceAlt : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: expanded
              ? Row(
                  children: [
                    Icon(icon, size: 20, color: selected ? AdminUi.accent : AdminUi.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected ? AdminUi.text : AdminUi.muted,
                          fontSize: 13.5,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (badge > 0)
                      Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(color: AdminUi.warn, borderRadius: BorderRadius.circular(10)),
                        child: Text('$badge',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF1A1200), fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                  ],
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, size: 21, color: selected ? AdminUi.accent : AdminUi.muted),
                    if (badge > 0)
                      Positioned(
                        top: 9,
                        right: 20,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AdminUi.warn, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: expanded ? tile : Tooltip(message: badge > 0 ? '$label ($badge cần xử lý)' : label, child: tile),
    );
  }

  Widget _footerAction({
    required IconData icon,
    required String label,
    required bool expanded,
    required VoidCallback onTap,
    Color color = AdminUi.muted,
  }) {
    final w = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: EdgeInsets.symmetric(horizontal: expanded ? 10 : 0),
        child: Row(
          mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            if (expanded) ...[
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500))),
            ],
          ],
        ),
      ),
    );
    return Material(color: Colors.transparent, child: expanded ? w : Tooltip(message: label, child: w));
  }

  void _confirmLogoutAdmin() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminUi.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AdminUi.border),
        ),
        title: const Text('Đăng xuất khỏi trang quản trị?',
            style: TextStyle(color: AdminUi.text, fontWeight: FontWeight.w600, fontSize: 16)),
        content: const Text('Bạn sẽ quay về màn hình đăng nhập.', style: TextStyle(color: AdminUi.muted, fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AdminUi.muted)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              AuthService.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AdminUi.danger, foregroundColor: Colors.white),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  void _confirmSync() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminUi.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AdminUi.border),
        ),
        title: const Text('Ghi dữ liệu sân lên Firestore?',
            style: TextStyle(color: AdminUi.text, fontWeight: FontWeight.w600, fontSize: 16)),
        content: Text(
          'Thao tác sẽ ghi ${_venues.length} sân đang hiển thị lên Firestore và có thể ghi đè dữ liệu hiện có. '
          'Chỉ dùng khi cần khôi phục hoặc nạp dữ liệu ban đầu.',
          style: const TextStyle(color: AdminUi.muted, fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AdminUi.muted)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _syncToFirestore();
            },
            style: FilledButton.styleFrom(backgroundColor: AdminUi.warn, foregroundColor: const Color(0xFF1A1200)),
            child: const Text('Ghi lên Firestore'),
          ),
        ],
      ),
    );
  }

  // ── THANH TRÊN ──
  Widget _buildTopBar({required bool showMenu, required bool compact}) {
    final pendingVenues = _venues.where((v) => v.isPending).length;
    final pendingBookings = _bookings.where((b) => AdminStats.isPending(b.status)).length;
    final todayD = DateTime.now();
    final todayStart = DateTime(todayD.year, todayD.month, todayD.day);
    final overdue = _bookings.where((b) {
      final d = BookingSlots.parseDate(b.date);
      return AdminStats.isPending(b.status) && d != null && d.isBefore(todayStart);
    }).length;
    final alerts = pendingVenues + pendingBookings;
    final user = AuthService.currentUser;
    final name = (user != null && user.fullName.trim().isNotEmpty) ? user.fullName.trim() : 'Quản trị viên';
    final updated = _lastLoaded == null
        ? null
        : 'Cập nhật ${_lastLoaded!.hour.toString().padLeft(2, '0')}:${_lastLoaded!.minute.toString().padLeft(2, '0')}';

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: showMenu ? 8 : 24),
      decoration: const BoxDecoration(
        color: AdminUi.bg,
        border: Border(bottom: BorderSide(color: AdminUi.border)),
      ),
      child: Row(
        children: [
          if (showMenu)
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: AdminUi.text),
              tooltip: 'Menu',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tabTitles[_selectedNavIndex],
                    style: const TextStyle(color: AdminUi.text, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (!compact)
                  Text(_tabSubtitles[_selectedNavIndex],
                      style: AdminUi.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (updated != null && !compact) Text(updated, style: AdminUi.caption),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AdminUi.muted, size: 20),
            tooltip: 'Tải lại dữ liệu',
            onPressed: _isLoading ? null : _loadData,
          ),
          PopupMenuButton<String>(
            tooltip: 'Việc cần xử lý',
            offset: const Offset(0, 46),
            color: AdminUi.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AdminUi.border),
            ),
            onSelected: (v) => setState(() {
              if (v == 'venues') {
                _selectedApprovalFilter = 'pending';
                _selectedNavIndex = 1;
              } else {
                _selectedBookingStatus = 'Chờ xác nhận';
                _selectedNavIndex = 2;
              }
            }),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                enabled: false,
                height: 36,
                child: Text('Việc cần xử lý', style: TextStyle(color: AdminUi.faint, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              if (alerts == 0)
                const PopupMenuItem(
                  enabled: false,
                  child: Text('Không có việc tồn đọng', style: TextStyle(color: AdminUi.muted, fontSize: 13)),
                ),
              if (pendingVenues > 0)
                PopupMenuItem(
                  value: 'venues',
                  child: Text('$pendingVenues sân chờ duyệt', style: const TextStyle(color: AdminUi.text, fontSize: 13)),
                ),
              if (pendingBookings > 0)
                PopupMenuItem(
                  value: 'bookings',
                  child: Text(
                    '$pendingBookings đơn chờ xác nhận${overdue > 0 ? ' ($overdue đã quá ngày chơi)' : ''}',
                    style: const TextStyle(color: AdminUi.text, fontSize: 13),
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded, color: AdminUi.muted, size: 22),
                  if (alerts > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: AdminUi.danger, borderRadius: BorderRadius.circular(8)),
                        child: Text(alerts > 99 ? '99+' : '$alerts',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            tooltip: 'Tài khoản',
            offset: const Offset(0, 46),
            color: AdminUi.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AdminUi.border),
            ),
            onSelected: (v) {
              if (v == 'logout') {
                _confirmLogoutAdmin();
              } else if (v == 'home') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
              } else if (v == 'sync') {
                _confirmSync();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: AdminUi.text, fontWeight: FontWeight.w600, fontSize: 13)),
                    if ((user?.email ?? '').isNotEmpty)
                      Text(user!.email, style: const TextStyle(color: AdminUi.muted, fontSize: 11.5)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(
                value: 'home',
                child: Text('Xem ứng dụng khách', style: TextStyle(color: AdminUi.text, fontSize: 13)),
              ),
              const PopupMenuItem(
                value: 'sync',
                child: Text('Ghi dữ liệu sân lên Firestore…', style: TextStyle(color: AdminUi.text, fontSize: 13)),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Đăng xuất', style: TextStyle(color: AdminUi.danger, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _avatar(name, 32),
                  if (!compact) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(name,
                          style: const TextStyle(color: AdminUi.text, fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const Icon(Icons.expand_more_rounded, color: AdminUi.muted, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CONTENT AREA ──
  Widget _buildContentArea() {
    switch (_selectedNavIndex) {
      case 1:
        return _minWidthScroll(_buildVenuesManagementTab());
      case 2:
        return _minWidthScroll(_buildBookingsTab());
      case 3:
        return _minWidthScroll(_buildCustomersTab());
      case 4:
        return _minWidthScroll(_buildPaymentsTab());
      default:
        return _buildAnalyticsTab();
    }
  }

  /// Các tab danh sách cần tối thiểu ~800px; màn hẹp hơn thì cuộn ngang thay vì bị tràn.
  Widget _minWidthScroll(Widget child) {
    const minW = 800.0;
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= minW) return child;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: minW, height: c.maxHeight, child: child),
      );
    });
  }

  // ==========================================
  // TAB 1: TỔNG QUAN (số liệu tính từ đơn đặt thật)
  // ==========================================
  AdminStats get _stats => AdminStats.compute(
        bookings: _bookings,
        venues: _venues,
        period: AdminPeriod.byKey(_selectedPeriod),
      );

  DemandModel get _demandModel {
    if (_model == null || !identical(_modelFor, _bookings)) {
      _model = DemandModel.fit(_bookings);
      _modelFor = _bookings;
    }
    return _model!;
  }

  static String _dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  Widget _twoCol(bool wide, Widget left, Widget right, {int l = 1, int r = 1}) {
    if (!wide) return Column(children: [left, const SizedBox(height: 16), right]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: l, child: left),
        const SizedBox(width: 16),
        Expanded(flex: r, child: right),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    final s = _stats;
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 980;
      return SingleChildScrollView(
        padding: EdgeInsets.all(c.maxWidth >= 760 ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewHeader(s),
            const SizedBox(height: 16),
            if (_loadError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: AdminUi.card(color: AdminUi.danger.withValues(alpha: 0.10), borderColor: AdminUi.danger.withValues(alpha: 0.4)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AdminUi.danger, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_loadError!, style: const TextStyle(color: AdminUi.text, fontSize: 13))),
                    TextButton(onPressed: _loadData, child: const Text('Thử lại')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildKpiRow(s),
            const SizedBox(height: 16),
            _twoCol(wide, _buildRevenueCard(s), _buildSportShareCard(s), l: 3, r: 2),
            const SizedBox(height: 16),
            _twoCol(wide, _buildSlotsCard(s), _buildTopVenuesCard(s)),
            const SizedBox(height: 16),
            _twoCol(wide, _buildForecastCard(), _buildAttentionCard(s)),
            const SizedBox(height: 16),
            Text(
              'Nguồn: ${_bookings.length} đơn đặt sân trên Firestore. Doanh thu chỉ gồm đơn đã xác nhận hoặc hoàn thành; '
              'kỳ thống kê tính theo ngày chơi. Mức thay đổi chỉ hiển thị khi kỳ trước có dữ liệu.',
              style: AdminUi.caption,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildOverviewHeader(AdminStats s) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        SegmentedTabs(
          items: [for (final p in AdminPeriod.all) (p.key, p.label)],
          selected: _selectedPeriod,
          onChanged: (k) => setState(() => _selectedPeriod = k),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_dm(s.from)} – ${_dm(s.to)}', style: AdminUi.caption),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: s.toCsv()));
                if (mounted) _showToast('Đã sao chép báo cáo CSV. Dán vào Excel hoặc Google Sheets.');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminUi.text,
                side: const BorderSide(color: AdminUi.border),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              label: const Text('Sao chép CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiRow(AdminStats s) {
    final tiles = <Widget>[
      KpiTile(
        label: 'Doanh thu',
        value: AdminStats.fmtMoney(s.revenue),
        icon: Icons.payments_outlined,
        color: AdminUi.accent,
        change: AdminStats.change(s.revenue, s.prevRevenue),
        footnote: s.hasData ? 'Chưa có kỳ trước để so sánh' : 'Chưa có đơn trong kỳ',
      ),
      KpiTile(
        label: 'Đơn đặt sân',
        value: '${s.orders}',
        icon: Icons.event_available_outlined,
        color: AdminUi.info,
        change: AdminStats.change(s.orders, s.prevOrders),
        footnote: '${s.pending} đơn đang chờ xác nhận',
      ),
      KpiTile(
        label: 'Tỷ lệ hủy',
        value: s.cancelRate == null ? '—' : '${(s.cancelRate! * 100).toStringAsFixed(1)}%',
        icon: Icons.event_busy_outlined,
        color: AdminUi.warn,
        invertGood: true,
        change: (s.cancelRate == null || s.prevCancelRate == null)
            ? null
            : AdminStats.change(s.cancelRate! * 100, s.prevCancelRate! * 100),
        footnote: '${s.cancelled} đơn hủy trong kỳ',
      ),
      KpiTile(
        label: 'Khách đặt sân',
        value: '${s.customers}',
        icon: Icons.people_outline_rounded,
        color: AdminUi.violet,
        change: AdminStats.change(s.customers, s.prevCustomers),
        footnote: s.orders == 0 ? 'Chưa có đơn trong kỳ' : 'TB ${AdminStats.fmtMoney(s.avgOrderValue)}/đơn',
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
      final w = (c.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }

  Widget _buildRevenueCard(AdminStats s) {
    final empty = s.series.every((b) => b.revenue == 0 && b.orders == 0);
    return AdminCard(
      title: 'Doanh thu theo thời gian',
      subtitle: s.period.days <= 1
          ? 'Theo giờ bắt đầu của ca đặt'
          : (s.period.days <= 31 ? 'Theo ngày chơi' : 'Theo tháng'),
      trailing: Text(AdminStats.fmtCompact(s.revenue),
          style: const TextStyle(color: AdminUi.text, fontSize: 20, fontWeight: FontWeight.w700)),
      child: empty
          ? const EmptyHint(icon: Icons.bar_chart_rounded, text: 'Chưa có đơn nào trong kỳ này.\nThử chọn kỳ dài hơn.')
          : MiniBarChart(
              values: [for (final b in s.series) b.revenue.toDouble()],
              labels: [for (final b in s.series) b.label],
              tooltips: [
                for (final b in s.series) '${b.tooltip}\n${AdminStats.fmtMoney(b.revenue)} • ${b.orders} đơn'
              ],
            ),
    );
  }

  Widget _buildSportShareCard(AdminStats s) {
    final entries = s.revenueBySport.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (a, e) => a + e.value);
    return AdminCard(
      title: 'Doanh thu theo môn',
      subtitle: 'Tỷ trọng trong kỳ',
      child: total == 0
          ? const EmptyHint(icon: Icons.donut_large_rounded, text: 'Chưa có doanh thu trong kỳ này.')
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 116,
                  height: 116,
                  child: CustomPaint(
                    painter: DonutChartPainter(
                      slices: [for (final e in entries) e.value / total],
                      colors: [for (final e in entries) AdminUi.sportColor(e.key)],
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      for (final e in entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(color: AdminUi.sportColor(e.key), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(e.key,
                                    style: const TextStyle(color: AdminUi.text, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Text('${(e.value / total * 100).round()}%',
                                  style: const TextStyle(color: AdminUi.text, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 56,
                                child: Text(AdminStats.fmtCompact(e.value),
                                    textAlign: TextAlign.right, style: AdminUi.caption),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSlotsCard(AdminStats s) {
    final maxOrders = s.slots.fold<int>(0, (a, e) => e.orders > a ? e.orders : a);
    return AdminCard(
      title: 'Khung giờ được đặt nhiều nhất',
      subtitle: 'Số đơn theo giờ bắt đầu ca',
      child: maxOrders == 0
          ? const EmptyHint(icon: Icons.schedule_rounded, text: 'Chưa có đơn nào trong kỳ này.')
          : Column(
              children: [
                for (final sl in s.slots)
                  HBarRow(
                    label: sl.label,
                    valueText: '${sl.orders} đơn',
                    ratio: sl.orders / maxOrders,
                    color: sl.orders == maxOrders ? AdminUi.warn : AdminUi.info,
                    note: sl.orders == maxOrders ? 'Cao điểm trong kỳ' : null,
                  ),
              ],
            ),
    );
  }

  Widget _buildTopVenuesCard(AdminStats s) {
    return AdminCard(
      title: 'Cụm sân doanh thu cao nhất',
      subtitle: 'Top 5 trong kỳ',
      trailing: TextButton(
        onPressed: () => setState(() => _selectedNavIndex = 1),
        child: const Text('Quản lý sân'),
      ),
      child: s.topVenues.isEmpty
          ? const EmptyHint(icon: Icons.stadium_outlined, text: 'Chưa có doanh thu trong kỳ này.')
          : Column(
              children: [
                for (var i = 0; i < s.topVenues.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AdminUi.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text('${i + 1}', style: const TextStyle(color: AdminUi.faint, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.topVenues[i].name,
                                  style: const TextStyle(color: AdminUi.text, fontSize: 13, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                '${s.topVenues[i].district != null ? '${s.topVenues[i].district} • ' : ''}${s.topVenues[i].orders} đơn',
                                style: AdminUi.caption,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(AdminStats.fmtMoney(s.topVenues[i].revenue),
                            style: const TextStyle(color: AdminUi.text, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildForecastCard() {
    final model = _demandModel;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final days = [
      for (var i = 0; i < 7; i++)
        model.forecastDay(start.add(Duration(days: i)), rain: _rainByDate[VnCalendar.key(start.add(Duration(days: i)))]),
    ];
    Color levelColor(String l) {
      switch (l) {
        case 'RẤT CAO':
        case 'CAO':
          return AdminUi.accent;
        case 'BÌNH THƯỜNG':
          return AdminUi.info;
        default:
          return AdminUi.warn;
      }
    }

    return AdminCard(
      title: 'Dự báo 7 ngày tới',
      subtitle: 'Nhu cầu và tỷ lệ hủy dự kiến (mô hình thống kê)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AdminUi.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${VnWeekday.name(days[i].date)} ${_dm(days[i].date)}',
                            style: const TextStyle(color: AdminUi.text, fontSize: 13, fontWeight: FontWeight.w500)),
                        if (days[i].holiday != null || days[i].weekend || (days[i].rain?.prob ?? 0) >= 50)
                          Text(
                            [
                              if (days[i].holiday != null) days[i].holiday!.name else if (days[i].weekend) 'Cuối tuần',
                              if ((days[i].rain?.prob ?? 0) >= 50) 'mưa ${days[i].rain!.prob.round()}%',
                            ].join(' • '),
                            style: AdminUi.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: StatusPill(days[i].level[0] + days[i].level.substring(1).toLowerCase(), levelColor(days[i].level)),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      days[i].expectedBookings == null ? '—' : '~${days[i].expectedBookings!.round()} đơn',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AdminUi.text, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('hủy ${(days[i].cancelRate * 100).round()}%',
                        textAlign: TextAlign.right, style: const TextStyle(color: AdminUi.muted, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Học từ ${model.n} đơn lịch sử. Mọi đơn mới đều chuyển khoản trước nên tỉ lệ hủy được dự báo theo nhóm trả trước. '
            'Ảnh hưởng của mưa và ngày lễ là giả định chuyên môn, chưa kiểm chứng bằng dữ liệu. '
            'Độ tin cậy: ${model.confidenceText.split(' (').first.toLowerCase()}.',
            style: AdminUi.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionCard(AdminStats s) {
    final pendingVenues = _venues.where((v) => v.isPending).length;
    final items = <(IconData, String, int, Color, VoidCallback)>[
      if (pendingVenues > 0)
        (Icons.stadium_outlined, 'Sân đang chờ duyệt', pendingVenues, AdminUi.warn, () => setState(() {
              _selectedApprovalFilter = 'pending';
              _selectedNavIndex = 1;
            })),
      if (s.pending > 0)
        (Icons.hourglass_top_rounded, 'Đơn chờ xác nhận', s.pending, AdminUi.info, () => setState(() {
              _selectedBookingStatus = 'Chờ xác nhận';
              _selectedNavIndex = 2;
            })),
      if (s.overduePending > 0)
        (Icons.warning_amber_rounded, 'Đơn chờ xác nhận đã quá ngày chơi', s.overduePending, AdminUi.danger, () => setState(() {
              _selectedBookingStatus = 'Chờ xác nhận';
              _selectedNavIndex = 2;
            })),
    ];
    final pay = s.paymentMethods.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final payTotal = pay.fold<int>(0, (a, e) => a + e.value);

    return AdminCard(
      title: 'Cần xử lý & thanh toán',
      subtitle: 'Việc tồn đọng và cách khách thanh toán trong kỳ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: AdminUi.accent, size: 18),
                  SizedBox(width: 8),
                  Text('Không có việc tồn đọng', style: TextStyle(color: AdminUi.muted, fontSize: 13)),
                ],
              ),
            )
          else
            for (final it in items)
              InkWell(
                onTap: it.$5,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(it.$1, color: it.$4, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(it.$2, style: const TextStyle(color: AdminUi.text, fontSize: 13))),
                      StatusPill('${it.$3}', it.$4),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, color: AdminUi.faint, size: 18),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AdminUi.border),
          const SizedBox(height: 10),
          const Text('Phương thức thanh toán', style: TextStyle(color: AdminUi.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          if (payTotal == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Chưa có đơn trong kỳ này.', style: AdminUi.caption),
            )
          else
            for (final e in pay.take(4))
              HBarRow(
                label: e.key,
                valueText: '${(e.value / payTotal * 100).round()}% • ${e.value} đơn',
                ratio: e.value / payTotal,
                color: AdminUi.info,
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
          color: AdminUi.surface,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AdminUi.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminUi.border.withOpacity(0.5)),
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchVenueQuery = val),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Tìm kiếm sân theo tên, quận, địa chỉ...',
                          hintStyle: TextStyle(color: AdminUi.faint, fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: AdminUi.faint, size: 18),
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
                      backgroundColor: AdminUi.accent,
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
                        color: AdminUi.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminUi.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDistrict,
                          dropdownColor: AdminUi.surface,
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
                    _approvalFilterChip('approved', 'Đã Duyệt (${_venues.where((v) => v.isApproved).length})'),
                    const SizedBox(width: 6),
                    _approvalFilterChip('rejected', 'Từ Chối (${_venues.where((v) => v.isRejected).length})'),
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
                      style: TextStyle(color: AdminUi.muted, fontSize: 14)),
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
                    colors: [AdminUi.accent, AdminUi.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [AdminUi.surfaceAlt, AdminUi.sidebar],
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AdminUi.accent
                  : AdminUi.border.withOpacity(0.6),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AdminUi.accent.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AdminUi.muted,
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
    Color activeColor = AdminUi.accent;
    Color activeColorDark = AdminUi.accent;
    if (key == 'pending') {
      activeColor = AdminUi.warn;
      activeColorDark = const Color(0xFFD97706);
    } else if (key == 'rejected') {
      activeColor = AdminUi.danger;
      activeColorDark = AdminUi.danger;
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
                    colors: [AdminUi.surfaceAlt, AdminUi.sidebar],
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? activeColor : AdminUi.border.withOpacity(0.6),
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
              color: selected ? Colors.white : AdminUi.muted,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVenueRowCard(Venue v) {
    Color statusBg = AdminUi.accent.withOpacity(0.15);
    Color statusColor = AdminUi.accent;
    String statusText = 'Đã duyệt';

    if (v.isPending) {
      statusBg = AdminUi.warn.withOpacity(0.15);
      statusColor = AdminUi.warn;
      statusText = 'Chờ duyệt';
    } else if (v.isRejected) {
      statusBg = AdminUi.danger.withOpacity(0.15);
      statusColor = AdminUi.danger;
      statusText = 'Từ chối';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminUi.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: v.isPending ? AdminUi.warn.withOpacity(0.6) : AdminUi.border.withOpacity(0.5),
          width: v.isPending ? 1.5 : 1.0,
        ),
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
                            color: AdminUi.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            v.type.toUpperCase(),
                            style: const TextStyle(
                                color: AdminUi.accent, fontSize: 10, fontWeight: FontWeight.bold),
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
                          style: const TextStyle(color: AdminUi.faint, fontSize: 11, fontFamily: 'monospace'),
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
                      style: const TextStyle(color: AdminUi.muted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(v.price,
                            style: const TextStyle(
                                color: AdminUi.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 10),
                        const Icon(Icons.access_time, size: 12, color: AdminUi.faint),
                        const SizedBox(width: 2),
                        Text(v.hours, style: const TextStyle(color: AdminUi.faint, fontSize: 11)),
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
                    icon: const Icon(Icons.edit_outlined, color: AdminUi.violet, size: 20),
                    tooltip: 'Chỉnh sửa',
                    onPressed: () => _openEditVenueDialog(v),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AdminUi.danger, size: 20),
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
                color: AdminUi.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminUi.warn.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AdminUi.warn, size: 16),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Yêu cầu đăng bài từ Chủ sân cần bạn phê duyệt:',
                      style: TextStyle(color: AdminUi.warn, fontSize: 12, fontWeight: FontWeight.w500),
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
                      backgroundColor: AdminUi.accent,
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
                      foregroundColor: AdminUi.danger,
                      side: const BorderSide(color: AdminUi.danger),
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
        backgroundColor: AdminUi.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel, color: AdminUi.danger),
            SizedBox(width: 8),
            Text('Từ Chối Bài Đăng Sân', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhập lý do từ chối để gửi phản hồi cho chủ sân "${v.name}":',
                style: const TextStyle(color: AdminUi.muted, fontSize: 13)),
            const SizedBox(height: 10),
            _dialogTextField('Lý Do Từ Chối *', reasonCtrl, 'VD: Cần cập nhật giấy phép / ảnh thực tế'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AdminUi.muted)),
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
            style: ElevatedButton.styleFrom(backgroundColor: AdminUi.danger),
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
                    color: AdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AdminUi.info.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text('Tổng Đơn Đặt', style: const TextStyle(color: AdminUi.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Icon(Icons.calendar_month_outlined, color: AdminUi.info, size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${_bookings.length}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Tất cả lịch đặt trên hệ thống', style: TextStyle(color: AdminUi.info, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AdminUi.warn.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text('Chờ Xác Nhận', style: const TextStyle(color: AdminUi.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Icon(Icons.hourglass_top_rounded, color: AdminUi.warn, size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$pendingCount', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Cần xử lý ngay', style: TextStyle(color: AdminUi.warn, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AdminUi.accent.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text('Đã Xác Nhận / Đang Đá', style: const TextStyle(color: AdminUi.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Icon(Icons.check_circle_outline, color: AdminUi.accent, size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$confirmedCount', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Lịch thi đấu sẵn sàng', style: TextStyle(color: AdminUi.accent, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AdminUi.violet.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text('Đã Hoàn Thành', style: const TextStyle(color: AdminUi.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Icon(Icons.task_alt, color: AdminUi.violet, size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$completedCount', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Đã chơi xong & thu tiền', style: TextStyle(color: AdminUi.violet, fontSize: 11)),
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
              color: AdminUi.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminUi.border.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AdminUi.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AdminUi.border.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: AdminUi.faint, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: (val) => setState(() => _searchBookingQuery = val),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Tìm theo mã đơn (BK-...), tên khách, SĐT, tên sân...',
                                  hintStyle: TextStyle(color: AdminUi.faint, fontSize: 13),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            if (_searchBookingQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(() => _searchBookingQuery = ''),
                                child: const Icon(Icons.close, color: AdminUi.muted, size: 16),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _openAddWalkinBookingDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminUi.accent,
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
                  Icon(Icons.event_busy, color: AdminUi.faint, size: 48),
                  SizedBox(height: 12),
                  Text('Không tìm thấy lịch đặt sân phù hợp', style: TextStyle(color: AdminUi.muted, fontSize: 14)),
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
    Color statusColor = AdminUi.warn;
    if (b.status == 'Đã xác nhận') statusColor = AdminUi.accent;
    if (b.status == 'Hoàn thành') statusColor = AdminUi.violet;
    if (b.status == 'Đã hủy') statusColor = AdminUi.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminUi.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminUi.border.withOpacity(0.5)),
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
                        color: AdminUi.violet, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
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
                style: const TextStyle(color: AdminUi.accent, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person, color: AdminUi.muted, size: 14),
              const SizedBox(width: 4),
              Text(b.customer,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 12),
              const Icon(Icons.phone, color: AdminUi.muted, size: 14),
              const SizedBox(width: 4),
              Text(b.phone, style: const TextStyle(color: AdminUi.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.sports_tennis, color: AdminUi.muted, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text('${b.venueName} (${b.field})',
                    style: const TextStyle(color: AdminUi.muted, fontSize: 12),
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
                  const Icon(Icons.access_time, color: AdminUi.muted, size: 14),
                  const SizedBox(width: 4),
                  Text('${b.time} • ${b.date}',
                      style: const TextStyle(color: AdminUi.muted, fontSize: 12)),
                ],
              ),
              // Action buttons (Approve, Complete, Cancel)
              Row(
                children: [
                  if (b.status == 'Chờ xác nhận') ...[
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: AdminUi.accent, size: 22),
                      tooltip: 'Xác nhận đơn',
                      onPressed: () async {
                        await FirestoreService.confirmBooking(b.id);
                        setState(() {
                          b.status = 'Đã xác nhận';
                          for (final p in _payments) {
                            if (p.bookingId == b.id && p.status.toLowerCase().contains('xử lý')) p.status = 'Thành công';
                          }
                        });
                        _showToast('Đã xác nhận đơn ${b.id} và đối soát tiền chuyển khoản!');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: AdminUi.danger, size: 22),
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
                      icon: const Icon(Icons.done_all, color: AdminUi.violet, size: 22),
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
                    color: AdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AdminUi.info.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text('Tổng Khách Hàng', style: const TextStyle(color: AdminUi.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Icon(Icons.people_outline, color: AdminUi.info, size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${_customers.length}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Đã đồng bộ cơ sở dữ liệu', style: TextStyle(color: AdminUi.info, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AdminUi.warn.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text('Hội Viên VIP', style: const TextStyle(color: AdminUi.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Icon(Icons.workspace_premium, color: AdminUi.warn, size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$vipCount', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Vàng & Kim Cương', style: TextStyle(color: AdminUi.warn, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AdminUi.accent.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text('Đang Hoạt Động', style: const TextStyle(color: AdminUi.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Icon(Icons.check_circle_outline, color: AdminUi.accent, size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$activeCount', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Tài khoản khả dụng', style: TextStyle(color: AdminUi.accent, fontSize: 11)),
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
              color: AdminUi.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminUi.border.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AdminUi.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AdminUi.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: AdminUi.muted, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: (val) => setState(() => _searchCustomerQuery = val),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Tìm theo tên, số điện thoại, email...',
                                  hintStyle: TextStyle(color: AdminUi.faint, fontSize: 13),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            if (_searchCustomerQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(() => _searchCustomerQuery = ''),
                                child: const Icon(Icons.close, color: AdminUi.muted, size: 16),
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
                        backgroundColor: AdminUi.accent,
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
                  Icon(Icons.person_search, color: AdminUi.faint, size: 48),
                  SizedBox(height: 12),
                  Text('Không tìm thấy khách hàng phù hợp', style: TextStyle(color: AdminUi.muted, fontSize: 14)),
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
                if (c.rank.contains('Kim Cương')) rankColor = AdminUi.info;
                else if (c.rank.contains('Vàng')) rankColor = AdminUi.warn;
                else if (c.rank.contains('Bạc')) rankColor = AdminUi.muted;

                final isLocked = c.status == 'Tạm khóa';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isLocked ? AdminUi.danger.withOpacity(0.3) : AdminUi.border.withOpacity(0.5)),
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
                                      color: AdminUi.danger.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Tạm khóa', style: TextStyle(color: AdminUi.danger, fontSize: 10, fontWeight: FontWeight.bold)),
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
                                    const Icon(Icons.phone_outlined, color: AdminUi.faint, size: 13),
                                    const SizedBox(width: 4),
                                    Text(c.phone, style: const TextStyle(color: AdminUi.muted, fontSize: 12)),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.email_outlined, color: AdminUi.faint, size: 13),
                                    const SizedBox(width: 4),
                                    Text(c.email, style: const TextStyle(color: AdminUi.muted, fontSize: 12)),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.sports, color: AdminUi.faint, size: 13),
                                    const SizedBox(width: 4),
                                    Text('Môn: ${c.favoriteSport}', style: const TextStyle(color: AdminUi.muted, fontSize: 12)),
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
                              style: const TextStyle(color: AdminUi.accent, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${c.bookingsCount} lượt đặt',
                              style: const TextStyle(color: AdminUi.muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),

                      // Nút hành động
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: AdminUi.muted, size: 20),
                        color: AdminUi.surface,
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
                                Icon(Icons.edit, color: AdminUi.info, size: 16),
                                SizedBox(width: 8),
                                Text('Chỉnh sửa', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle_status',
                            child: Row(
                              children: [
                                Icon(isLocked ? Icons.lock_open : Icons.lock_outline, color: AdminUi.warn, size: 16),
                                SizedBox(width: 8),
                                Text(isLocked ? 'Mở khóa tài khoản' : 'Tạm khóa tài khoản', style: const TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: AdminUi.danger, size: 16),
                                SizedBox(width: 8),
                                Text('Xóa khách', style: TextStyle(color: AdminUi.danger, fontSize: 13)),
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
  Widget _buildPaymentKpis() {
    int total = 0, online = 0, awaiting = 0, okCount = 0, processing = 0, refunded = 0;
    for (final p in _payments) {
      final st = p.status.toLowerCase();
      if (st.contains('hoàn')) {
        refunded++;
        continue;
      }
      if (st.contains('xử lý')) {
        processing++;
        awaiting += AdminStats.parseMoney(p.amount);
        continue;
      }
      final amt = AdminStats.parseMoney(p.amount);
      total += amt;
      okCount++;
      // Giao dịch tiền mặt cũ (nếu còn trong dữ liệu) vẫn nằm trong tổng đã thu, nhưng không tính vào chuyển khoản
      if (!p.method.toLowerCase().contains('tiền mặt')) online += amt;
    }
    String share(int v) => total == 0 ? 'Chưa có giao dịch thành công' : '${(v / total * 100).toStringAsFixed(1)}% tổng đã thu';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: KpiTile(
            label: 'Tổng đã thu',
            value: AdminStats.fmtMoney(total),
            icon: Icons.account_balance_wallet_outlined,
            color: AdminUi.accent,
            footnote: '$okCount thành công • $processing đang xử lý • $refunded hoàn tiền',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiTile(
            label: 'Đã nhận qua chuyển khoản / ví',
            value: AdminStats.fmtMoney(online),
            icon: Icons.qr_code_2_rounded,
            color: AdminUi.info,
            footnote: share(online),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiTile(
            label: 'Chờ đối soát chuyển khoản',
            value: AdminStats.fmtMoney(awaiting),
            icon: Icons.hourglass_top_rounded,
            color: AdminUi.warn,
            footnote: processing == 0 ? 'Không có giao dịch chờ' : '$processing giao dịch chờ xác nhận đã nhận tiền',
          ),
        ),
      ],
    );
  }

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
          // 1. TỔNG QUAN THU NGÂN (tính từ giao dịch thật)
          _buildPaymentKpis(),
          const SizedBox(height: 16),

          // 2. SEARCH & FILTER
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AdminUi.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminUi.border.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AdminUi.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AdminUi.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: AdminUi.muted, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: (val) => setState(() => _searchPaymentQuery = val),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Tìm theo mã PAY, mã đơn BK, khách, mã ngân hàng...',
                                  hintStyle: TextStyle(color: AdminUi.faint, fontSize: 13),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            if (_searchPaymentQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(() => _searchPaymentQuery = ''),
                                child: const Icon(Icons.close, color: AdminUi.muted, size: 16),
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
                        backgroundColor: AdminUi.accent,
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
                      _buildGenericChip('Chuyển khoản', 'VietQR', _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v)),
                      const SizedBox(width: 6),
                      _buildGenericChip('Ví MoMo', 'MoMo', _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v)),
                      const SizedBox(width: 6),
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
                  Icon(Icons.credit_card_off, color: AdminUi.faint, size: 48),
                  SizedBox(height: 12),
                  Text('Không tìm thấy giao dịch nào', style: TextStyle(color: AdminUi.muted, fontSize: 14)),
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

                Color statusColor = AdminUi.accent; // Success
                if (p.status == 'Đang xử lý') statusColor = AdminUi.warn;
                else if (p.status == 'Đã hoàn tiền') statusColor = AdminUi.danger;

                IconData methodIcon = Icons.qr_code;
                if (p.method.contains('MoMo')) methodIcon = Icons.account_balance_wallet_outlined;
                else if (p.method.contains('Tiền mặt')) methodIcon = Icons.payments_outlined;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AdminUi.border.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      // Method icon badge
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AdminUi.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AdminUi.border),
                        ),
                        child: Icon(methodIcon, color: AdminUi.info, size: 20),
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
                                  style: const TextStyle(color: AdminUi.info, fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AdminUi.border,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('Đơn ${p.bookingId}', style: const TextStyle(color: AdminUi.muted, fontSize: 10.5)),
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
                              style: const TextStyle(color: AdminUi.faint, fontSize: 11),
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
                            style: const TextStyle(color: AdminUi.accent, fontWeight: FontWeight.bold, fontSize: 15),
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
                        icon: const Icon(Icons.more_vert, color: AdminUi.muted, size: 20),
                        color: AdminUi.surface,
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
                                Icon(Icons.receipt_outlined, color: AdminUi.info, size: 16),
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
                                  Icon(Icons.check_circle, color: AdminUi.accent, size: 16),
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
                                  Icon(Icons.replay, color: AdminUi.danger, size: 16),
                                  SizedBox(width: 8),
                                  Text('Hoàn tiền giao dịch', style: TextStyle(color: AdminUi.danger, fontSize: 13)),
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
                    colors: [AdminUi.accent, AdminUi.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [AdminUi.surfaceAlt, AdminUi.sidebar],
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AdminUi.accent
                  : AdminUi.border.withOpacity(0.6),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AdminUi.accent.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AdminUi.muted,
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
            backgroundColor: AdminUi.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(isEdit ? Icons.edit : Icons.person_add, color: AdminUi.accent),
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
                              const Text('Môn Yêu Thích', style: TextStyle(color: AdminUi.muted, fontSize: 12)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AdminUi.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AdminUi.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedSport,
                                    isExpanded: true,
                                    dropdownColor: AdminUi.bg,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(value: 'Pickleball', child: Text('Pickleball')),
                                      DropdownMenuItem(value: 'Cầu lông', child: Text('Cầu lông')),
                                      DropdownMenuItem(value: 'Bóng đá', child: Text('Bóng đá')),
                                      DropdownMenuItem(value: 'Tennis', child: Text('Tennis')),
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
                              const Text('Hạng Hội Viên', style: TextStyle(color: AdminUi.muted, fontSize: 12)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AdminUi.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AdminUi.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedRank,
                                    isExpanded: true,
                                    dropdownColor: AdminUi.bg,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(value: 'VIP Kim Cương', child: Text('VIP Kim Cương')),
                                      DropdownMenuItem(value: 'VIP Vàng', child: Text('VIP Vàng')),
                                      DropdownMenuItem(value: 'Bạc', child: Text('Bạc')),
                                      DropdownMenuItem(value: 'Đồng', child: Text('Đồng')),
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
                child: const Text('Hủy', style: TextStyle(color: AdminUi.muted)),
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
                  backgroundColor: AdminUi.accent,
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
    final bkCtrl = TextEditingController();
    final custCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    String selectedMethod = 'VietQR Pro';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          return AlertDialog(
            backgroundColor: AdminUi.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.add_card, color: AdminUi.accent),
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
                    _dialogTextField('Mã Đơn Đặt Sân *', bkCtrl, 'VD: BK-123456'),
                    const SizedBox(height: 12),
                    _dialogTextField('Tên Khách Hàng *', custCtrl, 'VD: Trần Văn B'),
                    const SizedBox(height: 12),
                    _dialogTextField('Số Tiền Đã Nhận *', amountCtrl, 'VD: 300.000đ'),
                    const SizedBox(height: 12),
                    _dialogTextField('Mã Giao Dịch Ngân Hàng', refCtrl, 'Mã tham chiếu trên sao kê'),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Phương Thức Thanh Toán', style: TextStyle(color: AdminUi.muted, fontSize: 12)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AdminUi.bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AdminUi.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedMethod,
                              isExpanded: true,
                              dropdownColor: AdminUi.bg,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: const [
                                DropdownMenuItem(value: 'VietQR Pro', child: Text('Chuyển khoản ngân hàng (VietQR)')),
                                DropdownMenuItem(value: 'Ví MoMo', child: Text('Ví MoMo')),
                                DropdownMenuItem(value: 'VNPay QR', child: Text('VNPay QR')),
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
                child: const Text('Hủy', style: TextStyle(color: AdminUi.muted)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (bkCtrl.text.trim().isEmpty || custCtrl.text.trim().isEmpty || AdminStats.parseMoney(amountCtrl.text) <= 0) {
                    _showToast('Nhập mã đơn, tên khách và số tiền đã nhận!', isError: true);
                    return;
                  }
                  final now = DateTime.now();
                  final newPay = PaymentItem(
                    id: 'PAY-${now.millisecondsSinceEpoch.toString().substring(7)}',
                    bookingId: bkCtrl.text.trim(),
                    customer: custCtrl.text.trim(),
                    amount: amountCtrl.text.trim(),
                    method: selectedMethod,
                    time: '${BookingSlots.formatDate(now)} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                    status: 'Thành công',
                    bankRef: refCtrl.text.trim(),
                  );
                  setState(() => _payments.insert(0, newPay));
                  FirestoreService.addPayment(newPay);
                  _showToast('Đã ghi nhận thanh toán ${newPay.id} thành công!');
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminUi.accent,
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
        backgroundColor: AdminUi.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.receipt, color: AdminUi.info),
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
                  color: AdminUi.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminUi.border),
                ),
                child: Column(
                  children: [
                    const Text('ALOBOOKING - XÁC NHẬN THANH TOÁN', style: TextStyle(color: AdminUi.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 12),
                    Text(p.amount, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(p.status, style: const TextStyle(color: AdminUi.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                    const Divider(color: AdminUi.border, height: 24),
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
            child: const Text('Đóng', style: TextStyle(color: AdminUi.muted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showToast('Đang gửi biên lai điện tử cho khách hàng...');
            },
            icon: const Icon(Icons.print, size: 16),
            label: const Text('In / Gửi Biên Lai'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminUi.info,
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
          Text(label, style: const TextStyle(color: AdminUi.muted, fontSize: 12)),
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
    final courtsCtrl = TextEditingController(text: (existing?.courts ?? Venue.defaultCourtCount(selectedType)).toString());
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
            backgroundColor: AdminUi.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(isEdit ? Icons.edit : Icons.add_circle, color: AdminUi.accent),
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
                                  style: TextStyle(color: AdminUi.muted, fontSize: 12)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AdminUi.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AdminUi.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedType,
                                    isExpanded: true,
                                    dropdownColor: AdminUi.surface,
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
                                        if (!isEdit) courtsCtrl.text = Venue.defaultCourtCount(selectedType).toString();
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
                                  style: TextStyle(color: AdminUi.muted, fontSize: 12)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AdminUi.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AdminUi.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedDist,
                                    isExpanded: true,
                                    dropdownColor: AdminUi.surface,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: {..._districts, selectedDist}
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
                    _dialogTextField('Số Sân Con Trong Cụm (1–30)', courtsCtrl, 'VD: 8'),
                    const SizedBox(height: 12),
                    _dialogTextField('Tiện Ích & Tags', tagsCtrl, 'Mái che cao, Đèn LED, Thảm Yonex'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('URL Hình Ảnh Sân Thể Thao',
                            style: TextStyle(color: AdminUi.muted, fontSize: 12)),
                        TextButton(
                          onPressed: () {
                            final list = _sampleImages[selectedType] ?? _sampleImages['pickleball']!;
                            final next = list[math.Random().nextInt(list.length)];
                            setDialogState(() => imageCtrl.text = next);
                          },
                          child: const Text('Chọn ảnh mẫu đẹp',
                              style: TextStyle(color: AdminUi.accent, fontSize: 11)),
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
                child: const Text('Hủy', style: TextStyle(color: AdminUi.muted)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty || addressCtrl.text.trim().isEmpty) {
                    _showToast('Vui lòng điền tên sân và địa chỉ!', isError: true);
                    return;
                  }

                  final tags = tagsCtrl.text.split(',').map((t) => t.trim()).filter((t) => t.isNotEmpty).toList();
                  final courtCount = (int.tryParse(courtsCtrl.text.trim()) ?? Venue.defaultCourtCount(selectedType)).clamp(1, 30);

                  if (isEdit) {
                    // copyWith giữ nguyên chủ sân, trạng thái duyệt và các trường khác của sân
                    final updated = existing.copyWith(
                      name: nameCtrl.text.trim(),
                      type: selectedType,
                      district: selectedDist,
                      address: addressCtrl.text.trim(),
                      hours: hoursCtrl.text.trim(),
                      tags: tags.isNotEmpty ? tags : ['Đơn ngày'],
                      rating: double.tryParse(ratingCtrl.text) ?? existing.rating,
                      price: priceCtrl.text.trim(),
                      lat: lat,
                      lng: lng,
                      image: imageCtrl.text.trim(),
                      courtCount: courtCount,
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
                      courtCount: courtCount,
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
                  backgroundColor: AdminUi.accent,
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
          Text(label, style: const TextStyle(color: AdminUi.muted, fontSize: 12)),
          const SizedBox(height: 4),
        ],
        Container(
          decoration: BoxDecoration(
            color: AdminUi.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminUi.border),
          ),
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AdminUi.faint, fontSize: 12),
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
        backgroundColor: AdminUi.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AdminUi.danger),
            SizedBox(width: 8),
            Text('Xác Nhận Xóa Sân', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa sân "${v.name}" (#${v.id}) khỏi hệ thống?\nHành động này không thể hoàn tác.',
          style: const TextStyle(color: AdminUi.muted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AdminUi.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirestoreService.deleteVenue(v.id);
              setState(() => _venues.removeWhere((x) => x.id == v.id));
              Navigator.pop(ctx);
              _showToast('Đã xóa sân "${v.name}" thành công!', isError: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminUi.danger,
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
        backgroundColor: AdminUi.surface,
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
                            style: const TextStyle(color: AdminUi.accent, fontWeight: FontWeight.bold, fontSize: 11)),
                        Row(
                          children: [
                            const Icon(Icons.star, color: AdminUi.warn, size: 14),
                            Text(' ${v.rating} / 5.0', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(v.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 4),
                    Text(v.address, style: const TextStyle(color: AdminUi.muted, fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: AdminUi.faint, size: 14),
                        const SizedBox(width: 4),
                        Text(v.hours, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 16),
                        const Icon(Icons.payments_outlined, color: AdminUi.accent, size: 14),
                        const SizedBox(width: 4),
                        Text(v.price, style: const TextStyle(color: AdminUi.accent, fontWeight: FontWeight.bold, fontSize: 12)),
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
                            color: AdminUi.bg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AdminUi.border),
                          ),
                          child: Text('$t', style: const TextStyle(color: AdminUi.muted, fontSize: 11)),
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
            child: const Text('Đóng', style: TextStyle(color: AdminUi.muted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _openEditVenueDialog(v);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminUi.accent),
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
    String venueName = _venues.isNotEmpty ? _venues[0].name : '';
    final amountCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: BookingSlots.formatDate(DateTime.now()));
    final courtCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminUi.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đặt Sân Hộ Khách (đã nhận chuyển khoản)', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogTextField('Tên Khách Hàng *', custCtrl, 'Nguyễn Văn A'),
              const SizedBox(height: 10),
              _dialogTextField('Số Điện Thoại *', phoneCtrl, '0901234567'),
              const SizedBox(height: 10),
              _dialogTextField('Ngày Đặt (dd/MM/yyyy)', dateCtrl, '17/11/2026'),
              const SizedBox(height: 10),
              _dialogTextField('Khung Giờ *', timeCtrl, '18:00 - 19:00'),
              const SizedBox(height: 10),
              _dialogTextField('Sân Số', courtCtrl, '1'),
              const SizedBox(height: 10),
              _dialogTextField('Tổng Tiền Đã Chuyển Khoản *', amountCtrl, '200.000 đ'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AdminUi.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (custCtrl.text.trim().isEmpty ||
                  phoneCtrl.text.trim().isEmpty ||
                  timeCtrl.text.trim().isEmpty ||
                  venueName.isEmpty ||
                  AdminStats.parseMoney(amountCtrl.text) <= 0 ||
                  BookingSlots.parseDate(dateCtrl.text) == null ||
                  BookingSlots.parseRanges(timeCtrl.text).isEmpty) {
                _showToast('Nhập đủ tên, số điện thoại, ngày (dd/MM/yyyy), khung giờ (18:00 - 19:00) và số tiền!', isError: true);
                return;
              }
              final venue = _venues.firstWhere((v) => v.name == venueName);
              final courtNo = (int.tryParse(courtCtrl.text.trim()) ?? 1).clamp(1, venue.courts);
              final fieldName = '${Venue.courtLabel(venue.type)} $courtNo';
              final bookingId = 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
              final newBooking = BookingItem(
                id: bookingId,
                customer: custCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                venueName: venueName,
                field: fieldName,
                time: timeCtrl.text.trim(),
                date: dateCtrl.text.trim(),
                amount: amountCtrl.text.trim(),
                status: 'Đã xác nhận',
                paymentMethod: 'Chuyển khoản VietQR',
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
                ownerId: _venues.where((v) => v.name == newBooking.venueName).map((v) => v.ownerId).firstOrNull ?? 'admin_super_01',
                status: 'Đã xác nhận', // quản trị viên chỉ tạo đơn này sau khi đã nhận chuyển khoản
                paid: true,
              );
              setState(() => _bookings.insert(0, newBooking));
              Navigator.pop(ctx);
              _showToast('Đã tạo đơn đặt sân tại quầy $bookingId thành công!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminUi.accent),
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
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.colors != colors;
}

extension _IterableExt<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T) test) => where(test);
}
