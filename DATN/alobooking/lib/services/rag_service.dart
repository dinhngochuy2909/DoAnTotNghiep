import 'dart:math' as math;
import 'demand_forecast_service.dart';
import 'weather_service.dart';
import 'booking_slots.dart';
import '../models/venue.dart';
import 'firestore_service.dart';

/// Một đơn vị tri thức (chunk) trong kho RAG.
class RagKnowledgeChunk {
  final String id;
  final String category; // 'venue' | 'policy' | 'guide'
  final String title;
  final String content;
  final Venue? venueRef;
  final List<String> keywords;

  /// Văn bản đã chuẩn hoá (không dấu, chữ thường) dùng để chấm điểm BM25.
  late final List<String> tokens;

  RagKnowledgeChunk({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    this.venueRef,
    this.keywords = const [],
  }) {
    tokens = RagText.tokenize('$title $title $content ${keywords.join(' ')}');
  }
}

/// Ý định / các ràng buộc trích xuất từ câu hỏi.
class RagIntent {
  String? sport; // pickleball | badminton | football | tennis
  String? district; // đã chuẩn hoá không dấu
  String? districtLabel;
  final List<String> districts = []; // mọi quận được nhắc tới (để so sánh), đã bỏ dấu
  int? maxPricePerHour; // nghìn đồng
  int? hour; // giờ muốn chơi (0-23)
  DateTime date;
  bool dateExplicit = false;
  bool cheapest = false;
  bool topRated = false;
  bool nearest = false;
  final Set<String> amenities = {}; // den_dem, gui_xe, may_ban_bong, mai_che
  Venue? namedVenue;
  String? unknownArea; // địa điểm khách hỏi nhưng hệ thống không có sân
  bool wantsStats = false; // hỏi về mặt bằng giá (trung bình, bao nhiêu...)
  bool goldenHour = false; // hỏi giá khung giờ vàng / cao điểm
  final Set<String> topics = {}; // cancel, fixed, payment, promo, guide, weather, contact

  RagIntent(this.date);

  bool get wantsVenues =>
      sport != null ||
      district != null ||
      namedVenue != null ||
      unknownArea != null ||
      (wantsStats && (sport != null || district != null)) ||
      maxPricePerHour != null ||
      cheapest ||
      topRated ||
      nearest ||
      amenities.isNotEmpty;
}

/// Thống kê giá của một nhóm sân (đơn vị nghìn đồng).
class RagStats {
  final String label;
  final int count;
  final double avgLow; // giá khung thường trung bình
  final double avgHigh; // giá ca giờ vàng (16:00 – 22:00) trung bình
  final int minLow;
  final int maxHigh;
  final String unit; // 'giờ' | 'trận'

  const RagStats({
    required this.label,
    required this.count,
    required this.avgLow,
    required this.avgHigh,
    required this.minLow,
    required this.maxHigh,
    required this.unit,
  });

  static String _k(num v) => '${v.round()}k';

  String toText({bool goldenFocus = false}) {
    final b = StringBuffer();
    b.writeln('Thống kê giá $label ($count sân, đơn vị: đồng/$unit):');
    b.writeln('- Ca giờ vàng (${BookingSlots.goldenLabel}) trung bình: ${_k(avgHigh)}/$unit');
    b.writeln('- Khung giờ thường (ngoài ca vàng) trung bình: ${_k(avgLow)}/$unit');
    b.writeln('- Rẻ nhất: ${_k(minLow)}/$unit (khung thường); đắt nhất: ${_k(maxHigh)}/$unit (khung vàng)');
    return b.toString().trim();
  }
}

/// Kết quả truy xuất.
class RagRetrievalResult {
  final String query;
  final RagIntent intent;
  final RagStats? stats;
  final List<RagStats> moreStats; // các nhóm so sánh khác (khi hỏi nhiều quận)
  final List<RagKnowledgeChunk> chunks;
  final List<Venue> matchedVenues;
  final String augmentedPromptText;
  final int totalVenues;
  final String? forecastText; // dự đoán nhu cầu/hủy (khi khách hỏi)

  RagRetrievalResult({
    required this.query,
    required this.intent,
    this.stats,
    this.moreStats = const [],
    required this.chunks,
    required this.matchedVenues,
    required this.augmentedPromptText,
    required this.totalVenues,
    this.forecastText,
  });

  bool get hasPolicy => chunks.any((c) => c.category != 'venue');
}

/// Tiện ích chuẩn hoá tiếng Việt.
class RagText {
  static const _from =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  static const _to =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

  static String norm(String s) {
    final lower = s.toLowerCase();
    final b = StringBuffer();
    for (final r in lower.runes) {
      final ch = String.fromCharCode(r);
      final i = _from.indexOf(ch);
      b.write(i >= 0 ? _to[i] : ch);
    }
    return b
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9%\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static const _stop = {
    'la', 'va', 'cua', 'co', 'cho', 'toi', 'minh', 'ban', 'em', 'anh', 'chi',
    'nao', 'gi', 'the', 'nay', 'kia', 'o', 'tai', 'voi', 'duoc', 'khong', 'nhe',
    'a', 'ha', 'oi', 'xin', 'muon', 'can', 'hoi', 'nhung', 'thi', 'ma', 'de',
    'mot', 'cac', 'nhu', 'bao', 'nhieu', 'khi', 'ne', 'vay', 'sao',
  };

  static List<String> tokenize(String s) => norm(s)
      .split(' ')
      .where((t) => t.length > 1 && !_stop.contains(t))
      .toList();
}

/// Bộ máy RAG của AloBooking: nạp dữ liệu thật (Firestore), hiểu câu hỏi,
/// truy xuất bằng bộ lọc có cấu trúc + BM25, rồi dựng ngữ cảnh cho LLM.
class RagService {
  static const _ttl = Duration(minutes: 3);

