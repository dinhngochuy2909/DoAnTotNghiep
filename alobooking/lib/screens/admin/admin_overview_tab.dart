// ignore_for_file: invalid_use_of_protected_member
part of '../admin_screen.dart';

extension _AdminOverviewTab on _AdminScreenState {
  /// Công tắc, biển cảnh báo và bảng đối chiếu đáp án của chế độ mô phỏng (đặt trên thẻ dự báo).
  Widget _simulationPanel(BookingCountReport? report) {
    final sim = _sim;
    final on = _useSimulated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Switch(
              key: const ValueKey('admin-forecast-sim-toggle'),
              value: on,
              onChanged: _toggleSimulated,
              activeThumbColor: AdminUi.warn,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('Thử với dữ liệu mô phỏng', style: TextStyle(color: AdminUi.text, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            if (_countBusy)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AdminUi.muted)),
          ],
        ),
        if (on)
          Container(
            key: const ValueKey('admin-forecast-sim-banner'),
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6, bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AdminUi.warn.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminUi.warn.withValues(alpha: 0.6)),
            ),
            child: Text(
              sim == null
                  ? 'ĐANG DÙNG DỮ LIỆU MÔ PHỎNG (không phải đơn đặt sân thật). Đang nạp dữ liệu…'
                  : 'ĐANG DÙNG DỮ LIỆU MÔ PHỎNG: ${sim.retained} đơn do chương trình tự sinh (${sim.days} ngày, ${sim.from} đến ${sim.to}) '
                      'trộn với đơn thật đang có. Đây KHÔNG phải đơn đặt sân thật, chỉ để minh họa cách mô hình học và kiểm tra nó có tìm lại được '
                      'quy luật đã gài hay không. Doanh thu và số đơn ở các thẻ khác không bị ảnh hưởng.',
              style: const TextStyle(color: AdminUi.text, fontSize: 12, height: 1.45),
            ),
          ),
        if (on && sim != null && report != null && report.model.hasData) ...[
          InkWell(
            key: const ValueKey('admin-forecast-truth-toggle'),
            onTap: () => setState(() => _showTruth = !_showTruth),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(_showTruth ? Icons.expand_less : Icons.expand_more, size: 18, color: AdminUi.muted),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text('Mô hình có tìm lại được đáp án đã gài không?',
                        style: TextStyle(color: AdminUi.accent, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
          if (_showTruth)
            Container(
              key: const ValueKey('admin-forecast-truth-table'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: AdminUi.border.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mức nền: đáp án ${math.exp(sim.truth['intercept'] ?? 0).toStringAsFixed(1)} đơn/ngày, mô hình học ${report.model.intercept.toStringAsFixed(1)}.',
                    style: AdminUi.caption,
                  ),
                  const SizedBox(height: 4),
                  for (final c in report.model.coefficientInfo)
                    if (sim.truth.containsKey(c.key))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '${c.label}: đáp án x${math.exp(sim.truth[c.key]!).toStringAsFixed(2)} · giả định ban đầu x${math.exp(c.prior).toStringAsFixed(2)} · '
                          'học được x${math.exp(c.learned).toStringAsFixed(2)} (dữ liệu ${(c.dataShare * 100).round()}%)',
                          style: AdminUi.caption,
                        ),
                      ),
                  const SizedBox(height: 4),
                  Text(
                    'x1.00 là không ảnh hưởng. Yếu tố ít bằng chứng (như một kỳ Tết) hoặc trùng nhau (nóng và mùa hè) có thể lệch khá xa đáp án.',
                    style: AdminUi.caption,
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  // ==========================================
  // TAB 1: TỔNG QUAN (số liệu tính từ đơn đặt thật)
  // ==========================================
  AdminStats get _stats => AdminStats.compute(
        bookings: _bookings,
        venues: _venues,
        period: AdminPeriod.byKey(_selectedPeriod),
      );

  Widget _twoCol(bool wide, Widget left, Widget right, {int l = 1, int r = 1}) {
    if (!wide) return Column(children: [left, const SizedBox(height: 16), right]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: l, child: left),
        const SizedBox(width: 16),
        Expanded(flex: r, child: right),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    final s = _stats;
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 980;
      return SingleChildScrollView(
        padding: EdgeInsets.all(c.maxWidth >= 760 ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewHeader(s),
            const SizedBox(height: 16),
            if (_loadError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: AdminUi.card(color: AdminUi.danger.withValues(alpha: 0.10), borderColor: AdminUi.danger.withValues(alpha: 0.4)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AdminUi.danger, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_loadError!, style: const TextStyle(color: AdminUi.text, fontSize: 13))),
                    TextButton(onPressed: () => _loadData(force: true), child: const Text('Thử lại')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildKpiRow(s),
            const SizedBox(height: 16),
            _twoCol(wide, _buildRevenueCard(s), _buildSportShareCard(s), l: 3, r: 2),
            const SizedBox(height: 16),
            _twoCol(wide, _buildSlotsCard(s), _buildTopVenuesCard(s)),
            const SizedBox(height: 16),
            _twoCol(wide, _buildForecastCard(), _buildAttentionCard(s)),
            const SizedBox(height: 16),
            Text(
              'Nguồn: ${_bookings.length} đơn đặt sân trên Firestore. Doanh thu chỉ gồm đơn đã xác nhận hoặc hoàn thành; '
              'kỳ thống kê tính theo ngày chơi. Mức thay đổi chỉ hiển thị khi kỳ trước có dữ liệu.',
              style: AdminUi.caption,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildOverviewHeader(AdminStats s) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        SegmentedTabs(
          items: [for (final p in AdminPeriod.all) (p.key, p.label)],
          selected: _selectedPeriod,
          onChanged: (k) => setState(() => _selectedPeriod = k),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_AdminScreenState._dm(s.from)} – ${_AdminScreenState._dm(s.to)}', style: AdminUi.caption),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: s.toCsv()));
                if (mounted) _showToast('Đã sao chép báo cáo CSV. Dán vào Excel hoặc Google Sheets.');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminUi.text,
                side: const BorderSide(color: AdminUi.border),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              label: const Text('Sao chép CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiRow(AdminStats s) {
    final tiles = <Widget>[
      KpiTile(
        label: 'Doanh thu',
        value: AdminStats.fmtMoney(s.revenue),
        icon: Icons.payments_outlined,
        color: AdminUi.accent,
        change: AdminStats.change(s.revenue, s.prevRevenue),
        footnote: s.hasData ? 'Chưa có kỳ trước để so sánh' : 'Chưa có đơn trong kỳ',
      ),
      KpiTile(
        label: 'Đơn đặt sân',
        value: '${s.orders}',
        icon: Icons.event_available_outlined,
        color: AdminUi.info,
        change: AdminStats.change(s.orders, s.prevOrders),
        footnote: '${s.pending} đơn đang chờ xác nhận',
      ),
      KpiTile(
        label: 'Tỷ lệ hủy',
        value: s.cancelRate == null ? '—' : '${(s.cancelRate! * 100).toStringAsFixed(1)}%',
        icon: Icons.event_busy_outlined,
        color: AdminUi.warn,
        invertGood: true,
        change: (s.cancelRate == null || s.prevCancelRate == null)
            ? null
            : AdminStats.change(s.cancelRate! * 100, s.prevCancelRate! * 100),
        footnote: '${s.cancelled} đơn hủy trong kỳ',
      ),
      KpiTile(
        label: 'Khách đặt sân',
        value: '${s.customers}',
        icon: Icons.people_outline_rounded,
        color: AdminUi.violet,
        change: AdminStats.change(s.customers, s.prevCustomers),
        footnote: s.orders == 0 ? 'Chưa có đơn trong kỳ' : 'TB ${AdminStats.fmtMoney(s.avgOrderValue)}/đơn',
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
      final w = (c.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }

  Widget _buildRevenueCard(AdminStats s) {
    final empty = s.series.every((b) => b.revenue == 0 && b.orders == 0);
    return AdminCard(
      title: 'Doanh thu theo thời gian',
      subtitle: s.period.days <= 1
          ? 'Theo giờ bắt đầu của ca đặt'
          : (s.period.days <= 31 ? 'Theo ngày chơi' : 'Theo tháng'),
      trailing: Text(AdminStats.fmtCompact(s.revenue),
          style: const TextStyle(color: AdminUi.text, fontSize: 20, fontWeight: FontWeight.w700)),
      child: empty
          ? const EmptyHint(icon: Icons.bar_chart_rounded, text: 'Chưa có đơn nào trong kỳ này.\nThử chọn kỳ dài hơn.')
          : MiniBarChart(
              values: [for (final b in s.series) b.revenue.toDouble()],
              labels: [for (final b in s.series) b.label],
              tooltips: [
                for (final b in s.series) '${b.tooltip}\n${AdminStats.fmtMoney(b.revenue)} • ${b.orders} đơn'
              ],
            ),
    );
  }

  Widget _buildSportShareCard(AdminStats s) {
    final entries = s.revenueBySport.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (a, e) => a + e.value);
    return AdminCard(
      title: 'Doanh thu theo môn',
      subtitle: 'Tỷ trọng trong kỳ',
      child: total == 0
          ? const EmptyHint(icon: Icons.donut_large_rounded, text: 'Chưa có doanh thu trong kỳ này.')
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 116,
                  height: 116,
                  child: CustomPaint(
                    painter: DonutChartPainter(
                      slices: [for (final e in entries) e.value / total],
                      colors: [for (final e in entries) AdminUi.sportColor(e.key)],
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      for (final e in entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(color: AdminUi.sportColor(e.key), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(e.key,
                                    style: const TextStyle(color: AdminUi.text, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Text('${(e.value / total * 100).round()}%',
                                  style: const TextStyle(color: AdminUi.text, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 56,
                                child: Text(AdminStats.fmtCompact(e.value),
                                    textAlign: TextAlign.right, style: AdminUi.caption),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSlotsCard(AdminStats s) {
    final maxOrders = s.slots.fold<int>(0, (a, e) => e.orders > a ? e.orders : a);
    return AdminCard(
      title: 'Khung giờ được đặt nhiều nhất',
      subtitle: 'Số đơn theo giờ bắt đầu ca',
      child: maxOrders == 0
          ? const EmptyHint(icon: Icons.schedule_rounded, text: 'Chưa có đơn nào trong kỳ này.')
          : Column(
              children: [
                for (final sl in s.slots)
                  HBarRow(
                    label: sl.label,
                    valueText: '${sl.orders} đơn',
                    ratio: sl.orders / maxOrders,
                    color: sl.orders == maxOrders ? AdminUi.warn : AdminUi.info,
                    note: sl.orders == maxOrders ? 'Cao điểm trong kỳ' : null,
                  ),
              ],
            ),
    );
  }

  Widget _buildTopVenuesCard(AdminStats s) {
    return AdminCard(
      title: 'Cụm sân doanh thu cao nhất',
      subtitle: 'Top 5 trong kỳ',
      trailing: TextButton(
        onPressed: () => setState(() => _selectedNavIndex = 1),
        child: const Text('Quản lý sân'),
      ),
      child: s.topVenues.isEmpty
          ? const EmptyHint(icon: Icons.stadium_outlined, text: 'Chưa có doanh thu trong kỳ này.')
          : Column(
              children: [
                for (var i = 0; i < s.topVenues.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AdminUi.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text('${i + 1}', style: const TextStyle(color: AdminUi.faint, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.topVenues[i].name,
                                  style: const TextStyle(color: AdminUi.text, fontSize: 13, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                '${s.topVenues[i].district != null ? '${s.topVenues[i].district} • ' : ''}${s.topVenues[i].orders} đơn',
                                style: AdminUi.caption,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(AdminStats.fmtMoney(s.topVenues[i].revenue),
                            style: const TextStyle(color: AdminUi.text, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildForecastCard() {
    final model = _demandModel;
    final report = _countReport;
    final wx = BookingCountService.forecastWeather(_dailyWeather);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final days = [
      for (var i = 0; i < 7; i++)
        model.forecastDay(
          start.add(Duration(days: i)),
          rain: _rainByDate[VnCalendar.key(start.add(Duration(days: i)))],
          volume: report?.volumeFor(start.add(Duration(days: i)), weather: wx[VnCalendar.key(start.add(Duration(days: i)))]),
        ),
    ];
    Color levelColor(String l) {
      switch (l) {
        case 'RẤT CAO':
        case 'CAO':
          return AdminUi.success;
        case 'BÌNH THƯỜNG':
          return AdminUi.info;
        default:
          return AdminUi.warn;
      }
    }

    return AdminCard(
      title: _useSimulated ? 'Dự báo 7 ngày tới (dữ liệu mô phỏng)' : 'Dự báo 7 ngày tới',
      subtitle: report != null && report.model.hasData
          ? 'Số đơn dự kiến theo thứ, ngày lễ, mùa, mưa, nhiệt độ. Bấm một ngày để xem lý do'
          : 'Nhu cầu và tỷ lệ hủy dự kiến (mô hình thống kê)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _simulationPanel(report),
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AdminUi.border),
            InkWell(
              onTap: () => setState(() => _forecastOpenDay = _forecastOpenDay == i ? null : i),
              child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${VnWeekday.name(days[i].date)} ${_AdminScreenState._dm(days[i].date)}',
                            style: const TextStyle(color: AdminUi.text, fontSize: 13, fontWeight: FontWeight.w500)),
                        if (days[i].holiday != null || days[i].weekend || (days[i].rain?.prob ?? 0) >= 50)
                          Text(
                            [
                              if (days[i].holiday != null) days[i].holiday!.name else if (days[i].weekend) 'Cuối tuần',
                              if ((days[i].rain?.prob ?? 0) >= 50) 'mưa ${days[i].rain!.prob.round()}%',
                            ].join(' • '),
                            style: AdminUi.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: StatusPill(days[i].level[0] + days[i].level.substring(1).toLowerCase(), levelColor(days[i].level)),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          days[i].expectedBookings == null ? '—' : '~${days[i].expectedBookings!.round()} đơn',
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: AdminUi.text, fontSize: 13),
                        ),
                        if (days[i].low != null && days[i].high != null)
                          Text('${days[i].low!.round()}–${days[i].high!.round()}', style: AdminUi.caption),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('hủy ${(days[i].cancelRate * 100).round()}%',
                        textAlign: TextAlign.right, style: const TextStyle(color: AdminUi.muted, fontSize: 13)),
                  ),
                ],
              ),
              ),
            ),
            if (_forecastOpenDay == i)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminUi.border.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final f in days[i].factors)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $f', style: AdminUi.caption),
                        ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 10),
          Text(
            report != null && report.model.hasData
                ? '${report.honestyNote} Mưa, nhiệt độ, mùa và ngày lễ chưa đủ dữ liệu để học thì đang theo giả định chuyên môn '
                    '(ghi rõ ở từng yếu tố). Mọi đơn mới đều chuyển khoản trước nên tỉ lệ hủy được dự báo theo nhóm trả trước.'
                : 'Học từ ${model.n} đơn lịch sử. Mọi đơn mới đều chuyển khoản trước nên tỉ lệ hủy được dự báo theo nhóm trả trước. '
                    'Ảnh hưởng của mưa và ngày lễ là giả định chuyên môn, chưa kiểm chứng bằng dữ liệu. '
                    'Độ tin cậy: ${model.confidenceText.split(' (').first.toLowerCase()}.',
            style: AdminUi.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionCard(AdminStats s) {
    final pendingVenues = _venues.where((v) => v.isPending).length;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final pendingBookings = _bookings.where((b) => b.status == 'Chờ xác nhận').toList();
    final adminOwned = pendingBookings.where((b) => !BookingApproval.isOwnerManaged(b, _venues)).toList();
    final adminPending = adminOwned.length;
    final ownerPending = pendingBookings.length - adminPending;
    final adminOverdue = adminOwned.where((b) {
      final d = BookingSlots.parseDate(b.date);
      return d != null && d.isBefore(todayStart);
    }).length;
    final items = <(IconData, String, int, Color, VoidCallback)>[
      if (pendingVenues > 0)
        (Icons.stadium_outlined, 'Sân đang chờ duyệt', pendingVenues, AdminUi.warn, () => setState(() {
              _selectedApprovalFilter = 'pending';
              _selectedNavIndex = 1;
            })),
      // Đơn của sân đã có chủ riêng do chủ sân duyệt; admin chỉ phải duyệt đơn của sân do hệ thống quản lý.
      if (adminPending > 0)
        (Icons.hourglass_top_rounded, 'Đơn chờ admin xác nhận', adminPending, AdminUi.info, () => setState(() {
              _selectedBookingStatus = 'Chờ xác nhận';
              _selectedNavIndex = 2;
            })),
      if (adminOverdue > 0)
        (Icons.warning_amber_rounded, 'Đơn chờ xác nhận đã quá ngày chơi', adminOverdue, AdminUi.danger, () => setState(() {
              _selectedBookingStatus = 'Chờ xác nhận';
              _selectedNavIndex = 2;
            })),
      if (ownerPending > 0)
        (Icons.storefront_outlined, 'Đơn đang chờ chủ sân xác nhận', ownerPending, AdminUi.muted, () => setState(() {
              _selectedBookingStatus = 'Chờ xác nhận';
              _selectedNavIndex = 2;
            })),
    ];
    final pay = s.paymentMethods.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final payTotal = pay.fold<int>(0, (a, e) => a + e.value);

    return AdminCard(
      title: 'Cần xử lý & thanh toán',
      subtitle: 'Việc tồn đọng và cách khách thanh toán trong kỳ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: AdminUi.success, size: 18),
                  SizedBox(width: 8),
                  Text('Không có việc tồn đọng', style: TextStyle(color: AdminUi.muted, fontSize: 13)),
                ],
              ),
            )
          else
            for (final it in items)
              InkWell(
                onTap: it.$5,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(it.$1, color: it.$4, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(it.$2, style: const TextStyle(color: AdminUi.text, fontSize: 13))),
                      StatusPill('${it.$3}', it.$4),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, color: AdminUi.faint, size: 18),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AdminUi.border),
          const SizedBox(height: 10),
          const Text('Phương thức thanh toán', style: TextStyle(color: AdminUi.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          if (payTotal == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Chưa có đơn trong kỳ này.', style: AdminUi.caption),
            )
          else
            for (final e in pay.take(4))
              HBarRow(
                label: e.key,
                valueText: '${(e.value / payTotal * 100).round()}% • ${e.value} đơn',
                ratio: e.value / payTotal,
                color: AdminUi.info,
              ),
        ],
      ),
    );
  }
}
