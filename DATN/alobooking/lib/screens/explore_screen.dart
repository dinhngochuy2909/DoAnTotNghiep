import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../widgets/venue_image_view.dart';
import 'venue_detail_screen.dart';

/// Màn hình KHÁM PHÁ: duyệt sân theo môn, khu vực và đánh giá, toàn bộ lấy từ dữ liệu sân thật.
class ExploreScreen extends StatelessWidget {
  final List<Venue> venues;
  const ExploreScreen({super.key, required this.venues});

  static const _sports = <(String type, String label, IconData icon, Color color)>[
    ('badminton', 'Cầu lông', Icons.sports, Color(0xFF16A34A)),
    ('pickleball', 'Pickleball', Icons.sports_tennis, Color(0xFF8B5CF6)),
    ('football', 'Bóng đá', Icons.sports_soccer, Color(0xFF059669)),
    ('tennis', 'Tennis', Icons.sports_tennis, Color(0xFF0EA5E9)),
    ('basketball', 'Bóng rổ', Icons.sports_basketball, Color(0xFFF97316)),
  ];

  List<Venue> get _approved => venues.where((v) => v.isApproved).toList();

  @override
  Widget build(BuildContext context) {
    final list = _approved;
    final districts = <String, int>{};
    for (final v in list) {
      if (v.district.trim().isNotEmpty) districts[v.district] = (districts[v.district] ?? 0) + 1;
    }
    final topDistricts = districts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topRated = (list.where((v) => v.rating > 0).toList()..sort((a, b) => b.rating.compareTo(a.rating)))
        .take(10)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15803D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Khám phá sân', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: list.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chưa có sân nào để khám phá.', style: TextStyle(color: Color(0xFF64748B))),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _banner(list.length, districts.length)),
                SliverToBoxAdapter(child: _title('Theo môn thể thao')),
                SliverToBoxAdapter(child: _sportCategories(context, list)),
                if (topRated.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _title('Sân được đánh giá cao')),
                  SliverToBoxAdapter(child: _topRatedList(context, topRated)),
                ],
                SliverToBoxAdapter(child: _title('Theo khu vực')),
                SliverToBoxAdapter(child: _districtChips(context, topDistricts)),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Widget _banner(int venueCount, int districtCount) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF15803D), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tìm sân phù hợp với bạn',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('$venueCount sân đang mở đặt tại $districtCount quận/huyện',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
      );

  void _openList(BuildContext context, String title, List<Venue> items) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _VenueListPage(title: title, venues: items)));
  }

  Widget _sportCategories(BuildContext context, List<Venue> list) {
    final entries = [
      for (final s in _sports)
        (s, list.where((v) => v.type == s.$1).toList()),
    ].where((e) => e.$2.isNotEmpty).toList();
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final s = entries[i].$1;
          final items = entries[i].$2;
          return InkWell(
            onTap: () => _openList(context, s.$2, items),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 104,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(s.$3, color: s.$4, size: 26),
                  const SizedBox(height: 6),
                  Text(s.$2, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  Text('${items.length} sân', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _topRatedList(BuildContext context, List<Venue> items) {
    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final v = items[i];
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VenueDetailScreen(venue: v))),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 108, width: double.infinity, child: VenueImageView(imageUrl: v.image)),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text(v.district, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 15),
                            const SizedBox(width: 2),
                            Text('${v.rating}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Flexible(
                              child: Text(v.price,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                            ),
                          ],
                        ),
                      ],
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

  Widget _districtChips(BuildContext context, List<MapEntry<String, int>> districts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final d in districts)
            ActionChip(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              label: Text('${d.key} (${d.value})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              onPressed: () => _openList(context, d.key, _approved.where((v) => v.district == d.key).toList()),
            ),
        ],
      ),
    );
  }
}

class _VenueListPage extends StatelessWidget {
  final String title;
  final List<Venue> venues;
  const _VenueListPage({required this.title, required this.venues});

  @override
  Widget build(BuildContext context) {
    final sorted = [...venues]..sort((a, b) => b.rating.compareTo(a.rating));
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15803D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('$title (${venues.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final v = sorted[i];
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VenueDetailScreen(venue: v))),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(width: 72, height: 72, child: VenueImageView(imageUrl: v.image)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text('${v.district} • ${v.hours}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (v.rating > 0) ...[
                              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 15),
                              Text(' ${v.rating}  ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                            Flexible(
                              child: Text(v.price,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                            ),
                          ],
                        ),
                      ],
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
}