  static List<Venue> _venues = [];
  static List<BookingItem> _bookings = [];
  static DateTime? _loadedAt;
  static Future<void>? _loading;
  static List<RagKnowledgeChunk> _policyChunks = [];

  // BM25 cho toàn bộ corpus (policy + venue)
  static List<RagKnowledgeChunk> _corpus = [];
  static Map<String, int> _df = {};
  static double _avgLen = 1;

  static const _districts = [
    'cau giay', 'dong da', 'thanh xuan', 'ba dinh', 'hoan kiem', 'hai ba trung',
    'tay ho', 'nam tu liem', 'bac tu liem', 'ha dong', 'hoang mai', 'long bien',
    'gia lam', 'dong anh', 'thanh tri', 'hoai duc',
  ];

  static const _otherProvinces = [
    'hung yen', 'hai phong', 'hai duong', 'bac ninh', 'bac giang', 'vinh phuc', 'phu tho',
    'thai nguyen', 'nam dinh', 'thai binh', 'ha nam', 'ninh binh', 'quang ninh', 'hoa binh',
    'thanh hoa', 'nghe an', 'ha tinh', 'hue', 'da nang', 'quang nam', 'khanh hoa', 'nha trang',
    'da lat', 'lam dong', 'binh duong', 'dong nai', 'can tho', 'vung tau', 'sai gon',
    'ho chi minh', 'tphcm', 'hcm', 'lao cai', 'son la', 'lang son', 'tuyen quang',
  ];

  /// Danh sách quận/huyện hiện có sân (kèm số sân).
  static String coverageText() {
    final m = <String, int>{};
    for (final v in _venues) {
      m[v.district] = (m[v.district] ?? 0) + 1;
    }
    final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return e.map((x) => '${x.key} (${x.value})').join(', ');
  }

  static int get venueCount => _venues.length;

