import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/venue.dart';
import '../services/auth_service.dart';
import '../services/booking_slots.dart';
import '../services/cancel_policy.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';
import 'visual_booking_screen.dart';

/// Màn hình SÂN ĐÃ ĐẶT: lịch đặt thật của tài khoản đang đăng nhập (đọc từ Firestore).
class BookedScreen extends StatefulWidget {
  final List<Venue> allVenues;

  /// Đồng hồ để biết đã quá hạn hủy chưa; kiểm thử truyền giờ cố định.
  final DateTime Function() clock;

  const BookedScreen({super.key, this.allVenues = const [], this.clock = DateTime.now});

  @override
  State<BookedScreen> createState() => _BookedScreenState();
}

enum _BookingState { pending, upcoming, completed, cancelled }

class _BookedScreenState extends State<BookedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BookingItem> _mine = [];
  List<Venue> _venues = [];
  bool _loading = true;
  bool _failed = false;
  String _failureText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _venues = widget.allVenues;
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  /// Đơn của tài khoản này: ưu tiên uid, đơn cũ chưa có uid thì khớp theo số điện thoại (hoặc tên).
  bool _isMine(BookingItem b, AppUser u) {
    if (b.userId.isNotEmpty) return b.userId == u.uid;
    final up = _digits(u.phone), bp = _digits(b.phone);
    if (up.isNotEmpty && bp.isNotEmpty) return up == bp;
    return b.customer.trim().toLowerCase() == u.fullName.trim().toLowerCase();
  }

  Future<void> _load() async {
    final user = AuthService.currentUser;
    if (user == null || AuthService.isGuest) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    FirestoreService.lastLoadFailed = false;
    final results = await Future.wait<Object?>([
      FirestoreService.getBookings(),
      if (_venues.isEmpty) FirestoreService.getVenues(),
    ]);
    if (!mounted) return;
    final all = results[0] as List<BookingItem>;
    final failureText = FirestoreService.failureMessage();
    setState(() {
      _failureText = failureText;
      if (results.length > 1) _venues = results[1] as List<Venue>;
      _mine = all.where((b) => _isMine(b, user)).toList()
        ..sort((a, b) => (_start(b) ?? b.createdAt).compareTo(_start(a) ?? a.createdAt));
      _failed = FirestoreService.lastLoadFailed;
      _loading = false;
    });
  }

  DateTime? _start(BookingItem b) {
    final d = BookingSlots.parseDate(b.date);
    if (d == null) return null;
    final r = BookingSlots.parseRanges(b.time);
    final m = r.isEmpty ? 0 : r.map((x) => x.$1).reduce((a, b) => a < b ? a : b); // ca sớm nhất của đơn
    return DateTime(d.year, d.month, d.day, m ~/ 60, m % 60);
  }

  DateTime? _end(BookingItem b) {
    final d = BookingSlots.parseDate(b.date);
    if (d == null) return null;
    final r = BookingSlots.parseRanges(b.time);
    final m = r.isEmpty ? 24 * 60 : r.last.$2;
    return DateTime(d.year, d.month, d.day, 0, 0).add(Duration(minutes: m));
  }

  _BookingState _stateOf(BookingItem b) {
    if (BookingSlots.isCancelled(b.status)) return _BookingState.cancelled;
    final st = b.status.toLowerCase();
    final end = _end(b);
    if (st.contains('hoàn thành') || (end != null && end.isBefore(widget.clock()))) return _BookingState.completed;
    if (st.contains('chờ')) return _BookingState.pending;
    return _BookingState.upcoming;
  }

  Venue? _venueOf(BookingItem b) {
    final n = b.venueName.trim().toLowerCase();
    for (final v in _venues) {
      if (v.name.trim().toLowerCase() == n) return v;
    }
    return null;
  }

  List<BookingItem> _filteredList(int tab) {
    switch (tab) {
      case 1:
        return _mine.where((b) {
          final s = _stateOf(b);
          return s == _BookingState.upcoming || s == _BookingState.pending;
        }).toList();
      case 2:
        return _mine.where((b) => _stateOf(b) == _BookingState.completed).toList();
      case 3:
        return _mine.where((b) => _stateOf(b) == _BookingState.cancelled).toList();
      default:
        return _mine;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'football':
        return const Color(0xFF16A34A);
      case 'tennis':
        return const Color(0xFF0EA5E9);
      case 'pickleball':
        return const Color(0xFF8B5CF6);
      case 'basketball':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF059669);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'football':
        return Icons.sports_soccer;
      case 'tennis':
      case 'pickleball':
        return Icons.sports_tennis;
      case 'basketball':
        return Icons.sports_basketball;
      default:
        return Icons.sports;
    }
  }

  Widget _buildStatusBadge(_BookingState status) {
    Color bg;
    Color fg;
    String text;
    IconData icon;
    switch (status) {
      case _BookingState.pending:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        text = 'Chờ xác nhận';
        icon = Icons.hourglass_top_rounded;
        break;
      case _BookingState.upcoming:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        text = 'Đã xác nhận';
        icon = Icons.schedule_rounded;
        break;
      case _BookingState.completed:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        text = 'Đã hoàn thành';
        icon = Icons.check_circle_outline_rounded;
        break;
      case _BookingState.cancelled:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        text = 'Đã hủy';
        icon = Icons.cancel_outlined;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0369A1),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Lịch sử đặt sân', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: 'Sắp diễn ra'),
            Tab(text: 'Đã hoàn tất'),
            Tab(text: 'Đã hủy'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
          : TabBarView(
              controller: _tabController,
              children: [for (var i = 0; i < 4; i++) _buildBookingList(_filteredList(i))],
            ),
    );
  }

  Widget _buildBookingList(List<BookingItem> items) {
    if (items.isEmpty) {
      final loggedOut = AuthService.isGuest;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: loggedOut ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  loggedOut ? Icons.lock_outline_rounded : (_failed ? Icons.wifi_off_rounded : Icons.event_busy_rounded),
                  size: 48,
                  color: loggedOut ? const Color(0xFFD97706) : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                loggedOut
                    ? 'Đăng nhập để xem lịch đặt sân'
                    : (_failed ? 'Chưa tải được lịch đặt sân' : 'Chưa có lịch đặt sân nào'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                loggedOut
                    ? 'Lịch đặt sân được lưu theo tài khoản của bạn.'
                    : (_failed ? '${_failureText.isEmpty ? 'Kiểm tra kết nối mạng.' : _failureText} Bấm tải lại để thử lại.' : 'Các lịch đặt sân của bạn sẽ xuất hiện tại đây.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 18),
              if (loggedOut)
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                )
              else if (_failed)
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Tải lại'),
                ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _buildBookingCard(items[i]),
      ),
    );
  }

  Widget _buildBookingCard(BookingItem b) {
    final venue = _venueOf(b);
    final type = venue?.type ?? 'badminton';
    final color = _typeColor(type);
    final state = _stateOf(b);
    final active = state == _BookingState.upcoming || state == _BookingState.pending;
    final canCancel = active && CancelPolicy.canCustomerCancel(_start(b), widget.clock());

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_typeIcon(type), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.venueName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(b.field, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                    ],
                  ),
                ),
                _buildStatusBadge(state),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
            Row(
              children: [
                Expanded(child: _buildInfoItem(Icons.calendar_today_outlined, 'Ngày', b.date)),
                Expanded(child: _buildInfoItem(Icons.access_time_rounded, 'Khung giờ', b.time)),
              ],
            ),
            if (venue != null && venue.address.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoItem(Icons.location_on_outlined, 'Địa chỉ', venue.address),
            ],
            const SizedBox(height: 8),
            _buildInfoItem(Icons.payments_outlined, 'Thanh toán', b.paymentMethod),
            if (active && !canCancel) ...[
              const SizedBox(height: 8),
              Row(
                key: ValueKey('cancel-closed-${b.id}'),
                children: const [
                  Icon(Icons.lock_clock_outlined, size: 14, color: Color(0xFFB45309)),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Không hủy được: còn dưới ${CancelPolicy.minNoticeHours} tiếng tới giờ chơi.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                    ),
                  ),
                ],
              ),
            ],
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tổng tiền', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text(b.amount,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0284C7))),
                  ],
                ),
                if (canCancel)
                  OutlinedButton(
                    onPressed: () => _showCancelDialog(b),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: const Text('Hủy đặt sân', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  )
                else if (venue != null && (state == _BookingState.completed || state == _BookingState.cancelled))
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => VisualBookingScreen(venue: venue))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                    ),
                    child: const Text('Đặt lại sân', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 5),
        Text('$label: ', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showCancelDialog(BookingItem b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận hủy đặt sân', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
          'Hủy lượt đặt tại "${b.venueName}" lúc ${b.time} ngày ${b.date}? '
          'Đơn sẽ chuyển sang "Đã hủy". Việc hoàn tiền (nếu có) do chủ sân xử lý theo chính sách của sân. ${CancelPolicy.ruleText}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Giữ lại', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Kiểm tra lại: hộp thoại có thể đã mở lâu đến quá hạn hủy
              if (!CancelPolicy.canCustomerCancel(_start(b), widget.clock())) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã quá hạn hủy. ${CancelPolicy.ruleText}'), backgroundColor: Color(0xFFEF4444)),
                );
                return;
              }
              final ok = await FirestoreService.updateBookingStatus(b.id, 'Đã hủy');
              if (!mounted) return;
              if (ok) setState(() => b.status = 'Đã hủy');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Đã hủy lịch đặt sân' : 'Chưa hủy được, vui lòng thử lại'),
                  backgroundColor: ok ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
  }
}
