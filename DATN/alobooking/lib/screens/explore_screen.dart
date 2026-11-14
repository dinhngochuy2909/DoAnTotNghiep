import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../widgets/booking_bottom_sheet.dart';

/// Màn hình KHÁM PHÁ — bài viết, mẹo thể thao, giải đấu & cộng đồng
class ExploreScreen extends StatelessWidget {
  final List<Venue> venues;
  const ExploreScreen({super.key, required this.venues});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15803D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Khám phá thể thao',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Banner
          SliverToBoxAdapter(child: _buildBanner()),

          // Sport categories
          SliverToBoxAdapter(child: _buildSportCategories(context)),

          // Events / Tournaments section
          SliverToBoxAdapter(
            child: _buildSectionTitle('🏆 Giải đấu & Sự kiện sắp diễn ra'),
          ),
          SliverToBoxAdapter(child: _buildEventList(context)),

          // Tips & Training section
          SliverToBoxAdapter(
            child: _buildSectionTitle('💡 Bí quyết & Kỹ thuật thi đấu'),
          ),
          SliverToBoxAdapter(child: _buildTipsList(context)),

          // Community Groups section
          SliverToBoxAdapter(
            child: _buildSectionTitle('👥 Hội nhóm & Giao lưu thể thao'),
          ),
          SliverToBoxAdapter(child: _buildCommunitySection(context)),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF15803D), Color(0xFF16A34A), Color(0xFF22C55E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🔥 Xu hướng 2026',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cộng đồng thể thao Alobooking',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tìm bạn ghép đội, tham gia giải đấu và nâng cao kỹ năng mỗi ngày',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.emoji_events_rounded, size: 42, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildSportCategories(BuildContext context) {
    final sports = [
      {'label': 'Cầu lông', 'icon': Icons.sports, 'color': const Color(0xFF16A34A), 'count': '28 sân'},
      {'label': 'Pickleball', 'icon': Icons.sports_tennis, 'color': const Color(0xFF8B5CF6), 'count': '18 sân'},
      {'label': 'Bóng đá', 'icon': Icons.sports_soccer, 'color': const Color(0xFF059669), 'count': '14 sân'},
      {'label': 'Tennis', 'icon': Icons.sports_tennis, 'color': const Color(0xFF0EA5E9), 'count': '10 sân'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: sports.map((s) {
          final color = s['color'] as Color;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(s['icon'] as IconData, color: color, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s['label'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s['count'] as String,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEventList(BuildContext context) {
    final events = [
      {
        'title': 'Giải Cầu Lông Hà Nội Mở Rộng 2026',
        'date': '15/11/2026',
        'location': 'Nhà Thi Đấu Cầu Giấy, Hà Nội',
        'prize': '25.000.000đ',
        'tag': 'Đang mở đăng ký',
        'color': const Color(0xFF16A34A),
      },
      {
        'title': 'Pickleball Championship TP.HCM',
        'date': '22/11/2026',
        'location': 'CLB Sunrise Pickleball, Q7',
        'prize': '40.000.000đ',
        'tag': 'Hot deal',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'title': 'Cúp Bóng Đá Doanh Nhân Trẻ Cup',
        'date': '05/12/2026',
        'location': 'Sân Bóng Victory, Bình Thạnh',
        'prize': '50.000.000đ',
        'tag': 'Sắp diễn ra',
        'color': const Color(0xFF059669),
      },
    ];

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: events.length,
        itemBuilder: (ctx, i) {
          final e = events[i];
          final color = e['color'] as Color;

          return Container(
            width: 280,
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        e['tag'] as String,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      e['date'] as String,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Text(
                  e['title'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        e['location'] as String,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Giải thưởng: ${e['prize']}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEAB308),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF16A34A)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTipsList(BuildContext context) {
    final tips = [
      {
        'title': '5 bài tập khởi động tránh chấn thương khớp gối khi chơi Pickleball',
        'readTime': '4 phút đọc',
        'views': '2.4k lượt xem',
        'category': 'Sức khỏe',
      },
      {
        'title': 'Bí quyết chọn vợt cầu lông phù hợp với lối đánh công hay thủ',
        'readTime': '6 phút đọc',
        'views': '3.8k lượt xem',
        'category': 'Trang bị',
      },
      {
        'title': 'Chiến thuật phối hợp đôi nam nữ đỉnh cao trong thi đấu thể thao',
        'readTime': '5 phút đọc',
        'views': '1.9k lượt xem',
        'category': 'Chiến thuật',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: tips.map((t) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.article_outlined, color: Color(0xFF16A34A), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          t['category']!,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t['title']!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(t['readTime']!, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                          Text(t['views']!, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCommunitySection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups_rounded, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tìm bạn ghép đội gần bạn',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Hơn 12.000+ thành viên tích cực mỗi tuần',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tính năng kết nối cộng đồng đang chuẩn bị ra mắt!'),
                  backgroundColor: Color(0xFF16A34A),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text(
              'Tham gia nhóm Zalo / Facebook',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
