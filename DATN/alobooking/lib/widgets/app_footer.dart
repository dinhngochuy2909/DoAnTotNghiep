import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 900;
    final isMedium = screenWidth >= 600;

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
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 48 : 20,
              vertical: 32,
            ),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildBrandSection()),
                      const SizedBox(width: 32),
                      Expanded(flex: 2, child: _buildLinksSection()),
                      const SizedBox(width: 32),
                      Expanded(flex: 2, child: _buildSportsSection()),
                      const SizedBox(width: 32),
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
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildLinksSection()),
                              const SizedBox(width: 24),
                              Expanded(child: _buildSportsSection()),
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
                        ],
                      ),
          ),
          Container(
            height: 1,
            margin: EdgeInsets.symmetric(horizontal: isWide ? 48 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0),
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 48 : 20,
              vertical: 16,
            ),
            child: isWide
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCopyright(),
                      _buildSocialRow(),
                    ],
                  )
                : Column(
                    children: [
                      _buildCopyright(),
                      const SizedBox(height: 12),
                      _buildSocialRow(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

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
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              ),
              child: const Icon(Icons.sports_tennis, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
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
                  'Nền tảng đặt sân thể thao #1',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'AloBooking – Nền tảng đặt sân thể thao trực tuyến hàng đầu Việt Nam. '
          'Kết nối người chơi với hàng nghìn sân cầu lông, pickleball, bóng đá, '
          'tennis trên toàn quốc.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
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
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9),
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

  Widget _buildLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFooterHeading('Liên kết nhanh'),
        const SizedBox(height: 12),
        _buildFooterLink('🏠', 'Trang chủ'),
        _buildFooterLink('🔍', 'Tìm kiếm sân'),
        _buildFooterLink('📅', 'Sân đã đặt'),
        _buildFooterLink('❤️', 'Sân yêu thích'),
        _buildFooterLink('👤', 'Tài khoản'),
        _buildFooterLink('🎯', 'Sự kiện thể thao'),
      ],
    );
  }

  Widget _buildSportsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFooterHeading('Thể thao'),
        const SizedBox(height: 12),
        _buildFooterLink('🏸', 'Cầu lông'),
        _buildFooterLink('🎾', 'Pickleball'),
        _buildFooterLink('⚽', 'Bóng đá'),
        _buildFooterLink('🎾', 'Tennis'),
        _buildFooterLink('🏀', 'Bóng rổ'),
        _buildFooterLink('🏐', 'Bóng chuyền'),
      ],
    );
  }

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFooterHeading('Liên hệ & Hỗ trợ'),
        const SizedBox(height: 12),
        _buildContactItem(Icons.location_on_outlined, 'Địa chỉ',
            '72 Thành Thái, Phường 14, Quận 10\nTP. Hồ Chí Minh, Việt Nam'),
        const SizedBox(height: 10),
        _buildContactItem(Icons.phone_outlined, 'Hotline', '1900 6750'),
        const SizedBox(height: 10),
        _buildContactItem(Icons.email_outlined, 'Email', 'support@alobooking.vn'),
        const SizedBox(height: 10),
        _buildContactItem(Icons.access_time_outlined, 'Giờ hỗ trợ',
            'Thứ 2 – Chủ nhật: 7:00 – 22:00'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildBadge('✓ Bộ Công Thương'),
            _buildBadge('🔒 Bảo mật SSL'),
            _buildBadge('🏆 Tin cậy 2024'),
          ],
        ),
      ],
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF4ADE80), size: 15),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
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

  Widget _buildBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
      ),
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
            color: const Color(0xFF4ADE80),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLink(String emoji, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyright() {
    return Text(
      '©  AloBooking. Bảo lưu mọi quyền. '
      'Được phát triển bởi Đinh Ngọc Huy.',
      style: TextStyle(
        color: Colors.white.withOpacity(0.45),
        fontSize: 11,
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
        _buildSocialBtn('✉', 'Email', const Color(0xFF4ADE80)),
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
          color: color.withOpacity(0.18),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5), width: 1),
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
