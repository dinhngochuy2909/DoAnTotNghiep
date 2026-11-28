import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/venue_photos.dart';
import '../models/venue.dart';
import '../widgets/venue_image_view.dart';
import '../services/auth_service.dart';
import '../services/booking_slots.dart';
import '../services/firestore_service.dart';
import 'visual_booking_screen.dart';

class VenueDetailScreen extends StatefulWidget {
  final Venue venue;
  final bool isFavorite;
  final Function(int venueId)? onToggleFavorite;

  const VenueDetailScreen({
    super.key,
    required this.venue,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  State<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<VenueDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool _isFav;
  final List<String> _tabs = [
    'Thông tin',
    'Hình ảnh',
    'Quy định',
    'Đánh giá',
  ];

  // Đánh giá thật của khách đã chơi tại sân này
  List<ReviewItem> _reviews = [];
  bool _reviewsLoading = true;
  bool _canReview = false;

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFavorite;
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final reviews = await FirestoreService.getReviews(widget.venue.id);
    var can = false;
    final user = AuthService.currentUser;
    if (user != null && !AuthService.isGuest) {
      final bookings = await FirestoreService.getBookings();
      final now = DateTime.now();
      final played = bookings.any((b) {
        if (b.venueName.trim().toLowerCase() != widget.venue.name.trim().toLowerCase()) return false;
        if (!b.belongsTo(uid: user.uid, phone: user.phone, name: user.fullName)) return false;
        if (BookingSlots.isCancelled(b.status) || b.status.toLowerCase().contains('chờ')) return false;
        final d = BookingSlots.parseDate(b.date);
        final r = BookingSlots.parseRanges(b.time);
        if (d == null) return false;
        final endMin = r.isEmpty ? 24 * 60 : r.last.$2;
        return DateTime(d.year, d.month, d.day).add(Duration(minutes: endMin)).isBefore(now);
      });
      can = played && !reviews.any((r) => r.userId == user.uid);
    }
    if (!mounted) return;
    setState(() {
      _reviews = reviews;
      _canReview = can;
      _reviewsLoading = false;
    });
  }

  Future<void> _writeReview() async {
    var stars = 5;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Đánh giá sân', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setD(() => stars = i),
                      icon: Icon(i <= stars ? Icons.star_rounded : Icons.star_border_rounded,
                          color: const Color(0xFFF59E0B), size: 30),
                    ),
                ],
              ),
              TextField(
                controller: ctrl,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(hintText: 'Chia sẻ trải nghiệm của bạn tại sân này', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Gửi đánh giá')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final user = AuthService.currentUser!;
    final saved = await FirestoreService.addReview(ReviewItem(
      id: 'RV-${DateTime.now().millisecondsSinceEpoch}',
      venueId: widget.venue.id,
      userId: user.uid,
      userName: user.fullName,
      stars: stars,
      comment: ctrl.text.trim(),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(saved ? 'Cảm ơn bạn đã đánh giá!' : 'Chưa gửi được đánh giá, vui lòng thử lại')),
    );
    if (saved) _loadReviews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openBookingSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisualBookingScreen(venue: widget.venue),
      ),
    );
  }

  void _showChatDialog() {
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, color: Color(0xFF075985)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nhắn tin với ${widget.venue.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent, color: Color(0xFF0EA5E9)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chủ sân thường phản hồi trong vòng 5 phút. Bạn có thể hỏi về tình trạng sân trống hoặc đặt cố định.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Nhập tin nhắn cần hỏi...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF075985),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã gửi tin nhắn đến quản lý sân!')),
              );
            },
            child: const Text('Gửi tin nhắn'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.venue;
    final shareText = '${v.name}\n${v.address}\nGiờ mở cửa: ${v.hours}\nGiá: ${v.price}';

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: const Color(0xFF0369A1),
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              actions: [
                // Nút Share
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(Icons.share, color: Color(0xFF0F172A), size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép thông tin sân để chia sẻ')),
                        );
                      },
                    ),
                  ),
                ),

                // Nút Favorite Heart
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 18,
                    child: IconButton(
                      icon: Icon(
                        _isFav ? Icons.favorite : Icons.favorite_border,
                        color: _isFav ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() {
                          _isFav = !_isFav;
                        });
                        if (widget.onToggleFavorite != null) {
                          widget.onToggleFavorite!(v.id);
                        }
                      },
                    ),
                  ),
                ),

                // Nút Đặt Lịch màu vàng cam nổi bật như trong ảnh
                Padding(
                  padding: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
                  child: ElevatedButton(
                    onPressed: _openBookingSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEAB308), // Golden amber yellow
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Đặt lịch',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    VenueImageView(
                      imageUrl: v.displayImage,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.35),
                            Colors.transparent,
                            Colors.black.withOpacity(0.4),
                          ],
                        ),
                      ),
                    ),

                    // Nhãn báo đây là ảnh minh họa theo môn, không phải ảnh thật của sân
                    if (v.hasStockImage)
                      Positioned(
                        right: 16,
                        bottom: 56,
                        child: Container(
                          key: const ValueKey('stock-image-badge'),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_camera_outlined, color: Colors.white70, size: 12),
                              SizedBox(width: 4),
                              Text('Ảnh minh họa', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                            ],
                          ),
                        ),
                      ),

                    // Hai nút Pill nổi bật nằm ngang trên mép card trắng
                    Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          // Pill 1: Đánh giá sao
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9), // Teal green
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.white, size: 16),
                                const SizedBox(width: 5),
                                Text(
                                  v.rating > 0 ? '${v.rating} ★' : 'Chưa có đánh giá',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Pill 2: Chat với sân
                          InkWell(
                            onTap: _showChatDialog,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C4A6E), // Dark green
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat_bubble_outline, color: Colors.white, size: 15),
                                  SizedBox(width: 6),
                                  Text(
                                    'Chat với sân',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Card thông tin chính của cụm sân
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Logo + Tên sân + Tag môn
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo sân
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF9C3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFACC15), width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              v.logo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.sports_tennis, color: Color(0xFFD97706), size: 30),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Tên sân & Tag
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F9FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF0284C7)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.sports_tennis, size: 12, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 4),
                                    Text(
                                      v.type.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),

                    // Địa chỉ cụ thể
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFF0369A1), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            v.address,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF334155),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Giờ mở cửa
                    Row(
                      children: [
                        const Icon(Icons.access_time_filled, color: Color(0xFF0369A1), size: 17),
                        const SizedBox(width: 8),
                        Text(
                          v.hours,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Hotline / Liên hệ
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Color(0xFF0369A1), size: 17),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Hotline quản lý sân: 0988.123.456')),
                            );
                          },
                          child: const Text(
                            'Liên hệ: 0988.123.456',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Tab Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarHeaderDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: const Color(0xFF0EA5E9),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF0EA5E9),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                  tabs: _tabs.map((t) => Tab(text: t)).toList(),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTabInfo(),
            _buildTabGallery(),
            _buildTabRules(),
            _buildTabReviews(),
          ],
        ),
      ),

      // Bottom Bar với nút Đặt Lịch cố định
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Giá thuê từ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                Text(
                  widget.venue.price,
                  style: const TextStyle(color: Color(0xFF0369A1), fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openBookingSheet,
                icon: Icon(
                  AuthService.isGuest ? Icons.lock_outline : Icons.calendar_month,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  AuthService.isGuest ? 'ĐẶT LỊCH (CHẾ ĐỘ XEM)' : 'ĐẶT LỊCH NGAY',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AuthService.isGuest ? const Color(0xFF64748B) : const Color(0xFFEAB308), // Slate grey if guest, Amber yellow if customer
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Tab THÔNG TIN: chỉ hiển thị dữ liệu thật của sân
  Widget _buildTabInfo() {
    final v = widget.venue;
    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF0369A1)),
              const SizedBox(width: 10),
              SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)))),
              Expanded(
                child: Text(value.isEmpty ? 'Chưa cập nhật' : value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              ),
            ],
          ),
        );
    const sportNames = {
      'pickleball': 'Pickleball',
      'badminton': 'Cầu lông',
      'football': 'Bóng đá',
      'tennis': 'Tennis',
      'basketball': 'Bóng rổ',
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thông tin cụm sân', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          row(Icons.sports_tennis, 'Môn', sportNames[v.type] ?? v.type),
          row(Icons.location_on_outlined, 'Địa chỉ', v.address),
          row(Icons.map_outlined, 'Khu vực', v.district),
          row(Icons.grid_view_rounded, 'Số sân', '${v.courts} sân'),
          row(Icons.schedule_rounded, 'Giờ mở cửa', v.hours),
          row(Icons.payments_outlined, 'Giá', v.price),
          row(Icons.qr_code_2_rounded, 'Thanh toán', 'Chuyển khoản VietQR (không nhận tiền mặt)'),
          if (v.ownerName.trim().isNotEmpty) row(Icons.person_outline_rounded, 'Quản lý', v.ownerName),
          if (v.isDemo)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                key: const ValueKey('demo-venue-note'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'SÂN DEMO: đây là dữ liệu minh họa do hệ thống tạo để trình diễn, không phải cơ sở có thật. '
                  'Địa chỉ chỉ là khu vực gần đúng, giá và giờ mở cửa là mức tham khảo. '
                  'Bạn có thể xem lịch và bảng giá nhưng không đặt hoặc thanh toán được.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF92400E)),
                ),
              ),
            ),
          if (v.isImportedListing)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Vị trí và thông tin cơ bản lấy từ dữ liệu mở '
                  '${v.source == 'overture' ? '© Overture Maps Foundation (giấy phép CDLA-Permissive-2.0)' : '© OpenStreetMap contributors (giấy phép ODbL)'}. '
                  'Giá thuê, giờ mở cửa và số sân là mức tham khảo theo mặt bằng chung của môn này, '
                  'chưa được cơ sở xác nhận; vui lòng liên hệ trực tiếp để xác nhận trước khi đặt.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF475569)),
                ),
              ),
            ),
          const SizedBox(height: 18),
          const Text('Tiện ích', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          if (v.tags.isEmpty)
            const Text('Sân chưa cập nhật thông tin tiện ích.', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final t in v.tags) _facilityChip(Icons.check_circle_outline_rounded, t)],
            ),
        ],
      ),
    );
  }

  // 3. Tab QUY ĐỊNH
  Widget _buildTabRules() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_busy_rounded, color: Color(0xFF0369A1), size: 16),
                  SizedBox(width: 8),
                  Text('Hủy lịch và hoàn tiền',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Bạn tự hủy được khi còn cách giờ chơi từ 2 tiếng trở lên, trong mục "Lịch sử đặt sân"; dưới 2 tiếng thì không hủy được. Việc hoàn tiền (nếu đã thanh toán trước) '
                'do chủ sân xử lý theo chính sách riêng của từng sân. Nếu cần hỗ trợ, hãy liên hệ chủ sân hoặc Hotline/Zalo 0364059999.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Quy định chi tiết về trang phục, giờ nhận sân và dịch vụ đi kèm do từng cụm sân quy định. '
          'Vui lòng hỏi trực tiếp chủ sân trước khi đặt.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.45),
        ),
      ],
    );
  }

  // 4. Tab ĐÁNH GIÁ: đánh giá thật của khách đã chơi
  Widget _buildTabReviews() {
    if (_reviewsLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0369A1)));
    }
    final avg = _reviews.isEmpty ? null : _reviews.fold<int>(0, (a, r) => a + r.stars) / _reviews.length;
    final shown = avg ?? (widget.venue.rating > 0 ? widget.venue.rating : null);
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7DD3FC)),
          ),
          child: Row(
            children: [
              Text(
                shown == null ? '—' : shown.toStringAsFixed(1),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0369A1)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _reviews.isEmpty
                      ? 'Chưa có đánh giá nào từ khách đã đặt sân.'
                      : '${_reviews.length} đánh giá từ khách đã chơi tại sân này.',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_canReview)
          OutlinedButton.icon(
            onPressed: _writeReview,
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text('Viết đánh giá'),
          )
        else
          const Text(
            'Chỉ khách đã chơi xong tại sân này mới có thể viết đánh giá.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
          ),
        const SizedBox(height: 12),
        ..._reviews.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xFF0369A1).withValues(alpha: 0.12),
                            child: Text(
                              r.userName.isEmpty ? '?' : r.userName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0369A1)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(r.userName.isEmpty ? 'Khách' : r.userName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ],
                      ),
                      Text(fmt(r.createdAt), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(r.stars, (_) => const Icon(Icons.star, color: Color(0xFFF59E0B), size: 13)),
                  ),
                  if (r.comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(r.comment, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.35)),
                  ],
                ],
              ),
            )),
      ],
    );
  }

  Widget _facilityChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF0369A1)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
        ],
      ),
    );
  }

  // 4. Tab HÌNH ẢNH
  Widget _buildTabGallery() {
    // Ảnh chính của sân, rồi các ảnh khác CÙNG MÔN (trước đây luôn hiện ảnh cầu lông cho mọi sân)
    final v = widget.venue;
    final images = VenuePhotos.gallery(v.type, v.displayImage, v.id, count: 8);

    return Column(
      children: [
        if (v.hasStockImage)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ảnh minh họa theo môn ${const {
                          'badminton': 'cầu lông',
                          'pickleball': 'pickleball',
                          'tennis': 'tennis',
                          'basketball': 'bóng rổ',
                          'football': 'bóng đá',
                        }[v.type] ?? 'thể thao'}, chưa phải ảnh thực tế của sân.',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(14),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.3,
            ),
            itemCount: images.length,
            itemBuilder: (ctx, idx) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: VenueImageView(imageUrl: images[idx], fit: BoxFit.cover),
            ),
          ),
        ),
      ],
    );
  }

}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarHeaderDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarHeaderDelegate oldDelegate) {
    return false;
  }
}
