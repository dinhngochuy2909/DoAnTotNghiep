import 'package:flutter/material.dart';
import '../data/venue_photos.dart';
import '../models/venue.dart';
import '../services/booking_approval.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/admin_stats.dart';
import '../services/venue_permission.dart';
import '../theme/app_theme.dart';
import '../widgets/app_footer.dart';
import '../widgets/venue_card.dart';
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
import '../services/platform/image_picker_service.dart';

part 'home/home_header.dart';
part 'home/home_nav.dart';
part 'home/home_admin_sidebar.dart';
part 'home/home_venue_dialogs.dart';
part 'home/home_admin_dialogs.dart';

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
  final ScrollController _scrollCtrl = ScrollController(); // để chân trang đưa người dùng lên đầu trang
  final FocusNode _searchFocus = FocusNode();

  // ─── PHÂN QUYỀN VÀ TRẠNG THÁI QUẢN TRỊ ───
  bool get _isAdmin => AuthService.isAdmin;
  bool get _isOwner => AuthService.isOwner;
  bool _isSidebarExpanded = true;
  String _adminCourtSearch = '';
  bool _showOnlyMyVenues = false;

  bool _isMyVenue(Venue venue) => VenuePermission.canManage(
        role: _isAdmin ? 'admin' : (_isOwner ? 'owner' : ''),
        uid: AuthService.currentUser?.uid ?? '',
        venue: venue,
      );

  final List<String> _districts = [
    'Cầu Giấy', 'Đống Đa', 'Ba Đình', 'Hoàn Kiếm', 'Hai Bà Trưng',
    'Thanh Xuân', 'Tây Hồ', 'Nam Từ Liêm', 'Bắc Từ Liêm', 'Hà Đông',
    'Hoàng Mai', 'Long Biên', 'Gia Lâm', 'Đông Anh', 'Thanh Trì', 'Hoài Đức'
  ];

  // Kho ảnh minh họa theo môn (đã duyệt đúng môn), xem lib/data/venue_photos.dart
  final Map<String, List<String>> _sampleImages = VenuePhotos.bySport;

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  void _openAccount() {
    setState(() => _currentNavIndex = 4);
    Navigator.push(context, MaterialPageRoute(builder: (_) => AccountScreen(venues: _allVenues)));
  }

  /// Các liên kết ở chân trang điều khiển trang chủ: lên đầu trang, lọc theo môn, mở các màn hình khác.
  FooterActions _footerActions() => FooterActions(
        onHome: () {
          setState(() {
            _showOnlyMyVenues = false;
            _selectedType = 'all';
            _currentNavIndex = 0;
          });
          _scrollToTop();
        },
        onSearch: () {
          _scrollToTop();
          Future.delayed(const Duration(milliseconds: 480), () {
            if (mounted) _searchFocus.requestFocus();
          });
        },
        onBooked: _openBooked,
        onFavorites: _openFavorites,
        onAccount: _openAccount,
        onTop: _scrollToTop,
        onSport: (type) {
          setState(() {
            _showOnlyMyVenues = false;
            _selectedType = type;
          });
          _scrollToTop();
        },
      );

  /// [force]: bỏ qua danh sách đã nhớ và đọc lại từ máy chủ (nút "Thử lại"). Mở app bình thường dùng bản đã nhớ để
  /// không tốn lượt đọc Firestore.
  Future<void> _loadVenues({bool force = false}) async {
    setState(() => _isLoading = true);
    FirestoreService.lastLoadFailed = false;
    final venues = await FirestoreService.getVenues(forceRefresh: force);
    if (!mounted) return;
    setState(() {
      _allVenues = venues;
      _isLoading = false;
    });
    if (venues.isEmpty && FirestoreService.lastLoadFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không tải được danh sách sân. ${FirestoreService.failureMessage()}'),
          action: SnackBarAction(label: 'Thử lại', onPressed: () => _loadVenues(force: true)),
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
              backgroundColor: const Color(0xFF0284C7),
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
                                child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  int crossAxisCount = 3;
                                  if (constraints.maxWidth < 650) {
                                    crossAxisCount = 1;
                                  } else if (constraints.maxWidth < 950) {
                                    crossAxisCount = 2;
                                  }
                                  // Chiều cao thẻ = ảnh (theo bề rộng) + phần thông tin cố định (+ thanh quản lý với chủ sân/admin)
                                  final double cardWidth = (constraints.maxWidth - 32 - 14 * (crossAxisCount - 1)) / crossAxisCount;
                                  final double cardExtent =
                                      cardWidth * (crossAxisCount == 1 ? 0.56 : 0.5) + 178 + ((_isOwner || _isAdmin) ? 48 : 0);

                                  return CustomScrollView(
                                    controller: _scrollCtrl,
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
                                            mainAxisExtent: cardExtent,
                                          ),
                                        ),
                                      ),
                                      // ===== FOOTER =====
                                      SliverToBoxAdapter(
                                        child: AppFooter(actions: _footerActions()),
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
  /// Thẻ sân ở lưới trang chủ (giao diện mới ở widgets/venue_card.dart); mọi thao tác vẫn gọi các hàm cũ của màn hình.
  Widget _buildVenueCard(Venue venue) {
    final manage = _isAdmin || _isMyVenue(venue);
    return VenueCard(
      venue: venue,
      isFavorite: _favorites.contains(venue.id),
      canManage: manage,
      onTap: () => _openVenueDetail(venue),
      onBook: () => _openBooking(venue),
      onToggleFavorite: () => setState(() {
        if (!_favorites.remove(venue.id)) _favorites.add(venue.id);
      }),
      onEdit: manage ? () => _showVenueDialog(venue) : null,
      onDelete: manage ? () => _confirmDeleteVenue(venue) : null,
    );
  }
}
