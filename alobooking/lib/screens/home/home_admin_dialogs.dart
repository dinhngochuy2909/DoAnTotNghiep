// ignore_for_file: invalid_use_of_protected_member
part of '../home_screen.dart';

extension _HomeAdminDialogs on _HomeScreenState {
  // ==========================================
  // ANALYTICS & STATS DIALOG (THỐNG KÊ CHI TIẾT)
  // ==========================================
  void _showAnalyticsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(22),
          child: FutureBuilder<List<BookingItem>>(
            future: FirestoreService.getBookings(),
            builder: (context, snap) {
              final header = Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics, color: Color(0xFF0EA5E9), size: 24),
                      SizedBox(width: 10),
                      Text(
                        'BÁO CÁO & THỐNG KÊ DOANH THU',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    splashRadius: 18,
                  ),
                ],
              );
              if (!snap.hasData) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    header,
                    const Divider(height: 20),
                    const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))),
                  ],
                );
              }

              // Số liệu thật: admin xem toàn hệ thống, chủ sân chỉ xem các sân của mình
              final venues = _isAdmin ? _allVenues : _allVenues.where(_isMyVenue).toList();
              final names = venues.map((v) => v.name.trim().toLowerCase()).toSet();
              final bookings = snap.data!
                  .where((b) => _isAdmin || names.contains(b.venueName.trim().toLowerCase()))
                  .toList();
              final st = AdminStats.compute(bookings: bookings, venues: venues, period: AdminPeriod.month);
              final rated = venues.where((v) => v.rating > 0).toList();
              final avgRating = rated.isEmpty ? null : rated.fold<double>(0, (a, v) => a + v.rating) / rated.length;
              final sports = st.revenueBySport.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final totalRev = sports.fold<int>(0, (a, e) => a + e.value);
              final peak = st.slots.fold<SlotShare?>(null, (m, e) => (m == null || e.orders > m.orders) ? e : m);
              const colors = [Color(0xFF10B981), Color(0xFF38BDF8), Color(0xFFFBBF24), Color(0xFFA855F7), Color(0xFFEC4899)];

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const Divider(height: 20),
                    Text('30 ngày qua • ${bookings.length} đơn đặt sân trong dữ liệu',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildMetricTile('Doanh thu', AdminStats.fmtCompact(st.revenue), const Color(0xFF0EA5E9))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMetricTile('Đơn đặt sân', '${st.orders}', const Color(0xFF38BDF8))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            'Tỷ lệ hủy',
                            st.cancelRate == null ? '—' : '${(st.cancelRate! * 100).toStringAsFixed(1)}%',
                            const Color(0xFFFBBF24),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            'Đánh giá TB',
                            avgRating == null ? '—' : '${avgRating.toStringAsFixed(2)} ★',
                            const Color(0xFFA855F7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Tỷ trọng doanh thu theo môn:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 10),
                    if (totalRev == 0)
                      const Text('Chưa có doanh thu (đơn đã xác nhận) trong 30 ngày qua.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
                    else
                      for (var k = 0; k < sports.length; k++) ...[
                        if (k > 0) const SizedBox(height: 8),
                        _buildSportPercentBar(
                          sports[k].key,
                          sports[k].value / totalRev,
                          '${(sports[k].value / totalRev * 100).round()}% (${AdminStats.fmtCompact(sports[k].value)})',
                          colors[k % colors.length],
                        ),
                      ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_filled, color: Color(0xFF0EA5E9), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (peak == null || peak.orders == 0)
                                  ? 'Chưa có đơn đặt sân trong 30 ngày qua.'
                                  : 'Khung giờ nhiều đơn nhất: ${peak.label} (${peak.orders} đơn).',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }


  Widget _buildMetricTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildSportPercentBar(String label, double percent, String details, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            Text(details, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // BOOKINGS MANAGEMENT DIALOG (QUẢN LÝ ĐƠN ĐẶT SÂN)
  // ==========================================
  void _showBookingsDialog() async {
    final all = await FirestoreService.getBookings();

    if (!mounted) return;
    // Chủ sân chỉ thấy và duyệt đơn của sân mình; admin thấy tất cả nhưng chỉ duyệt đơn của sân do hệ thống quản lý.
    final role = AuthService.currentUser?.role ?? '';
    final uid = AuthService.currentUser?.uid ?? '';
    final bookings = role == 'owner' ? all.where((b) => BookingApproval.approverId(b, _allVenues) == uid).toList() : all;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            child: Container(
              width: 650,
              constraints: const BoxConstraints(maxHeight: 650),
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long, color: Color(0xFF0EA5E9), size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'QUẢN LÝ ĐƠN ĐẶT SÂN (${bookings.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: bookings.isEmpty
                        ? const Center(
                            child: Text('Chưa có đơn đặt sân nào.', style: TextStyle(color: Color(0xFF64748B))),
                          )
                        : ListView.separated(
                            itemCount: bookings.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (bCtx, idx) {
                              final item = bookings[idx];
                              final isConfirmed = item.status == 'Đã xác nhận';
                              final isCancelled = item.status == 'Đã hủy';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isConfirmed
                                          ? const Color(0xFF10B981).withOpacity(0.15)
                                          : (isCancelled
                                              ? const Color(0xFFEF4444).withOpacity(0.15)
                                              : const Color(0xFFF59E0B).withOpacity(0.15)),
                                      child: Icon(
                                        isConfirmed
                                            ? Icons.check
                                            : (isCancelled ? Icons.cancel_outlined : Icons.schedule),
                                        color: isConfirmed
                                            ? const Color(0xFF10B981)
                                            : (isCancelled ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(item.customer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              const SizedBox(width: 6),
                                              Text('(${item.phone})', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item.venueName} • ${item.time} • ${item.date}',
                                            style: const TextStyle(color: Color(0xFF334155), fontSize: 11),
                                          ),
                                          Text(
                                            'Tổng tiền: ${item.amount} (${item.paymentMethod})',
                                            style: const TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Status & Actions
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isConfirmed
                                                ? const Color(0xFF10B981).withOpacity(0.15)
                                                : (isCancelled
                                                    ? const Color(0xFFEF4444).withOpacity(0.15)
                                                    : const Color(0xFFF59E0B).withOpacity(0.15)),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.status,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isConfirmed
                                                  ? const Color(0xFF10B981)
                                                  : (isCancelled ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        if (!isConfirmed && !isCancelled && BookingApproval.canApprove(role: role, uid: uid, b: item, venues: _allVenues))
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () async {
                                                  final ok = await FirestoreService.confirmBooking(item.id);
                                                  if (!ok) return;
                                                  setDialogState(() {
                                                    item.status = 'Đã xác nhận';
                                                  });
                                                },
                                                child: const Text('Duyệt', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
                                              ),
                                              const SizedBox(width: 8),
                                              InkWell(
                                                onTap: () async {
                                                  final ok = await FirestoreService.updateBookingStatus(item.id, 'Đã hủy');
                                                  if (!ok) return;
                                                  setDialogState(() {
                                                    item.status = 'Đã hủy';
                                                  });
                                                },
                                                child: const Text('Hủy', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
                                              ),
                                            ],
                                          )
                                        else if (!isConfirmed && !isCancelled)
                                          Text(
                                            BookingApproval.viewOnlyLabel(item, _allVenues),
                                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
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
  // SYNC VENUES TO FIRESTORE (ĐỒNG BỘ CLOUD)
  // ==========================================
  void _syncToFirestore() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Đang đồng bộ dữ liệu sân lên Firestore...'),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );

    final count = await FirestoreService.syncVenues(_allVenues);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? '☁️ Đã đồng bộ thành công $count/${_allVenues.length} sân lên Firestore alobooking-b2484!'
                : '⚠️ Không thể kết nối Firestore, dữ liệu đang lưu cục bộ.',
          ),
          backgroundColor: count > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
    }
  }
}
