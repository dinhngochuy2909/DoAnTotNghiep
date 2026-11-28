// ignore_for_file: invalid_use_of_protected_member
part of '../admin_screen.dart';

extension _AdminPaymentsTab on _AdminScreenState {
  // ==========================================
  // TAB 5: THANH TOÁN & DOANH THU (PAYMENTS)
  // ==========================================
  Widget _buildPaymentKpis() {
    int total = 0, online = 0, awaiting = 0, okCount = 0, processing = 0, refunded = 0;
    for (final p in _payments) {
      final st = p.status.toLowerCase();
      if (st.contains('hoàn')) {
        refunded++;
        continue;
      }
      if (st.contains('xử lý')) {
        processing++;
        awaiting += AdminStats.parseMoney(p.amount);
        continue;
      }
      final amt = AdminStats.parseMoney(p.amount);
      total += amt;
      okCount++;
      // Giao dịch tiền mặt cũ (nếu còn trong dữ liệu) vẫn nằm trong tổng đã thu, nhưng không tính vào chuyển khoản
      if (!p.method.toLowerCase().contains('tiền mặt')) online += amt;
    }
    String share(int v) => total == 0 ? 'Chưa có giao dịch thành công' : '${(v / total * 100).toStringAsFixed(1)}% tổng đã thu';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: KpiTile(
            label: 'Tổng đã thu',
            value: AdminStats.fmtMoney(total),
            icon: Icons.account_balance_wallet_outlined,
            color: AdminUi.accent,
            footnote: '$okCount thành công • $processing đang xử lý • $refunded hoàn tiền',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiTile(
            label: 'Đã nhận qua chuyển khoản / ví',
            value: AdminStats.fmtMoney(online),
            icon: Icons.qr_code_2_rounded,
            color: AdminUi.info,
            footnote: share(online),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiTile(
            label: 'Chờ đối soát chuyển khoản',
            value: AdminStats.fmtMoney(awaiting),
            icon: Icons.hourglass_top_rounded,
            color: AdminUi.warn,
            footnote: processing == 0 ? 'Không có giao dịch chờ' : '$processing giao dịch chờ xác nhận đã nhận tiền',
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentsTab() {
    final filtered = _payments.where((p) {
      final q = _searchPaymentQuery.toLowerCase().trim();
      final matchQuery = q.isEmpty ||
          p.id.toLowerCase().contains(q) ||
          p.bookingId.toLowerCase().contains(q) ||
          p.customer.toLowerCase().contains(q) ||
          p.bankRef.toLowerCase().contains(q);

      final matchMethod = _selectedPaymentMethod == 'all' || p.method.contains(_selectedPaymentMethod);
      return matchQuery && matchMethod;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TỔNG QUAN THU NGÂN (tính từ giao dịch thật)
          _buildPaymentKpis(),
          const SizedBox(height: 16),

          // 2. SEARCH & FILTER
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AdminUi.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminUi.border.withOpacity(0.5)),
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
                                onChanged: (val) => setState(() => _searchPaymentQuery = val),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Tìm theo mã PAY, mã đơn BK, khách, mã ngân hàng...',
                                  hintStyle: TextStyle(color: AdminUi.faint, fontSize: 13),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            if (_searchPaymentQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(() => _searchPaymentQuery = ''),
                                child: const Icon(Icons.close, color: AdminUi.muted, size: 16),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _openAddPaymentDialog,
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('Tạo Phiếu Thu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
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
                // Method Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildGenericChip('Tất cả (${_payments.length})', 'all', _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v)),
                      const SizedBox(width: 6),
                      _buildGenericChip('Chuyển khoản', 'VietQR', _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v)),
                      const SizedBox(width: 6),
                      _buildGenericChip('Ví MoMo', 'MoMo', _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v)),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. DANH SÁCH GIAO DỊCH
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.credit_card_off, color: AdminUi.faint, size: 48),
                  SizedBox(height: 12),
                  Text('Không tìm thấy giao dịch nào', style: TextStyle(color: AdminUi.muted, fontSize: 14)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final p = filtered[i];

                Color statusColor = AdminUi.success; // Success
                if (p.status == 'Đang xử lý') statusColor = AdminUi.warn;
                else if (p.status == 'Đã hoàn tiền') statusColor = AdminUi.danger;

                IconData methodIcon = Icons.qr_code;
                if (p.method.contains('MoMo')) methodIcon = Icons.account_balance_wallet_outlined;
                else if (p.method.contains('Tiền mặt')) methodIcon = Icons.payments_outlined;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AdminUi.border.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      // Method icon badge
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AdminUi.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AdminUi.border),
                        ),
                        child: Icon(methodIcon, color: AdminUi.info, size: 20),
                      ),
                      const SizedBox(width: 12),

                      // Thông tin giao dịch
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  p.id,
                                  style: const TextStyle(color: AdminUi.info, fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AdminUi.border,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('Đơn ${p.bookingId}', style: const TextStyle(color: AdminUi.muted, fontSize: 10.5)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${p.customer} • ${p.method}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${p.time} • Ref: ${p.bankRef}',
                              style: const TextStyle(color: AdminUi.faint, fontSize: 11),
                            ),
                          ],
                        ),
                      ),

                      // Số tiền & Trạng thái
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            p.amount,
                            style: const TextStyle(color: AdminUi.accent, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withOpacity(0.5)),
                            ),
                            child: Text(
                              p.status,
                              style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),

