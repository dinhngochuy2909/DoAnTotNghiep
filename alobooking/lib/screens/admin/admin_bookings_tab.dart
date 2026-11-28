// ignore_for_file: invalid_use_of_protected_member
part of '../admin_screen.dart';

extension _AdminBookingsTab on _AdminScreenState {
  // ==========================================
  // TAB 3: QUẢN LÝ ĐẶT SÂN (BOOKINGS)
  // ==========================================
  Widget _buildBookingsTab() {
    final pendingCount = _bookings.where((b) => b.status == 'Chờ xác nhận').length;
    final confirmedCount = _bookings.where((b) => b.status == 'Đã xác nhận').length;
    final completedCount = _bookings.where((b) => b.status == 'Hoàn thành').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. KPI THỐNG KÊ ĐƠN ĐẶT ──
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
                          Flexible(child: Text('Tổng Đơn Đặt', style: TextStyle(color: AdminUi.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Icon(Icons.calendar_month_outlined, color: AdminUi.info, size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${_bookings.length}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Tất cả lịch đặt trên hệ thống', style: TextStyle(color: AdminUi.info, fontSize: 11)),
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
                          Flexible(child: Text('Chờ Xác Nhận', style: TextStyle(color: AdminUi.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Icon(Icons.hourglass_top_rounded, color: AdminUi.warn, size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$pendingCount', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Cần xử lý ngay', style: TextStyle(color: AdminUi.warn, fontSize: 11, fontWeight: FontWeight.w600)),
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
                          Flexible(child: Text('Đã Xác Nhận / Đang Đá', style: TextStyle(color: AdminUi.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Icon(Icons.check_circle_outline, color: AdminUi.success, size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$confirmedCount', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Lịch thi đấu sẵn sàng', style: TextStyle(color: AdminUi.success, fontSize: 11)),
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
                    border: Border.all(color: AdminUi.violet.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text('Đã Hoàn Thành', style: TextStyle(color: AdminUi.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Icon(Icons.task_alt, color: AdminUi.violet, size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$completedCount', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Đã chơi xong & thu tiền', style: TextStyle(color: AdminUi.violet, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 2. SEARCH & ACTIONS BAR ──
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
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AdminUi.border.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: AdminUi.faint, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: (val) => setState(() => _searchBookingQuery = val),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Tìm theo mã đơn (BK-...), tên khách, SĐT, tên sân...',
                                  hintStyle: TextStyle(color: AdminUi.faint, fontSize: 13),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            if (_searchBookingQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(() => _searchBookingQuery = ''),
                                child: const Icon(Icons.close, color: AdminUi.muted, size: 16),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _openAddWalkinBookingDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminUi.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Đặt Sân Tại Quầy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildGenericChip('Tất cả (${_bookings.length})', 'all', _selectedBookingStatus, (v) => setState(() => _selectedBookingStatus = v)),
                      _buildGenericChip('Chờ xác nhận ($pendingCount)', 'Chờ xác nhận', _selectedBookingStatus, (v) => setState(() => _selectedBookingStatus = v)),
                      _buildGenericChip('Đã xác nhận ($confirmedCount)', 'Đã xác nhận', _selectedBookingStatus, (v) => setState(() => _selectedBookingStatus = v)),
                      _buildGenericChip('Hoàn thành ($completedCount)', 'Hoàn thành', _selectedBookingStatus, (v) => setState(() => _selectedBookingStatus = v)),
                      _buildGenericChip('Đã hủy', 'Đã hủy', _selectedBookingStatus, (v) => setState(() => _selectedBookingStatus = v)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 3. DANH SÁCH LỊCH ĐẶT SÂN ──
          if (_filteredBookings.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.event_busy, color: AdminUi.faint, size: 48),
                  SizedBox(height: 12),
                  Text('Không tìm thấy lịch đặt sân phù hợp', style: TextStyle(color: AdminUi.muted, fontSize: 14)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredBookings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _buildBookingItemCard(_filteredBookings[i]),
            ),
        ],
      ),
    );
  }

  /// Giao dịch của đơn thuộc sân đã có chủ riêng: chủ sân xác nhận tiền/hoàn tiền, admin chỉ xem biên lai.
  bool _paymentOwnerManaged(PaymentItem p) {
    final b = _bookings.where((x) => x.id == p.bookingId).firstOrNull;
    return b != null && BookingApproval.isOwnerManaged(b, _venues);
  }

  Widget _buildBookingItemCard(BookingItem b) {
    Color statusColor = AdminUi.warn;
    if (b.status == 'Đã xác nhận') statusColor = AdminUi.success;
    if (b.status == 'Hoàn thành') statusColor = AdminUi.violet;
    if (b.status == 'Đã hủy') statusColor = AdminUi.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminUi.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminUi.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    b.id,
                    style: const TextStyle(
                        color: AdminUi.violet, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      b.status,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Text(
                b.amount,
                style: const TextStyle(color: AdminUi.accent, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person, color: AdminUi.muted, size: 14),
              const SizedBox(width: 4),
              Text(b.customer,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 12),
              const Icon(Icons.phone, color: AdminUi.muted, size: 14),
              const SizedBox(width: 4),
              Text(b.phone, style: const TextStyle(color: AdminUi.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.sports_tennis, color: AdminUi.muted, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text('${b.venueName} (${b.field})',
                    style: const TextStyle(color: AdminUi.muted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time, color: AdminUi.muted, size: 14),
                  const SizedBox(width: 4),
                  Text('${b.time} • ${b.date}',
                      style: const TextStyle(color: AdminUi.muted, fontSize: 12)),
                ],
              ),
              // Duyệt đơn: chủ sân của sân được đặt duyệt. Admin chỉ duyệt đơn của sân do hệ thống quản lý (chưa có chủ riêng).
              if (BookingApproval.isOwnerManaged(b, _venues))
                if (b.status == 'Chờ xác nhận' || b.status == 'Đã xác nhận')
                  Flexible(
                    child: Container(
                      key: ValueKey('admin-booking-owner-note-${b.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AdminUi.border.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storefront_outlined, size: 14, color: AdminUi.muted),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(BookingApproval.viewOnlyLabel(b, _venues),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: AdminUi.caption),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink()
              else
                Row(
                  children: [
                    if (b.status == 'Chờ xác nhận') ...[
                      IconButton(
                        key: ValueKey('admin-booking-confirm-${b.id}'),
                        icon: const Icon(Icons.check_circle_outline, color: AdminUi.success, size: 22),
                        tooltip: 'Xác nhận đơn',
                        onPressed: () async {
                          final ok = await FirestoreService.confirmBooking(b.id);
                          if (!mounted) return;
                          if (!ok) {
                            _showToast('Không xác nhận được đơn ${b.id}. Kiểm tra kết nối rồi thử lại.', isError: true);
                            return;
                          }
                          setState(() {
                            b.status = 'Đã xác nhận';
                            for (final p in _payments) {
                              if (p.bookingId == b.id && p.status.toLowerCase().contains('xử lý')) p.status = 'Thành công';
                            }
                          });
                          _showToast('Đã xác nhận đơn ${b.id} và đối soát tiền chuyển khoản!');
                        },
                      ),
                      IconButton(
                        key: ValueKey('admin-booking-cancel-${b.id}'),
                        icon: const Icon(Icons.cancel_outlined, color: AdminUi.danger, size: 22),
                        tooltip: 'Hủy đơn',
                        onPressed: () async {
                          final ok = await FirestoreService.updateBookingStatus(b.id, 'Đã hủy');
                          if (!mounted) return;
                          if (!ok) {
                            _showToast('Không hủy được đơn ${b.id}. Kiểm tra kết nối rồi thử lại.', isError: true);
                            return;
                          }
                          setState(() => b.status = 'Đã hủy');
                          _showToast('Đã hủy đơn ${b.id}!', isError: true);
                        },
                      ),
                    ],
                    if (b.status == 'Đã xác nhận')
                      IconButton(
                        key: ValueKey('admin-booking-complete-${b.id}'),
                        icon: const Icon(Icons.done_all, color: AdminUi.violet, size: 22),
                        tooltip: 'Đánh dấu hoàn thành',
                        onPressed: () async {
                          final ok = await FirestoreService.updateBookingStatus(b.id, 'Hoàn thành');
                          if (!mounted) return;
                          if (!ok) {
                            _showToast('Không cập nhật được đơn ${b.id}. Kiểm tra kết nối rồi thử lại.', isError: true);
                            return;
                          }
                          setState(() => b.status = 'Hoàn thành');
                          _showToast('Đơn ${b.id} đã hoàn thành!');
                        },
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ADD WALKIN BOOKING DIALOG ---
  void _openAddWalkinBookingDialog() {
    final custCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String venueName = _venues.isNotEmpty ? _venues[0].name : '';
    final amountCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: BookingSlots.formatDate(DateTime.now()));
    final courtCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminUi.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đặt Sân Hộ Khách (đã nhận chuyển khoản)', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogTextField('Tên Khách Hàng *', custCtrl, 'Nguyễn Văn A'),
              const SizedBox(height: 10),
              _dialogTextField('Số Điện Thoại *', phoneCtrl, '0901234567'),
              const SizedBox(height: 10),
              _dialogTextField('Ngày Đặt (dd/MM/yyyy)', dateCtrl, '17/11/2026'),
              const SizedBox(height: 10),
              _dialogTextField('Khung Giờ *', timeCtrl, '18:00 - 19:00'),
              const SizedBox(height: 10),
              _dialogTextField('Sân Số', courtCtrl, '1'),
              const SizedBox(height: 10),
              _dialogTextField('Tổng Tiền Đã Chuyển Khoản *', amountCtrl, '200.000 đ'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AdminUi.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (custCtrl.text.trim().isEmpty ||
                  phoneCtrl.text.trim().isEmpty ||
                  timeCtrl.text.trim().isEmpty ||
                  venueName.isEmpty ||
                  AdminStats.parseMoney(amountCtrl.text) <= 0 ||
                  BookingSlots.parseDate(dateCtrl.text) == null ||
                  BookingSlots.parseRanges(timeCtrl.text).isEmpty) {
                _showToast('Nhập đủ tên, số điện thoại, ngày (dd/MM/yyyy), khung giờ (18:00 - 19:00) và số tiền!', isError: true);
                return;
              }
              final venue = _venues.firstWhere((v) => v.name == venueName);
              final courtNo = (int.tryParse(courtCtrl.text.trim()) ?? 1).clamp(1, venue.courts);
              final fieldName = '${Venue.courtLabel(venue.type)} $courtNo';
              final bookingId = 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
              final newBooking = BookingItem(
                id: bookingId,
                customer: custCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                venueName: venueName,
                field: fieldName,
                time: timeCtrl.text.trim(),
                date: dateCtrl.text.trim(),
                amount: amountCtrl.text.trim(),
                status: 'Đã xác nhận',
                paymentMethod: 'Chuyển khoản VietQR',
              );
              await FirestoreService.createBooking(
                customer: newBooking.customer,
                phone: newBooking.phone,
                venueName: newBooking.venueName,
                field: newBooking.field,
                time: newBooking.time,
                date: newBooking.date,
                amount: newBooking.amount,
                paymentMethod: newBooking.paymentMethod,
                ownerId: _venues.where((v) => v.name == newBooking.venueName).map((v) => v.ownerId).firstOrNull ?? 'admin_super_01',
                status: 'Đã xác nhận', // quản trị viên chỉ tạo đơn này sau khi đã nhận chuyển khoản
                paid: true,
              );
              if (!mounted || !ctx.mounted) return;
              setState(() => _bookings.insert(0, newBooking));
              Navigator.pop(ctx);
              _showToast('Đã tạo đơn đặt sân tại quầy $bookingId thành công!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminUi.accent),
            child: const Text('Xác Nhận Đặt'),
          ),
        ],
      ),
    );
  }
}
