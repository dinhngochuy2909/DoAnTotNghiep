// ignore_for_file: invalid_use_of_protected_member
part of '../admin_screen.dart';

extension _AdminShell on _AdminScreenState {
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
      (5, Icons.campaign_outlined, 'Tin tức', 0),
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
                Text(_AdminScreenState._tabTitles[_selectedNavIndex],
                    style: const TextStyle(color: AdminUi.text, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (!compact)
                  Text(_AdminScreenState._tabSubtitles[_selectedNavIndex],
                      style: AdminUi.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (updated != null && !compact) Text(updated, style: AdminUi.caption),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AdminUi.muted, size: 20),
            tooltip: 'Tải lại dữ liệu',
            onPressed: _isLoading ? null : () => _loadData(force: true),
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
      case 5:
        return _buildNewsTab();
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
}
