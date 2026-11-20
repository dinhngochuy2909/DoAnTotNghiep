import 'venue_detail_screen.dart';
import '../widgets/venue_image_view.dart';
import 'package:flutter/material.dart';
import '../models/venue.dart';

/// Màn hình YÊU THÍCH — danh sách sân yêu thích của người dùng
class FavoritesScreen extends StatefulWidget {
  final List<Venue> allVenues;
  final Set<int> favoriteIds;
  final Function(int) onToggleFavorite;

  const FavoritesScreen({
    super.key,
    required this.allVenues,
    required this.favoriteIds,
    required this.onToggleFavorite,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    final favorites =
        widget.allVenues.where((v) => widget.favoriteIds.contains(v.id)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15803D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.favorite, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Sân yêu thích',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 8),
            if (favorites.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                    '${favorites.length}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
              ),
          ],
        ),
      ),
      body: favorites.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              itemBuilder: (ctx, i) => _buildFavoriteCard(favorites[i]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_border,
                size: 56, color: Color(0xFFEF4444)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Chưa có sân yêu thích',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn vào icon ❤️ trên thẻ sân để\nlưu vào danh sách yêu thích',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(Venue venue) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VenueDetailScreen(
            venue: venue,
            isFavorite: true,
            onToggleFavorite: widget.onToggleFavorite,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            child: SizedBox(
              width: 100,
              height: 100,
              child: VenueImageView(
                imageUrl: venue.displayImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF0F172A)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          venue.district,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        venue.ratingLabel,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        venue.price,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Remove favorite button
          IconButton(
            onPressed: () {
              widget.onToggleFavorite(venue.id);
              setState(() {});
            },
            icon: const Icon(Icons.favorite, color: Color(0xFFEF4444), size: 22),
          ),
        ],
      ),
    ),
  );
}
}
