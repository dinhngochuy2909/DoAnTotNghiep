import 'package:flutter/material.dart';

import '../data/venue_photos.dart';
import '../models/venue.dart';
import '../services/news_feed.dart';
import '../services/weather_service.dart';
import 'venue_image_view.dart';

/// Ảnh bìa của một tin: ảnh của tin; không có thì ảnh của sân gắn kèm; không có nữa thì rỗng (dùng nền chuyển sắc).
/// Đánh giá của khách không có ảnh bìa lớn.
String newsCoverUrl(NewsEntry e, Venue? venue) {
  if (e.kind == NewsKind.review) return '';
  if (e.imageUrl.trim().isNotEmpty) return e.imageUrl;
  return venue?.displayImage ?? '';
}

/// Ảnh nhỏ vuông của một tin (dùng ở danh sách tin liên quan): ảnh bìa nếu có, không thì ô màu theo loại tin.
class NewsThumb extends StatelessWidget {
  final NewsEntry entry;
  final Venue? venue;
  final double size;

  const NewsThumb({super.key, required this.entry, this.venue, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final s = NewsKindStyle.of(entry.kind);
    final url = newsCoverUrl(entry, venue);
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: s.gradient,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(s.icon, color: Colors.white, size: size * 0.42),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: url.trim().isEmpty
            ? fallback
            : VenueImageView(imageUrl: url, errorWidget: fallback),
      ),
    );
  }
}

/// Màu, biểu tượng và nền chuyển sắc của từng loại tin trong Khám phá.
class NewsKindStyle {
  /// Màu nhấn (nền nhạt của nhãn).
  final Color accent;

  /// Màu chữ/biểu tượng đậm hơn để đủ tương phản trên nền nhạt.
  final Color strong;
  final IconData icon;

  /// Nền chuyển sắc dùng khi tin không có ảnh.
  final List<Color> gradient;

  const NewsKindStyle(this.accent, this.strong, this.icon, this.gradient);

  static const _styles = <NewsKind, NewsKindStyle>{
    NewsKind.promo: NewsKindStyle(
      Color(0xFFF97316),
      Color(0xFFC2410C),
      Icons.local_offer_outlined,
      [Color(0xFFF97316), Color(0xFFDC2626)],
    ),
    NewsKind.event: NewsKindStyle(
      Color(0xFF8B5CF6),
      Color(0xFF6D28D9),
      Icons.event_outlined,
      [Color(0xFF8B5CF6), Color(0xFF4F46E5)],
    ),
    NewsKind.update: NewsKindStyle(
      Color(0xFF16A34A),
      Color(0xFF15803D),
      Icons.new_releases_outlined,
      [Color(0xFF16A34A), Color(0xFF0D9488)],
    ),
    NewsKind.notice: NewsKindStyle(
      Color(0xFF2563EB),
      Color(0xFF1D4ED8),
      Icons.campaign_outlined,
      [Color(0xFF2563EB), Color(0xFF4F46E5)],
    ),
    NewsKind.newVenue: NewsKindStyle(
      Color(0xFF0D9488),
      Color(0xFF0F766E),
      Icons.stadium_outlined,
      [Color(0xFF0D9488), Color(0xFF15803D)],
    ),
    NewsKind.review: NewsKindStyle(
      Color(0xFFF59E0B),
      Color(0xFFB45309),
      Icons.star_outline_rounded,
      [Color(0xFFF59E0B), Color(0xFFEA580C)],
    ),
  };

  static NewsKindStyle of(NewsKind kind) => _styles[kind]!;
}

/// Nhãn loại tin dạng viên thuốc: biểu tượng + tên loại.
class NewsKindBadge extends StatelessWidget {
  final NewsKind kind;

  /// true: nền trắng đặt trên ảnh; false: nền nhạt theo màu loại tin.
  final bool onImage;

  const NewsKindBadge({super.key, required this.kind, this.onImage = false});

