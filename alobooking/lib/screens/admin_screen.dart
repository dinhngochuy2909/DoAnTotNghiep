import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/venue_photos.dart';
import '../models/venue.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../models/news_post.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../widgets/venue_image_view.dart';
import 'package:flutter/services.dart';
import '../widgets/admin_ui.dart';
import '../services/admin_stats.dart';
import '../services/booking_slots.dart';
import '../services/booking_approval.dart';
import '../services/forecast/booking_count_service.dart';
import '../services/forecast/demand_forecast_service.dart';
import '../services/forecast/simulated_bookings.dart';
import '../services/weather/weather_service.dart';

part 'admin/admin_shell.dart';
part 'admin/admin_overview_tab.dart';
part 'admin/admin_venues_tab.dart';
part 'admin/admin_bookings_tab.dart';
part 'admin/admin_customers_tab.dart';
part 'admin/admin_payments_tab.dart';
part 'admin/admin_news_tab.dart';

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
  List<NewsPost> _news = [];
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
  List<DayWeather> _dailyWeather = [];

  /// Mô hình đếm đơn (thứ, lễ, mùa, mưa, nhiệt độ) và ngày đang mở xem chi tiết trong thẻ dự báo.
  BookingCountReport? _countReport;
  int? _forecastOpenDay;

  /// Chế độ thử với đơn MÔ PHỎNG (chỉ đưa vào mô hình dự đoán, không ghi Firestore, không tính vào số liệu khác).
  bool _useSimulated = false;
  SimulatedBookings? _sim;
  bool _countBusy = false;
  bool _showTruth = false;
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

  // Kho ảnh minh họa theo môn (đã duyệt đúng môn), xem lib/data/venue_photos.dart
  final Map<String, List<String>> _sampleImages = VenuePhotos.bySport;

  @override
  void initState() {
    super.initState();
    _selectedNavIndex = (widget.initialTabIndex >= 0 && widget.initialTabIndex < 6)
        ? widget.initialTabIndex
        : 0;
    _venues = List.from(widget.initialVenues);
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// [force]: đọc lại danh sách sân từ máy chủ (nút làm mới). Mở bảng quản trị bình thường dùng danh sách sân đã nhớ.
  Future<void> _loadData({bool force = false}) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    FirestoreService.lastLoadFailed = false;
    try {
      final results = await Future.wait<Object?>([
        FirestoreService.getVenues(forceRefresh: force),
        FirestoreService.getBookings(),
        FirestoreService.getCustomers(),
        FirestoreService.getPayments(),
        WeatherService.getCurrentWeather(),
        FirestoreService.getNews(),
      ]);
      if (!mounted) return;
      setState(() {
        final v = results[0] as List<Venue>;
        if (v.isNotEmpty) _venues = v;
        _bookings = results[1] as List<BookingItem>;
        _customers = FirestoreService.enrichCustomers(results[2] as List<CustomerItem>, _bookings);
        _payments = results[3] as List<PaymentItem>;
        if (FirestoreService.lastLoadFailed) {
          _loadError = '${FirestoreService.failureMessage()} Một số dữ liệu chưa tải được nên danh sách có thể chưa đầy đủ. Bấm làm mới để thử lại.';
        }
        _rainByDate = (results[4] as WeatherData).rainByDate;
        _dailyWeather = (results[4] as WeatherData).daily;
        _news = results[5] as List<NewsPost>;
        _sortNews();
        _lastLoaded = DateTime.now();
        _isLoading = false;
      });
      _refreshCountReport();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = FirestoreService.lastLoadFailed
            ? 'Không tải được dữ liệu. ${FirestoreService.failureMessage()}'
            : 'Không tải được dữ liệu. Kiểm tra kết nối rồi bấm làm mới.';
      });
    }
  }

  /// Huấn luyện mô hình đếm đơn sau khi tải xong dữ liệu (cần thêm thời tiết thật của các ngày đã có đơn).
  /// Chạy nền để không làm chậm bảng quản trị; lỗi thì giữ thẻ dự báo ở mức ước lượng cũ.
  Future<void> _refreshCountReport() async {
    final bookings = _bookings;
    final useSim = _useSimulated;
    if (mounted) setState(() => _countBusy = true);
    try {
      var input = bookings;
      if (useSim) {
        _sim ??= await SimulatedBookings.load();
        final sim = _sim;
        if (sim == null) {
          if (!mounted) return;
          setState(() {
            _useSimulated = false;
            _countBusy = false;
          });
          _showToast('Không đọc được dữ liệu mô phỏng.', isError: true);
          return;
        }
        input = [...bookings, ...sim.bookings];
      }
      final report = await BookingCountService.build(input);
      if (!mounted || !identical(bookings, _bookings) || useSim != _useSimulated) return;
      setState(() {
        _countReport = report;
        _countBusy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _countBusy = false);
    }
  }

  void _toggleSimulated(bool on) {
    setState(() {
      _useSimulated = on;
      _forecastOpenDay = null;
      _showTruth = false;
    });
    _refreshCountReport();
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
  static const _tabTitles = ['Tổng quan', 'Quản lý sân', 'Đơn đặt sân', 'Khách hàng', 'Thanh toán', 'Tin tức'];
  static const _tabSubtitles = [
    'Doanh thu, đơn đặt sân và dự báo nhu cầu từ dữ liệu thực',
    'Duyệt sân, cập nhật thông tin và bảng giá',
    'Theo dõi và xử lý lịch đặt của khách',
    'Hồ sơ khách hàng và hạng thành viên',
    'Giao dịch và đối soát thanh toán',
    'Đăng ưu đãi, sự kiện và thông báo hiện trong mục Khám phá của khách',
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

  DemandModel get _demandModel {
    if (_model == null || !identical(_modelFor, _bookings)) {
      _model = DemandModel.fit(_bookings);
      _modelFor = _bookings;
    }
    return _model!;
  }

  static String _dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  // ==========================================
  // TAB 5: TIN TỨC (hiện ở mục Khám phá của khách)
  // ==========================================
  static String _newsStamp(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

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
