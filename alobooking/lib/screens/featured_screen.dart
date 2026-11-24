import '../widgets/venue_image_view.dart';
import 'package:flutter/material.dart';
import '../models/venue.dart';
import 'visual_booking_screen.dart';

/// Màn hình NỔI BẬT — top sân được đặt nhiều nhất, ưu đãi đặc biệt
class FeaturedScreen extends StatelessWidget {
  final List<Venue> venues;
  const FeaturedScreen({super.key, required this.venues});

  @override
  Widget build(BuildContext context) {
    // Sort by rating desc for featured
    final topVenues = [...venues]
      ..sort((a, b) => b.rating.compareTo(a.rating));
    final top10 = topVenues.take(10).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0369A1),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Nổi bật',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Hot deals banner
          // Top ranked title
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                '🔥 Top sân được đánh giá cao nhất',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A)),
              ),
            ),
          ),
          // Ranked venue list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _buildRankedCard(context, top10[i], i + 1),
              childCount: top10.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildRankedCard(BuildContext context, Venue venue, int rank) {
    Color rankColor;
    IconData rankIcon;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = const Color(0xFFCBD5E1);
      rankIcon = Icons.emoji_events;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
      rankIcon = Icons.emoji_events;
    } else {
      rankColor = const Color(0xFF94A3B8);
      rankIcon = Icons.circle;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VisualBookingScreen(venue: venue)),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: rank <= 3
                  ? rankColor.withOpacity(0.15)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: rank <= 3
              ? Border.all(color: rankColor.withOpacity(0.4), width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 52,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(rankIcon, color: rankColor, size: rank <= 3 ? 22 : 12),
                  Text(
                    '#',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: rank <= 3 ? 13 : 11,
                        color: rankColor),
                  ),
                ],
              ),
            ),
            // Image
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: SizedBox(
                width: 70,
                height: 80,
                child: VenueImageView(
                  imageUrl: venue.displayImage,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      venue.district,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 12, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(
                          venue.ratingLabel,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          venue.hours,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Price + Chevron
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    venue.price,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0284C7),
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: Color(0xFF0284C7)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