  /// Nạp (hoặc làm mới) dữ liệu từ Firestore. Gọi nhiều lần vẫn an toàn.
  static Future<void> ensureLoaded({bool force = false}) {
    final fresh = _loadedAt != null && DateTime.now().difference(_loadedAt!) < _ttl;
    if (!force && fresh) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  static Future<void> _load() async {
    final results = await Future.wait([
      FirestoreService.getVenues(),
      FirestoreService.getBookings(),
    ]);
    // Chỉ sân đã được duyệt mới được tư vấn cho khách
    _venues = (results[0] as List<Venue>).where((v) => v.isApproved).toList();
    _bookings = results[1] as List<BookingItem>;
    _policyChunks = _buildPolicyChunks();
    _rebuildIndex();
    _loadedAt = DateTime.now();
  }

  static void _rebuildIndex() {
    final venueChunks = _venues.map(_venueChunk).toList();
    _corpus = [..._policyChunks, ...venueChunks];
    _df = {};
    var total = 0;
    for (final c in _corpus) {
      total += c.tokens.length;
      for (final t in c.tokens.toSet()) {
        _df[t] = (_df[t] ?? 0) + 1;
      }
    }
    _avgLen = _corpus.isEmpty ? 1 : total / _corpus.length;
  }

  // ───────────────────────── Chunks ─────────────────────────

  static String sportLabel(String type) {
    switch (type.toLowerCase()) {
      case 'pickleball':
        return 'Pickleball';
      case 'badminton':
        return 'Cầu lông';
      case 'football':
        return 'Bóng đá';
      case 'tennis':
        return 'Tennis';
      default:
        return type;
    }
  }

  static RagKnowledgeChunk _venueChunk(Venue v) {
    final sport = sportLabel(v.type);
    return RagKnowledgeChunk(
      id: 'venue_${v.id}',
      category: 'venue',
      title: v.name,
      venueRef: v,
      keywords: [sport, v.district, v.type, ...v.tags],
      content: '''Sân: ${v.name}
Môn: $sport
Địa chỉ: ${v.address} (quận/huyện/phường/xã: ${v.district}${v.distance.isEmpty ? '' : ', cách ~${v.distance}'})
Giờ mở cửa: ${v.hours}
Số sân con: ${v.courts} sân
Giá: ${v.price}
Đánh giá: ${v.rating}/5
Tiện ích: ${v.tags.join(', ')}
Chủ sân: ${v.ownerName}''',
    );
  }

  static List<RagKnowledgeChunk> _buildPolicyChunks() => [
        RagKnowledgeChunk(
          id: 'policy_cancel',
          category: 'policy',
          title: 'Chính sách hủy sân, dời lịch, hoàn cọc',
          keywords: ['huy san', 'doi lich', 'hoan tien', 'hoan coc', 'bao luu', 'mua bao'],
          content: '''- Lịch đã đặt KHÔNG tự hủy được trên ứng dụng (tránh giữ chỗ ảo).
- Bất khả kháng do thời tiết xấu (mưa bão, ngập sân ngoài trời): liên hệ Hotline 0364059999 trước giờ chơi ít nhất 2 tiếng để dời lịch hoặc bảo lưu 100% tiền cọc.
- Đổi khung giờ: báo trước tối thiểu 12 tiếng qua Hotline 0364059999 hoặc nhắn chủ sân.''',
        ),
        RagKnowledgeChunk(
          id: 'policy_fixed',
          category: 'policy',
          title: 'Đặt lịch cố định theo tháng/quý',
          keywords: ['co dinh', 'thang', 'quy', 'hang tuan', 'chiet khau', 'hotline'],
          content: '''- Đặt cố định hàng tuần (2-3 buổi/tuần) từ 1 tháng trở lên: chiết khấu 15% tổng tiền giờ.
- Ưu tiên giữ ca giờ vàng 16:00–22:00.
- Đăng ký qua Hotline/Zalo 0364059999 để nhân viên khoá sân cố định.''',
        ),
        RagKnowledgeChunk(
          id: 'policy_payment',
          category: 'policy',
          title: 'Thanh toán',
          keywords: ['thanh toan', 'vietqr', 'chuyen khoan', 'tien mat', 'dat coc', 'qr'],
          content: '''- Chỉ thanh toán bằng chuyển khoản ngân hàng quét mã VietQR (không nhận tiền mặt).
- Sau khi bấm xác nhận, ứng dụng hiện mã QR đúng số tiền kèm nội dung chuyển khoản là mã đơn; đơn chuyển sang "Đã xác nhận" khi ban quản lý nhận được tiền.
- Số tiền chuyển khoản là toàn bộ tiền các ca đã chọn (ứng dụng không có hình thức đặt cọc một phần).''',
        ),
        RagKnowledgeChunk(
          id: 'policy_promo',
          category: 'policy',
          title: 'Khuyến mãi và ưu đãi',
          keywords: ['khuyen mai', 'happy hours', 'giam gia', 'uu dai', 'sinh vien', 'may ban bong', 'mien phi'],
          content: '''- Happy Hours trưa 11:30–14:00 hằng ngày: giảm 20–25% sân Cầu lông và Pickleball.
- Miễn phí máy bắn bóng 05:00–08:00 tại Cụm sân Pickleball Cầu Giấy Park và D-Agility (chỉ các sân này được xác nhận có máy bắn bóng).
- Sinh viên: giảm thêm 10k/giờ khi xuất trình thẻ tại các sân khu vực Cầu Giấy và Đống Đa.''',
        ),
        RagKnowledgeChunk(
          id: 'guide_booking',
          category: 'guide',
          title: 'Hướng dẫn đặt sân trên ứng dụng',
          keywords: ['huong dan', 'cach dat', 'so do', 'dat san', 'chon gio', 'o trang', 'o do'],
          content: '''1. Chọn sân (hoặc bấm nút "ĐẶT SÂN" trên thẻ sân chatbot gợi ý).
2. Chọn ngày trên thanh ngày.
3. Bảng giờ: ô trắng = trống, ô đỏ = đã có người đặt, ô xám = tạm khoá.
4. Chạm vào các ô trắng muốn đặt (ô chọn có viền xanh đậm).
5. Kiểm tra "Tổng giờ" và "Tổng tiền" ở thanh dưới, bấm "TIẾP THEO" để xác nhận và thanh toán.
Giá mỗi sân ghi dạng "giá giờ thường - giá giờ vàng": ca giờ vàng là 16:00–22:00 và có giá nhỉnh hơn giờ thường (trước 16:00 và sau 22:00); mức chênh khác nhau theo từng sân.''',
        ),
        RagKnowledgeChunk(
          id: 'guide_weather',
          category: 'guide',
          title: 'Chọn sân theo thời tiết',
          keywords: ['thoi tiet', 'mua', 'nang', 'nong', 'trong nha', 'mai che', 'ngoai troi'],
          content: '''- Trời mưa/nồm: ưu tiên sân Cầu lông trong nhà hoặc Pickleball có mái che.
- Trời mát 20–28°C: hợp Bóng đá sân 7 và Tennis ngoài trời.
- Nắng nóng: chọn sân có quạt công nghiệp/điều hoà hoặc chơi sáng sớm/tối.''',
        ),
        RagKnowledgeChunk(
          id: 'guide_contact',
          category: 'guide',
          title: 'Liên hệ hỗ trợ',
          keywords: ['lien he', 'hotline', 'zalo', 'ho tro', 'so dien thoai', 'tong dai'],
          content: 'Hotline/Zalo hỗ trợ AloBooking: 0364059999.',
        ),
      ];

  // ───────────────────────── Hiểu câu hỏi ─────────────────────────

  static RagIntent parseIntent(String query, {List<String> history = const []}) {
    final q = RagText.norm(query);
    final now = DateTime.now();
    final it = RagIntent(DateTime(now.year, now.month, now.day));

    _fillSlots(it, q);

    // Câu hỏi nối tiếp ("còn quận Cầu Giấy thì sao?"): kế thừa môn/quận từ các lượt trước
    for (final h in history.reversed.take(4)) {
      final hq = RagText.norm(h);
      final prev = RagIntent(it.date);
      _fillSlots(prev, hq);
      it.sport ??= prev.sport;
      it.district ??= prev.district;
      if (it.districts.isEmpty) it.districts.addAll(prev.districts);
      it.districtLabel ??= prev.districtLabel;
      it.namedVenue ??= q.split(' ').length <= 8 ? prev.namedVenue : null;
      if (it.sport != null && it.district != null) break;
    }
    return it;
  }

  static void _fillSlots(RagIntent it, String q) {
    // Môn
    if (RegExp(r'\b(pickleball|pickle|pkl)\b').hasMatch(q)) {
      it.sport = 'pickleball';
    } else if (RegExp(r'cau long|badminton').hasMatch(q)) {
      it.sport = 'badminton';
    } else if (RegExp(r'bong da|da bong|san 7|san 5|san mini|football|soccer').hasMatch(q)) {
      it.sport = 'football';
    } else if (RegExp(r'tennis|quan vot').hasMatch(q)) {
      it.sport = 'tennis';
    }

    // Quận
    final known = {..._districts, ..._venues.expand(_districtNames)};
    final found = known.where((d) => d.isNotEmpty && q.contains(d)).toList()
      ..sort((a, b) => q.indexOf(a).compareTo(q.indexOf(b)));
    if (found.isNotEmpty) {
      it.district = found.first;
      it.districts.addAll(found);
    }
    // Địa điểm ngoài phạm vi dữ liệu (tỉnh/thành khác, quận/huyện lạ)
    if (it.district == null) {
      for (final prov in _otherProvinces) {
        if (RegExp('\\b$prov\\b').hasMatch(q)) {
          it.unknownArea = prov;
          break;
        }
      }
      it.unknownArea ??= RegExp(r'\b(?:quan|huyen|thi xa)\s+([a-z]+(?:\s[a-z]+)?)').firstMatch(q)?.group(1);
    }
    if (it.district != null) {
      final sample = _venues.where((v) => RagText.norm(v.district) == it.district);
      it.districtLabel = sample.isNotEmpty ? sample.first.district : it.district;
    }

    // Ngày
    final today = it.date;
    if (RegExp(r'\b(ngay mai|toi mai|sang mai|chieu mai|trua mai)\b|\bmai$').hasMatch(q)) {
      it.date = today.add(const Duration(days: 1));
      it.dateExplicit = true;
    } else if (q.contains('ngay kia') || q.contains('hom kia')) {
      it.date = today.add(const Duration(days: 2));
      it.dateExplicit = true;
    } else if (q.contains('hom nay') || q.contains('toi nay') || q.contains('bay gio')) {
      it.dateExplicit = true;
    } else {
      final m = RegExp(r'(\d{1,2})/(\d{1,2})(?:/(\d{4}))?').firstMatch(q);
      if (m != null) {
        final d = int.parse(m.group(1)!), mo = int.parse(m.group(2)!);
        final y = int.tryParse(m.group(3) ?? '') ?? today.year;
        if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
          it.date = DateTime(y, mo, d);
          it.dateExplicit = true;
        }
      }
    }

    // Giờ chơi: "19h", "7 gio toi", "18:30"
    final hm = RegExp(r'\b(\d{1,2})\s*(?:h|gio|:)\s*(\d{0,2})').firstMatch(q);
    if (hm != null) {
      var h = int.parse(hm.group(1)!);
      if (h <= 12 && RegExp(r'\b(toi|chieu|pm)\b').hasMatch(q) && h < 12) h += 12;
      if (h >= 0 && h <= 23) it.hour = h;
    } else if (RegExp(r'\b(toi nay|buoi toi|toi mai|gio vang)\b').hasMatch(q)) {
      // Không dùng "toi" đơn lẻ: sau khi bỏ dấu, "tôi" (đại từ) trùng với "tối"
      it.hour = 19;
    } else if (q.contains('sang som')) {
      it.hour = 6;
    }

    // Giá trần: "dưới 150k", "tối đa 200 nghìn"
    final pm = RegExp(r'(?:duoi|toi da|khong qua|<)\s*(\d{2,3})\s*(?:k|nghin|ngan)?').firstMatch(q);
    if (pm != null) it.maxPricePerHour = int.parse(pm.group(1)!);

    // Hỏi mặt bằng giá: "giá trung bình", "giá sân cầu lông là bao nhiêu"
    if (RegExp(r'\bgia\b|bao nhieu tien|het bao nhieu|chi phi|tien san').hasMatch(q) ||
        RegExp(r'trung binh|binh quan|mat bang').hasMatch(q)) {
      it.wantsStats = true;
    }
    if (RegExp(r'gio vang|gio cao diem|cao diem|gio dep|buoi toi|khung toi').hasMatch(q)) {
      it.goldenHour = true;
    }

    // Sắp xếp
    if (RegExp(r'\b(re nhat|gia re|re re|re hon|re nua|gia thap hon|tiet kiem|binh dan)\b').hasMatch(q)) it.cheapest = true;
    if (RegExp(r'tot nhat|danh gia cao|chat luong|uy tin|dep nhat|xin nhat').hasMatch(q)) it.topRated = true;
    if (RegExp(r'gan nhat|gan day|gan toi|gan em|gan minh').hasMatch(q)) it.nearest = true;

    // Tiện ích
    if (RegExp(r'den dem|den chieu|choi dem|choi toi|chieu sang').hasMatch(q)) it.amenities.add('den_dem');
    if (RegExp(r'gui xe|do xe|bai xe|parking').hasMatch(q)) it.amenities.add('gui_xe');
    if (RegExp(r'may ban bong|may tap').hasMatch(q)) it.amenities.add('may_ban_bong');
    if (RegExp(r'mai che|trong nha|co mai|tranh mua').hasMatch(q)) it.amenities.add('mai_che');

    // Chủ đề chính sách
    if (RegExp(r'\b(huy|doi lich|doi gio|doi ca|hoan tien|hoan coc|bao luu)\b').hasMatch(q)) it.topics.add('cancel');
    if (RegExp(r'co dinh|theo thang|hang tuan|theo quy|dai han').hasMatch(q)) it.topics.add('fixed');
    if (RegExp(r'thanh toan|chuyen khoan|vietqr|\bqr\b|tien mat|\b(dat coc|coc)\b').hasMatch(q)) it.topics.add('payment');
    if (RegExp(r'khuyen mai|happy hour|giam gia|uu dai|sinh vien|voucher|mien phi').hasMatch(q)) it.topics.add('promo');
    if (RegExp(r'cach dat|huong dan|dat nhu the nao|dat sao|so do|o trang|o do|chon gio|dat san.*(the nao|ntn)').hasMatch(q)) it.topics.add('guide');
    if (RegExp(r'thoi tiet|\bmua\b|nang|nong|nom').hasMatch(q)) it.topics.add('weather');
    if (it.topics.contains('weather') &&
        RegExp(r'\bmua\b|nom').hasMatch(q) &&
        RegExp(r'chon san|san nao|nen choi|nen dat|goi y').hasMatch(q)) {
      it.amenities.add('mai_che');
    }
    if (RegExp(r'lien he|hotline|zalo|so dien thoai|sdt|tong dai|ho tro').hasMatch(q)) it.topics.add('contact');
    if (RegExp(r'du doan|(ty|ti) le (huy|dat)|dong khach|vang khach|co dong|nhu cau (dat|san)|ngay nao (dong|vang)|bao nhieu (don|luot) (dat|huy)').hasMatch(q)) {
      it.topics.add('forecast');
    }

    // Tên sân cụ thể
    it.namedVenue ??= _findNamedVenue(q);
  }