                      // Actions
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: AdminUi.muted, size: 20),
                        color: AdminUi.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onSelected: (action) {
                          if (action == 'success') {
                            setState(() => p.status = 'Thành công');
                            FirestoreService.updatePaymentStatus(p.id, 'Thành công');
                            _showToast('Đã xác nhận thanh toán ${p.id}!');
                          } else if (action == 'refund') {
                            setState(() => p.status = 'Đã hoàn tiền');
                            FirestoreService.updatePaymentStatus(p.id, 'Đã hoàn tiền');
                            _showToast('Đã hoàn tiền giao dịch ${p.id}!', isError: true);
                          } else if (action == 'receipt') {
                            _openPaymentReceiptDialog(p);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'receipt',
                            child: Row(
                              children: [
                                Icon(Icons.receipt_outlined, color: AdminUi.info, size: 16),
                                SizedBox(width: 8),
                                Text('Xem biên lai', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          if (p.status != 'Thành công' && !_paymentOwnerManaged(p))
                            const PopupMenuItem(
                              value: 'success',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: AdminUi.success, size: 16),
                                  SizedBox(width: 8),
                                  Text('Đánh dấu thành công', style: TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              ),
                            ),
                          if (p.status != 'Đã hoàn tiền' && !_paymentOwnerManaged(p))
                            const PopupMenuItem(
                              value: 'refund',
                              child: Row(
                                children: [
                                  Icon(Icons.replay, color: AdminUi.danger, size: 16),
                                  SizedBox(width: 8),
                                  Text('Hoàn tiền giao dịch', style: TextStyle(color: AdminUi.danger, fontSize: 13)),
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

  Widget _buildGenericChip(String label, String key, String currentSelected, ValueChanged<String> onSelected) {
    final selected = currentSelected == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => onSelected(key),
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
                  : AdminUi.border.withOpacity(0.6),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AdminUi.accent.withOpacity(0.35),
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

  void _openAddPaymentDialog() {
    final bkCtrl = TextEditingController();
    final custCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    String selectedMethod = 'VietQR Pro';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          return AlertDialog(
            backgroundColor: AdminUi.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.add_card, color: AdminUi.accent),
                SizedBox(width: 8),
                Text('Tạo Phiếu Thu / Thu Ngân', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogTextField('Mã Đơn Đặt Sân *', bkCtrl, 'VD: BK-123456'),
                    const SizedBox(height: 12),
                    _dialogTextField('Tên Khách Hàng *', custCtrl, 'VD: Trần Văn B'),
                    const SizedBox(height: 12),
                    _dialogTextField('Số Tiền Đã Nhận *', amountCtrl, 'VD: 300.000đ'),
                    const SizedBox(height: 12),
                    _dialogTextField('Mã Giao Dịch Ngân Hàng', refCtrl, 'Mã tham chiếu trên sao kê'),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Phương Thức Thanh Toán', style: TextStyle(color: AdminUi.muted, fontSize: 12)),
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
                              value: selectedMethod,
                              isExpanded: true,
                              dropdownColor: AdminUi.bg,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: const [
                                DropdownMenuItem(value: 'VietQR Pro', child: Text('Chuyển khoản ngân hàng (VietQR)')),
                                DropdownMenuItem(value: 'Ví MoMo', child: Text('Ví MoMo')),
                                DropdownMenuItem(value: 'VNPay QR', child: Text('VNPay QR')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedMethod = val);
                              },
                            ),
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
                  if (bkCtrl.text.trim().isEmpty || custCtrl.text.trim().isEmpty || AdminStats.parseMoney(amountCtrl.text) <= 0) {
                    _showToast('Nhập mã đơn, tên khách và số tiền đã nhận!', isError: true);
                    return;
                  }
                  final now = DateTime.now();
                  final newPay = PaymentItem(
                    id: 'PAY-${now.millisecondsSinceEpoch.toString().substring(7)}',
                    bookingId: bkCtrl.text.trim(),
                    customer: custCtrl.text.trim(),
                    amount: amountCtrl.text.trim(),
                    method: selectedMethod,
                    time: '${BookingSlots.formatDate(now)} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                    status: 'Thành công',
                    bankRef: refCtrl.text.trim(),
                  );
                  setState(() => _payments.insert(0, newPay));
                  FirestoreService.addPayment(newPay);
                  _showToast('Đã ghi nhận thanh toán ${newPay.id} thành công!');
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminUi.accent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Xác Nhận Thu Tiền'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openPaymentReceiptDialog(PaymentItem p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminUi.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.receipt, color: AdminUi.info),
            SizedBox(width: 8),
            Text('Biên Lai Thanh Toán', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminUi.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminUi.border),
                ),
                child: Column(
                  children: [
                    const Text('ALOBOOKING - XÁC NHẬN THANH TOÁN', style: TextStyle(color: AdminUi.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 12),
                    Text(p.amount, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(p.status, style: const TextStyle(color: AdminUi.success, fontSize: 12, fontWeight: FontWeight.bold)),
                    const Divider(color: AdminUi.border, height: 24),
                    _receiptRow('Mã GD:', p.id),
                    _receiptRow('Mã Đơn:', p.bookingId),
                    _receiptRow('Khách Hàng:', p.customer),
                    _receiptRow('Phương Thức:', p.method),
                    _receiptRow('Thời Gian:', p.time),
                    _receiptRow('Mã Ref Bank:', p.bankRef),
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
              _showToast('Đang gửi biên lai điện tử cho khách hàng...');
            },
            icon: const Icon(Icons.print, size: 16),
            label: const Text('In / Gửi Biên Lai'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminUi.info,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AdminUi.muted, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _dialogTextField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: const TextStyle(color: AdminUi.muted, fontSize: 12)),
          const SizedBox(height: 4),
        ],
        Container(
          decoration: BoxDecoration(
            color: AdminUi.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminUi.border),
          ),
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AdminUi.faint, fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
