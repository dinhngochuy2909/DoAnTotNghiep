// ignore_for_file: invalid_use_of_protected_member
part of '../home_screen.dart';

extension _HomeNav on _HomeScreenState {
  // ==========================================
  // 4. BOTTOM NAVIGATION BAR (Special Center Button)
  // ==========================================
  Widget _buildBottomNav() {
    return Container(
      height: 66,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Color(0x1A0F172A), blurRadius: 18, offset: Offset(0, -4))],
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
                              ? const Color(0xFF0284C7)
                              : Colors.white),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _isOwner ? const Color(0xFF0284C7) : const Color(0xFF0284C7),
                          width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: (_isOwner ? const Color(0xFF0284C7) : const Color(0xFF0284C7)).withValues(alpha: 0.35),
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
                                : const Color(0xFF0284C7)),
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
                      color: _isOwner ? const Color(0xFF0284C7) : const Color(0xFF0284C7),
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

  /// Một mục của thanh điều hướng dưới: biểu tượng trong viên thuốc nền nhạt khi đang chọn, chữ đậm hơn.
  Widget _navItemUi(IconData icon, String label, bool selected) {
    final color = selected ? const Color(0xFF0284C7) : const Color(0xFF64748B);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE0F2FE) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildNavItem(int idx, IconData icon, String label, bool isActive) {
    final selected = _currentNavIndex == idx || (isActive && _currentNavIndex == 0);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _currentNavIndex = idx),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: _navItemUi(icon, label, selected)),
    );
  }

  Widget _buildNavItemWithAction(
      int idx, IconData icon, String label, VoidCallback onTap) {
    final selected = _currentNavIndex == idx;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() => _currentNavIndex = idx);
        onTap();
      },
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: _navItemUi(icon, label, selected)),
    );
  }

  /// Nav item đặc biệt cho Tài khoản — mở dialog đăng xuất
  Widget _buildNavItemAccount() {
    final selected = _currentNavIndex == 4;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() => _currentNavIndex = 4);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AccountScreen(venues: _allVenues)),
        );
      },
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: _navItemUi(Icons.person_outline_rounded, 'Tài khoản', selected)),
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
}