  static Venue? _findNamedVenue(String q) {
    Venue? best;
    double bestScore = 0;
    final qTokens = q.split(' ').toSet();
    const generic = {'san', 'cum', 'cau', 'long', 'bong', 'da', 'mini', 'tennis', 'pickleball', 'club', 'clb', 'trung', 'tam', 'the', 'thao', 'ha', 'noi'};
    for (final v in _venues) {
      final name = RagText.norm(v.name);
      if (q.contains(name)) return v;
      final distinct = name.split(' ').where((t) => t.length > 1 && !generic.contains(t)).toList();
      if (distinct.length < 2) continue;
      final hit = distinct.where(qTokens.contains).length;
      final score = hit / distinct.length;
      if (hit >= 2 && score >= 0.75 && score > bestScore) {
        bestScore = score;
        best = v;
      }
    }
    return best;
  }

  // ───────────────────────── Truy xuất ─────────────────────────

  /// Ghi đè ý định bằng kết quả LLM hiểu câu hỏi (đã xét cả lịch sử hội thoại).
  /// LLM hiểu ngôn ngữ tự nhiên tốt hơn luật cứng; luật chỉ còn là phương án dự phòng.
  static void applyLlmIntent(RagIntent it, Map<String, dynamic> m) {
    String? s(String k) {
      final v = m[k];
      return v is String && v.trim().isNotEmpty && v.trim().toLowerCase() != 'null' ? v.trim() : null;
    }

    int? n(String k) => m[k] is num ? (m[k] as num).round() : int.tryParse('${m[k]}');
    bool b(String k) => m[k] == true;

    final sport = s('sport');
    it.sport = const {'pickleball', 'badminton', 'football', 'tennis'}.contains(sport) ? sport : null;

    final known = {..._districts, ..._venues.expand(_districtNames)}..remove('');
    it.districts.clear();
    it.district = null;
    it.unknownArea = null;
    final dList = m['districts'] is List ? (m['districts'] as List).map((e) => RagText.norm('$e')).toList() : <String>[];
    for (final d in dList) {
      final hit = known.where((k) => d == k || d.contains(k) || k.contains(d)).toList();
      if (hit.isNotEmpty && !it.districts.contains(hit.first)) it.districts.add(hit.first);
    }
    if (it.districts.isNotEmpty) {
      it.district = it.districts.first;
      final sample = _venues.where((v) => RagText.norm(v.district) == it.district);
      it.districtLabel = sample.isNotEmpty ? sample.first.district : it.district;
    } else {
      it.districtLabel = null;
      final other = s('other_area');
      if (other != null) it.unknownArea = other;
    }

    final p = n('max_price_k');
    it.maxPricePerHour = (p != null && p > 0) ? p : null;
    final h = n('hour');
    it.hour = (h != null && h >= 0 && h <= 23) ? h : null;
    final ds = s('date');
    if (ds != null) {
      final d = DateTime.tryParse(ds);
      if (d != null) {
        it.date = DateTime(d.year, d.month, d.day);
        it.dateExplicit = true;
      }
    }

    it.wantsStats = b('wants_price_stats');
    it.goldenHour = b('golden_hour');
    it.cheapest = b('cheapest');
    it.topRated = b('top_rated');
    it.nearest = b('nearest');

    it.amenities
      ..clear()
      ..addAll(((m['amenities'] as List?) ?? const []).map((e) => '$e').where(const {'den_dem', 'gui_xe', 'may_ban_bong', 'mai_che'}.contains));
    it.topics
      ..clear()
      ..addAll(((m['topics'] as List?) ?? const []).map((e) => '$e').where(const {'cancel', 'fixed', 'payment', 'promo', 'guide', 'weather', 'contact', 'forecast'}.contains));

    final vn = s('venue_name');
    it.namedVenue = vn != null ? _findNamedVenue(RagText.norm(vn)) : null;
    if (it.namedVenue != null) {
      it.unknownArea = null;
    }
  }

