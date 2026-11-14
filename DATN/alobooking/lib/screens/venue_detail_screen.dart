import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/venue.dart';
import '../widgets/venue_image_view.dart';
import '../widgets/booking_bottom_sheet.dart';
import '../services/auth_service.dart';
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
    'Gói hội viên',
    'Dịch vụ',
    'Hình ảnh',
    'Điều khoản & quy định',
    'Đánh giá',
  ];

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFavorite;
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _generateSlug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll(RegExp(r'[đ]'), 'd')
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
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
            const Icon(Icons.chat_bubble_outline, color: Color(0xFF065F46)),
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
                  const Icon(Icons.support_agent, color: Color(0xFF10B981)),
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
              backgroundColor: const Color(0xFF065F46),
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
    final slug = _generateSlug(v.name);
    final bookingUrl = 'https://datlich.alobo.vn/san/sport_${v.type}_$slug';

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: const Color(0xFF15803D),
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
                        Clipboard.setData(ClipboardData(text: bookingUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép link chia sẻ sân!')),
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
                      imageUrl: v.image,
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
                              color: const Color(0xFF10B981), // Teal green
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
                                  v.rating > 0 ? '${v.rating} ★ (120 đánh giá)' : 'Chưa có đánh giá',
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
                                color: const Color(0xFF064E3B), // Dark green
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
                                  color: const Color(0xFFF0FDF4),
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
                        const Icon(Icons.location_on, color: Color(0xFF15803D), size: 18),
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
                        const Icon(Icons.access_time_filled, color: Color(0xFF15803D), size: 17),
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
                        const Icon(Icons.phone, color: Color(0xFF15803D), size: 17),
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
                  labelColor: const Color(0xFF10B981),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF10B981),
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
            // 1. Tab THÔNG TIN (khớp 100% với ảnh của người dùng)
            _buildTabInfo(bookingUrl),

            // 2. Tab GÓI HỘI VIÊN
            _buildTabMemberships(),

            // 3. Tab DỊCH VỤ
            _buildTabServices(),

            // 4. Tab HÌNH ẢNH
            _buildTabGallery(),

            // 5. Tab ĐIỀU KHOẢN & QUY ĐỊNH
            _buildTabRules(),

            // 6. Tab ĐÁNH GIÁ
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
                  style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 16),
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

  // 1. Tab THÔNG TIN
  Widget _buildTabInfo(String bookingUrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Link đặt lịch online (màu cam như trong ảnh)
          const Text(
            'Link đặt lịch online',
            style: TextStyle(
              color: Color(0xFFEA580C), // Orange color from screenshot
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    bookingUrl,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0F766E),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: bookingUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã sao chép link đặt lịch online!')),
                    );
                  },
                  child: const Icon(
                    Icons.copy,
                    color: Color(0xFF0F766E),
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Giới thiệu sân
          const Text('Giới thiệu cụm sân', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Text(
            'Cụm sân ${widget.venue.name} đạt tiêu chuẩn thi đấu quốc gia với mặt thảm chống trơn trượt cao cấp, hệ thống đèn LED chống lóa, trần cao thoáng mát. Đầy đủ các tiện ích phục vụ người chơi thể thao chuyên nghiệp và phong trào.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
          ),
          const SizedBox(height: 20),

          // Tiện ích nổi bật
          const Text('Tiện ích có sẵn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _facilityChip(Icons.roofing, 'Mái che cao'),
              _facilityChip(Icons.lightbulb_outline, 'Đèn LED ban đêm'),
              _facilityChip(Icons.local_parking, 'Bãi đỗ ô tô & xe máy'),
              _facilityChip(Icons.shower, 'Phòng tắm nóng lạnh'),
              _facilityChip(Icons.local_drink, 'Nước uống miễn phí'),
              _facilityChip(Icons.wifi, 'Wifi tốc độ cao'),
              _facilityChip(Icons.sports, 'Cho thuê vợt & bóng'),
              _facilityChip(Icons.fastfood, 'Căn tin giải khát'),
            ],
          ),
          const SizedBox(height: 20),

          // Sơ đồ cụm sân
          const Text('Sơ đồ các sân con', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _courtBox('Sân #1', 'Thảm Pro', true)),
              const SizedBox(width: 8),
              Expanded(child: _courtBox('Sân #2', 'Thảm Pro', true)),
              const SizedBox(width: 8),
              Expanded(child: _courtBox('Sân #3', 'Sân VIP', false)),
            ],
          ),
        ],
      ),
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
          Icon(icon, size: 15, color: const Color(0xFF15803D)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
        ],
      ),
    );
  }

  Widget _courtBox(String name, String type, bool isAvailable) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isAvailable ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isAvailable ? const Color(0xFF86EFAC) : const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(type, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isAvailable ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isAvailable ? 'Đang trống' : 'Có lịch đặt',
              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Tab GÓI HỘI VIÊN
  Widget _buildTabMemberships() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _membershipCard('Gói Tháng Linh Hoạt', '800.000đ/tháng', 'Giảm 15% so với đặt lẻ', [
          'Cố định 2 buổi / tuần',
          'Ưu tiên giữ sân khung giờ vàng (17h - 21h)',
          'Tặng 1 buổi tập miễn phí với HLV',
        ]),
        const SizedBox(height: 12),
        _membershipCard('Gói Quý VIP', '2.200.000đ/quý', 'Tiết kiệm 20%', [
          'Cố định 3 buổi / tuần',
          'Miễn phí 100% dịch vụ gửi xe',
          'Tặng 2 lốc nước Pocari Sweat mỗi tháng',
          'Đổi lịch linh hoạt trước 6 tiếng',
        ]),
        const SizedBox(height: 12),
        _membershipCard('Gói Năm Kim Cương', '7.900.000đ/năm', 'Tiết kiệm 30% cao cấp', [
          'Chơi không giới hạn khung giờ thường',
          'Tặng bộ vợt và bóng chính hãng',
          'Ưu tiên đăng ký giải đấu nội bộ',
        ]),
      ],
    );
  }

  Widget _membershipCard(String title, String price, String badge, List<String> benefits) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                child: Text(badge, style: const TextStyle(color: Color(0xFFD97706), fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(price, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...benefits.map((b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(b, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                  ],
                ),
              )),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã chọn $title. Vui lòng liên hệ ban quản lý để kích hoạt!')),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF15803D),
                side: const BorderSide(color: Color(0xFF15803D)),
              ),
              child: const Text('Đăng Ký Gói Hội Viên'),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Tab DỊCH VỤ
  Widget _buildTabServices() {
    final services = [
      {'name': 'Thuê vợt thể thao cao cấp', 'price': '30.000đ / buổi', 'icon': Icons.sports_tennis},
      {'name': 'Mua bóng / quả cầu thi đấu', 'price': '25.000đ - 60.000đ / quả', 'icon': Icons.sports_baseball},
      {'name': 'Nước uống giải khát (Pocari, Revive...)', 'price': '15.000đ - 25.000đ / chai', 'icon': Icons.local_drink},
      {'name': 'Dịch vụ căng cước vợt lấy ngay', 'price': '80.000đ - 150.000đ / lần', 'icon': Icons.build},
      {'name': 'Huấn luyện viên kèm 1-1', 'price': '250.000đ / giờ', 'icon': Icons.person},
      {'name': 'Trọng tài điều hành trận đấu', 'price': '150.000đ / trận', 'icon': Icons.sports},
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      separatorBuilder: (_, __) => const Divider(height: 16),
      itemBuilder: (_, idx) {
        final s = services[idx];
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(s['icon'] as IconData, color: const Color(0xFF15803D), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(s['price'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã thêm yêu cầu: ${s['name']}')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF0F172A),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              child: const Text('Chọn', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  // 4. Tab HÌNH ẢNH
  Widget _buildTabGallery() {
    final images = [
      widget.venue.image,
      'https://images.unsplash.com/photo-1521537634581-0dced2fee2ef?w=600&h=380&fit=crop',
      'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=600&h=380&fit=crop',
      'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=600&h=380&fit=crop',
    ];

    return GridView.builder(
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
    );
  }

  // 5. Tab ĐIỀU KHOẢN & QUY ĐỊNH
  Widget _buildTabRules() {
    final rules = [
      {'title': 'Chính sách hủy và hoàn tiền', 'desc': 'Khách hàng hủy trước 12 tiếng được hoàn 100% tiền cọc. Hủy từ 6-12 tiếng hoàn 50%. Sau thời gian này không hoàn cọc.'},
      {'title': 'Quy định trang phục thi đấu', 'desc': 'Bắt buộc mang giày thể thao chuyên dụng có đế mềm để bảo vệ thảm sân. Không mang giày tây, dép lê vào khu vực sân.'},
      {'title': 'Vệ sinh & An toàn', 'desc': 'Nghiêm cấm hút thuốc, mang kẹo cao su, rượu bia hoặc các chất dễ cháy nổ vào khu vực thi đấu. Giữ trật tự chung sau 22h đêm.'},
      {'title': 'Check-in đúng giờ', 'desc': 'Quý khách vui lòng đến trước giờ đặt 10 phút để nhận sân và làm thủ tục check-in tại quầy lễ tân.'},
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, idx) {
        final r = rules[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified, color: Color(0xFF15803D), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)))),
                ],
              ),
              const SizedBox(height: 6),
              Text(r['desc']!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4)),
            ],
          ),
        );
      },
    );
  }

  // 6. Tab ĐÁNH GIÁ
  Widget _buildTabReviews() {
    final reviews = [
      {'name': 'Nguyễn Văn An', 'stars': 5, 'date': '30/10/2026', 'comment': 'Sân rất đẹp, mặt thảm bám tốt, hệ thống đèn sáng không bị lóa mắt. Chủ sân nhiệt tình!'},
      {'name': 'Trần Thị Bích', 'stars': 5, 'date': '28/10/2026', 'comment': 'Bãi đỗ xe rộng rãi, có phòng tắm nóng lạnh sạch sẽ. Giá cả rất hợp lý cho nhóm bạn.'},
      {'name': 'Lê Hoàng Nam', 'stars': 4, 'date': '25/10/2026', 'comment': 'Sân thoáng, đặt lịch trên app rất nhanh và tiện lợi. Sẽ quay lại thường xuyên.'},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tổng điểm
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            children: [
              Column(
                children: [
                  Text(
                    widget.venue.rating > 0 ? widget.venue.rating.toStringAsFixed(1) : '4.8',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                      Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                      Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                      Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                      Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đánh giá chất lượng dịch vụ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    SizedBox(height: 4),
                    Text('98% người chơi hài lòng và muốn quay lại cụm sân này.', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ...reviews.map((r) => Container(
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
                            backgroundColor: const Color(0xFF15803D).withOpacity(0.12),
                            child: Text(
                              (r['name'] as String).substring(0, 1),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF15803D)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(r['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ],
                      ),
                      Text(r['date'] as String, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(
                      r['stars'] as int,
                      (_) => const Icon(Icons.star, color: Color(0xFFF59E0B), size: 13),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(r['comment'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.35)),
                ],
              ),
            )),
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
