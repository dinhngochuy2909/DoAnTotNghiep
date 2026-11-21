import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/venue.dart';
import '../services/booking_slots.dart';
import '../services/firestore_service.dart';
import '../services/rag_service.dart' show RagText;
import '../services/user_location.dart';
import '../widgets/venue_image_view.dart';
import 'venue_detail_screen.dart';
import 'visual_booking_screen.dart';

typedef BookingsLoader = Future<List<BookingItem>> Function();
typedef LocationLoader = Future<({double lat, double lng})?> Function();

/// Một khung giờ (giờ bắt đầu) của cụm sân và số sân con còn trống.
class _Slot {
  final int hour;
  final int free;
  final int total;
  const _Slot(this.hour, this.free, this.total);
}

/// Một cụm sân trong kết quả: khoảng cách (nếu biết vị trí) và các khung giờ sau khi lọc.
class _Row {
  final Venue venue;
  final double? km;
  final List<_Slot> slots;
  const _Row(this.venue, this.km, this.slots);

  int get freeSlots => slots.where((s) => s.free > 0).length;
}

/// Màn hình TÌM SÂN (trước đây là tab Khám phá, hiện chưa được liên kết từ đâu): tìm sân theo ngày, giờ, môn, khu vực và giá; mỗi sân hiện các khung giờ còn trống
/// tính từ lịch đặt thật trong Firestore.
class VenueFinderScreen extends StatefulWidget {
  final List<Venue> venues;

  /// Chỉ dùng khi kiểm thử: thay cho việc đọc đơn đặt từ Firestore / xin vị trí / đồng hồ hệ thống.
  final BookingsLoader? bookingsLoader;
  final LocationLoader? locationLoader;
  final DateTime? now;

  const VenueFinderScreen({
    super.key,
    required this.venues,
    this.bookingsLoader,
    this.locationLoader,
    this.now,
  });

  @override
  State<VenueFinderScreen> createState() => _VenueFinderScreenState();
}

