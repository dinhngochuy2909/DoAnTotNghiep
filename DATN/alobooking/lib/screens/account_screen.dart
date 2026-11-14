import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../services/auth_service.dart';
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
  String _selectedMenu = 'whats_new'; // 'whats_new' | 'groups' | 'classes' | 'memberships' | 'settings' | 'about' | 'terms'

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
    final notifs = await FirestoreService.getNotifications();
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

  void _showVouchersDialog() {
    final vouchers = [
      {'code': 'ALOBO50', 'desc': 'Giảm 50k cho đơn đặt sân đầu tiên', 'exp': 'HSD: 31/12/2026'},
      {'code': 'GIOPHUCVU', 'desc': 'Giảm 20% khi đặt sân khung giờ vàng (17h-20h)', 'exp': 'HSD: 15/11/2026'},
      {'code': 'PICKLEBALLPRO', 'desc': 'Tặng 1 buổi trải nghiệm thảm Pickleball miễn phí', 'exp': 'HSD: 30/11/2026'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.card_giftcard, color: Color(0xFFEA580C)),
            SizedBox(width: 8),
            Text('Kho ưu đãi & Voucher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: vouchers
                .map((v) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDBA74)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.confirmation_number_outlined, color: Color(0xFFEA580C)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v['code']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC2410C))),
                                Text(v['desc']!, style: const TextStyle(fontSize: 12, color: Color(0xFF431407))),
                                Text(v['exp']!, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA580C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Đã áp dụng mã ${v['code']}!')),
                              );
                            },
                            child: const Text('Dùng ngay', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ))
                .toList(),
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

    return Scaffold(
      backgroundColor: const Color(0xFF065F46), // Dark green background like screenshot
      body: Row(
        children: [
          // ─── LEFT SIDEBAR (MÀU TRẮNG + XANH CHUẨN SCREENSHOT) ───
          Container(
            width: 320,
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
                      _quickActionButton(Icons.school_outlined, 'Khoá học', () {
                        setState(() => _selectedMenu = 'classes');
                      }),
                      _quickActionButton(Icons.card_giftcard, 'Ưu đãi', _showVouchersDialog),
                    ],
                  ),
                ),

                // Scrollable Menu List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _menuSectionHeader('Hoạt động'),
                      _menuTile('Nhóm của tôi', Icons.groups_outlined, 'groups'),
                      _menuTile('Danh sách lịch học', Icons.school_outlined, 'classes'),
                      _menuTile('Gói hội viên', Icons.workspace_premium_outlined, 'memberships'),

                      const SizedBox(height: 10),
                      _menuSectionHeader('Hệ thống'),
                      _menuTile('Cài đặt', Icons.settings_outlined, 'settings'),
                      _menuTile('Thông tin phiên bản', Icons.info_outline, 'about'),
                      _menuTile('Điều khoản và chính sách', Icons.shield_outlined, 'terms'),
                      _menuTile('Ứng dụng có gì mới', Icons.newspaper_outlined, 'whats_new', isHighlighted: true),
                    ],
                  ),
                ),

                // Version at bottom
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('Thông tin phiên bản: 2.10.5', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                ),
              ],
            ),
          ),

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
      onTap: () => setState(() => _selectedMenu = key),
    );
  }

  Widget _buildRightPaneContent() {
    if (_selectedMenu == 'whats_new') {
      return _buildWhatsNewDocument();
    } else if (_selectedMenu == 'groups') {
      return _buildGroupsContent();
    } else if (_selectedMenu == 'classes') {
      return _buildClassesContent();
    } else if (_selectedMenu == 'memberships') {
      return _buildMembershipsContent();
    } else {
      return _buildGenericSettingsContent();
    }
  }

  // Khớp 100% với tài liệu và nội dung trong bức ảnh của người dùng
  Widget _buildWhatsNewDocument() {
    return Scaffold(
      backgroundColor: const Color(0xFF065F46),
      appBar: AppBar(
        backgroundColor: const Color(0xFF065F46),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Ứng dụng có gì mới', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề chính
            const Text(
              '🚀 ALOBO USER – Cập nhật mới & Gợi ý tính năng quan trọng',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Tag phiên bản
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Text(
                '🗂️ [Phiên bản mới nhất: 2.8.4 | Phát hành: 12/01/2026]',
                style: TextStyle(color: Color(0xFF86EFAC), fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),

            // Lời mở đầu
            const Text(
              'ALOBO mang đến một bước nâng cấp lớn về trải nghiệm người chơi – cá nhân hóa – giao diện, giúp bạn tìm sân nhanh hơn, chơi đúng gu hơn và kết nối thể thao dễ dàng hơn.\n👉 Cùng xem những điểm mới trong 2.8.4 và nhắc lại các tính năng hay từ các phiên bản cũ nhé!',
              style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white24),
            const SizedBox(height: 20),

            // Section 1: MỚI TRONG PHIÊN BẢN 2.8.4
            const Text(
              '🔥 MỚI TRONG PHIÊN BẢN 2.8.4 – TRẢI NGHIỆM HOÀN TOÀN MỚI',
              style: TextStyle(
                color: Color(0xFFFDE047), // Bright yellow
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Subsection: Newsfeed & Tab Khám phá
            const Row(
              children: [
                Icon(Icons.newspaper, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Newsfeed & Tab Khám phá', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 8),
            _bulletPoint('Giao diện ứng dụng được thiết kế lại, menu & navbar mới hiện đại hơn.'),
            _bulletPoint('Bổ sung tab Khám phá – nơi bạn dễ dàng xem:'),
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 4, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _subBullet('📣 Bài đăng từ chủ sân'),
                  _subBullet('⏳ Ưu đãi sân trống / giờ trống (Flash sale giờ vàng)'),
                  _subBullet('🔄 Pass sân / pass lịch (Cộng đồng nhượng lại lịch đặt)'),
                  _subBullet('🎟️ Ưu đãi sự kiện vãng lai – ghép đội – xé vé'),
                ],
              ),
            ),
            _bulletPoint('Lợi ích:\n👉 Không cần tìm kiếm thủ công – ưu đãi & sân phù hợp sẽ tự tìm đến bạn.'),

            const SizedBox(height: 24),

            // Subsection: Cá nhân hóa trải nghiệm người chơi
            const Row(
              children: [
                Icon(Icons.person_pin, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Cá nhân hóa trải nghiệm người chơi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 8),
            _bulletPoint('Thêm Walkthrough hướng dẫn sử dụng cho người dùng mới.'),
            _bulletPoint('Cho phép bạn cập nhật thông tin cá nhân hóa:'),
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 4, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _subBullet('📍 Khu vực thường chơi: $_preferredDistrict'),
                  _subBullet('🏸 Môn thể thao yêu thích: $_favoriteSport'),
                  _subBullet('🏆 Trình độ chơi: $_skillLevel'),
                ],
              ),
            ),

            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showPersonalizationDialog,
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Cập Nhật Gu Thể Thao Của Bạn Ngay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.white70, fontSize: 14)),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }

  Widget _subBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Text(text, style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 12.5, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildGroupsContent() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups, size: 50, color: Color(0xFF15803D)),
            const SizedBox(height: 12),
            const Text('Hội Nhóm Thể Thao Của Tôi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Bạn đang tham gia: CLB Pickleball Hà Nội Pro (18 thành viên) & CLB Cầu Lông Đống Đa.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đang kết nối danh sách nhóm...'))),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D), foregroundColor: Colors.white),
              child: const Text('Tạo Nhóm Mới / Ghép Đội'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassesContent() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school, size: 50, color: Color(0xFF0284C7)),
            SizedBox(height: 12),
            Text('Danh Sách Khoá Học & Lịch Tập', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            Text('Khoá học đang theo dõi: Lớp Pickleball Cơ Bản & Chiến Thuật Đôi (Thứ 3, 5 hàng tuần tại Ga Hà Nội).', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipsContent() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium, size: 50, color: Color(0xFFF59E0B)),
            SizedBox(height: 12),
            Text('Gói Hội Viên Của Bạn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            Text('Bạn đang sở hữu thẻ VIP Vàng: Giảm 15% tất cả đơn đặt sân giờ vàng & miễn phí gửi xe.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericSettingsContent() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.settings, size: 50, color: Color(0xFF64748B)),
            const SizedBox(height: 12),
            const Text('Cài Đặt Hệ Thống & Tài Khoản', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Quản lý thông báo, đổi mật khẩu và liên kết tài khoản bảo mật.', style: TextStyle(color: Colors.grey)),
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
                backgroundColor: const Color(0xFFEF4444).withOpacity(0.12),
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Đăng Xuất Tài Khoản', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
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
