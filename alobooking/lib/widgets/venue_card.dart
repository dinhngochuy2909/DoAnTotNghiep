import 'package:flutter/material.dart';

import '../models/venue.dart';
import '../services/venue_hours.dart';
import '../theme/app_theme.dart';
import 'news_visuals.dart' show StockPhotoLabel;
import 'venue_image_view.dart';

/// Thẻ sân ở trang chủ: ảnh lớn phía trên, thông tin gọn bên dưới, giá và nút Đặt lịch ở chân thẻ.
///
/// Mọi nhãn đều tính từ dữ liệu thật: trạng thái mở cửa theo giờ hoạt động và giờ hiện tại, nguồn của sân
/// (đã xác thực, dữ liệu mở, sân minh họa), nhãn "Ảnh minh họa" khi dùng ảnh trong kho.
class VenueCard extends StatelessWidget {
  final Venue venue;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onBook;

  /// Quản trị viên hoặc chủ sân của sân này: hiện thanh quản lý (trạng thái, Sửa, Xóa) dưới thẻ.
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Chỉ dùng khi kiểm thử: cố định giờ để kiểm tra nhãn mở/đóng cửa.
  final DateTime? now;

  const VenueCard({
    super.key,
    required this.venue,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onBook,
    this.canManage = false,
    this.onEdit,
    this.onDelete,
    this.now,
  });

  static const _sports = {
    'badminton': ('🏸', 'Cầu lông'),
    'pickleball': ('🏓', 'Pickleball'),
    'football': ('⚽', 'Bóng đá'),
    'tennis': ('🎾', 'Tennis'),
    'basketball': ('🏀', 'Bóng rổ'),
  };

  /// Nguồn gốc của sân, nói thật cho người xem: sân do chủ sân/admin nhập và đã duyệt mới được ghi "Đã xác thực".
  static (IconData, String, Color) provenance(Venue v) {
    if (v.isDemo)
      return (Icons.science_outlined, 'Sân minh họa', const Color(0xFFB45309));
    if (v.isImportedListing)
      return (Icons.public_rounded, 'Dữ liệu mở', AppColors.muted);
    return (Icons.verified_rounded, 'Đã xác thực', AppColors.primary);
  }

  @override
  Widget build(BuildContext context) {
    final (emoji, sportName) = _sports[venue.type] ?? ('🏸', 'Cầu lông');
    final status = VenueHours.statusAt(venue.hours, now ?? DateTime.now());
    final (provIcon, provLabel, provColor) = provenance(venue);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('venue-card-${venue.id}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _photo(emoji, sportName)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      venue.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 3),
                        if (venue.distance.isNotEmpty)
                          Text(
                            '${venue.distance} · ',
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            venue.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Giờ + trạng thái mở cửa nằm trong một khối tự xuống dòng khi thẻ hẹp; nhãn nguồn giữ nguyên bên phải.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    size: 14,
                                    color: AppColors.muted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    venue.hours,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                              if (status != OpenStatus.unknown)
                                _statusPill(status),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(provIcon, size: 13, color: provColor),
                            const SizedBox(width: 3),
                            Text(
                              provLabel,
                              key: ValueKey('venue-card-source-${venue.id}'),
                              style: TextStyle(
                                color: provColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.lineSoft),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Giá từ',
                                style: TextStyle(
                                  color: AppColors.faint,
                                  fontSize: 11.5,
                                ),
                              ),
                              Text(
                                venue.price.isNotEmpty
                                    ? venue.price
                                    : 'Liên hệ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _bookButton(),
                      ],
                    ),
                  ],
                ),
              ),
              if (canManage) _manageBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photo(String emoji, String sportName) {
    return Stack(
      fit: StackFit.expand,
      children: [
        VenueImageView(imageUrl: venue.displayImage, fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x33000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0x99000000),
              ],
              stops: [0, 0.3, 0.6, 1],
            ),
          ),
        ),
        Positioned(
          left: 10,
          top: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: AppShadows.soft,
            ),
            child: Text(
              '$emoji $sportName',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            shadowColor: Colors.black38,
            child: InkWell(
              key: ValueKey('venue-fav-${venue.id}'),
              customBorder: const CircleBorder(),
              onTap: onToggleFavorite,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 19,
                  color: isFavorite ? AppColors.danger : AppColors.muted,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 15,
                  color: Color(0xFFFBBF24),
                ),
                const SizedBox(width: 3),
                Text(
                  venue.ratingLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (venue.hasStockImage)
          const Positioned(right: 10, bottom: 10, child: StockPhotoLabel()),
      ],
    );
  }

  Widget _statusPill(OpenStatus status) {
    final open = status == OpenStatus.open;
    final color = open ? AppColors.success : AppColors.muted;
    return Container(
      key: ValueKey('venue-card-status-${venue.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: open ? AppColors.successSoft : AppColors.lineSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            open ? 'Đang mở' : 'Đã đóng',
            style: TextStyle(
              color: open ? const Color(0xFF166534) : AppColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookButton() {
    return Material(
      color: AppColors.cta,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        key: ValueKey('venue-book-${venue.id}'),
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onBook,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 16,
                color: AppColors.ink,
              ),
              SizedBox(width: 6),
              Text(
                'Đặt lịch',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Thanh quản lý dưới thẻ: trạng thái duyệt của sân và nút Sửa, Xóa.
  Widget _manageBar() {
    final (Color bg, Color fg, IconData icon, String label) = venue.isPending
        ? (
            const Color(0xFFFEF3C7),
            const Color(0xFFB45309),
            Icons.hourglass_top_rounded,
            'Chờ duyệt',
          )
        : venue.isRejected
        ? (
            AppColors.dangerSoft,
            const Color(0xFFB91C1C),
            Icons.error_outline_rounded,
            'Bị từ chối',
          )
        : (
            AppColors.primarySoft,
            AppColors.primaryDark,
            Icons.verified_rounded,
            'Đã duyệt',
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.primaryMist,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (onEdit != null)
            TextButton.icon(
              key: ValueKey('venue-edit-${venue.id}'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: const Text('Sửa'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          if (onDelete != null)
            TextButton.icon(
              key: ValueKey('venue-delete-${venue.id}'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 15),
              label: const Text('Xóa'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}
