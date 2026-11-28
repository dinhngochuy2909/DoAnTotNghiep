// ignore_for_file: invalid_use_of_protected_member
part of '../admin_screen.dart';

extension _AdminCustomersTab on _AdminScreenState {
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
                    border: Border.all(color: AdminUi.info.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text('Tổng Khách Hàng', style: TextStyle(color: AdminUi.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                    border: Border.all(color: AdminUi.warn.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text('Hội Viên VIP', style: TextStyle(color: AdminUi.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                    border: Border.all(color: AdminUi.success.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text('Đang Hoạt Động', style: TextStyle(color: AdminUi.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Icon(Icons.check_circle_outline, color: AdminUi.success, size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$activeCount', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Tài khoản khả dụng', style: TextStyle(color: AdminUi.success, fontSize: 11)),
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
              border: Border.all(color: AdminUi.border.withValues(alpha: 0.5)),
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
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final c = filtered[i];
                Color rankColor = const Color(0xFFCD7F32); // Bronze
                if (c.rank.contains('Kim Cương')) {
                  rankColor = AdminUi.info;
                } else if (c.rank.contains('Vàng')) {
                  rankColor = AdminUi.warn;
                } else if (c.rank.contains('Bạc')) {
                  rankColor = AdminUi.muted;
                }

                final isLocked = c.status == 'Tạm khóa';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isLocked ? AdminUi.danger.withValues(alpha: 0.3) : AdminUi.border.withValues(alpha: 0.5)),
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
                            colors: [rankColor.withValues(alpha: 0.8), rankColor],
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
                                    color: rankColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: rankColor.withValues(alpha: 0.5)),
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
                                      color: AdminUi.danger.withValues(alpha: 0.15),
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
}