  static Future<RagRetrievalResult> retrieve(
    String query, {
    List<String> history = const [],
    int topVenues = 4,
    Map<String, dynamic>? llmIntent,
  }) async {
    await ensureLoaded();
    final intent = parseIntent(query, history: history);
    if (llmIntent != null) applyLlmIntent(intent, llmIntent);

    // 1. Tìm sân bằng bộ lọc có cấu trúc
    List<Venue> venues = [];
    if (intent.unknownArea != null) {
      venues = [];
    } else if (intent.namedVenue != null) {
      venues = [intent.namedVenue!];
    } else if (intent.wantsVenues || _looksLikeVenueSearch(query)) {
      venues = _searchVenues(intent, topVenues);
    }

    // 2. BM25 chọn chunk chính sách/hướng dẫn liên quan
    final topicToChunk = {
      'cancel': 'policy_cancel',
      'fixed': 'policy_fixed',
      'payment': 'policy_payment',
      'promo': 'policy_promo',
      'guide': 'guide_booking',
      'weather': 'guide_weather',
      'contact': 'guide_contact',
    };
    final policyChunks = <RagKnowledgeChunk>[];
    if (intent.topics.isNotEmpty) {
      // Có chủ đề rõ ràng: lấy đúng tài liệu của chủ đề đó
      for (final t in intent.topics) {
        final c = _policyChunks.where((c) => c.id == topicToChunk[t]);
        if (c.isNotEmpty) policyChunks.add(c.first);
      }
    } else if (venues.isEmpty && !intent.wantsVenues) {
      // Không rõ chủ đề: dùng BM25 và chỉ giữ kết quả đủ liên quan
      final qTokens = RagText.tokenize(query);
      final scored = <MapEntry<RagKnowledgeChunk, double>>[];
      for (final c in _policyChunks) {
        final s = _bm25(c, qTokens);
        if (s >= 4.0) scored.add(MapEntry(c, s));
      }
      scored.sort((a, b) => b.value.compareTo(a.value));
      policyChunks.addAll(scored.take(2).map((e) => e.key));
    }
    // Hỏi máy bắn bóng -> luôn kèm chính sách khuyến mãi (nguồn xác nhận sân có máy)
    if (intent.amenities.contains('may_ban_bong') && !policyChunks.any((c) => c.id == 'policy_promo')) {
      policyChunks.add(_policyChunks.firstWhere((c) => c.id == 'policy_promo'));
    }
    // Đặt sân: luôn có hướng dẫn nếu hỏi cách đặt mà chưa có
    final chunks = <RagKnowledgeChunk>[
      ...venues.map((v) => _venueChunk(v)),
      ...policyChunks,
    ];

    // 3. Dựng ngữ cảnh cho LLM (kèm lịch đặt thực tế)
    final b = StringBuffer();
    b.writeln('=== TRI THỨC ALOBOOKING (đã truy xuất) ===');
    b.writeln('Hôm nay: ${_fmtDate(DateTime.now())}. Ngày khách hỏi: ${_fmtDate(intent.date)}.');
    b.writeln('Tổng số sân đang hoạt động trên hệ thống: ${_venues.length}.');
    final statsList = <RagStats>[];
    if (intent.wantsStats && intent.unknownArea == null && intent.namedVenue == null) {
      if (intent.districts.length > 1) {
        for (final d in intent.districts) {
          final st = priceStats(intent, onlyDistrict: d);
          if (st != null) statsList.add(st);
        }
      } else {
        final st = priceStats(intent);
        if (st != null) statsList.add(st);
      }
    }
    final stats = statsList.isNotEmpty ? statsList.first : null;
    if (stats != null) {
      for (final st in statsList) {
        b.writeln('\n## ${st.toText()}');
      }
      if (statsList.length > 1) {
        b.writeln('Khách muốn SO SÁNH: hãy đặt các nhóm cạnh nhau và nói rõ nhóm nào rẻ hơn bao nhiêu.');
      }
      b.writeln('Khi khách hỏi giá trung bình/mặt bằng giá, trả lời bằng đúng các con số thống kê này (nhấn mạnh khung giờ khách hỏi), sau đó mới nêu vài sân làm ví dụ.');
    }
    if (venues.isNotEmpty) {
      b.writeln('\n## SÂN PHÙ HỢP (${venues.length} kết quả, đã sắp xếp theo yêu cầu)');
      if (intent.amenities.contains('mai_che')) {
        b.writeln('LƯU Ý: dữ liệu KHÔNG ghi sân nào có mái che/trong nhà. Các sân dưới đây chỉ là cầu lông/pickleball (thường chơi trong nhà). Đừng khẳng định chắc chắn có mái che; hãy nói "thường là sân trong nhà" và khuyên khách hỏi Hotline 0364059999 để xác nhận.');
      }
      for (var i = 0; i < venues.length; i++) {
        b.writeln('[Sân ${i + 1}]');
        b.writeln(_venueChunk(venues[i]).content);
        b.writeln(availabilityText(venues[i], intent.date, hour: intent.hour));
        b.writeln();
      }
    } else if (intent.unknownArea != null) {
      b.writeln('\n## HỆ THỐNG KHÔNG CÓ SÂN tại "${intent.unknownArea}". AloBooking hiện chỉ có sân ở Hà Nội.');
      b.writeln('Khu vực đang có sân (số sân): ${coverageText()}.');
      b.writeln('Hãy nói rõ điều này, gợi ý khách chọn quận/huyện Hà Nội gần nhất (ví dụ khách ở Hưng Yên nên xem Gia Lâm, Long Biên, Thanh Trì, Hoàng Mai) và mời hỏi lại theo quận.');
    } else if (intent.wantsVenues) {
      b.writeln('\n## KHÔNG có sân nào trong hệ thống khớp đủ các tiêu chí của khách.');
    }
    for (final c in policyChunks) {
      b.writeln('## ${c.title}');
      b.writeln(c.content);
      b.writeln();
    }
    String? forecastText;
    if (intent.topics.contains('forecast')) {
      try {
        final w = await WeatherService.getCurrentWeather();
        forecastText = DemandForecastService.buildPromptSection(_bookings, intent.date,
            rainByDate: w.rainByDate, sport: intent.sport);
      } catch (_) {
        forecastText = DemandForecastService.buildPromptSection(_bookings, intent.date, sport: intent.sport);
      }
      b.writeln('\n$forecastText');
    }
    b.writeln('=== HẾT TRI THỨC ===');

    return RagRetrievalResult(
      query: query,
      intent: intent,
      stats: stats,
      moreStats: statsList.length > 1 ? statsList.sublist(1) : const [],
      chunks: chunks,
      matchedVenues: venues,
      augmentedPromptText: b.toString(),
      totalVenues: _venues.length,
      forecastText: forecastText,
    );
  }

