// ignore_for_file: invalid_use_of_protected_member
part of '../admin_screen.dart';

extension _AdminNewsTab on _AdminScreenState {
  Color _newsColor(String category) {
    switch (category) {
      case 'promo':
        return AdminUi.warn;
      case 'event':
        return AdminUi.violet;
      case 'update':
        return AdminUi.success;
      default:
        return AdminUi.info;
    }
  }

  void _sortNews() => _news.sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });

  Widget _buildNewsTab() {
    return LayoutBuilder(builder: (context, c) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(c.maxWidth >= 760 ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminCard(
              title: 'Tin đã đăng (${_news.length})',
              subtitle: 'Hiện ở mục Khám phá của khách. Tin ghim nằm trên cùng, còn lại mới nhất trước.',
              trailing: ElevatedButton.icon(
                key: const ValueKey('admin-news-add'),
                onPressed: () => _openNewsDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Đăng tin mới', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminUi.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              child: _news.isEmpty
                  ? const EmptyHint(
                      icon: Icons.campaign_outlined,
                      text: 'Chưa có tin nào. Bấm "Đăng tin mới" để đăng ưu đãi, sự kiện hoặc thông báo cho khách.',
                    )
                  : Column(children: [for (final p in _news) _newsRow(p)]),
            ),
            const SizedBox(height: 16),
            const AdminCard(
              title: 'Tin tự động',
              subtitle: 'Hệ thống tự thêm vào Khám phá, không cần đăng tay',
              child: Text(
                '• Sân mới: sân được duyệt hoặc thêm trong 30 ngày qua (chỉ sân có ngày duyệt; sân nhập từ dữ liệu mở và sân demo không đưa lên).\n'
                '• Đánh giá mới: đánh giá có nội dung của khách trong 30 ngày qua, tối đa 10 đánh giá gần nhất.',
                style: TextStyle(color: AdminUi.muted, fontSize: 13, height: 1.55),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _newsRow(NewsPost p) {
    final color = _newsColor(p.category);
    final venueName = p.venueId == 0 ? null : _venues.where((v) => v.id == p.venueId).map((v) => v.name).firstOrNull;
    return Container(
      key: ValueKey('admin-news-${p.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AdminUi.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminUi.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: StatusPill(NewsPost.labelOf(p.category), color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(p.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AdminUi.text, fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    if (p.pinned) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.push_pin, size: 14, color: AdminUi.warn),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${_AdminScreenState._newsStamp(p.createdAt)}${p.isExternal ? ' · Nguồn: ${p.sourceName.isEmpty ? Uri.parse(p.sourceUrl).host : p.sourceName}' : ''}${venueName != null ? ' · Gắn sân: $venueName' : ''}',
                  style: AdminUi.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Tin dẫn từ báo ngoài chỉ có tiêu đề + liên kết: admin xóa được nhưng không sửa nội dung của báo
          if (!p.isExternal)
            IconButton(
              key: ValueKey('admin-news-edit-${p.id}'),
              tooltip: 'Sửa',
              icon: const Icon(Icons.edit_outlined, size: 19, color: AdminUi.muted),
              onPressed: () => _openNewsDialog(existing: p),
            ),
          IconButton(
            key: ValueKey('admin-news-delete-${p.id}'),
            tooltip: 'Xóa',
            icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AdminUi.danger),
            onPressed: () => _confirmDeleteNews(p),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteNews(NewsPost p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminUi.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AdminUi.border)),
        title: const Text('Xóa tin này?', style: TextStyle(color: AdminUi.text, fontWeight: FontWeight.w600, fontSize: 16)),
        content: Text('"${p.title}" sẽ biến mất khỏi mục Khám phá của khách.',
            style: const TextStyle(color: AdminUi.muted, fontSize: 13.5, height: 1.45)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: AdminUi.muted))),
          FilledButton(
            key: const ValueKey('admin-news-confirm-delete'),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await FirestoreService.deleteNews(p.id);
              if (!mounted) return;
              if (!ok) {
                _showToast('Không xóa được tin. Kiểm tra kết nối rồi thử lại.', isError: true);
                return;
              }
              setState(() => _news.removeWhere((x) => x.id == p.id));
              _showToast('Đã xóa tin.');
            },
            style: FilledButton.styleFrom(backgroundColor: AdminUi.danger, foregroundColor: Colors.white),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _openNewsDialog({NewsPost? existing}) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    final imageCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    var category = existing?.category ?? 'promo';
    var pinned = existing?.pinned ?? false;
    Venue? linked = (existing == null || existing.venueId == 0) ? null : _venues.where((v) => v.id == existing.venueId).firstOrNull;
    String? error;
    var saving = false;
    var photoSport = 'badminton';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AdminUi.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AdminUi.border)),
          title: Text(isEdit ? 'Sửa tin' : 'Đăng tin mới', style: const TextStyle(color: AdminUi.text, fontWeight: FontWeight.w600, fontSize: 17)),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Loại tin', style: TextStyle(color: AdminUi.muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final c in NewsPost.categories)
                        ChoiceChip(
                          key: ValueKey('admin-news-cat-${c.$1}'),
                          label: Text(c.$2),
                          selected: category == c.$1,
                          showCheckmark: false,
                          onSelected: (_) => setD(() => category = c.$1),
                          selectedColor: _newsColor(c.$1).withValues(alpha: 0.25),
                          backgroundColor: AdminUi.bg,
                          side: BorderSide(color: category == c.$1 ? _newsColor(c.$1) : AdminUi.border),
                          labelStyle: TextStyle(color: category == c.$1 ? AdminUi.text : AdminUi.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  KeyedSubtree(key: const ValueKey('admin-news-title'), child: _dialogTextField('Tiêu đề *', titleCtrl, 'VD: Giảm 20% giờ vàng cuối tuần')),
                  const SizedBox(height: 12),
                  const Text('Nội dung *', style: TextStyle(color: AdminUi.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(color: AdminUi.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AdminUi.border)),
                    child: TextField(
                      key: const ValueKey('admin-news-body'),
                      controller: bodyCtrl,
                      minLines: 4,
                      maxLines: 8,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
                      decoration: const InputDecoration(
                        hintText: 'Viết nội dung tin: áp dụng khi nào, ở đâu, điều kiện...',
                        hintStyle: TextStyle(color: AdminUi.faint, fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  KeyedSubtree(key: const ValueKey('admin-news-image'), child: _dialogTextField('Ảnh (đường dẫn http, không bắt buộc)', imageCtrl, 'https://...')),
                  const SizedBox(height: 8),
                  const Text('Hoặc chọn ảnh minh họa có sẵn', style: TextStyle(color: AdminUi.muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final sp in const [('badminton', 'Cầu lông'), ('pickleball', 'Pickleball'), ('tennis', 'Tennis'), ('basketball', 'Bóng rổ'), ('football', 'Bóng đá')])
                        ChoiceChip(
                          key: ValueKey('admin-news-photo-sport-${sp.$1}'),
                          label: Text(sp.$2),
                          selected: photoSport == sp.$1,
                          showCheckmark: false,
                          onSelected: (_) => setD(() => photoSport = sp.$1),
                          selectedColor: AdminUi.accent.withValues(alpha: 0.25),
                          backgroundColor: AdminUi.bg,
                          side: BorderSide(color: photoSport == sp.$1 ? AdminUi.accent : AdminUi.border),
                          labelStyle: TextStyle(color: photoSport == sp.$1 ? AdminUi.text : AdminUi.muted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 62,
                    child: ListView.separated(
                      key: const ValueKey('admin-news-photos'),
                      scrollDirection: Axis.horizontal,
                      itemCount: math.min(12, VenuePhotos.forSport(photoSport).length),
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final url = VenuePhotos.forSport(photoSport)[i];
                        final chosen = imageCtrl.text.trim() == url;
                        return InkWell(
                          key: ValueKey('admin-news-photo-$i'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setD(() => imageCtrl.text = url),
                          child: Container(
                            width: 104,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: chosen ? AdminUi.accent : AdminUi.border, width: chosen ? 2.5 : 1),
                            ),
                            child: VenueImageView(imageUrl: url),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Ảnh trong kho là ảnh minh họa (Pexels/Unsplash) nên tin sẽ ghi nhãn "Ảnh minh họa". Ảnh riêng của bạn thì không có nhãn.',
                      style: TextStyle(color: AdminUi.faint, fontSize: 11, height: 1.35)),
                  const SizedBox(height: 12),
                  const Text('Gắn với một sân (không bắt buộc)', style: TextStyle(color: AdminUi.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  if (linked != null)
                    Container(
                      key: const ValueKey('admin-news-linked'),
                      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                      decoration: BoxDecoration(color: AdminUi.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AdminUi.accent)),
                      child: Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 16, color: AdminUi.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(linked!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AdminUi.text, fontSize: 13)),
                          ),
                          IconButton(
                            tooltip: 'Bỏ gắn sân',
                            icon: const Icon(Icons.close_rounded, size: 18, color: AdminUi.muted),
                            onPressed: () => setD(() => linked = null),
                          ),
                        ],
                      ),
                    )
                  else
                    Autocomplete<Venue>(
                      displayStringForOption: (v) => v.name,
                      optionsBuilder: (value) {
                        final q = value.text.trim().toLowerCase();
                        if (q.length < 2) return const Iterable<Venue>.empty();
                        return _venues.where((v) => v.isApproved && !v.isDemo && v.name.toLowerCase().contains(q)).take(8);
                      },
                      onSelected: (v) => setD(() => linked = v),
                      fieldViewBuilder: (ctx, ctrl, focus, onSubmit) => Container(
                        decoration: BoxDecoration(color: AdminUi.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AdminUi.border)),
                        child: TextField(
                          key: const ValueKey('admin-news-venue-search'),
                          controller: ctrl,
                          focusNode: focus,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Gõ tên sân (từ 2 ký tự) để chọn',
                            hintStyle: TextStyle(color: AdminUi.faint, fontSize: 12),
                            prefixIcon: Icon(Icons.search, size: 18, color: AdminUi.muted),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    key: const ValueKey('admin-news-pinned'),
                    value: pinned,
                    onChanged: (v) => setD(() => pinned = v),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeThumbColor: AdminUi.accent,
                    title: const Text('Ghim lên đầu Khám phá', style: TextStyle(color: AdminUi.text, fontSize: 13.5)),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(error!, key: const ValueKey('admin-news-error'), style: const TextStyle(color: AdminUi.danger, fontSize: 12.5)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: AdminUi.muted)),
            ),
            ElevatedButton(
              key: const ValueKey('admin-news-save'),
              onPressed: saving
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      final body = bodyCtrl.text.trim();
                      final img = imageCtrl.text.trim();
                      String? err;
                      if (title.length < 3) {
                        err = 'Nhập tiêu đề (ít nhất 3 ký tự).';
                      } else if (body.isEmpty) {
                        err = 'Nhập nội dung tin.';
                      } else if (img.isNotEmpty && !img.startsWith('http')) {
                        err = 'Ảnh phải là đường dẫn bắt đầu bằng http:// hoặc https://';
                      }
                      if (err != null) {
                        setD(() => error = err);
                        return;
                      }
                      setD(() {
                        saving = true;
                        error = null;
                      });
                      final post = existing != null
                          ? existing.copyWith(title: title, body: body, category: category, imageUrl: img, venueId: linked?.id ?? 0, pinned: pinned)
                          : NewsPost(
                              id: 'n${DateTime.now().millisecondsSinceEpoch}',
                              title: title,
                              body: body,
                              category: category,
                              imageUrl: img,
                              venueId: linked?.id ?? 0,
                              pinned: pinned,
                              createdAt: DateTime.now(),
                            );
                      final ok = isEdit ? await FirestoreService.updateNews(post) : await FirestoreService.addNews(post);
                      if (!ok) {
                        if (ctx.mounted) {
                          setD(() {
                            saving = false;
                            error = 'Không lưu được. Kiểm tra kết nối rồi thử lại.';
                          });
                        }
                        return;
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      setState(() {
                        final i = _news.indexWhere((x) => x.id == post.id);
                        if (i >= 0) {
                          _news[i] = post;
                        } else {
                          _news.add(post);
                        }
                        _sortNews();
                      });
                      _showToast(isEdit ? 'Đã cập nhật tin.' : 'Đã đăng tin lên mục Khám phá.');
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AdminUi.accent, foregroundColor: Colors.white),
              child: Text(saving ? 'Đang lưu…' : (isEdit ? 'Lưu thay đổi' : 'Đăng tin')),
            ),
          ],
        ),
      ),
    );
  }
}
