import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../services/auth_service.dart';
import '../models/notification_item.dart';
import '../services/firestore_service.dart';
import 'booked_screen.dart';
import 'explore_screen.dart';
import 'featured_screen.dart';
import 'map_screen.dart';
import 'login_screen.dart';

class AccountScreen extends StatefulWidget {
  final List<Venue> venues;
  const AccountScreen({super.key, required this.venues});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String _selectedMenu = 'settings';

  // Cá nhân hóa thông tin người chơi
  String _preferredDistrict = 'Đống Đa';
  String _favoriteSport = 'Pickleball';
  String _skillLevel = 'Phong trào (Khá)';

  final List<String> _districts = [
    'Đống Đa', 'Cầu Giấy', 'Ba Đình', 'Hoàn Kiếm', 'Thanh Xuân', 'Hai Bà Trưng', 'Tây Hồ', 'Nam Từ Liêm'
  ];

  final List<String> _sports = ['Pickleball', 'Cầu lông', 'Bóng đá', 'Tennis', 'Bóng rổ'];
  final List<String> _levels = ['Mới tập chơi', 'Phong trào (Cơ bản)', 'Phong trào (Khá)', 'Bán chuyên', 'Chuyên nghiệp'];

  void _showPersonalizationDialog() {
    String tempDist = _preferredDistrict;
    String tempSport = _favoriteSport;
    String tempLevel = _skillLevel;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.tune, color: Color(0xFF15803D)),
              SizedBox(width: 8),
              Text('Cá nhân hóa trải nghiệm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📍 Khu vực thường chơi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: tempDist,
                  items: _districts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (val) => setDialogState(() => tempDist = val!),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),

                const Text('🏸 Môn thể thao yêu thích', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: tempSport,
                  items: _sports.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setDialogState(() => tempSport = val!),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),

