import 'package:flutter/material.dart';

import '../data/info_pages.dart';

/// Trang thông tin mở từ chân trang: giới thiệu, hướng dẫn, câu hỏi thường gặp, điều khoản, chính sách...
class InfoPageScreen extends StatelessWidget {
  static const _green = Color(0xFF15803D);
  static const _ink = Color(0xFF0F172A);
  static const _body = Color(0xFF334155);
  static const _grey = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);

  final InfoPage page;

  const InfoPageScreen({super.key, required this.page});

  /// Mở trang [id]. [replace] = true thì thay trang hiện tại (dùng khi chuyển giữa các trang thông tin).
  static void open(
    BuildContext context,
    InfoPageId id, {
    bool replace = false,
  }) {
    final route = MaterialPageRoute<void>(
      builder: (_) => InfoPageScreen(page: InfoPages.of(id)),
    );
    if (replace) {
      Navigator.pushReplacement(context, route);
    } else {
      Navigator.push(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final others = InfoPages.all.where((p) => p.id != page.id).toList();
    return Scaffold(
      key: ValueKey('info-page-${page.id.name}'),
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          page.title.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
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
                  _header(),
                  for (final s in page.sections) _section(s),
                  if (page.faq.isNotEmpty) _faqList(),
                  const SizedBox(height: 6),
                  _more(context, others),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration get _card => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _line),
    boxShadow: const [
      BoxShadow(color: Color(0x0F0F172A), blurRadius: 14, offset: Offset(0, 6)),
    ],
  );

  Widget _header() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14532D), Color(0xFF15803D), Color(0xFF0D9488)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33166534),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            page.title,
            key: const ValueKey('info-title'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          if (page.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              page.note,
              key: const ValueKey('info-note'),
              style: const TextStyle(color: Color(0xFFBBF7D0), fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            page.intro,
            key: const ValueKey('info-intro'),
            style: const TextStyle(
              color: Color(0xFFF0FDF4),
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(InfoSection s) {
    return Container(
      key: ValueKey('info-section-${s.heading}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.heading,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final p in s.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                p,
                style: const TextStyle(
                  color: _body,
                  fontSize: 14.5,
                  height: 1.6,
                ),
              ),
            ),
          for (var i = 0; i < s.bullets.length; i++)
            _bullet(i, s.bullets[i], s.numbered),
        ],
      ),
    );
  }

  Widget _bullet(int i, String text, bool numbered) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (numbered)
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 1),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  color: _green,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: Color(0xFF16A34A),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _body,
                fontSize: 14.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faqList() {
    return Column(
      children: [
        for (var i = 0; i < page.faq.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            clipBehavior: Clip.antiAlias,
            decoration: _card,
            child: Material(
              type: MaterialType.transparency,
              child: Theme(
                data: ThemeData(
                  dividerColor: Colors.transparent,
                  colorScheme: const ColorScheme.light(primary: _green),
                ),
                child: ExpansionTile(
                  key: ValueKey('info-faq-$i'),
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  title: Text(
                    page.faq[i].question,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  children: [
                    Text(
                      page.faq[i].answer,
                      style: const TextStyle(
                        color: _body,
                        fontSize: 14.5,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _more(BuildContext context, List<InfoPage> others) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Xem thêm',
            style: TextStyle(
              color: _grey,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in others)
                ActionChip(
                  key: ValueKey('info-more-${p.id.name}'),
                  avatar: Icon(p.icon, size: 16, color: _green),
                  label: Text(p.title),
                  backgroundColor: const Color(0xFFF0FDF4),
                  side: const BorderSide(color: Color(0xFFBBF7D0)),
                  labelStyle: const TextStyle(
                    color: Color(0xFF166534),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  onPressed: () =>
                      InfoPageScreen.open(context, p.id, replace: true),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