class _VenueFinderScreenState extends State<VenueFinderScreen> {
  // ── màu ──
  static const _green = Color(0xFF15803D);
  static const _accent = Color(0xFF16A34A);
  static const _tint = Color(0xFFDCFCE7);
  static const _ink = Color(0xFF0F172A);
  static const _grey = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);
  static const _red = Color(0xFFDC2626);

  static const _sports = <(String type, String label, IconData icon)>[
    ('badminton', 'Cầu lông', Icons.sports),
    ('pickleball', 'Pickleball', Icons.sports_tennis),
    ('football', 'Bóng đá', Icons.sports_soccer),
    ('tennis', 'Tennis', Icons.sports_tennis),
    ('basketball', 'Bóng rổ', Icons.sports_basketball),
  ];

  static const _dayparts = <(String key, String label, int from, int to)>[
    ('all', 'Cả ngày', 0, 24),
    ('morning', 'Sáng', 5, 12),
    ('afternoon', 'Chiều', 12, 18),
    ('evening', 'Tối', 18, 24),
  ];

  static const _priceBands = <(String key, String label)>[
    ('all', 'Tất cả mức giá'),
    ('lt100', 'Dưới 100.000đ'),
    ('100to200', '100.000 – 200.000đ'),
    ('gt200', 'Trên 200.000đ'),
  ];

  static const _radii = [5, 10, 20, 30];

  // ── thời gian ──
  late DateTime _now;
  late DateTime _today;
  late DateTime _selected;
  late DateTime _stripStart;

  // ── bộ lọc ──
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _sport = 'all';
  String? _district;
  String _areaMode = 'radius'; // 'radius' | 'district'
  int? _radiusKm;
  String _daypart = 'all';
  String _priceBand = 'all';
  bool _onlyFree = false;
  bool _hideDemo = false;
  String _sort = 'best';

  // ── dữ liệu ──
  ({double lat, double lng})? _me;
  bool _locating = false;
  List<BookingItem> _bookings = [];
  bool _bookingsFailed = false;
  bool _bookingsLoading = true;
  Map<String, List<(String, Set<int>)>> _index = {};
  final Map<int, List<_Slot>> _slotCache = {};
  final Map<int, int> _picked = {};

  void Function(VoidCallback)? _sheetSetState;

  @override
  void initState() {
    super.initState();
    _now = widget.now ?? DateTime.now();
    _today = DateTime(_now.year, _now.month, _now.day);
    _selected = _today;
    _stripStart = _today;
    _loadBookings();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _bookingsLoading = true);
    var list = <BookingItem>[];
    var failed = false;
    try {
      list = await (widget.bookingsLoader ?? FirestoreService.getBookings)();
      failed = widget.bookingsLoader == null && FirestoreService.lastLoadFailed && list.isEmpty;
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _bookings = list;
      _bookingsFailed = failed;
      _bookingsLoading = false;
      _reindex();
    });
  }

  void _reindex() {
    _index = BookingSlots.bookedIndex(_bookings, _selected);
    _slotCache.clear();
  }

  /// Cập nhật trạng thái và làm mới cả bảng lọc đang mở (nếu có).
  void _apply(VoidCallback fn) {
    setState(fn);
    _sheetSetState?.call(() {});
  }

  // ── tính toán ──

  bool _bookable(Venue v) => !v.isDemo && v.hasListedPrice;

  bool get _isToday => _selected == _today;

  /// Các khung giờ trong ngày đang chọn của cụm sân (đã bỏ giờ đã qua nếu là hôm nay).
  List<_Slot> _allSlots(Venue v) {
    return _slotCache.putIfAbsent(v.id, () {
      if (!_bookable(v)) return const <_Slot>[];
      final (open, close) = BookingSlots.openRange(v.hours);
      final booked = BookingSlots.slotsFromIndex(_index, v, v.courts);
      return [
        for (var h = open; h < close; h++)
          if (!_isToday || h > _now.hour) _Slot(h, BookingSlots.freeCourts(booked, v.courts, h), v.courts),
      ];
    });
  }

  List<_Slot> _slotsInDaypart(Venue v) {
    final dp = _dayparts.firstWhere((d) => d.$1 == _daypart);
    return _allSlots(v).where((s) => s.hour >= dp.$3 && s.hour < dp.$4).toList();
  }

  int? _lowPrice(Venue v) => v.hasListedPrice ? BookingSlots.priceForHour(v, 10) : null;

  double _km(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  List<Venue> get _approved => widget.venues.where((v) => v.isApproved).toList();

  List<_Row> _results() {
    final phrase = RagText.norm(_query);
    final tokens = phrase.split(' ').where((t) => t.isNotEmpty).toList();
    final rows = <_Row>[];
    for (final v in _approved) {
      if (_hideDemo && v.isDemo) continue;
      if (_sport != 'all' && v.type != _sport) continue;
      if (_district != null && v.district != _district) continue;
      if (tokens.isNotEmpty) {
        final hay = RagText.norm('${v.name} ${v.address} ${v.district}');
        // Cụm từ ngắn (tên quận, tên sân) phải khớp nguyên cụm, nếu không "hà đông" sẽ khớp nhầm "Hà Nội, Đống Đa";
        // câu dài từ 3 từ trở lên thì chỉ cần có đủ các từ.
        final match = hay.contains(phrase) || (tokens.length >= 3 && tokens.every(hay.contains));
        if (!match) continue;
      }
      if (_priceBand != 'all') {
        final p = _lowPrice(v);
        if (p == null) continue;
        final ok = switch (_priceBand) {
          'lt100' => p < 100000,
          '100to200' => p >= 100000 && p <= 200000,
          _ => p > 200000,
        };
        if (!ok) continue;
      }
      double? km;
      if (_me != null) km = _km(_me!.lat, _me!.lng, v.lat, v.lng);
      if (_radiusKm != null && _me != null && (km == null || km > _radiusKm!)) continue;

      final slots = _slotsInDaypart(v);
      if (_daypart != 'all' && slots.isEmpty) continue;
      if (_onlyFree && !slots.any((s) => s.free > 0)) continue;
      rows.add(_Row(v, km, slots));
    }

    int byBest(_Row a, _Row b) {
      final demo = (a.venue.isDemo ? 1 : 0).compareTo(b.venue.isDemo ? 1 : 0);
      if (demo != 0) return demo;
      final free = (b.freeSlots > 0 ? 1 : 0).compareTo(a.freeSlots > 0 ? 1 : 0);
      if (free != 0) return free;
      final r = b.venue.rating.compareTo(a.venue.rating);
      return r != 0 ? r : a.venue.id.compareTo(b.venue.id);
    }

    int cmp(_Row a, _Row b) {
      switch (_sort) {
        case 'near':
          final c = (a.km ?? 1e9).compareTo(b.km ?? 1e9);
          return c != 0 ? c : byBest(a, b);
        case 'priceAsc':
        case 'priceDesc':
          final pa = _lowPrice(a.venue), pb = _lowPrice(b.venue);
          if (pa == null && pb == null) return byBest(a, b);
          if (pa == null) return 1;
          if (pb == null) return -1;
          final c = _sort == 'priceAsc' ? pa.compareTo(pb) : pb.compareTo(pa);
          return c != 0 ? c : byBest(a, b);
        case 'rating':
          final c = b.venue.rating.compareTo(a.venue.rating);
          return c != 0 ? c : byBest(a, b);
        case 'name':
          return a.venue.name.compareTo(b.venue.name);
        default:
          return byBest(a, b);
      }
    }

    rows.sort(cmp);
    return rows;
  }

  int get _activeFilters =>
      (_sport != 'all' ? 1 : 0) +
      (_district != null ? 1 : 0) +
      (_radiusKm != null && _me != null ? 1 : 0) +
      (_daypart != 'all' ? 1 : 0) +
      (_priceBand != 'all' ? 1 : 0) +
      (_onlyFree ? 1 : 0) +
      (_hideDemo ? 1 : 0) +
      (_query.trim().isNotEmpty ? 1 : 0);

  void _resetFilters() {
    _apply(() {
      _searchCtrl.clear();
      _query = '';
      _sport = 'all';
      _district = null;
      _radiusKm = null;
      _areaMode = 'radius';
      _daypart = 'all';
      _priceBand = 'all';
      _onlyFree = false;
      _hideDemo = false;
      _sort = _me != null ? 'near' : 'best';
    });
  }

  Future<void> _locate() async {
    _apply(() => _locating = true);
    final me = await (widget.locationLoader ?? requestUserLocation)();
    if (!mounted) return;
    _apply(() {
      _locating = false;
      if (me != null) {
        _me = me;
        _areaMode = 'radius';
        _radiusKm ??= 10;
        if (_sort == 'best') _sort = 'near';
      }
    });
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không lấy được vị trí của bạn. Hãy cho phép trình duyệt truy cập vị trí rồi thử lại.')),
      );
    }
  }

  // ── định dạng ──

  String _money(int v) =>
      '${v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';

  String _hh(int h) => '${h.toString().padLeft(2, '0')}:00';

  String _dayKey(DateTime d) => '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  String _weekday(DateTime d) => d.weekday == DateTime.sunday ? 'CN' : 'Th ${d.weekday + 1}';

  String _dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  // ── giao diện ──

  @override
  Widget build(BuildContext context) {
    final rows = _results();
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('TÌM SÂN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, fontStyle: FontStyle.italic)),
      ),
      body: _approved.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chưa có sân nào để khám phá.', style: TextStyle(color: _grey)),
              ),
            )
          : LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 960;
                if (!wide) return _content(rows, wide: false);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      key: const ValueKey('explore-sidebar'),
                      width: 340,
                      margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                      decoration: _cardDecoration(),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _filters(),
                      ),
                    ),
                    Expanded(child: _content(rows, wide: true)),
                  ],
                );
              },
            ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      );

  Widget _content(List<_Row> rows, {required bool wide}) {
    final freeSlots = rows.fold<int>(0, (s, r) => s + r.freeSlots);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(child: _searchField()),
                if (!wide) ...[
                  const SizedBox(width: 8),
                  _filterButton(),
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverToBoxAdapter(child: _dateCard()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(child: _resultsHeader(rows.length, freeSlots)),
        ),
        if (_bookingsFailed)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(child: _failedBanner()),
          ),
        if (rows.isEmpty)
          SliverToBoxAdapter(child: _emptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 560,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 244,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _venueCard(rows[i]),
                childCount: rows.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _searchField() {
    return TextField(
      key: const ValueKey('explore-search'),
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _query = v),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Tìm theo tên sân, quận/huyện, địa chỉ…',
        hintStyle: const TextStyle(fontSize: 13.5, color: _grey),
        prefixIcon: const Icon(Icons.search_rounded, color: _grey),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() {
                  _searchCtrl.clear();
                  _query = '';
                }),
              ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accent, width: 1.5)),
      ),
    );
  }

  Widget _filterButton() {
    final n = _activeFilters;
    return OutlinedButton.icon(
      key: const ValueKey('explore-filter-button'),
      onPressed: _openFilterSheet,
      style: OutlinedButton.styleFrom(
        foregroundColor: _green,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _line),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.tune_rounded, size: 18),
      label: Text(n > 0 ? 'Bộ lọc ($n)' : 'Bộ lọc', style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          _sheetSetState = setSheet;
          final count = _results().length;
          return FractionallySizedBox(
            heightFactor: 0.88,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(2))),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _filters(),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const ValueKey('explore-sheet-apply'),
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Xem $count sân', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() => _sheetSetState = null);
  }

  // ── bộ lọc ──

  Widget _filters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 20, color: _ink),
                SizedBox(width: 8),
                Text('Bộ lọc', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
              ],
            ),
            OutlinedButton.icon(
              key: const ValueKey('explore-locate'),
              onPressed: _locating ? null : _locate,
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _accent),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: _locating
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded, size: 16),
              label: Text(_me != null ? 'Đã định vị' : 'Gần tôi', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            TextButton.icon(
              key: const ValueKey('explore-reset'),
              onPressed: _activeFilters == 0 ? null : _resetFilters,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Đặt lại', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _switchRow('Chỉ hiện sân còn chỗ', _onlyFree, (v) => _apply(() => _onlyFree = v), const ValueKey('explore-only-free')),
        _switchRow('Ẩn sân demo (dữ liệu minh họa)', _hideDemo, (v) => _apply(() => _hideDemo = v), const ValueKey('explore-hide-demo')),
        const Divider(height: 24, color: _line),
        _sectionTitle('Khu vực'),
        _areaTabs(),
        const SizedBox(height: 10),
        if (_areaMode == 'radius') _radiusPills() else _districtPills(),
        const SizedBox(height: 18),
        _sectionTitle('Môn thể thao'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _pill('sport-all', 'Tất cả môn', _sport == 'all', () => _apply(() => _sport = 'all'), icon: Icons.apps_rounded),
            for (final s in _sports)
              _pill('sport-${s.$1}', s.$2, _sport == s.$1, () => _apply(() => _sport = s.$1), icon: s.$3),
          ],
        ),
        const SizedBox(height: 18),
        _sectionTitle('Buổi chơi'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in _dayparts) _pill('daypart-${d.$1}', d.$2, _daypart == d.$1, () => _apply(() => _daypart = d.$1)),
          ],
        ),
        const SizedBox(height: 18),
        _sectionTitle('Khoảng giá (một giờ)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in _priceBands) _pill('price-${p.$1}', p.$2, _priceBand == p.$1, () => _apply(() => _priceBand = p.$1)),
          ],
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _ink)),
      );

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged, Key key) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, color: _ink))),
        Switch(
          key: key,
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: _accent,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFFCBD5E1),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ],
    );
  }

  Widget _areaTabs() {
    Widget tab(String mode, String label, IconData icon) {
      final sel = _areaMode == mode;
      return Expanded(
        child: InkWell(
          key: ValueKey('area-$mode'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => _apply(() => _areaMode = mode),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: sel ? Border.all(color: _line) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: sel ? _green : _grey),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? _green : _grey)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          tab('radius', 'Theo bán kính', Icons.radar_rounded),
          tab('district', 'Theo quận/huyện', Icons.location_city_rounded),
        ],
      ),
    );
  }

  Widget _radiusPills() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in _radii)
              _pill('radius-$r', 'Trong $r km', _radiusKm == r && _me != null, () {
                if (_me == null) {
                  _locate();
                  _apply(() => _radiusKm = r);
                } else {
                  _apply(() => _radiusKm = _radiusKm == r ? null : r);
                }
              }),
          ],
        ),
        if (_me == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Bấm "Gần tôi" để dùng vị trí của bạn và lọc theo bán kính.', style: TextStyle(fontSize: 12, color: _grey)),
          ),
      ],
    );
  }

  Widget _districtPills() {
    final counts = <String, int>{};
    for (final v in _approved) {
      if (v.district.trim().isNotEmpty) counts[v.district] = (counts[v.district] ?? 0) + 1;
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _pill('district-all', 'Tất cả', _district == null, () => _apply(() => _district = null)),
        for (final e in entries)
          _pill('district-${e.key}', '${e.key} (${e.value})', _district == e.key, () => _apply(() => _district = _district == e.key ? null : e.key)),
      ],
    );
  }

  Widget _pill(String id, String label, bool selected, VoidCallback onTap, {IconData? icon}) {
    return InkWell(
      key: ValueKey('pill-$id'),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _tint : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _accent : _line, width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? _green : _grey),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? _green : _ink)),
          ],
        ),
      ),
    );
  }

  // ── ngày chơi ──

  Widget _dateCard() {
    final days = [for (var i = 0; i < 14; i++) _stripStart.add(Duration(days: i))];
    final last = days.last;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Ngày chơi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
              ),
              InkWell(
                key: const ValueKey('explore-pick-date'),
                borderRadius: BorderRadius.circular(10),
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_dm(_stripStart)} - ${_dm(last)}/${last.year}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _green)),
                      const SizedBox(width: 6),
                      const Icon(Icons.calendar_month_rounded, size: 16, color: _green),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final d = days[i];
                final sel = d == _selected;
                return InkWell(
                  key: ValueKey('day-${_dayKey(d)}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _apply(() {
                    _selected = d;
                    _picked.clear();
                    _reindex();
                  }),
                  child: Container(
                    width: 66,
                    decoration: BoxDecoration(
                      color: sel ? _accent : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? _accent : _line),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(d == _today ? 'Hôm nay' : _weekday(d),
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: sel ? Colors.white : _grey)),
                        const SizedBox(height: 2),
                        Text('${d.day}', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: sel ? Colors.white : _ink)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 365)),
      helpText: 'Chọn ngày chơi',
    );
    if (picked == null || !mounted) return;
    final d = DateTime(picked.year, picked.month, picked.day);
    _apply(() {
      _selected = d;
      _stripStart = d;
      _picked.clear();
      _reindex();
    });
  }

  // ── kết quả ──

  Widget _resultsHeader(int venues, int freeSlots) {
    const sorts = <(String, String)>[
      ('best', 'Phù hợp nhất'),
      ('near', 'Gần tôi nhất'),
      ('priceAsc', 'Giá thấp đến cao'),
      ('priceDesc', 'Giá cao đến thấp'),
      ('rating', 'Đánh giá cao'),
      ('name', 'Tên A-Z'),
    ];
    final label = sorts.firstWhere((s) => s.$1 == _sort, orElse: () => sorts.first).$2;
    return Row(
      children: [
        Expanded(
          child: Text(
            _bookingsLoading ? '$venues sân · đang tải lịch…' : '$venues sân · $freeSlots khung giờ trống',
            key: const ValueKey('explore-count'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
          ),
        ),
        PopupMenuButton<String>(
          key: const ValueKey('explore-sort'),
          onSelected: (v) {
            if (v == 'near' && _me == null) {
              _locate();
            }
            setState(() => _sort = v);
          },
          itemBuilder: (ctx) => [
            for (final s in sorts)
              PopupMenuItem(value: s.$1, child: Text(s.$2, style: TextStyle(fontWeight: _sort == s.$1 ? FontWeight.w800 : FontWeight.w500))),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _line)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_vert_rounded, size: 16, color: _green),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _failedBanner() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF92400E)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Chưa tải được lịch đặt sân nên chưa biết khung giờ nào đã kín. Các khung giờ hiển thị có thể không còn trống.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
          TextButton(onPressed: _loadBookings, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 44, color: _grey),
          const SizedBox(height: 10),
          const Text('Không có sân phù hợp với bộ lọc', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 4),
          const Text('Thử đổi ngày, bỏ bớt bộ lọc hoặc tìm từ khóa khác.', style: TextStyle(fontSize: 12.5, color: _grey)),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('explore-empty-reset'),
            onPressed: _resetFilters,
            child: const Text('Đặt lại bộ lọc'),
          ),
        ],
      ),
    );
  }

  // ── thẻ sân ──

  Widget _venueCard(_Row row) {
    final v = row.venue;
    final km = row.km;
    final sub = [
      if (km != null) '${km.toStringAsFixed(1).replaceAll('.', ',')} km',
      v.district,
      if (_bookable(v) && !_bookingsLoading) '${row.freeSlots} khung trống',
    ].where((s) => s.trim().isNotEmpty).join(' · ');

    return Container(
      key: ValueKey('explore-card-${v.id}'),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 44, height: 44, child: VenueImageView(imageUrl: v.displayImage)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(v.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _ink)),
                        ),
                        if (v.isDemo) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                            child: const Text('DEMO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 13, color: _grey),
                        const SizedBox(width: 2),
                        Expanded(child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: _grey))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: ValueKey('explore-more-${v.id}'),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VenueDetailScreen(venue: v))),
                style: TextButton.styleFrom(
                  backgroundColor: _tint,
                  foregroundColor: _green,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Xem thêm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _slotArea(row)),
        ],
      ),
    );
  }

  Widget _note(String text, {Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.4, color: _grey)),
    );
  }

  Widget _slotArea(_Row row) {
    final v = row.venue;
    if (v.isDemo) {
      return _note('Sân demo: dữ liệu minh họa, không phải cơ sở có thật. Chỉ xem thông tin, không đặt được.',
          key: ValueKey('explore-demo-note-${v.id}'));
    }
    if (!v.hasListedPrice) {
      return _note('Cụm sân chưa niêm yết giá trên AloBooking. Vui lòng liên hệ trực tiếp cơ sở để đặt.');
    }
    final slots = row.slots;
    if (slots.isEmpty) {
      return _note(_isToday && _daypart == 'all'
          ? 'Hôm nay đã hết giờ chơi. Hãy chọn một ngày khác.'
          : 'Không có khung giờ nào trong buổi này.');
    }

    // Khung giờ đang chọn: mặc định là khung còn chỗ đầu tiên
    final firstFree = slots.firstWhere((s) => s.free > 0, orElse: () => slots.first);
    final pickedHour = _picked[v.id];
    final selected = slots.firstWhere((s) => s.hour == pickedHour, orElse: () => firstFree);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: slots.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) => _slotChip(v, slots[i], slots[i].hour == selected.hour),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _slotDetail(v, selected)),
      ],
    );
  }

  Widget _slotChip(Venue v, _Slot s, bool selected) {
    final full = s.free == 0;
    final golden = BookingSlots.isGolden(s.hour);
    return InkWell(
      key: ValueKey('explore-slot-${v.id}-${s.hour}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _picked[v.id] = s.hour),
      child: Container(
        width: 64,
        decoration: BoxDecoration(
          color: selected ? _tint : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _accent : _line, width: selected ? 1.5 : 1),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_hh(s.hour), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: full ? _grey : _ink)),
                  Text(full ? 'Hết chỗ' : '${s.free}/${s.total} sân',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: full ? _red : _green)),
                ],
              ),
            ),
            if (golden)
              const Positioned(
                top: 3,
                right: 4,
                child: Icon(Icons.local_fire_department_rounded, size: 11, color: Color(0xFFF59E0B)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _slotDetail(Venue v, _Slot s) {
    final full = s.free == 0;
    final golden = BookingSlots.isGolden(s.hour);
    return Container(
      key: ValueKey('explore-detail-${v.id}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
        color: const Color(0xFFFAFAFA),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            decoration: BoxDecoration(
              color: full ? const Color(0xFFF1F5F9) : _tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_hh(s.hour), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: full ? _grey : _green)),
                Icon(Icons.more_vert_rounded, size: 12, color: full ? _grey : _accent),
                Text(_hh(s.hour + 1), style: const TextStyle(fontSize: 11.5, color: _grey)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(golden ? 'Giờ vàng' : 'Khung giờ thường',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: golden ? const Color(0xFFB45309) : _ink)),
                const SizedBox(height: 2),
                Text(full ? 'Hết chỗ' : 'Còn ${s.free}/${s.total} sân trống',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: full ? _red : _grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_money(BookingSlots.priceForHour(v, s.hour))} / giờ',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _green)),
              const SizedBox(height: 4),
              SizedBox(
                height: 30,
                child: ElevatedButton.icon(
                  key: ValueKey('explore-book-${v.id}'),
                  onPressed: full
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => VisualBookingScreen(venue: v, initialDate: _selected)),
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(full ? Icons.block_rounded : Icons.add_rounded, size: 15),
                  label: Text(full ? 'Hết chỗ' : 'Đặt sân', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
