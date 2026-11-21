import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/venue.dart';
import '../services/firestore_service.dart';
import '../services/news_feed.dart';
import '../widgets/news_visuals.dart';
import '../widgets/venue_image_view.dart';
import 'venue_detail_screen.dart';

/// Trang đọc đầy đủ một tin trong Khám phá: ảnh bìa lớn, toàn bộ nội dung, thông tin sân gắn kèm,
/// đánh giá thật của khách về sân đó, sân tương tự và các tin khác. Mọi số liệu đều lấy từ dữ liệu thật.
class NewsDetailScreen extends StatelessWidget {
  static const _green = Color(0xFF15803D);
  static const _ink = Color(0xFF0F172A);
  static const _grey = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);

  final NewsEntry entry;

  /// Sân gắn kèm (null nếu tin không gắn sân hoặc sân không còn trong danh sách).
  final Venue? venue;

  /// "Bây giờ" dùng để tính "3 giờ trước".
  final DateTime now;

  /// Toàn bộ sân, đánh giá và dòng tin: để gợi ý sân tương tự, liệt kê đánh giá và tin liên quan.
  final List<Venue> venues;
  final List<ReviewItem> reviews;
  final List<NewsEntry> entries;

  const NewsDetailScreen({
    super.key,
    required this.entry,
    this.venue,
    required this.now,
    this.venues = const [],
    this.reviews = const [],
    this.entries = const [],
  });

  BoxDecoration get _card => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 14, offset: Offset(0, 6))],
      );

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final v = venue;
    final isReview = e.kind == NewsKind.review;
    final timeLabel = NewsFeed.ago(e.time, now);
    final similar = v == null ? const <Venue>[] : NewsFeed.similarVenues(v, venues);
    final related = NewsFeed.relatedEntries(e, entries);

    return Scaffold(
      key: const ValueKey('news-detail'),
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('CHI TIẾT TIN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontStyle: FontStyle.italic)),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _head(context, e, v, isReview, timeLabel),
                  if (v != null) ...[
                    _gap(),
                    _venueInfo(context, v),
                    _gap(),
                    _venueReviews(v),
                  ],
                  if (similar.isNotEmpty) ...[
                    _gap(),
                    _similar(context, similar),
                  ],
                  if (related.isNotEmpty) ...[
                    _gap(),
                    _related(context, related),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 14);

  Widget _head(BuildContext context, NewsEntry e, Venue? v, bool isReview, String timeLabel) {
    final cover = newsCoverUrl(e, v);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isReview) NewsCover(kind: e.kind, imageUrl: cover, aspectRatio: 16 / 9, timeLabel: timeLabel, pinned: e.pinned),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isReview) ...[
                  Row(
                    children: [
                      NewsKindBadge(kind: e.kind),
                      const Spacer(),
                      Text(timeLabel, style: const TextStyle(color: _grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Text(e.title, key: const ValueKey('news-detail-title'), style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800, height: 1.3)),
                if (e.stars > 0) ...[
                  const SizedBox(height: 8),
                  Row(children: [for (var i = 1; i <= 5; i++) Icon(i <= e.stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 22, color: const Color(0xFFF59E0B))]),
                ],
                if (e.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(e.body.trim(), key: const ValueKey('news-detail-body'), style: const TextStyle(color: Color(0xFF334155), fontSize: 15.5, height: 1.6)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${e.isAuto ? 'Tự động từ dữ liệu AloBooking' : 'Đăng bởi ${e.byline}'} · ${NewsFeed.fullDate(e.time)}',
                        key: const ValueKey('news-detail-meta'),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('news-detail-copy'),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await Clipboard.setData(ClipboardData(text: e.body.trim().isEmpty ? e.title : '${e.title}\n\n${e.body.trim()}'));
                        messenger.showSnackBar(const SnackBar(content: Text('Đã sao chép nội dung tin'), duration: Duration(seconds: 2)));
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Sao chép'),
                      style: TextButton.styleFrom(foregroundColor: _green, visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(IconData icon, String title, Widget child, {Key? key, String? trailing}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _green),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800))),
              if (trailing != null) Text(trailing, style: const TextStyle(color: _grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _grey),
          const SizedBox(width: 10),
          SizedBox(width: 78, child: Text(label, style: const TextStyle(color: _grey, fontSize: 13.5))),
          Expanded(child: Text(value, style: const TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.35))),
        ],
      ),
    );
  }

  Widget _venueInfo(BuildContext context, Venue v) {
    final imported = v.isImportedListing;
    final sub = [
      Venue.courtLabel(v.type),
      if (v.district.trim().isNotEmpty) v.district.trim(),
      if (v.hasStockImage) 'ảnh minh họa',
    ].join(' · ');
    final price = v.hasListedPrice ? '${v.price}${imported ? ' (tham khảo)' : ''}' : 'Chưa niêm yết giá, hãy liên hệ sân';
    final hours = v.hours.trim().isEmpty ? 'Chưa cập nhật' : '${v.hours.trim()}${imported ? ' (tham khảo)' : ''}';
    return _section(
      Icons.place_outlined,
      'Thông tin sân',
      key: const ValueKey('news-detail-venue-info'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 56, height: 56, child: VenueImageView(imageUrl: v.displayImage)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.name, style: const TextStyle(color: _ink, fontSize: 15.5, fontWeight: FontWeight.w800, height: 1.3)),
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(color: _grey, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (v.address.trim().isNotEmpty) _infoRow(Icons.location_on_outlined, 'Địa chỉ', v.address.trim()),
          _infoRow(Icons.schedule_rounded, 'Giờ mở cửa', hours),
          _infoRow(Icons.payments_outlined, 'Giá thuê', price),
          if (!imported) _infoRow(Icons.grid_view_rounded, 'Số sân', '${v.courts} sân'),
          if (v.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in v.tags.where((t) => t.trim().isNotEmpty).take(8))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBBF7D0))),
                      child: Text(t.trim(), style: const TextStyle(color: Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          if (imported) ...[
            const SizedBox(height: 6),
            Container(
              key: const ValueKey('news-detail-imported-note'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
              child: Text(
                'Địa điểm này lấy từ dữ liệu mở nên giá, giờ mở cửa chỉ là mức tham khảo, chưa được cơ sở xác nhận. '
                '${v.source == 'overture' ? '© Overture Maps Foundation (giấy phép CDLA-Permissive-2.0).' : '© OpenStreetMap contributors (giấy phép ODbL).'}',
                style: const TextStyle(color: Color(0xFF78350F), fontSize: 12, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('news-detail-venue'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VenueDetailScreen(venue: v))),
              icon: const Icon(Icons.sports_tennis_rounded, size: 18),
              label: const Text('Xem sân', style: TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(backgroundColor: _green, padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _venueReviews(Venue v) {
    final list = NewsFeed.reviewsOf(v.id, reviews);
    final avg = list.isEmpty ? 0.0 : list.fold<int>(0, (s, r) => s + r.stars) / list.length;
    return _section(
      Icons.star_outline_rounded,
      'Đánh giá của khách',
      key: const ValueKey('news-detail-reviews'),
      trailing: list.isEmpty ? null : '${list.length} đánh giá',
      list.isEmpty
          ? const Text('Chưa có đánh giá nào cho sân này. Sau khi đặt và chơi, bạn có thể là người đầu tiên đánh giá.',
              key: ValueKey('news-detail-no-reviews'), style: TextStyle(color: _grey, fontSize: 13.5, height: 1.45))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(avg.toStringAsFixed(1), key: const ValueKey('news-detail-avg'), style: const TextStyle(color: _ink, fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Row(children: [for (var i = 1; i <= 5; i++) Icon(i <= avg.round() ? Icons.star_rounded : Icons.star_outline_rounded, size: 20, color: const Color(0xFFF59E0B))]),
                  ],
                ),
                const SizedBox(height: 10),
                for (final r in list.take(3)) _reviewRow(r),
              ],
            ),
    );
  }

  Widget _reviewRow(ReviewItem r) {
    return Container(
      key: ValueKey('news-detail-review-${r.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(NewsFeed.reviewerName(r.userName), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w700))),
              Text(NewsFeed.ago(r.createdAt, now), style: const TextStyle(color: _grey, fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 4),
          Row(children: [for (var i = 1; i <= 5; i++) Icon(i <= r.stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 15, color: const Color(0xFFF59E0B))]),
          if (r.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r.comment.trim(), style: const TextStyle(color: Color(0xFF334155), fontSize: 13.5, height: 1.45)),
          ],
        ],
      ),
    );
  }

  Widget _similar(BuildContext context, List<Venue> list) {
    return _section(
      Icons.explore_outlined,
      'Sân tương tự',
      key: const ValueKey('news-detail-similar'),
      SizedBox(
        height: 188,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final s = list[i];
            final price = s.hasListedPrice ? '${s.price}${s.isImportedListing ? ' (tham khảo)' : ''}' : 'Chưa niêm yết giá';
            return InkWell(
              key: ValueKey('news-similar-${s.id}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VenueDetailScreen(venue: s))),
              child: Container(
                width: 172,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _line), color: Colors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 92,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          VenueImageView(imageUrl: s.displayImage),
                          if (s.hasStockImage) const Positioned(right: 6, bottom: 6, child: StockPhotoLabel()),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.25)),
                          const SizedBox(height: 3),
                          Text(s.district.trim().isEmpty ? Venue.courtLabel(s.type) : s.district.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _grey, fontSize: 11.5)),
                          Text(price, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _green, fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _related(BuildContext context, List<NewsEntry> list) {
    final byId = {for (final v in venues) v.id: v};
    return _section(
      Icons.newspaper_rounded,
      'Tin khác',
      key: const ValueKey('news-detail-related'),
      Column(
        children: [
          for (final o in list)
            InkWell(
              key: ValueKey('news-related-${o.id}'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => NewsDetailScreen(entry: o, venue: o.venueId == 0 ? null : byId[o.venueId], now: now, venues: venues, reviews: reviews, entries: entries),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    NewsThumb(entry: o, venue: o.venueId == 0 ? null : byId[o.venueId], size: 60),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w700, height: 1.3)),
                          const SizedBox(height: 3),
                          Text('${o.kind.label} · ${NewsFeed.ago(o.time, now)}', style: const TextStyle(color: _grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _grey),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