                const Text('🏆 Trình độ chơi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: tempLevel,
                  items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  onChanged: (val) => setDialogState(() => tempLevel = val!),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF15803D),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _preferredDistrict = tempDist;
                  _favoriteSport = tempSport;
                  _skillLevel = tempLevel;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã cập nhật gu thể thao cá nhân hóa thành công!')),
                );
              },
              child: const Text('Lưu thông tin'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog() async {
    final me = AuthService.currentUser;
    final ids = <String>{if (me != null) me.uid, if (me != null && me.isAdmin) 'admin_super_01'};
    final notifs = me == null || AuthService.isGuest
        ? <NotificationItem>[]
        : (await FirestoreService.getNotifications()).where((n) => ids.contains(n.userId)).toList();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('Hộp thư thông báo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 480,
          height: 380,
          child: notifs.isEmpty
              ? const Center(child: Text('Không có thông báo mới.'))
              : ListView.separated(
                  itemCount: notifs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final n = notifs[idx];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF15803D).withOpacity(0.12),
                        child: const Icon(Icons.sports, color: Color(0xFF15803D), size: 18),
                      ),
                      title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(n.message, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final userName = user?.fullName.isNotEmpty == true ? user!.fullName : 'Khách vãng lai';
    final userEmail = user?.email.isNotEmpty == true ? user!.email : 'Chưa đăng nhập tài khoản';
    // Điện thoại / cửa sổ hẹp: thanh bên rộng 320 + khung nội dung không đủ chỗ, dồn thành một cột cuộn
    final narrow = MediaQuery.of(context).size.width < 760;

    return Scaffold(
      backgroundColor: const Color(0xFF065F46), // Dark green background like screenshot
      body: narrow
          ? _buildSidebar(userName, userEmail, narrow: true)
          : Row(
              children: [
                _buildSidebar(userName, userEmail, narrow: false),

                // ─── RIGHT CONTENT PANE (HIỂN THỊ CHUẨN XÁC NỘI DUNG ỨNG DỤNG CÓ GÌ MỚI) ───
                Expanded(
                  child: Container(
                    color: const Color(0xFF065F46), // Dark green background from screenshot
                    child: _buildRightPaneContent(),
                  ),
                ),
              ],
            ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _bottomNavItem(Icons.home_outlined, 'Trang chủ', () => Navigator.pop(context)),
            _bottomNavItem(Icons.location_on_outlined, 'Bản đồ', () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MapScreen(venues: widget.venues)));
            }),
            _bottomNavItemCenter(Icons.article_outlined, 'Khám phá', () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ExploreScreen(venues: widget.venues)));
            }),
            _bottomNavItem(Icons.local_fire_department_outlined, 'Nổi bật', () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => FeaturedScreen(venues: widget.venues)));
            }),
            _bottomNavItem(Icons.person, 'Tài khoản', () {}, isActive: true),
          ],
        ),
      ),
    );
  }

  /// Thanh bên (hồ sơ, lối tắt, menu). Màn hình hẹp (điện thoại) dùng một cột cuộn full chiều rộng.
  Widget _buildSidebar(String userName, String userEmail, {required bool narrow}) {
    return Container(
            width: narrow ? null : 320,
            color: const Color(0xFFF8FAFC),
            child: Column(
              children: [
                // Header Profile Card
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                  color: const Color(0xFF065F46),
                  child: Column(
                    children: [
                      // User Info Row
                      InkWell(
                        onTap: _showPersonalizationDialog,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AuthService.isGuest ? const Color(0xFFFEF3C7) : const Color(0xFFFEF08A),
                                child: Text(AuthService.isGuest ? '👀' : '👦', style: const TextStyle(fontSize: 22)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      userEmail,
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Hạng thành viên badge / Vai trò
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AuthService.isGuest ? const Color(0xFFB45309).withOpacity(0.3) : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AuthService.isGuest ? const Color(0xFFFDE68A) : Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Text(AuthService.isGuest ? '👀' : '💎', style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 8),
                            Text(
                              AuthService.isGuest ? 'Khách Xem Sân (Chỉ xem)' : 'Hạng thành viên',
                              style: TextStyle(
                                color: AuthService.isGuest ? const Color(0xFFFDE68A) : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.chevron_right, color: Colors.white70, size: 16),
                          ],
                        ),
                      ),

                      // Nút Đăng nhập/Đăng ký dành cho Khách vãng lai
                      if (AuthService.isGuest) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                            },
                            icon: const Icon(Icons.login, size: 16),
                            label: const Text('ĐĂNG NHẬP / ĐĂNG KÝ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFEF08A),
                              foregroundColor: const Color(0xFF15803D),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 4 Quick Action Buttons (Lịch đã đặt, Thông báo, Khoá học, Ưu đãi)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _quickActionButton(Icons.event_note, 'Lịch đã đặt', () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => BookedScreen(allVenues: widget.venues)));
                      }),
                      _quickActionButton(Icons.notifications_outlined, 'Thông báo', _showNotificationsDialog),
                    ],
                  ),
                ),

                // Scrollable Menu List
                Expanded(
                  // Material trong suốt nằm TRÊN lớp màu nền của Container, để màu chọn/hiệu ứng chạm của ListTile hiện ra
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _menuSectionHeader('Hoạt động'),
                      _menuTile('Lịch đã đặt', Icons.event_note_outlined, 'bookings'),
                      _menuTile('Thông báo', Icons.notifications_outlined, 'notifications'),

                      const SizedBox(height: 10),
                      _menuSectionHeader('Hệ thống'),
                      _menuTile('Tài khoản', Icons.person_outline, 'settings', isHighlighted: true),
                      // Màn hình hẹp không có khung bên phải: hiện thẻ tài khoản ngay dưới menu
                      if (narrow) _buildGenericSettingsContent(narrow: true),
                    ],
                    ),
                  ),
                ),

              ],
            ),
          );
  }

  Widget _quickActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 66,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFF8FAFC),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF15803D)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          ],
        ),
      ),
    );
  }

  Widget _menuSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
    );
  }

  Widget _menuTile(String title, IconData icon, String key, {bool isHighlighted = false}) {
    final isSelected = _selectedMenu == key;
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: isSelected ? const Color(0xFF15803D) : const Color(0xFF64748B)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? const Color(0xFF15803D) : const Color(0xFF1E293B),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
      tileColor: isSelected ? const Color(0xFFDCFCE7) : Colors.transparent,
      onTap: () {
        if (key == 'bookings') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => BookedScreen(allVenues: widget.venues)));
        } else if (key == 'notifications') {
          _showNotificationsDialog();
        } else {
          setState(() => _selectedMenu = key);
        }
      },
    );
  }

  Widget _buildRightPaneContent() => _buildGenericSettingsContent();


  Widget _buildGenericSettingsContent({bool narrow = false}) {
    final u = AuthService.currentUser;
    final loggedIn = u != null && !AuthService.isGuest;
    Widget line(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF15803D)),
              const SizedBox(width: 10),
              SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13))),
              Expanded(
                child: Text(value.isEmpty ? 'Chưa cập nhật' : value,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
            ],
          ),
        );
    return Center(
      child: Container(
        // Máy tính: thẻ rộng 460 giữa khung xanh; điện thoại: thẻ chiếm hết chiều rộng còn lại
        width: narrow ? double.infinity : 460,
        padding: EdgeInsets.all(narrow ? 16 : 24),
        margin: EdgeInsets.all(narrow ? 12 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: narrow ? Border.all(color: const Color(0xFFE2E8F0)) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tài khoản', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            if (loggedIn) ...[
              line(Icons.person_outline, 'Họ tên', u.fullName),
              line(Icons.email_outlined, 'Email', u.email),
              line(Icons.phone_outlined, 'Điện thoại', u.phone),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  AuthService.logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              const Text('Bạn chưa đăng nhập. Đăng nhập để đặt sân và xem lịch sử đặt sân.',
                  style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('Đăng nhập'),
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _bottomNavItem(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: isActive ? const Color(0xFF15803D) : const Color(0xFF64748B)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? const Color(0xFF15803D) : const Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _bottomNavItemCenter(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: const Offset(0, -6),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF15803D), width: 2),
              ),
              child: const Icon(Icons.article_outlined, color: Color(0xFF15803D), size: 22),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -4),
            child: const Text('Khám phá', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
          ),
        ],
      ),
    );
  }
}
