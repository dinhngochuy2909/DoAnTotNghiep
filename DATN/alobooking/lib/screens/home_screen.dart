import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/admin_stats.dart';
import '../widgets/app_footer.dart';
import 'login_screen.dart';
import 'booked_screen.dart';
import 'favorites_screen.dart';
import 'map_screen.dart';
import 'explore_screen.dart';
import 'featured_screen.dart';
import 'admin_screen.dart';
import 'owner_screen.dart';
import 'venue_detail_screen.dart';
import 'visual_booking_screen.dart';
import 'account_screen.dart';
import '../widgets/venue_image_view.dart';
import '../services/image_picker_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Venue> _allVenues = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _currentNavIndex = 0;
  final Set<int> _favorites = {};
  String _selectedType = 'all'; // 'all' | 'badminton' | 'pickleball' | 'football' | 'tennis'

  // ─── PHÂN QUYỀN VÀ TRẠNG THÁI QUẢN TRỊ ───
  bool get _isAdmin => AuthService.isAdmin;
  bool get _isOwner => AuthService.isOwner;
  bool _isSidebarExpanded = true;
  String _adminCourtSearch = '';
  bool _showOnlyMyVenues = false;

  bool _isMyVenue(Venue venue) {
    if (_isAdmin) return true;
    if (!_isOwner) return false;
    final myUid = AuthService.currentUser?.uid ?? '';
    return venue.ownerId == myUid ||
        venue.district == 'Đống Đa' ||
        venue.name.contains('Đống Đa');
  }

  final List<String> _districts = [
    'Cầu Giấy', 'Đống Đa', 'Ba Đình', 'Hoàn Kiếm', 'Hai Bà Trưng',
    'Thanh Xuân', 'Tây Hồ', 'Nam Từ Liêm', 'Bắc Từ Liêm', 'Hà Đông',
    'Hoàng Mai', 'Long Biên', 'Gia Lâm', 'Đông Anh', 'Thanh Trì', 'Hoài Đức'
  ];

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
    _loadVenues();
  }

  Future<void> _loadVenues() async {
    setState(() => _isLoading = true);
    FirestoreService.lastLoadFailed = false;
    final venues = await FirestoreService.getVenues();
    if (!mounted) return;
    setState(() {
      _allVenues = venues;
      _isLoading = false;
    });
    if (venues.isEmpty && FirestoreService.lastLoadFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Không tải được danh sách sân. Kiểm tra kết nối mạng rồi thử lại.'),
          action: SnackBarAction(label: 'Thử lại', onPressed: _loadVenues),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  String _vietnameseDate() {
    final now = DateTime.now();
    const days = ['Chủ nhật', 'Thứ hai', 'Thứ ba', 'Thứ tư', 'Thứ năm', 'Thứ sáu', 'Thứ bảy'];
    final day = days[now.weekday % 7];
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    return '$day, $dd/$mm/${now.year}';
  }

  List<Venue> get _filteredVenues {
    var list = _allVenues;
    // Nếu Chủ Sân bật bộ lọc "Sân của tôi"
    if (_showOnlyMyVenues && _isOwner) {
      list = list.where((v) => _isMyVenue(v)).toList();
    } else if (!_isAdmin) {
      // Khách hàng thông thường chỉ nhìn thấy sân đã được Admin phê duyệt (Chủ sân thấy thêm sân của mình để quản lý)
      list = list.where((v) =>
          v.isApproved ||
          (_isOwner && _isMyVenue(v))).toList();
    }
    if (_selectedType != 'all') {
      list = list.where((v) => v.type == _selectedType).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((v) {
        return v.name.toLowerCase().contains(q) ||
            v.address.toLowerCase().contains(q) ||
            v.district.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  void _openBooking(Venue venue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisualBookingScreen(venue: venue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 850;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light background like screenshot
      drawer: (!isDesktop && _isAdmin)
          ? Drawer(
              width: 320,
              backgroundColor: const Color(0xFF0F172A),
              child: _buildAdminLeftSidebarContent(isDrawer: true),
            )
          : null,
      floatingActionButton: _isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _showVenueDialog(null),
              backgroundColor: const Color(0xFF16A34A),
              elevation: 4,
              icon: const Icon(Icons.add_circle, color: Colors.white, size: 20),
              label: const Text(
                'Đăng Sân Mới',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── 1. PHẦN QUẢN TRỊ RIÊNG (CHỈ SUPER ADMIN TRÊN DESKTOP) ───
                if (_isAdmin && isDesktop)
                  _buildAdminLeftSidebar(),

                // ─── 2. GIAO DIỆN KHÁCH HÀNG 100% Y HỆT (TOÀN BỘ MÀN HÌNH CHO NGƯỜI DÙNG & CHỦ SÂN) ───
                Expanded(
                  child: Column(
                    children: [
                      // ===== 1. TOP EMERALD GREEN HEADER =====
                      _buildTopHeader(),

                      // ===== 2. WHITE FLOATING SEARCH & QUICK ACTIONS BAR =====
                      _buildSearchAndQuickActionBar(),

                      // ===== 2.5 BANNER QUẢN LÝ SÂN CỦA TÔI NỔI BẬT RA NGOÀI =====
                      if (_isOwner)
                        _buildOwnerQuickManagementBanner(),

                      // ===== 2.6 CATEGORY CHIPS & MY VENUES TOGGLE =====
                      _buildCategoryChipsRow(),

                      const SizedBox(height: 6),

                      // ===== 3. VENUE CARDS GRID + FOOTER =====
                      Expanded(
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(color: Color(0xFF16A34A)),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  int crossAxisCount = 3;
                                  if (constraints.maxWidth < 650) {
                                    crossAxisCount = 1;
                                  } else if (constraints.maxWidth < 950) {
                                    crossAxisCount = 2;
                                  }
                                  final double aspectRatio = crossAxisCount == 1
                                      ? (_isOwner ? 0.94 : 1.02)
                                      : (_isOwner ? 1.15 : 1.25);

                                  return CustomScrollView(
                                    slivers: [
                                      SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                                        sliver: SliverGrid(
                                          delegate: SliverChildBuilderDelegate(
                                            (ctx, idx) => _buildVenueCard(_filteredVenues[idx]),
                                            childCount: _filteredVenues.length,
                                          ),
                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: crossAxisCount,
                                            crossAxisSpacing: 14,
                                            mainAxisSpacing: 14,
                                            childAspectRatio: aspectRatio,
                                          ),
                                        ),
                                      ),
                                      // ===== FOOTER =====
                                      const SliverToBoxAdapter(
                                        child: AppFooter(),
                                      ),
                                    ],
                                  );
                                },
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
      bottomNavigationBar: (_isAdmin && isDesktop) ? null : _buildBottomNav(),
    );
  }

  // ==========================================
  // 1. TOP HEADER (Green Banner)
  // ==========================================
  Widget _buildTopHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 750;

    // Giao diện Header riêng biệt tối ưu cho Điện Thoại
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Color(0xFF15803D),
          gradient: LinearGradient(
            colors: [Color(0xFF15803D), Color(0xFF16A34A), Color(0xFF047857)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Cụm Logo + Tên Ứng dụng + Lời chào
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF166534),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.sports_tennis, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'AloBooking',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            AuthService.isGuest
                                ? 'Khách'
                                : (_isOwner ? 'Chủ Sân' : (_isAdmin ? 'Admin' : 'Thành viên')),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      AuthService.currentUser?.fullName ?? 'Khách xem sân',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),

            // Nút hành động nhanh bên phải
            Row(
              children: [
                if (AuthService.isGuest)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    icon: const Icon(Icons.login, color: Color(0xFF15803D), size: 14),
                    label: const Text(
                      'Đăng nhập',
                      style: TextStyle(
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF15803D),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  )
                else if (_isOwner)
                  ElevatedButton.icon(
                    onPressed: () => _showVenueDialog(null),
                    icon: const Icon(Icons.add, color: Color(0xFF15803D), size: 15),
                    label: const Text(
                      'Thêm sân',
                      style: TextStyle(
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF08A),
                      foregroundColor: const Color(0xFF15803D),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  )
                else if (_isAdmin)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AdminScreen(initialVenues: _allVenues)),
                      );
                    },
                    icon: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 14),
                    label: const Text(
                      'Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),

                const SizedBox(width: 8),

                // Biểu tượng chuông thông báo
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🔔 Bạn không có thông báo mới.')),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_none, color: Colors.white, size: 19),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFF15803D), // Deep emerald green matching screenshot
        gradient: LinearGradient(
          colors: [Color(0xFF15803D), Color(0xFF16A34A), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Logo + Greeting Info
          Row(
            children: [
              // Circular green logo with white stylised icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF166534),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: const Center(
                  child: Icon(Icons.sports_tennis, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _vietnameseDate(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AuthService.currentUser?.fullName ?? 'Khách vãng lai',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right: Admin Portal Button, Chat icon, Vietnam Flag, Notification bell
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
              // Huy hiệu Quản trị viên (Chỉ hiển thị cho tài khoản Quản trị)
              if (_isAdmin) ...[
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminScreen(initialVenues: _allVenues),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Quản Trị Viên 👑',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // NÚT THÊM SÂN MỚI NỔI BẬT NHẤT TRÊN HEADER DÀNH CHO CHỦ SÂN
              if (_isOwner) ...[
                ElevatedButton.icon(
                  onPressed: () => _showVenueDialog(null),
                  icon: const Icon(Icons.add_circle, color: Color(0xFF15803D), size: 18),
                  label: const Text(
                    '+ THÊM SÂN MỚI',
                    style: TextStyle(
                      color: Color(0xFF15803D),
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF08A), // Bright golden yellow
                    foregroundColor: const Color(0xFF15803D),
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Nút Đăng nhập / Đăng ký & Huy hiệu Khách Xem Sân (Chỉ hiển thị cho Khách vãng lai / chưa đăng nhập)
              if (AuthService.isGuest) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  icon: const Icon(Icons.login, color: Color(0xFF15803D), size: 16),
                  label: const Text(
                    'ĐĂNG NHẬP / ĐĂNG KÝ',
                    style: TextStyle(
                      color: Color(0xFF15803D),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF15803D),
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // NÚT QUẢN LÝ SÂN CỦA TÔI NỔI BẬT TRÊN HEADER
              if (_isOwner) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OwnerScreen(initialVenues: _allVenues, initialTabIndex: 0),
                      ),
                    );
                  },
                  icon: const Icon(Icons.dashboard_customize, color: Colors.white, size: 16),
                  label: Text(
                    'QUẢN LÝ SÂN CỦA TÔI (${_allVenues.where(_isMyVenue).length}) ↗',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Huy hiệu Chủ Sân Đối Tác (Chỉ hiển thị cho tài khoản Chủ Sân)
              if (_isOwner) ...[
                InkWell(
                  onTap: () {
                    setState(() {
                      _showOnlyMyVenues = !_showOnlyMyVenues;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _showOnlyMyVenues ? const Color(0xFF15803D) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_alt_outlined, color: Colors.white, size: 15),
                        const SizedBox(width: 4),
                        Text(
                          _showOnlyMyVenues ? 'Đang lọc sân của tôi' : 'Lọc sân của tôi',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OwnerScreen(initialVenues: _allVenues, initialTabIndex: 1),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insights, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Doanh Thu 📊',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // Chat icon
              _buildHeaderIcon(Icons.chat_bubble_outline),
              const SizedBox(width: 10),

              // Vietnam Flag Badge (Red circle with yellow star)
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFDA251D), // Vietnam Flag Red
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.star, color: Color(0xFFFFDE00), size: 18),
                ),
              ),
              const SizedBox(width: 10),

              // Notification bell
              _buildHeaderIcon(Icons.notifications_none),
            ],
          ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  // ==========================================
  // 2. SEARCH & QUICK ACTION BAR (White Floating)
  // ==========================================
  Widget _buildSearchAndQuickActionBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 750;

    // Giao diện Thanh Tìm Kiếm riêng biệt cho Điện Thoại (Thoáng, Rộng, Đầy đủ tính năng, Không bị ép nén)
    if (isMobile) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Color(0xFF16A34A), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                decoration: const InputDecoration(
                  hintText: 'Tìm sân bóng, cầu lông, pickleball...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            IconButton(
              onPressed: () => _showFilterSheet(),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.tune,
                    color: _selectedType != 'all'
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF16A34A),
                    size: 20,
                  ),
                  if (_selectedType != 'all')
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Green logo inside search
          const Icon(Icons.sports_tennis, color: Color(0xFF16A34A), size: 20),
          const SizedBox(width: 8),

          // Search input field
          Expanded(
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // Filter Slider icon
          IconButton(
            onPressed: () => _showFilterSheet(),
            icon: Icon(
              Icons.tune,
              color: _selectedType != 'all'
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF16A34A),
              size: 18,
            ),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

          if (_isOwner) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OwnerScreen(initialVenues: _allVenues, initialTabIndex: 0),
                  ),
                );
              },
              icon: const Icon(Icons.stadium_outlined, size: 15),
              label: const Text('Quản Lý Sân Của Tôi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],

          const SizedBox(width: 8),
          const SizedBox(
            height: 24,
            child: VerticalDivider(color: Color(0xFFE2E8F0), thickness: 1),
          ),
          const SizedBox(width: 8),

          // Quick actions on the right (Gần tôi, Bản đồ, Sân đã đặt, Yêu thích, Quản trị)
          _buildQuickAction(Icons.near_me_outlined, 'Gần tôi', () => _openMap()),
          const SizedBox(width: 12),
          _buildQuickAction(Icons.map_outlined, 'Bản đồ', () => _openMap()),
          const SizedBox(width: 12),
          _buildQuickAction(Icons.check_box_outlined, 'Sân đã đặt', () => _openBooked()),
          const SizedBox(width: 12),
          _buildQuickAction(Icons.favorite, 'Yêu thích', () => _openFavorites()),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF15803D), size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF15803D),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 2.4 BANNER QUẢN LÝ SÂN CỦA TÔI NỔI BẬT RA NGOÀI (CHỦ SÂN)
  // ==========================================
  Widget _buildOwnerQuickManagementBanner() {
    final myVenuesCount = _allVenues.where(_isMyVenue).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF38BDF8), width: 1),
                ),
                child: const Icon(Icons.stadium_outlined, color: Color(0xFF38BDF8), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'CỔNG QUẢN LÝ SÂN CỦA TÔI',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$myVenuesCount sân',
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Xem toàn bộ danh sách sân của bạn, thêm sân mới, sửa, xóa, theo dõi doanh thu và khách hàng.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              // NÚT CHÍNH: MỞ QUẢN LÝ SÂN CỦA TÔI
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OwnerScreen(initialVenues: _allVenues, initialTabIndex: 0),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text(
                  '👉 MỞ QUẢN LÝ SÂN CỦA TÔI',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7), // Sky blue
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              // NÚT THÊM SÂN MỚI
              ElevatedButton.icon(
                onPressed: () => _showVenueDialog(null),
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text(
                  '+ THÊM SÂN MỚI',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981), // Emerald green
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              // NÚT DOANH THU & ĐƠN ĐẶT
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OwnerScreen(initialVenues: _allVenues, initialTabIndex: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.insights, size: 16, color: Color(0xFF38BDF8)),
                label: const Text(
                  '📊 Doanh Thu & Đơn Đặt',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF38BDF8)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2.5 CATEGORY CHIPS & SÂN CỦA TÔI ROW
  // ==========================================
  Widget _buildCategoryChipsRow() {
    final myVenuesCount = _allVenues.where(_isMyVenue).length;

    final categories = [
      {'key': 'all', 'label': 'Tất cả sân'},
      {'key': 'badminton', 'label': 'Cầu lông 🏸'},
      {'key': 'football', 'label': 'Bóng đá ⚽'},
      {'key': 'pickleball', 'label': 'Pickleball 🏓'},
      {'key': 'tennis', 'label': 'Tennis 🎾'},
      {'key': 'basketball', 'label': 'Bóng rổ 🏀'},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Nếu là Chủ Sân: Nút lọc riêng "Sân của tôi"
          if (_isOwner) ...[
            GestureDetector(
              onTap: () {
                setState(() {
                  _showOnlyMyVenues = !_showOnlyMyVenues;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _showOnlyMyVenues ? const Color(0xFF15803D) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _showOnlyMyVenues ? const Color(0xFF15803D) : const Color(0xFF16A34A),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showOnlyMyVenues ? Icons.check_circle : Icons.stadium_outlined,
                      color: _showOnlyMyVenues ? Colors.white : const Color(0xFF15803D),
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Sân của tôi ($myVenuesCount)',
                      style: TextStyle(
                        color: _showOnlyMyVenues ? Colors.white : const Color(0xFF15803D),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Nút nhanh "+ Thêm sân mới"
            GestureDetector(
              onTap: () => _showVenueDialog(null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle, color: Color(0xFF16A34A), size: 16),
                    SizedBox(width: 4),
                    Text(
                      '+ Đăng Sân Mới',
                      style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Danh sách loại thể thao
          ...categories.map((c) {
            final isSelected = !_showOnlyMyVenues && _selectedType == c['key'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _showOnlyMyVenues = false;
                  _selectedType = c['key'] as String;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF16A34A) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    c['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }),

          // Nút Doanh thu & Khách của Chủ Sân
          if (_isOwner)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OwnerScreen(initialVenues: _allVenues, initialTabIndex: 1),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0D9488), width: 1.2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.insights, color: Color(0xFF0D9488), size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Doanh Thu & Khách',
                      style: TextStyle(
                        color: Color(0xFF0D9488),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── NAVIGATION ACTIONS ──
  void _openMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MapScreen(venues: _allVenues)),
    );
  }

  void _openBooked() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => BookedScreen(allVenues: _allVenues)),
    );
  }

  void _openFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FavoritesScreen(
          allVenues: _allVenues,
          favoriteIds: _favorites,
          onToggleFavorite: (id) {
            setState(() {
              if (_favorites.contains(id)) {
                _favorites.remove(id);
              } else {
                _favorites.add(id);
              }
            });
          },
        ),
      ),
    );
  }

  // ── FILTER BOTTOM SHEET ──
  void _showFilterSheet() {
    final types = [
      {'key': 'all', 'label': 'Tất cả', 'emoji': '🏅'},
      {'key': 'badminton', 'label': 'Cầu lông', 'emoji': '🏸'},
      {'key': 'pickleball', 'label': 'Pickleball', 'emoji': '🎾'},
      {'key': 'football', 'label': 'Bóng đá', 'emoji': '⚽'},
      {'key': 'tennis', 'label': 'Tennis', 'emoji': '🎾'},
      {'key': 'basketball', 'label': 'Bóng rổ', 'emoji': '🏀'},
    ];
    String tempType = _selectedType;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
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
              const SizedBox(height: 20),
              const Text(
                '🎯 Lọc theo loại sân',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: types.map((t) {
                  final selected = tempType == t['key'];
                  return GestureDetector(
                    onTap: () =>
                        setSheetState(() => tempType = t['key'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t['emoji'] as String,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            t['label'] as String,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedType = 'all');
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Xóa bộ lọc',
                          style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedType = tempType);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Áp dụng',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _getSportEmoji(String type) {
    switch (type) {
      case 'football':
        return '⚽';
      case 'tennis':
        return '🎾';
      case 'pickleball':
        return '🏓';
      case 'basketball':
        return '🏀';
      default:
        return '🏸';
    }
  }

  String _getSportName(String type) {
    switch (type.toLowerCase()) {
      case 'football':
        return 'Bóng đá';
      case 'tennis':
        return 'Tennis';
      case 'pickleball':
        return 'Pickleball';
      case 'basketball':
        return 'Bóng rổ';
      default:
        return 'Cầu lông';
    }
  }

  void _openVenueDetail(Venue venue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VenueDetailScreen(
          venue: venue,
          isFavorite: _favorites.contains(venue.id),
          onToggleFavorite: (id) {
            setState(() {
              if (_favorites.contains(id)) {
                _favorites.remove(id);
              } else {
                _favorites.add(id);
              }
            });
          },
        ),
      ),
    );
  }

  // ==========================================
  // 3. VENUE CARD (Exact ALOBO Card Form)
  // ==========================================
  Widget _buildVenueCard(Venue venue) {
    final isFav = _favorites.contains(venue.id);

    return InkWell(
      onTap: () => _openVenueDetail(venue),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Image Area
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: VenueImageView(
                      imageUrl: venue.image,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Top Left Badges (Rating, Đơn ngày, Sự kiện)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Row(
                    children: [
                      // Star Rating Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 11),
                            if (venue.rating > 0) ...[
                              const SizedBox(width: 2),
                              Text(
                                venue.rating.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Green "Đơn ngày" Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981), // Bright green
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Đơn ngày',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Magenta/Pink "Sự kiện" Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD946EF), // Pink/Purple
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Sự kiện',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Badge định danh nếu là sân của chủ sân
                      if (_isMyVenue(venue)) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: venue.isPending
                                ? const Color(0xFFD97706) // Amber
                                : venue.isRejected
                                    ? const Color(0xFFDC2626) // Red
                                    : const Color(0xFF0284C7), // Blue
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                venue.isPending
                                    ? Icons.hourglass_top
                                    : venue.isRejected
                                        ? Icons.error_outline
                                        : Icons.verified_user,
                                color: Colors.white,
                                size: 10,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                venue.isPending
                                    ? 'Chờ duyệt'
                                    : venue.isRejected
                                        ? 'Bị từ chối'
                                        : 'Sân của bạn',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Top Right Floating Action Buttons (Admin / Chủ Sân controls + Heart & Share)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      // Quyền Quản trị viên HOẶC Chủ Sân (nếu là sân của chủ sân đó)
                      if (_isAdmin || _isMyVenue(venue)) ...[
                        InkWell(
                          onTap: () => _showVenueDialog(venue),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7), // Blue
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 12),
                                SizedBox(width: 3),
                                Text(
                                  'Sửa',
                                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _confirmDeleteVenue(venue),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444), // Crimson red
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.delete_outline, color: Colors.white, size: 12),
                                SizedBox(width: 3),
                                Text(
                                  'Xóa',
                                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],

                      // Heart button
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isFav) {
                              _favorites.remove(venue.id);
                            } else {
                              _favorites.add(venue.id);
                            }
                          });
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? const Color(0xFFEF4444) : const Color(0xFF475569),
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Share / Route button
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(
                          Icons.alt_route,
                          color: Color(0xFF475569),
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Info Area (Thiết kế hiện đại, thông thoáng, hiển thị Giá Sân rõ ràng trên Điện Thoại)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hàng 1: Loại hình thể thao & Đánh giá sao
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_getSportEmoji(venue.type)} ${_getSportName(venue.type)}',
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.star, color: Color(0xFFF59E0B), size: 13),
                    const SizedBox(width: 2),
                    Text(
                      venue.ratingLabel,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '· Đã xác thực',
                      style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Tên sân nổi bật
                Text(
                  venue.name,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Khoảng cách + Địa chỉ
                Row(
                  children: [
                    const Icon(Icons.place, size: 12.5, color: Color(0xFFEF4444)),
                    const SizedBox(width: 2),
                    Text(
                      venue.distance.isEmpty ? '' : '${venue.distance} · ',
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        venue.address,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Giờ hoạt động & Trạng thái mở cửa
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      venue.hours,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Mở cửa',
                      style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),

                // Hàng Giá sân & Nút ĐẶT LỊCH rõ ràng
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Cột Giá sân
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Giá chỉ từ:',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            venue.price.isNotEmpty ? venue.price : '100.000đ - 250.000đ/ca',
                            style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Nút ĐẶT LỊCH to rõ, dễ bấm trên màn hình cảm ứng
                    ElevatedButton.icon(
                      onPressed: () => _openBooking(venue),
                      icon: const Icon(Icons.calendar_month, size: 13),
                      label: const Text(
                        'ĐẶT LỊCH',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEAB308), // Golden amber yellow
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 1,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // THANH QUẢN LÝ DÀNH CHO CHỦ SÂN (RÕ RÀNG VỚI NÚT SỬA & XÓA)
          if (_isMyVenue(venue))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                border: Border(top: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  // Huy hiệu trạng thái
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: venue.isPending
                          ? const Color(0xFFFEF3C7)
                          : (venue.isRejected ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: venue.isPending
                            ? const Color(0xFFF59E0B)
                            : (venue.isRejected ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          venue.isPending
                              ? Icons.hourglass_top
                              : (venue.isRejected ? Icons.error_outline : Icons.verified),
                          size: 12,
                          color: venue.isPending
                              ? const Color(0xFFB45309)
                              : (venue.isRejected ? const Color(0xFFB91C1C) : const Color(0xFF15803D)),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          venue.isPending
                              ? 'Chờ Duyệt'
                              : (venue.isRejected ? 'Bị Từ Chối' : 'Sân Của Bạn'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: venue.isPending
                                ? const Color(0xFFB45309)
                                : (venue.isRejected ? const Color(0xFFB91C1C) : const Color(0xFF15803D)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Nút SỬA SÂN
                  ElevatedButton.icon(
                    onPressed: () => _showVenueDialog(venue),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('SỬA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Nút XÓA SÂN
                  ElevatedButton.icon(
                    onPressed: () => _confirmDeleteVenue(venue),
                    icon: const Icon(Icons.delete_outline, size: 14),
                    label: const Text('XÓA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

  // ==========================================
  // 4. BOTTOM NAVIGATION BAR (Special Center Button)
  // ==========================================
  Widget _buildBottomNav() {
    return Container(
      height: 62,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Trang chủ
          _buildNavItem(0, Icons.home, 'Trang chủ', true),

          // 2. Bản đồ
          _buildNavItemWithAction(
            1, Icons.location_on_outlined, 'Bản đồ', _openMap),

          // 3. NÚT CHÍNH GIỮA: QUẢN LÝ SÂN (CHO CHỦ SÂN) HOẶC KHÁM PHÁ (CHO KHÁCH)
          InkWell(
            onTap: () {
              if (_isOwner) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OwnerScreen(initialVenues: _allVenues, initialTabIndex: 0),
                  ),
                );
              } else {
                setState(() => _currentNavIndex = 2);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ExploreScreen(venues: _allVenues)),
                );
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _isOwner
                          ? const Color(0xFF0284C7)
                          : (_currentNavIndex == 2
                              ? const Color(0xFF16A34A)
                              : Colors.white),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _isOwner ? const Color(0xFF0284C7) : const Color(0xFF16A34A),
                          width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: (_isOwner ? const Color(0xFF0284C7) : const Color(0xFF16A34A)).withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _isOwner ? Icons.stadium_outlined : Icons.article_outlined,
                        color: _isOwner
                            ? Colors.white
                            : (_currentNavIndex == 2
                                ? Colors.white
                                : const Color(0xFF16A34A)),
                        size: _isOwner ? 25 : 22,
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -4),
                  child: Text(
                    _isOwner ? 'Quản Lý Sân' : 'Khám phá',
                    style: TextStyle(
                      color: _isOwner ? const Color(0xFF0284C7) : const Color(0xFF16A34A),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Doanh Thu (cho Chủ Sân) hoặc Nổi bật (cho Khách)
          _isOwner
              ? _buildNavItemWithAction(
                  3,
                  Icons.insights,
                  'Doanh Thu',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OwnerScreen(initialVenues: _allVenues, initialTabIndex: 1),
                    ),
                  ),
                )
              : _buildNavItemWithAction(
                  3,
                  Icons.local_fire_department_outlined,
                  'Nổi bật',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FeaturedScreen(venues: _allVenues)),
                  ),
                ),

          // 5. Tài khoản
          _buildNavItemAccount(),
        ],
      ),
    );
  }

  Widget _buildNavItem(int idx, IconData icon, String label, bool isActive) {
    final selected = _currentNavIndex == idx || (isActive && _currentNavIndex == 0);
    return InkWell(
      onTap: () => setState(() => _currentNavIndex = idx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItemWithAction(
      int idx, IconData icon, String label, VoidCallback onTap) {
    final selected = _currentNavIndex == idx;
    return InkWell(
      onTap: () {
        setState(() => _currentNavIndex = idx);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nav item đặc biệt cho Tài khoản — mở dialog đăng xuất
  Widget _buildNavItemAccount() {
    final selected = _currentNavIndex == 4;
    return InkWell(
      onTap: () {
        setState(() => _currentNavIndex = 4);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AccountScreen(venues: _allVenues)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline,
              color: selected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              'Tài khoản',
              style: TextStyle(
                color: selected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text(
              'Đăng xuất',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?',
          style: TextStyle(color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AuthService.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ADMIN LEFT SIDEBAR (PHẦN QUẢN TRỊ BÊN TRÁI)
  // ==========================================
  Widget _buildAdminLeftSidebar() {
    final double width = _isSidebarExpanded ? 310 : 70;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: width,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Dark slate luxury admin theme
        border: Border(
          right: BorderSide(color: Color(0xFF1E293B), width: 1.5),
        ),
      ),
      child: _buildAdminLeftSidebarContent(isDrawer: false),
    );
  }

  Widget _buildAdminLeftSidebarContent({required bool isDrawer}) {
    if (!_isSidebarExpanded && !isDrawer) {
      // Collapsed rail mode
      return Column(
        children: [
          const SizedBox(height: 16),
          IconButton(
            tooltip: 'Mở rộng thanh quản trị',
            onPressed: () => setState(() => _isSidebarExpanded = true),
            icon: const Icon(Icons.menu_open, color: Color(0xFF10B981), size: 24),
          ),
          const SizedBox(height: 20),
          IconButton(
            tooltip: 'Thêm sân mới',
            onPressed: () => _showVenueDialog(null),
            icon: const Icon(Icons.add_circle, color: Color(0xFF10B981), size: 24),
          ),
          const SizedBox(height: 14),
          IconButton(
            tooltip: 'Thống kê',
            onPressed: _showAnalyticsDialog,
            icon: const Icon(Icons.analytics_outlined, color: Colors.white70, size: 22),
          ),
          const SizedBox(height: 14),
          IconButton(
            tooltip: 'Đơn đặt sân',
            onPressed: _showBookingsDialog,
            icon: const Icon(Icons.receipt_long_outlined, color: Colors.white70, size: 22),
          ),
          const SizedBox(height: 14),
          IconButton(
            tooltip: 'Đồng bộ Firestore',
            onPressed: _syncToFirestore,
            icon: const Icon(Icons.cloud_sync_outlined, color: Colors.white70, size: 22),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 22),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    // Expanded sidebar mode (310px)
    final filteredSidebarVenues = _adminCourtSearch.isEmpty
        ? _allVenues
        : _allVenues.where((v) {
            final q = _adminCourtSearch.toLowerCase();
            return v.name.toLowerCase().contains(q) ||
                v.district.toLowerCase().contains(q) ||
                v.type.toLowerCase().contains(q);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header with Brand & Collapse Button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF047857)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('👑', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'BẢNG QUẢN TRỊ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'ALOBOOKING ADMIN',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDrawer)
                IconButton(
                  tooltip: 'Thu gọn thanh bên',
                  icon: const Icon(Icons.chevron_left, color: Colors.white70),
                  onPressed: () => setState(() => _isSidebarExpanded = false),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),

        // 2. Admin User Info Card
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                  child: const Text(
                    'AD',
                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AuthService.currentUser?.fullName ?? 'Super Admin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Trực tuyến (Admin)',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. PRIMARY ACTION: THÊM SÂN THỂ THAO MỚI
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: InkWell(
            onTap: () => _showVenueDialog(null),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'THÊM SÂN MỚI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 4. KPI STATS SUMMARY (4 mini cards)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: _buildMiniStatCard(
                  'Tổng Sân',
                  '${_allVenues.length}',
                  Icons.sports_tennis,
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniStatCard(
                  'Đang Mở',
                  '${_allVenues.length}',
                  Icons.check_circle_outline,
                  const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniStatCard(
                  'D.Thu/ngày',
                  '4.25Tr',
                  Icons.monetization_on_outlined,
                  const Color(0xFFFBBF24),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniStatCard(
                  'Đơn đặt',
                  '28',
                  Icons.calendar_month_outlined,
                  const Color(0xFFA855F7),
                ),
              ),
            ],
          ),
        ),

        // 5. Admin Navigation Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildAdminToolButton(
                      icon: Icons.insights,
                      label: 'Thống Kê',
                      color: const Color(0xFF38BDF8),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminScreen(initialVenues: _allVenues, initialTabIndex: 0),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildAdminToolButton(
                      icon: Icons.sports_tennis,
                      label: 'Sân Bãi',
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminScreen(initialVenues: _allVenues, initialTabIndex: 1),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildAdminToolButton(
                      icon: Icons.receipt_long_outlined,
                      label: 'Đơn Đặt',
                      color: const Color(0xFFA855F7),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminScreen(initialVenues: _allVenues, initialTabIndex: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildAdminToolButton(
                      icon: Icons.people_outline,
                      label: 'Khách Hàng',
                      color: const Color(0xFFFBBF24),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminScreen(initialVenues: _allVenues, initialTabIndex: 3),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildAdminToolButton(
                      icon: Icons.payments_outlined,
                      label: 'Thu Ngân',
                      color: const Color(0xFF34D399),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminScreen(initialVenues: _allVenues, initialTabIndex: 4),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildAdminToolButton(
                      icon: Icons.cloud_sync_outlined,
                      label: 'Đồng Bộ',
                      color: const Color(0xFF64748B),
                      onTap: _syncToFirestore,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminScreen(initialVenues: _allVenues, initialTabIndex: 0),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dashboard_customize, color: Color(0xFF10B981), size: 15),
                        SizedBox(width: 6),
                        Text(
                          'TRUNG TÂM QUẢN TRỊ TOÀN DIỆN ↗',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(color: Color(0xFF1E293B), height: 16),

        // 6. Court Quick Management List inside Sidebar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUẢN LÝ SÂN (${_allVenues.length})',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminScreen(initialVenues: _allVenues),
                    ),
                  );
                },
                child: const Text(
                  'Xem tất cả ↗',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Mini search field in sidebar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF94A3B8), size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _adminCourtSearch = val),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    decoration: const InputDecoration(
                      hintText: 'Tìm nhanh tên sân...',
                      hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_adminCourtSearch.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _adminCourtSearch = ''),
                    child: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 14),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Scrollable Court List
        Expanded(
          child: filteredSidebarVenues.isEmpty
              ? const Center(
                  child: Text(
                    'Không tìm thấy sân phù hợp',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  itemCount: filteredSidebarVenues.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, idx) {
                    final venue = filteredSidebarVenues[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          Text(_getSportEmoji(venue.type), style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  venue.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${venue.district} • ${venue.price}',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 9.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Edit Button
                          IconButton(
                            tooltip: 'Sửa sân',
                            icon: const Icon(Icons.edit, color: Color(0xFF38BDF8), size: 15),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            onPressed: () => _showVenueDialog(venue),
                          ),
                          // Delete Button
                          IconButton(
                            tooltip: 'Xóa sân',
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 15),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            onPressed: () => _confirmDeleteVenue(venue),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // 7. Footer: Thông tin phiên đăng nhập & Đăng xuất
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF1E293B))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trạng thái tài khoản
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Tài khoản: Super Admin',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Nút Đăng xuất
              InkWell(
                onTap: _confirmLogout,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: Color(0xFFEF4444), size: 15),
                      SizedBox(width: 6),
                      Text(
                        'Đăng xuất Admin',
                        style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 8.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }


  Widget _buildAdminToolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ADD & EDIT VENUE DIALOG (THÊM / SỬA SÂN)
  // ==========================================
  void _showVenueDialog(Venue? existingVenue) {
    final isEdit = existingVenue != null;
    final nameCtrl = TextEditingController(text: isEdit ? existingVenue.name : '');
    final addressCtrl = TextEditingController(text: isEdit ? existingVenue.address : '');
    final hoursCtrl = TextEditingController(text: isEdit ? existingVenue.hours : '06:00 – 23:00');
    final priceCtrl = TextEditingController(text: isEdit ? existingVenue.price : '100k - 200k/h');
    final imageCtrl = TextEditingController(
      text: isEdit
          ? existingVenue.image
          : (_sampleImages['badminton']?.first ??
              'https://images.unsplash.com/photo-1521537634581-0dced2fee2ef?w=600&h=320&fit=crop&q=80'),
    );

    String selectedType = isEdit ? existingVenue.type : 'badminton';
    String selectedDistrict = isEdit ? existingVenue.district : _districts.first;
    bool isUploadingImage = false;
    bool showUrlField = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final sportPresets = _sampleImages[selectedType] ?? _sampleImages['badminton']!;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            child: Container(
              width: 580,
              constraints: const BoxConstraints(maxHeight: 700),
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isEdit ? const Color(0xFF0284C7).withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit : Icons.add_business,
                          color: isEdit ? const Color(0xFF0284C7) : const Color(0xFF10B981),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'CẬP NHẬT THÔNG TIN SÂN' : 'THÊM SÂN THỂ THAO MỚI',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              isEdit ? 'Sửa thông tin sân #${existingVenue.id}' : 'Tạo mới cụm sân thể thao và đồng bộ',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Form Fields (Scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Thông báo kiểm duyệt dành riêng cho Chủ Sân
                          if (_isOwner) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFF59E0B)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Lưu ý: Sân của bạn sau khi lưu sẽ ở trạng thái Chờ duyệt. Admin sẽ kiểm duyệt nội dung trước khi hiển thị công khai cho toàn bộ khách hàng.',
                                      style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 1. Tên sân
                          const Text('Tên sân thể thao *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              hintText: 'VD: Sân Cầu Lông Victor Pro, Sân Bóng Mini Cầu Giấy...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 2. Môn thể thao & Quận (Row)
                          Row(
                            children: [
                              // Môn thể thao
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Môn thể thao *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: selectedType,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        isDense: true,
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'badminton', child: Text('🏸 Cầu lông')),
                                        DropdownMenuItem(value: 'pickleball', child: Text('🏓 Pickleball')),
                                        DropdownMenuItem(value: 'football', child: Text('⚽ Bóng đá')),
                                        DropdownMenuItem(value: 'tennis', child: Text('🎾 Tennis')),
                                        DropdownMenuItem(value: 'basketball', child: Text('🏀 Bóng rổ')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() {
                                            selectedType = val;
                                            final presets = _sampleImages[val];
                                            if (presets != null && presets.isNotEmpty) {
                                              imageCtrl.text = presets.first;
                                            }
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Quận
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Quận / Huyện *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: selectedDistrict,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        isDense: true,
                                      ),
                                      items: {..._districts, selectedDistrict}
                                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) setDialogState(() => selectedDistrict = val);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 3. Địa chỉ chi tiết
                          const Text('Địa chỉ cụ thể *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: addressCtrl,
                            decoration: InputDecoration(
                              hintText: 'VD: Số 12 Ngõ 198 Nguyễn Tuân, Thanh Xuân, Hà Nội',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 4. Giá thuê & Giờ mở cửa (Đã xóa khoảng cách)
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Giá thuê / giờ *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: priceCtrl,
                                      decoration: InputDecoration(
                                        hintText: 'VD: 100k - 200k/h',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        isDense: true,
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
                                    const Text('Giờ mở cửa *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: hoursCtrl,
                                      decoration: InputDecoration(
                                        hintText: 'VD: 06:00 – 23:00',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        isDense: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 5. Hình ảnh sân (Tải từ máy tính / Nhập link / Mẫu ảnh)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Hình ảnh sân *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              if (imageCtrl.text.startsWith('data:image'))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Đã tải ảnh từ máy',
                                        style: TextStyle(color: Color(0xFF16A34A), fontSize: 10.5, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Khung xem trước ảnh sân
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                Container(
                                  height: 135,
                                  width: double.infinity,
                                  color: const Color(0xFFF1F5F9),
                                  child: VenueImageView(
                                    imageUrl: imageCtrl.text,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Xem trước ảnh sân',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                if (isUploadingImage)
                                  Container(
                                    height: 135,
                                    width: double.infinity,
                                    color: Colors.black.withOpacity(0.5),
                                    alignment: Alignment.center,
                                    child: const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                        SizedBox(height: 8),
                                        Text(
                                          'Đang tải và tối ưu ảnh...',
                                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Nút tải ảnh từ máy & nút dán link
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
                                              setDialogState(() {
                                                imageCtrl.text = picked;
                                              });
                                            }
                                          } catch (e) {
                                            debugPrint('Error picking image: $e');
                                          } finally {
                                            setDialogState(() => isUploadingImage = false);
                                          }
                                        },
                                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                                  label: const Text(
                                    '📁 TẢI ẢNH TỪ MÁY TÍNH / THIẾT BỊ',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setDialogState(() => showUrlField = !showUrlField);
                                },
                                icon: Icon(showUrlField ? Icons.close : Icons.link, size: 16),
                                label: Text(showUrlField ? 'Ẩn URL' : 'Dán URL', style: const TextStyle(fontSize: 11.5)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0284C7),
                                  side: const BorderSide(color: Color(0xFF0284C7)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),

                          if (showUrlField) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: imageCtrl,
                              decoration: InputDecoration(
                                hintText: 'Dán link URL ảnh (https://...)',
                                prefixIcon: const Icon(Icons.link, size: 18, color: Color(0xFF64748B)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ],

                          const SizedBox(height: 10),

                          // Chọn ảnh mẫu nhanh 1-chạm
                          Row(
                            children: [
                              const Text('Hoặc chọn mẫu: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.w500)),
                              ...sportPresets.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final url = entry.value;
                                final isSelected = imageCtrl.text == url;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ActionChip(
                                    label: Text(
                                      'Mẫu ${idx + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? const Color(0xFF15803D) : const Color(0xFF334155),
                                      ),
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        imageCtrl.text = url;
                                      });
                                    },
                                    backgroundColor: isSelected
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFF1F5F9),
                                    side: BorderSide(
                                      color: isSelected ? const Color(0xFF16A34A) : Colors.transparent,
                                      width: 1.2,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vui lòng nhập tên sân thể thao!')),
                            );
                            return;
                          }

                          final id = isEdit
                              ? existingVenue.id
                              : (_allVenues.map((v) => v.id).fold(0, (max, current) => current > max ? current : max) + 1);

                          final myUid = AuthService.currentUser?.uid ?? 'owner_chuan_01';
                          final myName = AuthService.currentUser?.fullName ?? 'Trần Văn Chủ Sân';

                          final ownerId = isEdit
                              ? (existingVenue.ownerId.isNotEmpty ? existingVenue.ownerId : myUid)
                              : (_isOwner ? myUid : 'admin_super_01');

                          final ownerName = isEdit
                              ? (existingVenue.ownerName.isNotEmpty ? existingVenue.ownerName : myName)
                              : (_isOwner ? myName : 'Hệ Thống Alobooking');

                          // Nếu là chủ sân đăng bài hoặc sửa bài -> chuyển về trạng thái 'pending' để admin duyệt
                          // Nếu là super admin thì phê duyệt luôn ('approved')
                          final approvalStatus = _isAdmin
                              ? (isEdit ? existingVenue.approvalStatus : 'approved')
                              : 'pending';

                          final venueToSave = Venue(
                            id: id,
                            name: name,
                            type: selectedType,
                            district: selectedDistrict,
                            distance: isEdit ? existingVenue.distance : '1.0km',
                            address: addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : 'Hà Nội',
                            hours: hoursCtrl.text.trim().isNotEmpty ? hoursCtrl.text.trim() : '06:00 – 23:00',
                            tags: isEdit ? existingVenue.tags : ['Đơn ngày', 'Sự kiện'],
                            rating: isEdit ? existingVenue.rating : 4.8,
                            price: priceCtrl.text.trim().isNotEmpty ? priceCtrl.text.trim() : '100k - 200k/h',
                            lat: isEdit ? existingVenue.lat : 21.0285,
                            lng: isEdit ? existingVenue.lng : 105.8542,
                            image: imageCtrl.text.trim().isNotEmpty
                                ? imageCtrl.text.trim()
                                : 'https://images.unsplash.com/photo-1521537634581-0dced2fee2ef?w=600&h=320&fit=crop&q=80',
                            logo: isEdit
                                ? existingVenue.logo
                                : 'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=100&h=100&fit=crop&q=80',
                            ownerId: ownerId,
                            ownerName: ownerName,
                            approvalStatus: approvalStatus,
                            rejectReason: isEdit ? existingVenue.rejectReason : '',
                          );

                          Navigator.pop(ctx);

                          setState(() {
                            if (isEdit) {
                              final idx = _allVenues.indexWhere((v) => v.id == existingVenue.id);
                              if (idx != -1) _allVenues[idx] = venueToSave;
                            } else {
                              _allVenues.insert(0, venueToSave);
                            }
                          });

                          // Save to Firestore
                          if (isEdit) {
                            await FirestoreService.updateVenue(venueToSave);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_isOwner
                                      ? '✅ Đã lưu cập nhật sân "${venueToSave.name}"! Sân đang chờ Admin duyệt lại để hiển thị công khai.'
                                      : '✅ Đã cập nhật sân "${venueToSave.name}" thành công!'),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            }
                          } else {
                            await FirestoreService.addVenue(venueToSave);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_isOwner
                                      ? '✅ Đã gửi sân mới "${venueToSave.name}"! Sân đang chờ Admin duyệt trước khi hiển thị công khai.'
                                      : '✅ Đã thêm sân mới "${venueToSave.name}" thành công!'),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(isEdit ? 'LƯU CẬP NHẬT' : 'THÊM SÂN MỚI'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // CONFIRM DELETE VENUE (XÓA SÂN)
  // ==========================================
  void _confirmDeleteVenue(Venue venue) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 26),
            SizedBox(width: 10),
            Text('Xác nhận xóa sân', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa sân "${venue.name}" khỏi hệ thống?\nThao tác này sẽ xóa dữ liệu trên hệ thống và Firestore.',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _allVenues.removeWhere((v) => v.id == venue.id);
              });
              await FirestoreService.deleteVenue(venue.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🗑️ Đã xóa sân "${venue.name}" thành công!'),
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xóa Sân', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ANALYTICS & STATS DIALOG (THỐNG KÊ CHI TIẾT)
  // ==========================================
  void _showAnalyticsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(22),
          child: FutureBuilder<List<BookingItem>>(
            future: FirestoreService.getBookings(),
            builder: (context, snap) {
              final header = Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics, color: Color(0xFF10B981), size: 24),
                      SizedBox(width: 10),
                      Text(
                        'BÁO CÁO & THỐNG KÊ DOANH THU',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    splashRadius: 18,
                  ),
                ],
              );
              if (!snap.hasData) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    header,
                    const Divider(height: 20),
                    const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))),
                  ],
                );
              }

              // Số liệu thật: admin xem toàn hệ thống, chủ sân chỉ xem các sân của mình
              final venues = _isAdmin ? _allVenues : _allVenues.where(_isMyVenue).toList();
              final names = venues.map((v) => v.name.trim().toLowerCase()).toSet();
              final bookings = snap.data!
                  .where((b) => _isAdmin || names.contains(b.venueName.trim().toLowerCase()))
                  .toList();
              final st = AdminStats.compute(bookings: bookings, venues: venues, period: AdminPeriod.month);
              final rated = venues.where((v) => v.rating > 0).toList();
              final avgRating = rated.isEmpty ? null : rated.fold<double>(0, (a, v) => a + v.rating) / rated.length;
              final sports = st.revenueBySport.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final totalRev = sports.fold<int>(0, (a, e) => a + e.value);
              final peak = st.slots.fold<SlotShare?>(null, (m, e) => (m == null || e.orders > m.orders) ? e : m);
              const colors = [Color(0xFF10B981), Color(0xFF38BDF8), Color(0xFFFBBF24), Color(0xFFA855F7), Color(0xFFEC4899)];

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const Divider(height: 20),
                    Text('30 ngày qua • ${bookings.length} đơn đặt sân trong dữ liệu',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildMetricTile('Doanh thu', AdminStats.fmtCompact(st.revenue), const Color(0xFF10B981))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMetricTile('Đơn đặt sân', '${st.orders}', const Color(0xFF38BDF8))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            'Tỷ lệ hủy',
                            st.cancelRate == null ? '—' : '${(st.cancelRate! * 100).toStringAsFixed(1)}%',
                            const Color(0xFFFBBF24),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            'Đánh giá TB',
                            avgRating == null ? '—' : '${avgRating.toStringAsFixed(2)} ★',
                            const Color(0xFFA855F7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Tỷ trọng doanh thu theo môn:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 10),
                    if (totalRev == 0)
                      const Text('Chưa có doanh thu (đơn đã xác nhận) trong 30 ngày qua.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
                    else
                      for (var k = 0; k < sports.length; k++) ...[
                        if (k > 0) const SizedBox(height: 8),
                        _buildSportPercentBar(
                          sports[k].key,
                          sports[k].value / totalRev,
                          '${(sports[k].value / totalRev * 100).round()}% (${AdminStats.fmtCompact(sports[k].value)})',
                          colors[k % colors.length],
                        ),
                      ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_filled, color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (peak == null || peak.orders == 0)
                                  ? 'Chưa có đơn đặt sân trong 30 ngày qua.'
                                  : 'Khung giờ nhiều đơn nhất: ${peak.label} (${peak.orders} đơn).',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }


  Widget _buildMetricTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildSportPercentBar(String label, double percent, String details, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            Text(details, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // BOOKINGS MANAGEMENT DIALOG (QUẢN LÝ ĐƠN ĐẶT SÂN)
  // ==========================================
  void _showBookingsDialog() async {
    final bookings = await FirestoreService.getBookings();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            child: Container(
              width: 650,
              constraints: const BoxConstraints(maxHeight: 650),
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long, color: Color(0xFF10B981), size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'QUẢN LÝ ĐƠN ĐẶT SÂN (${bookings.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: bookings.isEmpty
                        ? const Center(
                            child: Text('Chưa có đơn đặt sân nào.', style: TextStyle(color: Color(0xFF64748B))),
                          )
                        : ListView.separated(
                            itemCount: bookings.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (bCtx, idx) {
                              final item = bookings[idx];
                              final isConfirmed = item.status == 'Đã xác nhận';
                              final isCancelled = item.status == 'Đã hủy';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isConfirmed
                                          ? const Color(0xFF10B981).withOpacity(0.15)
                                          : (isCancelled
                                              ? const Color(0xFFEF4444).withOpacity(0.15)
                                              : const Color(0xFFF59E0B).withOpacity(0.15)),
                                      child: Icon(
                                        isConfirmed
                                            ? Icons.check
                                            : (isCancelled ? Icons.cancel_outlined : Icons.schedule),
                                        color: isConfirmed
                                            ? const Color(0xFF10B981)
                                            : (isCancelled ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(item.customer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              const SizedBox(width: 6),
                                              Text('(${item.phone})', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item.venueName} • ${item.time} • ${item.date}',
                                            style: const TextStyle(color: Color(0xFF334155), fontSize: 11),
                                          ),
                                          Text(
                                            'Tổng tiền: ${item.amount} (${item.paymentMethod})',
                                            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Status & Actions
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isConfirmed
                                                ? const Color(0xFF10B981).withOpacity(0.15)
                                                : (isCancelled
                                                    ? const Color(0xFFEF4444).withOpacity(0.15)
                                                    : const Color(0xFFF59E0B).withOpacity(0.15)),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.status,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isConfirmed
                                                  ? const Color(0xFF10B981)
                                                  : (isCancelled ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        if (!isConfirmed && !isCancelled)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () async {
                                                  await FirestoreService.confirmBooking(item.id);
                                                  setDialogState(() {
                                                    item.status = 'Đã xác nhận';
                                                  });
                                                },
                                                child: const Text('Duyệt', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
                                              ),
                                              const SizedBox(width: 8),
                                              InkWell(
                                                onTap: () async {
                                                  await FirestoreService.updateBookingStatus(item.id, 'Đã hủy');
                                                  setDialogState(() {
                                                    item.status = 'Đã hủy';
                                                  });
                                                },
                                                child: const Text('Hủy', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // SYNC VENUES TO FIRESTORE (ĐỒNG BỘ CLOUD)
  // ==========================================
  void _syncToFirestore() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Đang đồng bộ dữ liệu sân lên Firestore...'),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );

    final count = await FirestoreService.syncVenues(_allVenues);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? '☁️ Đã đồng bộ thành công $count/${_allVenues.length} sân lên Firestore alobooking-b2484!'
                : '⚠️ Không thể kết nối Firestore, dữ liệu đang lưu cục bộ.',
          ),
          backgroundColor: count > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
    }
  }
}