  /// Thống kê giá trên TOÀN BỘ sân thuộc môn/quận khách hỏi (không chỉ vài sân đầu).
  static RagStats? priceStats(RagIntent it, {String? onlyDistrict}) {
    final dist = onlyDistrict ?? it.district;
    final list = _venues.where((v) {
      if (it.sport != null && v.type.toLowerCase() != it.sport) return false;
      if (dist != null && !RagText.norm(v.district).contains(dist)) return false;
      return true;
    }).toList();

    final prices = <(int, int)>[];
    var perMatch = 0;
    for (final v in list) {
      final p = priceRange(v.price);
      if (p == null) continue;
      prices.add(p);
      if (v.price.toLowerCase().contains('/trận') || v.price.toLowerCase().contains('/tran')) perMatch++;
    }
    if (prices.isEmpty) return null;

    final sportName = it.sport != null ? sportLabel(it.sport!).toLowerCase() : 'các môn';
    final distSample = dist == null ? <Venue>[] : _venues.where((v) => RagText.norm(v.district) == dist).toList();
    final distLabel = distSample.isNotEmpty ? distSample.first.district : (dist ?? it.districtLabel);
    final label = 'sân $sportName${distLabel != null ? ' tại $distLabel' : ' toàn hệ thống'}';
    return RagStats(
      label: label,
      count: prices.length,
      avgLow: prices.fold<int>(0, (s, p) => s + p.$1) / prices.length,
      avgHigh: prices.fold<int>(0, (s, p) => s + p.$2) / prices.length,
      minLow: prices.map((p) => p.$1).reduce(math.min),
      maxHigh: prices.map((p) => p.$2).reduce(math.max),
      unit: perMatch * 2 > prices.length ? 'trận' : 'giờ',
    );
  }

