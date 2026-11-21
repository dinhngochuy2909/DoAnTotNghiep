/// Một bài tin do quản trị viên đăng trong mục Khám phá (collection `news` trên Firestore).
class NewsPost {
  /// Các loại tin admin được chọn khi đăng: (khóa lưu, nhãn hiển thị).
  static const categories = <(String key, String label)>[
    ('promo', 'Ưu đãi'),
    ('event', 'Sự kiện'),
    ('update', 'Có gì mới'),
    ('notice', 'Thông báo'),
  ];

  static String labelOf(String category) {
    for (final c in categories) {
      if (c.$1 == category) return c.$2;
    }
    return 'Thông báo';
  }

  final String id;
  final String title;
  final String body;

  /// 'promo' | 'event' | 'update' | 'notice'
  final String category;

  /// Ảnh minh họa (URL), rỗng nếu không có.
  final String imageUrl;

  /// Mã sân được gắn kèm (0 = không gắn sân nào).
  final int venueId;

  /// Tin ghim luôn nằm trên cùng.
  final bool pinned;
  final String author;
  final DateTime createdAt;

  const NewsPost({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'notice',
    this.imageUrl = '',
    this.venueId = 0,
    this.pinned = false,
    this.author = 'AloBooking',
    required this.createdAt,
  });

  NewsPost copyWith({
    String? title,
    String? body,
    String? category,
    String? imageUrl,
    int? venueId,
    bool? pinned,
    String? author,
  }) =>
      NewsPost(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        category: category ?? this.category,
        imageUrl: imageUrl ?? this.imageUrl,
        venueId: venueId ?? this.venueId,
        pinned: pinned ?? this.pinned,
        author: author ?? this.author,
        createdAt: createdAt,
      );

  /// Đọc một tài liệu Firestore; trả về null nếu thiếu tiêu đề hoặc ngày đăng không hợp lệ
  /// (không tự bịa ngày để tin lên đầu bảng).
  static NewsPost? tryFromFirestoreFields(String docId, Map<String, dynamic> f) {
    String s(String k) => (f[k]?['stringValue'] ?? '').toString();
    final title = s('title').trim();
    final created = DateTime.tryParse(s('createdAt'));
    if (title.isEmpty || created == null) return null;
    return NewsPost(
      id: docId,
      title: title,
      body: s('body'),
      category: s('category').isEmpty ? 'notice' : s('category'),
      imageUrl: s('imageUrl'),
      venueId: int.tryParse((f['venueId']?['integerValue'] ?? '0').toString()) ?? 0,
      pinned: f['pinned']?['booleanValue'] == true,
      author: s('author').isEmpty ? 'AloBooking' : s('author'),
      createdAt: created,
    );
  }

  Map<String, dynamic> toFirestoreFields() => {
        'title': {'stringValue': title},
        'body': {'stringValue': body},
        'category': {'stringValue': category},
        'imageUrl': {'stringValue': imageUrl},
        'venueId': {'integerValue': venueId.toString()},
        'pinned': {'booleanValue': pinned},
        'author': {'stringValue': author},
        'createdAt': {'stringValue': createdAt.toIso8601String()},
      };
}