  @override
  Widget build(BuildContext context) {
    final s = NewsKindStyle.of(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: onImage
            ? Colors.white.withValues(alpha: 0.94)
            : s.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 14, color: s.strong),
          const SizedBox(width: 4),
          Text(
            kind.label,
            style: TextStyle(
              color: s.strong,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ảnh bìa của một tin: ảnh thật nếu có, không thì nền chuyển sắc theo loại tin kèm biểu tượng lớn.
/// Nhãn loại và thời gian nằm đè lên ảnh; ảnh lấy từ kho ảnh minh họa thì ghi rõ "Ảnh minh họa".
class NewsCover extends StatelessWidget {
  final NewsKind kind;
  final String imageUrl;
  final double aspectRatio;

  /// "3 giờ trước"... hiện ở góc phải trên; rỗng thì không hiện.
  final String timeLabel;
  final bool pinned;

  const NewsCover({
    super.key,
    required this.kind,
    this.imageUrl = '',
    this.aspectRatio = 16 / 8,
    this.timeLabel = '',
    this.pinned = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = NewsKindStyle.of(kind);
    final hasPhoto = imageUrl.trim().isNotEmpty;
    final backdrop = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: s.gradient,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            bottom: -18,
            child: Icon(
              s.icon,
              size: 130,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          Positioned(
            left: -30,
            top: -40,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
        ],
      ),
    );

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasPhoto)
            VenueImageView(imageUrl: imageUrl, errorWidget: backdrop)
          else
            backdrop,
          if (hasPhoto)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0x59000000),
                  ],
                  stops: [0, 0.35, 0.65, 1],
                ),
              ),
            ),
          Positioned(
            left: 10,
            top: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NewsKindBadge(kind: kind, onImage: true),
                if (pinned) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.push_pin, size: 13, color: s.strong),
                  ),
                ],
              ],
            ),
          ),
          if (timeLabel.isNotEmpty)
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (hasPhoto && VenuePhotos.isStock(imageUrl))
            const Positioned(right: 8, bottom: 8, child: StockPhotoLabel()),
        ],
      ),
    );
  }
}

/// Nhãn nhỏ "Ảnh minh họa" cho ảnh lấy từ kho ảnh (không phải ảnh thật do chủ sân/admin đăng).
class StockPhotoLabel extends StatelessWidget {
  const StockPhotoLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Ảnh minh họa',
        style: TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

/// Biểu tượng bầu trời vẽ bằng icon (màu luôn đúng, không phụ thuộc phông emoji của máy).
class SkyIcon extends StatelessWidget {
  final Sky sky;
  final double size;

  /// Dùng màu đơn sắc (ví dụ trắng trên ảnh tối) thay cho màu riêng từng loại.
  final Color? color;

  const SkyIcon(this.sky, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    switch (sky) {
      case Sky.clear:
        return Icon(
          Icons.wb_sunny_rounded,
          size: size,
          color: color ?? const Color(0xFFF59E0B),
        );
      case Sky.partly:
        // mặt trời ló sau đám mây
        return SizedBox(
          width: size * 1.15,
          height: size,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: Icon(
                  Icons.wb_sunny_rounded,
                  size: size * 0.7,
                  color: color ?? const Color(0xFFF59E0B),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Icon(
                  Icons.cloud_rounded,
                  size: size * 0.8,
                  color: color ?? const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        );
      case Sky.cloudy:
        return Icon(
          Icons.cloud_rounded,
          size: size,
          color: color ?? const Color(0xFF94A3B8),
        );
      case Sky.fog:
        return Icon(
          Icons.foggy,
          size: size,
          color: color ?? const Color(0xFF94A3B8),
        );
      case Sky.rain:
        return Icon(
          Icons.umbrella_rounded,
          size: size,
          color: color ?? const Color(0xFF2563EB),
        );
      case Sky.storm:
        return Icon(
          Icons.thunderstorm_rounded,
          size: size,
          color: color ?? const Color(0xFF7C3AED),
        );
    }
  }
}