  static bool _looksLikeVenueSearch(String query) {
    final q = RagText.norm(query);
    return RegExp(r'\b(tim|goi y|de xuat|danh sach|co san|san nao|cho nao|o dau|tu van)\b').hasMatch(q) &&
        q.contains('san');
  }

  static List<Venue> _searchVenues(RagIntent it, int limit) {
    bool hasTag(Venue v, RegExp re) => v.tags.any((t) => re.hasMatch(RagText.norm(t)));

    var list = _venues.where((v) {
      if (it.sport != null && v.type.toLowerCase() != it.sport) return false;
      if (it.district != null) {
        final ds = it.districts.isNotEmpty ? it.districts : [it.district!];
        final inArea = ds.any((d) =>
            RagText.norm(v.district).contains(d) || RagText.norm(v.address).contains(d));
        if (!inArea) return false;
      }
      if (it.maxPricePerHour != null) {
        final p = priceRange(v.price);
        // Ngân sách áp dụng cho đúng khung giờ khách muốn chơi: trong ca vàng 16:00–22:00 (hoặc hỏi giờ vàng) tính giá cao
        final peak = BookingSlots.isGolden(it.hour ?? 0) || it.goldenHour;
        if (p == null || (peak ? p.$2 : p.$1) > it.maxPricePerHour!) return false;
      }
      if (it.amenities.contains('den_dem') && !hasTag(v, RegExp(r'den'))) return false;
      if (it.amenities.contains('gui_xe') && !hasTag(v, RegExp(r'gui xe|do xe'))) return false;
      if (it.amenities.contains('may_ban_bong')) {
        // Chỉ các sân được chính sách xác nhận mới có máy bắn bóng
        final n = RagText.norm(v.name);
        if (!(hasTag(v, RegExp(r'may ban bong')) || n.contains('cau giay park') || n.contains('d agility') || n.contains('agility'))) {
          return false;
        }
      }
      if (it.amenities.contains('mai_che') && !hasTag(v, RegExp(r'mai che|trong nha'))) {
        // Dữ liệu chưa gắn thẻ mái che: chỉ coi cầu lông/pickleball là có khả năng trong nhà
        if (v.type != 'badminton' && v.type != 'pickleball') return false;
      }
      if (it.hour != null && !_openAt(v.hours, it.hour!)) return false;
      return true;
    }).toList();

    // Nới lỏng nếu quá chặt: bỏ tiện ích/giờ nhưng giữ môn + quận
    if (list.isEmpty && (it.sport != null || it.district != null)) {
      list = _venues.where((v) {
        if (it.sport != null && v.type.toLowerCase() != it.sport) return false;
        if (it.district != null) {
          final ds = it.districts.isNotEmpty ? it.districts : [it.district!];
          if (!ds.any((d) => RagText.norm(v.district).contains(d))) return false;
        }
        return true;
      }).toList();
    }

    int cmp(Venue a, Venue b) {
      if (it.cheapest) {
        final c = (priceRange(a.price)?.$1 ?? 1 << 30).compareTo(priceRange(b.price)?.$1 ?? 1 << 30);
        if (c != 0) return c;
      }
      if (it.nearest) {
        final c = _km(a.distance).compareTo(_km(b.distance));
        if (c != 0) return c;
      }
      return b.rating.compareTo(a.rating);
    }

    list.sort(cmp);
    return list.take(limit).toList();
  }

