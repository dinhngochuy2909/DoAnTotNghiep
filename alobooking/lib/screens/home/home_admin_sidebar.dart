// ignore_for_file: invalid_use_of_protected_member
part of '../home_screen.dart';

extension _HomeAdminSidebar on _HomeScreenState {
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
            icon: const Icon(Icons.menu_open, color: Color(0xFF0EA5E9), size: 24),
          ),
          const SizedBox(height: 20),
          IconButton(
            tooltip: 'Thêm sân mới',
            onPressed: () => _showVenueDialog(null),
            icon: const Icon(Icons.add_circle, color: Color(0xFF0EA5E9), size: 24),
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
                    colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
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
                        color: Color(0xFF0EA5E9),
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
                  backgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                  child: const Text(
                    'AD',
                    style: TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold, fontSize: 12),
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
                              color: Color(0xFF0EA5E9),
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
                  colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.35),
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
                  const Color(0xFF0EA5E9),
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
                      color: const Color(0xFF0EA5E9),
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
                      color: const Color(0xFF38BDF8),
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
                      border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.5)),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dashboard_customize, color: Color(0xFF0EA5E9), size: 15),
                        SizedBox(width: 6),
                        Text(
                          'TRUNG TÂM QUẢN TRỊ TOÀN DIỆN ↗',
                          style: TextStyle(
                            color: Color(0xFF0EA5E9),
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
                    color: Color(0xFF0EA5E9),
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
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
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
                    Icon(Icons.shield_outlined, color: Color(0xFF0EA5E9), size: 14),
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
          border: Border.all(color: color.withValues(alpha: 0.3)),
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
}
