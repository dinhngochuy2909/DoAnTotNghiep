// ignore_for_file: invalid_use_of_protected_member
part of '../home_screen.dart';

extension _HomeHeader on _HomeScreenState {
  // ==========================================
  // 1. TOP HEADER (Green Banner)
  // ==========================================
  Widget _buildTopHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 750;

    // Giao diện Header riêng biệt tối ưu cho Điện Thoại
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
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
                    color: const Color(0xFF075985),
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
                    icon: const Icon(Icons.login, color: Color(0xFF0369A1), size: 14),
                    label: const Text(
                      'Đăng nhập',
                      style: TextStyle(
                        color: Color(0xFF0369A1),
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0369A1),
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
                    icon: const Icon(Icons.add, color: Color(0xFF0369A1), size: 15),
                    label: const Text(
                      'Thêm sân',
                      style: TextStyle(
                        color: Color(0xFF0369A1),
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF08A),
                      foregroundColor: const Color(0xFF0369A1),
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
                      backgroundColor: const Color(0xFF0EA5E9),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
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
                  color: const Color(0xFF075985),
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
                      color: const Color(0xFF0EA5E9),
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
                  icon: const Icon(Icons.add_circle, color: Color(0xFF0369A1), size: 18),
                  label: const Text(
                    '+ THÊM SÂN MỚI',
                    style: TextStyle(
                      color: Color(0xFF0369A1),
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF08A), // Bright golden yellow
                    foregroundColor: const Color(0xFF0369A1),
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
                  icon: const Icon(Icons.login, color: Color(0xFF0369A1), size: 16),
                  label: const Text(
                    'ĐĂNG NHẬP / ĐĂNG KÝ',
                    style: TextStyle(
                      color: Color(0xFF0369A1),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0369A1),
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
                      color: _showOnlyMyVenues ? const Color(0xFF0369A1) : const Color(0xFF0F172A),
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
                      color: const Color(0xFF0891B2),
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
            const Icon(Icons.search, color: Color(0xFF0284C7), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                focusNode: _searchFocus,
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
                        : const Color(0xFF0284C7),
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
          const Icon(Icons.sports_tennis, color: Color(0xFF0284C7), size: 20),
          const SizedBox(width: 8),

          // Search input field
          Expanded(
            child: TextField(
              focusNode: _searchFocus,
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
                  : const Color(0xFF0284C7),
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
            Icon(icon, color: const Color(0xFF0369A1), size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF0369A1),
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
                            color: const Color(0xFF0EA5E9),
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
                  backgroundColor: const Color(0xFF0EA5E9), // Emerald green
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
                  color: _showOnlyMyVenues ? const Color(0xFF0369A1) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _showOnlyMyVenues ? const Color(0xFF0369A1) : const Color(0xFF0284C7),
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
                      color: _showOnlyMyVenues ? Colors.white : const Color(0xFF0369A1),
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Sân của tôi ($myVenuesCount)',
                      style: TextStyle(
                        color: _showOnlyMyVenues ? Colors.white : const Color(0xFF0369A1),
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
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0EA5E9), width: 1.2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle, color: Color(0xFF0284C7), size: 16),
                    SizedBox(width: 4),
                    Text(
                      '+ Đăng Sân Mới',
                      style: TextStyle(
                        color: Color(0xFF0284C7),
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
                  color: isSelected ? const Color(0xFF0284C7) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
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
                  border: Border.all(color: const Color(0xFF0891B2), width: 1.2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.insights, color: Color(0xFF0891B2), size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Doanh Thu & Khách',
                      style: TextStyle(
                        color: Color(0xFF0891B2),
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
                            ? const Color(0xFF0284C7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF0284C7)
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
                        backgroundColor: const Color(0xFF0284C7),
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
}