  static double _bm25(RagKnowledgeChunk c, List<String> q, {double k1 = 1.4, double b = 0.75}) {
    if (q.isEmpty) return 0;
    final n = _corpus.length;
    final tf = <String, int>{};
    for (final t in c.tokens) {
      tf[t] = (tf[t] ?? 0) + 1;
    }
    var score = 0.0;
    for (final t in q.toSet()) {
      final f = tf[t];
      if (f == null) continue;
      final df = _df[t] ?? 0;
      final idf = math.log(1 + (n - df + 0.5) / (df + 0.5));
      score += idf * (f * (k1 + 1)) / (f + k1 * (1 - b + b * c.tokens.length / _avgLen));
    }
    return score;
  }

  // ───────────────────────── Lịch đặt thực tế ─────────────────────────

  /// Mô tả các ca đã đặt của một sân trong ngày (đọc từ collection bookings).
  static String availabilityText(Venue v, DateTime date, {int? hour}) {
    final key = RagText.norm(v.name);
    final booked = _bookings.where((b) {
      if (RagText.norm(b.venueName) != key) return false;
      if (b.status.toLowerCase().contains('hủy') || b.status.toLowerCase().contains('huy')) return false;
      return _sameDay(b.date, date);
    }).toList();

    final label = _fmtDate(date);
    if (booked.isEmpty) {
      return 'Lịch $label: chưa có ca nào được đặt trong hệ thống (giờ mở cửa ${v.hours}).';
    }
    final slots = booked.map((b) => '${b.time} (${b.field})').join('; ');
    var s = 'Lịch $label: đã có ${booked.length} ca được đặt: $slots. Các khung giờ khác trong giờ mở cửa ${v.hours} chưa có ai đặt trong hệ thống.';
    if (hour != null) {
      final clash = booked.where((b) {
        final m = RegExp(r'(\d{1,2}):?(\d{0,2})\s*-\s*(\d{1,2})').firstMatch(b.time);
        if (m == null) return false;
        final s0 = int.parse(m.group(1)!), e0 = int.parse(m.group(3)!);
        return hour >= s0 && hour < e0;
      }).toList();
      s += clash.isEmpty
          ? ' Khung ${hour}h hiện chưa có ai đặt.'
          : ' Khung ${hour}h ĐÃ có người đặt (${clash.map((b) => b.field).join(', ')}).';
    }
    return s;
  }

  static bool _sameDay(String s, DateTime d) {
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s.trim());
    if (m != null) {
      return int.parse(m.group(1)!) == d.day && int.parse(m.group(2)!) == d.month && int.parse(m.group(3)!) == d.year;
    }
    final m2 = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s.trim());
    if (m2 != null) {
      return int.parse(m2.group(1)!) == d.year && int.parse(m2.group(2)!) == d.month && int.parse(m2.group(3)!) == d.day;
    }
    return false;
  }

  // ───────────────────────── Tiện ích ─────────────────────────

  /// "80k - 160k/h" -> (80, 160) (đơn vị nghìn đồng)
  static (int, int)? priceRange(String price) {
    final m = RegExp(r'(\d+)\s*k\s*-\s*(\d+)\s*k').firstMatch(price.toLowerCase());
    if (m == null) return null;
    return (int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  static bool _openAt(String hours, int hour) {
    final m = RegExp(r'(\d{1,2}):?\d{0,2}\s*[–-]\s*(\d{1,2}):?\d{0,2}').firstMatch(hours);
    if (m == null) return true;
    return hour >= int.parse(m.group(1)!) && hour < int.parse(m.group(2)!);
  }

  /// Tên khu vực của sân để nhận diện trong câu hỏi: đầy đủ và bỏ tiền tố "phường/xã"
  /// (sân nhập từ OpenStreetMap ghi theo phường/xã: "Phường Xuân Đỉnh" ~ "xuân đỉnh").
  static Iterable<String> _districtNames(Venue v) {
    final full = RagText.norm(v.district);
    final short = full.replaceFirst(RegExp(r'^(phuong|xa) '), '');
    return {full, short};
  }

  static double _km(String d) => double.tryParse(RegExp(r'[\d.]+').stringMatch(d) ?? '') ?? 999;

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
