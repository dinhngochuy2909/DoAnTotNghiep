// ignore_for_file: invalid_use_of_protected_member
part of '../home_screen.dart';

extension _HomeVenueDialogs on _HomeScreenState {
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
          : VenuePhotos.pick('badminton', 0),
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
                          color: isEdit ? const Color(0xFF0284C7).withOpacity(0.12) : const Color(0xFF0EA5E9).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit : Icons.add_business,
                          color: isEdit ? const Color(0xFF0284C7) : const Color(0xFF0EA5E9),
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
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, color: Color(0xFF0284C7), size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Đã tải ảnh từ máy',
                                        style: TextStyle(color: Color(0xFF0284C7), fontSize: 10.5, fontWeight: FontWeight.bold),
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
                                    backgroundColor: const Color(0xFF0EA5E9),
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
                          // Wrap thay cho Row: kho ảnh mẫu có hàng chục ảnh nên phải xuống dòng
                          Wrap(
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
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
                                        color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF334155),
                                      ),
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        imageCtrl.text = url;
                                      });
                                    },
                                    backgroundColor: isSelected
                                        ? const Color(0xFFE0F2FE)
                                        : const Color(0xFFF1F5F9),
                                    side: BorderSide(
                                      color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
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
                                : VenuePhotos.pick(selectedType, 0), // chưa nhập ảnh: dùng ảnh minh họa đúng môn
                            logo: isEdit
                                ? existingVenue.logo
                                : 'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=100&h=100&fit=crop&q=80',
                            ownerId: ownerId,
                            ownerName: ownerName,
                            approvalStatus: approvalStatus,
                            rejectReason: isEdit ? existingVenue.rejectReason : '',
                            // Giữ nguyên số sân con, nguồn dữ liệu và ngày duyệt khi sửa (trước đây bị đặt lại về mặc định)
                            courtCount: isEdit ? existingVenue.courtCount : 0,
                            source: isEdit ? existingVenue.source : '',
                            approvedAt: isEdit ? existingVenue.approvedAt : (approvalStatus == 'approved' ? DateTime.now() : null),
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
                          backgroundColor: const Color(0xFF0EA5E9),
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
}
