// ignore_for_file: invalid_use_of_protected_member
part of '../admin_screen.dart';

extension _AdminVenuesTab on _AdminScreenState {
  // ==========================================
  // TAB 2: QUẢN LÝ SÂN THỂ THAO (CRUD)
  // ==========================================
  Widget _buildVenuesManagementTab() {
    return Column(
      children: [
        // Controls Bar (Search + Filter + Add Button)
        Container(
          padding: const EdgeInsets.all(16),
          color: AdminUi.surface,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AdminUi.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminUi.border.withValues(alpha: 0.5)),
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchVenueQuery = val),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Tìm kiếm sân theo tên, quận, địa chỉ...',
                          hintStyle: TextStyle(color: AdminUi.faint, fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: AdminUi.faint, size: 18),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _openAddVenueDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminUi.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm Sân', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'Tất cả môn'),
                    _filterChip('pickleball', 'Pickleball'),
                    _filterChip('badminton', 'Cầu lông'),
                    _filterChip('football', 'Bóng đá'),
                    _filterChip('tennis', 'Tennis'),
                    _filterChip('basketball', 'Bóng rổ'),
                    const SizedBox(width: 10),
                    // District dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AdminUi.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminUi.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDistrict,
                          dropdownColor: AdminUi.surface,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('Tất cả quận')),
                            ..._districts.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                          ],
                          onChanged: (val) => setState(() => _selectedDistrict = val ?? 'all'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Filter by Approval Status
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _approvalFilterChip('all', 'Tất cả (${_venues.length})'),
                    const SizedBox(width: 6),
                    _approvalFilterChip('pending', 'Chờ Duyệt ⏳ (${_venues.where((v) => v.isPending).length})'),
                    const SizedBox(width: 6),
                    _approvalFilterChip('approved', 'Đã Duyệt (${_venues.where((v) => v.isApproved).length})'),
                    const SizedBox(width: 6),
                    _approvalFilterChip('rejected', 'Từ Chối (${_venues.where((v) => v.isRejected).length})'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Venues List
        Expanded(
          child: _filteredVenues.isEmpty
              ? const Center(
                  child: Text('Không tìm thấy sân phù hợp.',
                      style: TextStyle(color: AdminUi.muted, fontSize: 14)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredVenues.length,
                  itemBuilder: (ctx, i) => _buildVenueRowCard(_filteredVenues[i]),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String key, String label) {
    final selected = _selectedSport == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedSport = key),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [AdminUi.accent, AdminUi.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [AdminUi.surfaceAlt, AdminUi.sidebar],
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AdminUi.accent
                  : AdminUi.border.withValues(alpha: 0.6),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AdminUi.accent.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AdminUi.muted,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _approvalFilterChip(String key, String label) {
    final selected = _selectedApprovalFilter == key;
    // "Tất cả" dùng màu chủ đạo (xanh biển); chỉ bộ lọc "Đã duyệt" mới mang nghĩa thành công (xanh lá)
    Color activeColor = key == 'approved' ? AdminUi.success : AdminUi.accent;
    Color activeColorDark = activeColor;
    if (key == 'pending') {
      activeColor = AdminUi.warn;
      activeColorDark = const Color(0xFFD97706);
    } else if (key == 'rejected') {
      activeColor = AdminUi.danger;
      activeColorDark = AdminUi.danger;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedApprovalFilter = key),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [activeColor, activeColorDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [AdminUi.surfaceAlt, AdminUi.sidebar],
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? activeColor : AdminUi.border.withValues(alpha: 0.6),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AdminUi.muted,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVenueRowCard(Venue v) {
    Color statusBg = AdminUi.success.withValues(alpha: 0.15);
    Color statusColor = AdminUi.success;
    String statusText = 'Đã duyệt';

    if (v.isPending) {
      statusBg = AdminUi.warn.withValues(alpha: 0.15);
      statusColor = AdminUi.warn;
      statusText = 'Chờ duyệt';
    } else if (v.isRejected) {
      statusBg = AdminUi.danger.withValues(alpha: 0.15);
      statusColor = AdminUi.danger;
      statusText = 'Từ chối';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminUi.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: v.isPending ? AdminUi.warn.withValues(alpha: 0.6) : AdminUi.border.withValues(alpha: 0.5),
          width: v.isPending ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: VenueImageView(
                  imageUrl: v.displayImage,
                  width: 75,
                  height: 75,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AdminUi.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            v.type.toUpperCase(),
                            style: const TextStyle(
                                color: AdminUi.accent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '#${v.id}',
                          style: const TextStyle(color: AdminUi.faint, fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${v.address} (${v.district}) • Chủ: ${v.ownerName}',
                      style: const TextStyle(color: AdminUi.muted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(v.price,
                            style: const TextStyle(
                                color: AdminUi.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 10),
                        const Icon(Icons.access_time, size: 12, color: AdminUi.faint),
                        const SizedBox(width: 2),
                        Text(v.hours, style: const TextStyle(color: AdminUi.faint, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons (Detail, Edit, Delete)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, color: Color(0xFF60A5FA), size: 20),
                    tooltip: 'Xem chi tiết',
                    onPressed: () => _openViewDetailDialog(v),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AdminUi.violet, size: 20),
                    tooltip: 'Chỉnh sửa',
                    onPressed: () => _openEditVenueDialog(v),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AdminUi.danger, size: 20),
                    tooltip: 'Xóa sân',
                    onPressed: () => _openDeleteVenueDialog(v),
                  ),
                ],
              ),
            ],
          ),

          // Action bar if PENDING approval
          if (v.isPending) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AdminUi.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminUi.warn.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AdminUi.warn, size: 16),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Yêu cầu đăng bài từ Chủ sân cần bạn phê duyệt:',
                      style: TextStyle(color: AdminUi.warn, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Giữ ngày duyệt lần đầu nếu sân từng được duyệt (sửa rồi duyệt lại không thành "sân mới")
                      final stamp = v.approvedAt ?? DateTime.now();
                      await FirestoreService.updateVenueApproval(v.id, 'approved', '', stamp);
                      final updated = v.copyWith(approvalStatus: 'approved', approvedAt: stamp);
                      final idx = _venues.indexWhere((item) => item.id == v.id);
                      if (idx != -1) setState(() => _venues[idx] = updated);
                      _showToast('Đã duyệt đăng bài sân "${v.name}" thành công!');
                    },
                    icon: const Icon(Icons.check_circle, size: 14),
                    label: const Text('Duyệt Đăng', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminUi.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openRejectDialog(v),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: const Text('Từ Chối', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminUi.danger,
                      side: const BorderSide(color: AdminUi.danger),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openRejectDialog(Venue v) {
    final reasonCtrl = TextEditingController(text: 'Hình ảnh chưa rõ nét hoặc thiếu bảng giá chi tiết');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminUi.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel, color: AdminUi.danger),
            SizedBox(width: 8),
            Text('Từ Chối Bài Đăng Sân', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhập lý do từ chối để gửi phản hồi cho chủ sân "${v.name}":',
                style: const TextStyle(color: AdminUi.muted, fontSize: 13)),
            const SizedBox(height: 10),
            _dialogTextField('Lý Do Từ Chối *', reasonCtrl, 'VD: Cần cập nhật giấy phép / ảnh thực tế'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AdminUi.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim().isEmpty ? 'Chưa đáp ứng tiêu chuẩn kiểm duyệt' : reasonCtrl.text.trim();
              await FirestoreService.updateVenueApproval(v.id, 'rejected', reason);
              if (!mounted || !ctx.mounted) return;
              final updated = v.copyWith(approvalStatus: 'rejected', rejectReason: reason);
              final idx = _venues.indexWhere((item) => item.id == v.id);
              if (idx != -1) setState(() => _venues[idx] = updated);
              Navigator.pop(ctx);
              _showToast('Đã từ chối duyệt bài sân "${v.name}"!', isError: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminUi.danger),
            child: const Text('Xác Nhận Từ Chối', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOGS: ADD / EDIT / DELETE VENUES
  // ==========================================
  void _openAddVenueDialog() {
    _openVenueFormDialog(null);
  }

  void _openEditVenueDialog(Venue v) {
    _openVenueFormDialog(v);
  }

  void _openVenueFormDialog(Venue? existing) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String selectedType = existing?.type ?? 'pickleball';
    String selectedDist = existing?.district ?? 'Đống Đa';
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final priceCtrl = TextEditingController(text: existing?.price ?? '120k - 220k/h');
    final hoursCtrl = TextEditingController(text: existing?.hours ?? '06:00 – 23:00');
    final courtsCtrl = TextEditingController(text: (existing?.courts ?? Venue.defaultCourtCount(selectedType)).toString());
    final ratingCtrl = TextEditingController(text: existing?.rating.toString() ?? '4.8');
    final tagsCtrl = TextEditingController(
        text: existing?.tags.join(', ') ?? 'Mái che cao, Đèn LED, Thảm Yonex, Chỗ đỗ xe');
    final imageCtrl = TextEditingController(
      text: existing?.image ?? _sampleImages['pickleball']![0],
    );
    double lat = existing?.lat ?? _districtCoordinates['Đống Đa']!['lat']!;
    double lng = existing?.lng ?? _districtCoordinates['Đống Đa']!['lng']!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          return AlertDialog(
            backgroundColor: AdminUi.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(isEdit ? Icons.edit : Icons.add_circle, color: AdminUi.accent),
                const SizedBox(width: 8),
                Text(isEdit ? 'Chỉnh Sửa Sân Thể Thao' : 'Thêm Sân Thể Thao Mới',
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogTextField('Tên Cụm Sân *', nameCtrl, 'VD: Cụm Sân Pickleball Đống Đa'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Môn Thể Thao *',
                                  style: TextStyle(color: AdminUi.muted, fontSize: 12)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AdminUi.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AdminUi.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedType,
                                    isExpanded: true,
                                    dropdownColor: AdminUi.surface,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(value: 'pickleball', child: Text('Pickleball')),
                                      DropdownMenuItem(value: 'badminton', child: Text('Cầu lông')),
                                      DropdownMenuItem(value: 'football', child: Text('Bóng đá')),
                                      DropdownMenuItem(value: 'tennis', child: Text('Tennis')),
                                      DropdownMenuItem(value: 'basketball', child: Text('Bóng rổ')),
                                    ],
                                    onChanged: (val) {
                                      setDialogState(() {
                                        selectedType = val ?? 'pickleball';
                                        final list = _sampleImages[selectedType] ?? _sampleImages['pickleball']!;
                                        imageCtrl.text = list[0];
                                        if (!isEdit) courtsCtrl.text = Venue.defaultCourtCount(selectedType).toString();
                                      });
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
                              const Text('Quận Huyện *',
                                  style: TextStyle(color: AdminUi.muted, fontSize: 12)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AdminUi.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AdminUi.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedDist,
                                    isExpanded: true,
                                    dropdownColor: AdminUi.surface,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: {..._districts, selectedDist}
                                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                        .toList(),
                                    onChanged: (val) {
                                      setDialogState(() {
                                        selectedDist = val ?? 'Đống Đa';
                                        final coords = _districtCoordinates[selectedDist];
                                        if (coords != null) {
                                          lat = coords['lat']!;
                                          lng = coords['lng']!;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _dialogTextField('Địa Chỉ Cụ Thể *', addressCtrl, 'VD: 18 Chùa Bộc, Đống Đa, Hà Nội'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _dialogTextField('Mức Giá Thuê/Giờ', priceCtrl, '120k - 220k/h')),
                        const SizedBox(width: 12),
                        Expanded(child: _dialogTextField('Giờ Hoạt Động', hoursCtrl, '06:00 – 23:00')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _dialogTextField('Số Sân Con Trong Cụm (1–30)', courtsCtrl, 'VD: 8'),
                    const SizedBox(height: 12),
                    _dialogTextField('Tiện Ích & Tags', tagsCtrl, 'Mái che cao, Đèn LED, Thảm Yonex'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('URL Hình Ảnh Sân Thể Thao',
                            style: TextStyle(color: AdminUi.muted, fontSize: 12)),
                        TextButton(
                          onPressed: () {
                            final list = _sampleImages[selectedType] ?? _sampleImages['pickleball']!;
                            final next = list[math.Random().nextInt(list.length)];
                            setDialogState(() => imageCtrl.text = next);
                          },
                          child: const Text('Chọn ảnh mẫu đẹp',
                              style: TextStyle(color: AdminUi.accent, fontSize: 11)),
                        ),
                      ],
                    ),
                    _dialogTextField('', imageCtrl, 'https://images.unsplash.com/...'),
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
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty || addressCtrl.text.trim().isEmpty) {
                    _showToast('Vui lòng điền tên sân và địa chỉ!', isError: true);
                    return;
                  }

                  final tags = tagsCtrl.text.split(',').map((t) => t.trim()).filter((t) => t.isNotEmpty).toList();
                  final courtCount = (int.tryParse(courtsCtrl.text.trim()) ?? Venue.defaultCourtCount(selectedType)).clamp(1, 30);

                  if (isEdit) {
                    // copyWith giữ nguyên chủ sân, trạng thái duyệt và các trường khác của sân
                    final updated = existing.copyWith(
                      name: nameCtrl.text.trim(),
                      type: selectedType,
                      district: selectedDist,
                      address: addressCtrl.text.trim(),
                      hours: hoursCtrl.text.trim(),
                      tags: tags.isNotEmpty ? tags : ['Đơn ngày'],
                      rating: double.tryParse(ratingCtrl.text) ?? existing.rating,
                      price: priceCtrl.text.trim(),
                      lat: lat,
                      lng: lng,
                      image: imageCtrl.text.trim(),
                      courtCount: courtCount,
                    );
                    await FirestoreService.updateVenue(updated);
                    setState(() {
                      final idx = _venues.indexWhere((x) => x.id == existing.id);
                      if (idx != -1) _venues[idx] = updated;
                    });
                    _showToast('Đã cập nhật sân "${updated.name}" thành công!');
                  } else {
                    final newId = _venues.isNotEmpty ? _venues.map((x) => x.id).reduce(math.max) + 1 : 1;
                    final created = Venue(
                      id: newId,
                      name: nameCtrl.text.trim(),
                      type: selectedType,
                      district: selectedDist,
                      distance: '1.2km',
                      address: addressCtrl.text.trim(),
                      hours: hoursCtrl.text.trim(),
                      tags: tags.isNotEmpty ? tags : ['Đơn ngày'],
                      rating: double.tryParse(ratingCtrl.text) ?? 4.8,
                      price: priceCtrl.text.trim(),
                      lat: lat,
                      lng: lng,
                      image: imageCtrl.text.trim(),
                      logo: 'https://ui-avatars.com/api/?name=PB&background=10b981&color=fff&size=40&bold=true',
                      courtCount: courtCount,
                      approvedAt: DateTime.now(),
                    );
                    await FirestoreService.addVenue(created);
                    setState(() {
                      _venues.insert(0, created);
                    });
                    _showToast('Đã thêm sân "${created.name}" thành công!');
                  }

                  if (!ctx.mounted) return;
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

  // --- DELETE VENUE DIALOG ---
  void _openDeleteVenueDialog(Venue v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminUi.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AdminUi.danger),
            SizedBox(width: 8),
            Text('Xác Nhận Xóa Sân', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa sân "${v.name}" (#${v.id}) khỏi hệ thống?\nHành động này không thể hoàn tác.',
          style: const TextStyle(color: AdminUi.muted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AdminUi.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirestoreService.deleteVenue(v.id);
              if (!mounted || !ctx.mounted) return;
              setState(() => _venues.removeWhere((x) => x.id == v.id));
              Navigator.pop(ctx);
              _showToast('Đã xóa sân "${v.name}" thành công!', isError: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminUi.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác Nhận Xóa'),
          ),
        ],
      ),
    );
  }

  // --- DETAIL VENUE DIALOG ---
  void _openViewDetailDialog(Venue v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminUi.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: VenueImageView(
                    imageUrl: v.displayImage,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(v.type.toUpperCase(),
                            style: const TextStyle(color: AdminUi.accent, fontWeight: FontWeight.bold, fontSize: 11)),
                        Row(
                          children: [
                            const Icon(Icons.star, color: AdminUi.warn, size: 14),
                            Text(' ${v.rating} / 5.0', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(v.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 4),
                    Text(v.address, style: const TextStyle(color: AdminUi.muted, fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: AdminUi.faint, size: 14),
                        const SizedBox(width: 4),
                        Text(v.hours, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 16),
                        const Icon(Icons.payments_outlined, color: AdminUi.accent, size: 14),
                        const SizedBox(width: 4),
                        Text(v.price, style: const TextStyle(color: AdminUi.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: v.tags.map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AdminUi.bg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AdminUi.border),
                          ),
                          child: Text(t, style: const TextStyle(color: AdminUi.muted, fontSize: 11)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: AdminUi.muted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _openEditVenueDialog(v);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminUi.accent),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Chỉnh Sửa'),
          ),
        ],
      ),
    );
  }
}
