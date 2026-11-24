import 'package:flutter/material.dart';

import '../data/info_pages.dart';
import '../screens/info_page_screen.dart';

/// Các hành động mà chân trang điều khiển được trên trang chủ. Hành động nào để null thì mục tương ứng hiện như chữ thường (không bấm được).
class FooterActions {
  final VoidCallback? onHome;
  final VoidCallback? onSearch;
  final VoidCallback? onBooked;
  final VoidCallback? onFavorites;
  final VoidCallback? onAccount;
  final VoidCallback? onTop;

  /// Lọc theo môn: nhận khóa môn ('badminton', 'pickleball', 'football', 'tennis', 'basketball').
  final void Function(String sportType)? onSport;

  const FooterActions({
    this.onHome,
    this.onSearch,
    this.onBooked,
    this.onFavorites,
    this.onAccount,
    this.onTop,
    this.onSport,
  });
}

class AppFooter extends StatelessWidget {
  static const _accent = Color(0xFF4ADE80);

  final FooterActions actions;

  const AppFooter({super.key, this.actions = const FooterActions()});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 1100;
    final isMedium = screenWidth >= 760;
    final hPad = screenWidth >= 900 ? 48.0 : 20.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2419), Color(0xFF14532D), Color(0xFF166534)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 32),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildBrandSection()),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildLinksSection()),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildSportsSection()),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildAboutSection(context)),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildPolicySection(context)),
                      const SizedBox(width: 24),
                      Expanded(flex: 3, child: _buildContactSection()),
                    ],
                  )
                : isMedium
                ? Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildBrandSection()),
                          const SizedBox(width: 24),
                          Expanded(child: _buildContactSection()),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildLinksSection()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildSportsSection()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildAboutSection(context)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildPolicySection(context)),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBrandSection(),
                      const SizedBox(height: 24),
                      _buildContactSection(),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildLinksSection()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildSportsSection()),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildAboutSection(context)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildPolicySection(context)),
                        ],
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
            child: _buildTrustStrip(context, isMedium),
          ),
          Container(
            height: 1,
            margin: EdgeInsets.symmetric(horizontal: hPad),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.25),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          // Chừa đáy trống để nút chat AI và nút demo nổi ở góc dưới không che dòng bản quyền và mạng xã hội
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 76),
            child: isMedium
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildBackToTop(),
                      const SizedBox(width: 16),
                      Expanded(child: _buildCopyright()),
                      const SizedBox(width: 20),
                      _buildSocialRow(),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCopyright(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [_buildBackToTop(), _buildSocialRow()],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Thương hiệu ───
  Widget _buildBrandSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.sports_tennis,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AloBooking',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'Nền tảng đặt sân thể thao',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'AloBooking – nền tảng đặt sân thể thao trực tuyến. '
          'Kết nối người chơi với các sân cầu lông, pickleball, bóng đá, tennis, bóng rổ.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12.5,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStoreBadge(Icons.apple, 'App Store', 'iOS'),
            _buildStoreBadge(Icons.android, 'Google Play', 'Android'),
          ],
        ),
      ],
    );
  }

  Widget _buildStoreBadge(IconData icon, String store, String platform) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                platform,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 9,
                ),
              ),
              Text(
                store,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Các cột liên kết ───
  Widget _buildLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFooterHeading('Liên kết nhanh'),
        const SizedBox(height: 12),
        _FooterLink(
          linkKey: 'footer-link-home',
          leading: '🏠',
          label: 'Trang chủ',
          onTap: actions.onHome,
        ),
        _FooterLink(
          linkKey: 'footer-link-search',
          leading: '🔍',
          label: 'Tìm kiếm sân',
          onTap: actions.onSearch,
        ),
        _FooterLink(
          linkKey: 'footer-link-booked',
          leading: '📅',
          label: 'Sân đã đặt',
          onTap: actions.onBooked,
        ),
        _FooterLink(
          linkKey: 'footer-link-favorites',
          leading: '❤️',
          label: 'Sân yêu thích',
          onTap: actions.onFavorites,
        ),
        _FooterLink(
          linkKey: 'footer-link-account',
          leading: '👤',
          label: 'Tài khoản',
          onTap: actions.onAccount,
        ),
      ],
    );
  }

  Widget _buildSportsSection() {
    VoidCallback? sport(String type) =>
        actions.onSport == null ? null : () => actions.onSport!(type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFooterHeading('Thể thao'),
        const SizedBox(height: 12),
        _FooterLink(
          linkKey: 'footer-link-sport-badminton',
          leading: '🏸',
          label: 'Cầu lông',
          onTap: sport('badminton'),
        ),
        _FooterLink(
          linkKey: 'footer-link-sport-pickleball',
          leading: '🏓',
          label: 'Pickleball',
          onTap: sport('pickleball'),
        ),
        _FooterLink(
          linkKey: 'footer-link-sport-football',
          leading: '⚽',
          label: 'Bóng đá',
          onTap: sport('football'),
        ),
        _FooterLink(
          linkKey: 'footer-link-sport-tennis',
          leading: '🎾',
          label: 'Tennis',
          onTap: sport('tennis'),
        ),
        _FooterLink(
          linkKey: 'footer-link-sport-basketball',
          leading: '🏀',
          label: 'Bóng rổ',
          onTap: sport('basketball'),
        ),
      ],
    );
  }

  Widget _infoLink(BuildContext context, InfoPageId id, String label) =>
      _FooterLink(
        linkKey: 'footer-link-info-${id.name}',
        label: label,
        onTap: () => InfoPageScreen.open(context, id),
      );

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFooterHeading('Về AloBooking'),
        const SizedBox(height: 12),
        _infoLink(context, InfoPageId.about, 'Giới thiệu'),
        _infoLink(context, InfoPageId.guide, 'Hướng dẫn đặt sân'),
        _infoLink(context, InfoPageId.faq, 'Câu hỏi thường gặp'),
        _infoLink(context, InfoPageId.owners, 'Dành cho chủ sân'),
      ],
    );
  }

  Widget _buildPolicySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFooterHeading('Chính sách'),
        const SizedBox(height: 12),
        _infoLink(context, InfoPageId.terms, 'Điều khoản sử dụng'),
        _infoLink(context, InfoPageId.privacy, 'Chính sách bảo mật'),
        _infoLink(context, InfoPageId.payments, 'Thanh toán & hủy sân'),
      ],
    );
  }

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFooterHeading('Liên hệ & Hỗ trợ'),
        const SizedBox(height: 12),
        _buildContactItem(
          Icons.location_on_outlined,
          'Địa chỉ',
          '72 Thành Thái, Phường 14, Quận 10\nTP. Hồ Chí Minh, Việt Nam',
        ),
        const SizedBox(height: 10),
        _buildContactItem(Icons.phone_outlined, 'Hotline', '1900 6750'),
        const SizedBox(height: 10),
        _buildContactItem(
          Icons.email_outlined,
          'Email',
          'support@alobooking.vn',
        ),
        const SizedBox(height: 10),
        _buildContactItem(
          Icons.access_time_outlined,
          'Giờ hỗ trợ',
          'Thứ 2 – Chủ nhật: 7:00 – 22:00',
        ),
      ],
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _accent, size: 15),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterHeading(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 28,
          height: 2,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  // ─── Dải thanh toán & cam kết ───
  Widget _buildTrustStrip(BuildContext context, bool isMedium) {
    final payment = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stripHeading(Icons.qr_code_2_rounded, 'Thanh toán'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _pill(Icons.qr_code_2_rounded, 'Chuyển khoản VietQR'),
            _pill(Icons.account_balance_outlined, 'Chuẩn NAPAS 247'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Không nhận tiền mặt.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          key: const ValueKey('footer-trust-payments'),
          borderRadius: BorderRadius.circular(6),
          onTap: () => InfoPageScreen.open(context, InfoPageId.payments),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Thanh toán & hủy sân ›',
              style: TextStyle(
                color: _accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );

    const promises = [
      'Kiểm tra trùng giờ trước khi ghi nhận đơn',
      'Sân chưa niêm yết giá không nhận đặt online',
      'Sân Demo luôn có nhãn, không nhận đặt hay thanh toán',
      'Ảnh minh họa và dữ liệu mở luôn ghi rõ nguồn',
    ];
    final commitments = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stripHeading(Icons.verified_user_outlined, 'Cam kết minh bạch'),
        const SizedBox(height: 10),
        // Lưới 2 cột đều nhau khi đủ rộng, 1 cột khi hẹp
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 480 ? 2 : 1;
            final itemW = (c.maxWidth - (cols - 1) * 20) / cols;
            return Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                for (final p in promises)
                  SizedBox(
                    width: itemW,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: _accent,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            p,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );

    return Container(
      key: const ValueKey('footer-trust'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: isMedium
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: payment),
                const SizedBox(width: 28),
                Expanded(flex: 7, child: commitments),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [payment, const SizedBox(height: 18), commitments],
            ),
    );
  }

  Widget _stripHeading(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: _accent),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Dòng cuối ───
  Widget _buildCopyright() {
    return Text(
      '©  AloBooking. Bảo lưu mọi quyền. '
      'Được phát triển bởi Đinh Ngọc Huy. '
      'Một phần dữ liệu vị trí sân: © OpenStreetMap contributors, © Overture Maps Foundation. '
      'Ảnh minh họa các môn thể thao: Pexels, Unsplash.',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.45),
        fontSize: 11,
      ),
    );
  }

  Widget _buildBackToTop() {
    final onTop = actions.onTop;
    if (onTop == null) return const SizedBox.shrink();
    return OutlinedButton.icon(
      key: const ValueKey('footer-to-top'),
      onPressed: onTop,
      icon: const Icon(Icons.arrow_upward_rounded, size: 15),
      label: const Text(
        'Lên đầu trang',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 34),
      ),
    );
  }

  Widget _buildSocialRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSocialBtn('f', 'Facebook', const Color(0xFF1877F2)),
        const SizedBox(width: 8),
        _buildSocialBtn('Z', 'Zalo', const Color(0xFF0068FF)),
        const SizedBox(width: 8),
        _buildSocialBtn('▶', 'YouTube', const Color(0xFFFF0000)),
        const SizedBox(width: 8),
        _buildSocialBtn('✉', 'Email', _accent),
      ],
    );
  }

  Widget _buildSocialBtn(String letter, String tooltip, Color color) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        ),
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Một liên kết ở chân trang: đổi màu khi rê chuột, bấm được nếu có [onTap]; không có thì chỉ là chữ thường.
class _FooterLink extends StatefulWidget {
  final String linkKey;
  final String? leading;
  final String label;
  final VoidCallback? onTap;

  const _FooterLink({
    required this.linkKey,
    this.leading,
    required this.label,
    this.onTap,
  });

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final clickable = widget.onTap != null;
    final active = clickable && _hover;
    final text = Text(
      widget.label,
      style: TextStyle(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.7),
        fontSize: 12.5,
        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        decoration: active ? TextDecoration.underline : TextDecoration.none,
        decorationColor: AppFooter._accent,
      ),
    );
    final row = Row(
      children: [
        if (widget.leading != null)
          Text(widget.leading!, style: const TextStyle(fontSize: 12))
        else
          const Text(
            '›',
            style: TextStyle(
              color: AppFooter._accent,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        const SizedBox(width: 8),
        Flexible(child: text),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: clickable
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: InkWell(
                key: ValueKey(widget.linkKey),
                borderRadius: BorderRadius.circular(6),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: row,
                ),
              ),
            )
          : Padding(
              key: ValueKey(widget.linkKey),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: row,
            ),
    );
  }
}
