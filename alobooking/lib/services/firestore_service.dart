import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/venue.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../models/notification_item.dart';
import '../models/news_post.dart';
import 'auth_service.dart';
import 'firebase_config.dart';
import 'session.dart';
import 'venue_cache.dart';

class BookingItem {
  final String id;
  final String customer;
  final String phone;
  final String venueName;
  final String field;
  final String time;
  final String date;
  final String amount;
  String status;
  final String paymentMethod;
  final DateTime createdAt;

  /// uid tài khoản đã đặt (rỗng với đơn cũ hoặc đơn tại quầy)
  final String userId;

  /// uid chủ sân được đặt và mã sân; luật bảo mật dựa vào hai trường này.
  final String ownerId;
  final int venueId;

  BookingItem({
    required this.id,
    required this.customer,
    required this.phone,
    required this.venueName,
    required this.field,
    required this.time,
    required this.date,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    DateTime? createdAt,
    this.userId = '',
    this.ownerId = '',
    this.venueId = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Một dòng lịch bận công khai (collection `slots`): không có tên, số điện thoại hay số tiền.
  factory BookingItem.fromSlot(String docId, Map<String, dynamic> fields) {
    String v(String k) => (fields[k]?['stringValue'] ?? '').toString();
    return BookingItem(
      id: docId,
      customer: '',
      phone: '',
      amount: '',
      venueName: v('venueName'),
      field: v('field'),
      time: v('time'),
      date: v('date'),
      status: v('status'),
      paymentMethod: v('paymentMethod'),
      createdAt: DateTime.tryParse(v('createdAt')),
      venueId: int.tryParse((fields['venueId']?['integerValue'] ?? '0').toString()) ?? 0,
    );
  }

  /// Đơn này có phải của tài khoản (uid, số điện thoại, tên) không.
  /// Ưu tiên uid; đơn cũ chưa có uid thì khớp theo số điện thoại, thiếu số thì khớp theo tên.
  bool belongsTo({required String uid, required String phone, required String name}) {
    if (userId.isNotEmpty) return userId == uid;
    String digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
    final up = digits(phone), bp = digits(this.phone);
    if (up.isNotEmpty && bp.isNotEmpty) return up == bp;
    return customer.trim().toLowerCase() == name.trim().toLowerCase();
  }

  factory BookingItem.fromFirestoreFields(String docId, Map<String, dynamic> fields) {
    return BookingItem(
      id: fields['id']?['stringValue'] ?? docId,
      customer: fields['customer']?['stringValue'] ?? 'Khách đặt sân',
      phone: fields['phone']?['stringValue'] ?? '090xxxxxxx',
      venueName: fields['venueName']?['stringValue'] ?? 'Sân Thể Thao',
      field: fields['field']?['stringValue'] ?? 'Sân tiêu chuẩn',
      time: fields['time']?['stringValue'] ?? '18:00 - 19:30',
      date: fields['date']?['stringValue'] ?? '31/10/2026',
      amount: fields['amount']?['stringValue'] ?? '200,000đ',
      status: fields['status']?['stringValue'] ?? 'Chờ xác nhận',
      paymentMethod: fields['paymentMethod']?['stringValue'] ?? 'Chuyển khoản QR',
      createdAt: DateTime.tryParse(fields['createdAt']?['stringValue'] ?? '') ?? DateTime.now(),
      userId: fields['userId']?['stringValue'] ?? '',
      ownerId: fields['ownerId']?['stringValue'] ?? '',
      venueId: int.tryParse((fields['venueId']?['integerValue'] ?? '0').toString()) ?? 0,
    );
  }
}

/// Đánh giá của khách đã chơi tại một sân.
class ReviewItem {
  final String id;
  final int venueId;
  final String userId;
  final String userName;
  final int stars; // 1..5
  final String comment;
  final DateTime createdAt;

  ReviewItem({
    required this.id,
    required this.venueId,
    required this.userId,
    required this.userName,
    required this.stars,
    required this.comment,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ReviewItem.fromFirestoreFields(String docId, Map<String, dynamic> f) {
    String v(String k) => (f[k]?['stringValue'] ?? '').toString();
    int n(String k) => int.tryParse((f[k]?['integerValue'] ?? f[k]?['stringValue'] ?? '0').toString()) ?? 0;
    return ReviewItem(
      id: docId,
      venueId: n('venueId'),
      userId: v('userId'),
      userName: v('userName'),
      stars: n('stars').clamp(1, 5),
      comment: v('comment'),
      createdAt: DateTime.tryParse(v('createdAt')) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestoreFields() => {
        'venueId': {'integerValue': venueId.toString()},
        'userId': {'stringValue': userId},
        'userName': {'stringValue': userName},
        'stars': {'integerValue': stars.toString()},
        'comment': {'stringValue': comment},
        'createdAt': {'stringValue': createdAt.toIso8601String()},
      };
}

/// Vì sao một lần tải từ Firestore thất bại. Thứ tự từ nhẹ đến nặng: khi có nhiều lỗi, giữ lỗi nặng nhất.
enum LoadFailure {
  /// Không lỗi.
  none,

  /// Không kết nối được máy chủ (mất mạng, bị chặn, quá thời gian).
  network,

  /// Máy chủ trả lỗi khác (5xx, 4xx không phải hết hạn mức).
  server,

  /// Máy chủ trả 429: hết hạn mức đọc miễn phí trong ngày hoặc đang bị giới hạn tốc độ.
  quota,
}

class FirestoreService {
  static const String projectId = FirebaseConfig.projectId;

  /// Lý do thất bại của các lần tải gần nhất (từ lần đặt lại cuối). [LoadFailure.none] nếu không lỗi.
  static LoadFailure lastFailure = LoadFailure.none;

  /// true nếu một lần tải gần nhất từ Firestore thất bại (mất mạng/lỗi máy chủ/hết hạn mức).
  /// Giao diện dùng cờ này để báo lỗi rõ ràng thay vì hiển thị dữ liệu mẫu. Gán false để đặt lại.
  static bool get lastLoadFailed => lastFailure != LoadFailure.none;
  static set lastLoadFailed(bool failed) {
    if (!failed) {
      lastFailure = LoadFailure.none;
    } else if (lastFailure == LoadFailure.none) {
      lastFailure = LoadFailure.server;
    }
  }

  static LoadFailure _classify(int statusCode) => statusCode == 429 ? LoadFailure.quota : LoadFailure.server;

  /// Ghi nhận một lỗi tải, giữ lỗi nặng nhất.
  static void _raise(LoadFailure f) {
    if (f.index > lastFailure.index) lastFailure = f;
  }

  /// Câu báo lỗi cho người dùng, nói đúng nguyên nhân thay vì lúc nào cũng bảo "kiểm tra mạng".
  /// Trả về chuỗi rỗng khi không có lỗi.
  static String failureMessage([LoadFailure? failure]) {
    switch (failure ?? lastFailure) {
      case LoadFailure.none:
        return '';
      case LoadFailure.network:
        return 'Không kết nối được máy chủ. Hãy kiểm tra mạng rồi thử lại.';
      case LoadFailure.server:
        return 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';
      case LoadFailure.quota:
        return 'Máy chủ đang quá tải hoặc đã hết lượt đọc dữ liệu trong ngày. Vui lòng thử lại sau.';
    }
  }

  /// Liệt kê toàn bộ tài liệu của một collection (có phân trang).
  static Future<({bool ok, List<Map<String, dynamic>> docs})> _listDocs(String collection, {int pageSize = 300}) async {
    final docs = <Map<String, dynamic>>[];
    String? pageToken;
    do {
      final q = pageToken != null && pageToken.isNotEmpty ? '&pageToken=$pageToken' : '';
      http.Response res;
      try {
        res = await http.get(Uri.parse('$baseUrl/$collection?pageSize=$pageSize$q'), headers: await Session.headers());
      } catch (_) {
        _raise(LoadFailure.network);
        return (ok: false, docs: docs);
      }
      if (res.statusCode != 200) {
        // 404/rỗng được coi là collection chưa có dữ liệu, các lỗi khác là lỗi tải
        if (res.statusCode == 404) return (ok: true, docs: docs);
        _raise(_classify(res.statusCode));
        return (ok: false, docs: docs);
      }
      try {
        final data = json.decode(res.body);
        final list = data['documents'] as List<dynamic>?;
        if (list != null) docs.addAll(list.cast<Map<String, dynamic>>());
        pageToken = data['nextPageToken'] as String?;
      } catch (_) {
        _raise(LoadFailure.server);
        return (ok: false, docs: docs);
      }
    } while (pageToken != null && pageToken.isNotEmpty);
    return (ok: true, docs: docs);
  }

  static const String baseUrl = FirebaseConfig.firestoreUrl;

  /// Lấy danh sách sân thể thao.
  ///
  /// Mỗi sân là một lượt đọc trong hạn mức Firestore (50.000 lượt mỗi ngày, app có hơn một nghìn sân), nên danh sách
  /// được nhớ lại ([VenueCache]): còn mới (30 phút) thì dùng thẳng, không hỏi máy chủ.
  /// [forceRefresh]: bỏ qua bản nhớ, đọc lại từ máy chủ (nút "Thử lại", "Làm mới").
  /// Tải lỗi mà đang có bản nhớ (kể cả đã cũ) thì dùng bản đó thay vì trả về danh sách rỗng hoặc dở dang.
  static Future<List<Venue>> getVenues({bool forceRefresh = false}) async {
    final cached = VenueCache.read();
    if (!forceRefresh && cached != null && VenueCache.isFresh(cached.savedAt)) return cached.venues;

    final r = await _fetchVenues();
    if (r.complete && r.venues.isNotEmpty) {
      VenueCache.write(r.venues);
      return r.venues;
    }
    if (r.failure != LoadFailure.none) {
      if (cached != null) return cached.venues;
      _raise(r.failure);
    }
    return r.venues;
  }

  /// Đọc toàn bộ sân từ Firestore (có phân trang). [complete] = false nếu có trang nào tải lỗi.
  static Future<({List<Venue> venues, bool complete, LoadFailure failure})> _fetchVenues() async {
    final List<Venue> allVenues = [];
    var failure = LoadFailure.none;
    try {
      String? pageToken;

      do {
        final queryParam = pageToken != null ? '&pageToken=$pageToken' : '';
        http.Response response;
        try {
          response = await http.get(Uri.parse('$baseUrl/venues?pageSize=300$queryParam'), headers: await Session.headers());
        } catch (_) {
          failure = LoadFailure.network;
          break;
        }

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final documents = data['documents'] as List<dynamic>?;

          if (documents != null && documents.isNotEmpty) {
            for (final doc in documents) {
              final fields = doc['fields'] as Map<String, dynamic>?;
              final name = fields?['name']?['stringValue'];
              final id = fields?['id']?['integerValue'];
              if (name != null &&
                  name.isNotEmpty &&
                  id != null &&
                  !name.contains('Alobooking System Connected')) {
                allVenues.add(Venue(
                  id: int.tryParse(fields?['id']?['integerValue'] ?? '0') ?? 0,
                  name: fields?['name']?['stringValue'] ?? '',
                  type: fields?['type']?['stringValue'] ?? 'badminton',
                  district: fields?['district']?['stringValue'] ?? '',
                  distance: fields?['distance']?['stringValue'] ?? '1.0km',
                  address: fields?['address']?['stringValue'] ?? '',
                  hours: fields?['hours']?['stringValue'] ?? '05:00 – 23:00',
                  // Có trường tags nhưng mảng rỗng nghĩa là sân chưa khai báo tiện ích: giữ rỗng, không tự thêm
                  tags: fields?['tags'] == null
                      ? ['Đơn ngày']
                      : ((fields?['tags']?['arrayValue']?['values'] as List<dynamic>?)
                              ?.map((v) => v['stringValue']?.toString() ?? '')
                              .toList() ??
                          <String>[]),
                  rating: double.tryParse(
                          fields?['rating']?['doubleValue']?.toString() ?? '4.8') ??
                      4.8,
                  price: fields?['price']?['stringValue'] ?? '100k - 200k/h',
                  lat: double.tryParse(
                          fields?['lat']?['doubleValue']?.toString() ?? '21.0') ??
                      21.0,
                  lng: double.tryParse(
                          fields?['lng']?['doubleValue']?.toString() ?? '105.8') ??
                      105.8,
                  image: fields?['image']?['stringValue'] ?? '',
                  logo: fields?['logo']?['stringValue'] ?? '',
                  ownerId: fields?['ownerId']?['stringValue'] ?? 'admin_super_01',
                  ownerName: fields?['ownerName']?['stringValue'] ?? 'Hệ Thống Alobooking',
                  approvalStatus: fields?['approvalStatus']?['stringValue'] ?? 'approved',
                  rejectReason: fields?['rejectReason']?['stringValue'] ?? '',
                  courtCount: int.tryParse((fields?['courtCount']?['integerValue'] ?? '0').toString()) ?? 0,
                  source: fields?['source']?['stringValue'] ?? '',
                  approvedAt: DateTime.tryParse(fields?['approvedAt']?['stringValue'] ?? ''),
                ));
              }
            }
          }
          pageToken = data['nextPageToken'] as String?;
        } else {
          if (response.statusCode != 404) failure = _classify(response.statusCode);
          break;
        }
      } while (pageToken != null && pageToken.isNotEmpty);
    } catch (e) {
      // dữ liệu trả về sai định dạng
      failure = LoadFailure.server;
    }
    allVenues.sort((a, b) => a.id.compareTo(b.id));
    return (venues: allVenues, complete: failure == LoadFailure.none, failure: failure);
  }

  /// Thêm sân thể thao mới lên Firestore
  static Future<bool> addVenue(Venue venue) async {
    try {
      final docId = venue.id.toString();
      final payload = {
        'fields': {
          'id': {'integerValue': venue.id.toString()},
          'name': {'stringValue': venue.name},
          'type': {'stringValue': venue.type},
          'district': {'stringValue': venue.district},
          'distance': {'stringValue': venue.distance},
          'address': {'stringValue': venue.address},
          'hours': {'stringValue': venue.hours},
          'tags': {
            'arrayValue': {
              'values': venue.tags.map((t) => {'stringValue': t}).toList()
            }
          },
          'rating': {'doubleValue': venue.rating},
          'price': {'stringValue': venue.price},
          'lat': {'doubleValue': venue.lat},
          'lng': {'doubleValue': venue.lng},
          'image': {'stringValue': venue.image},
          'logo': {'stringValue': venue.logo},
          'ownerId': {'stringValue': venue.ownerId},
          'ownerName': {'stringValue': venue.ownerName},
          'approvalStatus': {'stringValue': venue.approvalStatus},
          'rejectReason': {'stringValue': venue.rejectReason},
          'courtCount': {'integerValue': venue.courtCount.toString()},
          'source': {'stringValue': venue.source},
          if (venue.approvedAt != null) 'approvedAt': {'stringValue': venue.approvedAt!.toIso8601String()},
        }
      };

      final response = await http.post(
        Uri.parse('$baseUrl/venues?documentId=$docId'),
        headers: await Session.headers(json: true),
        body: json.encode(payload),
      );
      final ok = response.statusCode == 200 || response.statusCode == 201;
      if (ok) VenueCache.upsert(venue);
      return ok;
    } catch (e) {
      return false;
    }
  }

  /// Cập nhật thông tin sân thể thao
  static Future<bool> updateVenue(Venue venue) async {
    try {
      final docId = venue.id.toString();
      final payload = {
        'fields': {
          'id': {'integerValue': venue.id.toString()},
          'name': {'stringValue': venue.name},
          'type': {'stringValue': venue.type},
          'district': {'stringValue': venue.district},
          'distance': {'stringValue': venue.distance},
          'address': {'stringValue': venue.address},
          'hours': {'stringValue': venue.hours},
          'tags': {
            'arrayValue': {
              'values': venue.tags.map((t) => {'stringValue': t}).toList()
            }
          },
          'rating': {'doubleValue': venue.rating},
          'price': {'stringValue': venue.price},
          'lat': {'doubleValue': venue.lat},
          'lng': {'doubleValue': venue.lng},
          'image': {'stringValue': venue.image},
          'logo': {'stringValue': venue.logo},
          'ownerId': {'stringValue': venue.ownerId},
          'ownerName': {'stringValue': venue.ownerName},
          'approvalStatus': {'stringValue': venue.approvalStatus},
          'rejectReason': {'stringValue': venue.rejectReason},
          'courtCount': {'integerValue': venue.courtCount.toString()},
          'source': {'stringValue': venue.source},
          if (venue.approvedAt != null) 'approvedAt': {'stringValue': venue.approvedAt!.toIso8601String()},
        }
      };

      final response = await http.patch(
        Uri.parse('$baseUrl/venues/$docId'),
        headers: await Session.headers(json: true),
        body: json.encode(payload),
      );
      final ok = response.statusCode == 200;
      if (ok) VenueCache.upsert(venue);
      return ok;
    } catch (e) {
      return false;
    }
  }

  /// Xóa sân thể thao khỏi Firestore
  static Future<bool> deleteVenue(int venueId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/venues/$venueId'), headers: await Session.headers());
      final ok = response.statusCode == 200;
      if (ok) VenueCache.removeId(venueId);
      return ok;
    } catch (e) {
      return false;
    }
  }

  /// Duyệt / Từ chối duyệt sân (Super Admin)
  ///
  /// [approvedAt]: lúc duyệt lần đầu, chỉ ghi khi duyệt thành công (giữ ngày cũ nếu sân từng được duyệt).
  static Future<bool> updateVenueApproval(int venueId, String newStatus,
      [String rejectReason = '', DateTime? approvedAt]) async {
    try {
      final stamp = newStatus == 'approved' ? approvedAt : null;
      final payload = {
        'fields': {
          'approvalStatus': {'stringValue': newStatus},
          'rejectReason': {'stringValue': rejectReason},
          if (stamp != null) 'approvedAt': {'stringValue': stamp.toIso8601String()},
        }
      };
      final response = await http.patch(
        Uri.parse('$baseUrl/venues/$venueId?updateMask.fieldPaths=approvalStatus&updateMask.fieldPaths=rejectReason'
            '${stamp != null ? '&updateMask.fieldPaths=approvedAt' : ''}'),
        headers: await Session.headers(json: true),
        body: json.encode(payload),
      );
      final ok = response.statusCode == 200;
      if (ok) {
        VenueCache.update(
          venueId,
          (v) => v.copyWith(approvalStatus: newStatus, rejectReason: rejectReason, approvedAt: stamp ?? v.approvedAt),
        );
      }
      return ok;
    } catch (e) {
      return false;
    }
  }

  /// Đồng bộ toàn bộ danh sách sân thể thao lên Firestore alobooking-b2484
  static Future<int> syncVenues(List<Venue> venues) async {
    int count = 0;
    for (final v in venues) {
      final ok = await addVenue(v);
      if (ok) count++;
    }
    return count;
  }

  /// Tài liệu có `field` đúng bằng `value`. Luật bảo mật chỉ cho người thường đọc qua truy vấn lọc kiểu này.
  static Future<({bool ok, List<Map<String, dynamic>> docs})> _queryDocs(String collection, String field, String value) async {
    final docs = <Map<String, dynamic>>[];
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('$baseUrl:runQuery'),
        headers: await Session.headers(json: true),
        body: json.encode({
          'structuredQuery': {
            'from': [
              {'collectionId': collection}
            ],
            'where': {
              'fieldFilter': {
                'field': {'fieldPath': field},
                'op': 'EQUAL',
                'value': {'stringValue': value},
              }
            },
          }
        }),
      );
    } catch (_) {
      _raise(LoadFailure.network);
      return (ok: false, docs: docs);
    }
    if (res.statusCode != 200) {
      _raise(_classify(res.statusCode));
      return (ok: false, docs: docs);
    }
    try {
      for (final row in json.decode(res.body) as List<dynamic>) {
        final doc = (row as Map<String, dynamic>)['document'];
        if (doc != null) docs.add(doc as Map<String, dynamic>);
      }
    } catch (_) {
      _raise(LoadFailure.server);
      return (ok: false, docs: docs);
    }
    return (ok: true, docs: docs);
  }

  /// Tài liệu (đơn, phiếu thu) tài khoản hiện tại được xem: quản trị viên thấy tất cả; chủ sân thấy của sân mình
  /// và của chính mình; khách thấy của mình; chưa đăng nhập thì không có gì (và không hỏi máy chủ).
  static Future<List<Map<String, dynamic>>> _visibleDocs(String collection) async {
    final user = AuthService.currentUser;
    if (user == null || user.isGuest) return [];
    if (user.isAdmin) return (await _listDocs(collection, pageSize: 100)).docs;
    final own = (await _queryDocs(collection, 'userId', user.uid)).docs;
    if (!user.isOwner) return own;
    final venue = (await _queryDocs(collection, 'ownerId', user.uid)).docs;
    return {for (final doc in [...own, ...venue]) doc['name'] as String: doc}.values.toList();
  }

  /// Đơn đặt sân mà tài khoản hiện tại được xem, mới nhất trước.
  static Future<List<BookingItem>> getBookings() async {
    try {
      final bookings = [
        for (final doc in await _visibleDocs('bookings'))
          BookingItem.fromFirestoreFields((doc['name'] as String).split('/').last, doc['fields'] as Map<String, dynamic>)
      ];
      bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return bookings;
    } catch (_) {
      _raise(LoadFailure.server);
      return <BookingItem>[];
    }
  }

  /// Lịch bận công khai của mọi sân: dùng cho sơ đồ giờ trống, tìm sân, chatbot và dự báo nhu cầu.
  static Future<List<BookingItem>> getSlots() async {
    final r = await _listDocs('slots');
    return [
      for (final doc in r.docs)
        BookingItem.fromSlot((doc['name'] as String).split('/').last, (doc['fields'] as Map<String, dynamic>?) ?? {})
    ];
  }

  /// Cập nhật trạng thái đơn đặt sân
  static Future<bool> updateBookingStatus(String bookingId, String newStatus) async {
    try {
      final payload = {
        'fields': {
          'status': {'stringValue': newStatus},
        }
      };
      final response = await http.patch(
        Uri.parse('$baseUrl/bookings/$bookingId?updateMask.fieldPaths=status'),
        headers: await Session.headers(json: true),
        body: json.encode(payload),
      );
      if (response.statusCode != 200) return false;
      // Đơn bị hủy: đánh dấu cả dòng lịch công khai để ô giờ trống lại.
      if (newStatus == 'Đã hủy') {
        await http.patch(
          Uri.parse('$baseUrl/slots/$bookingId?updateMask.fieldPaths=status&currentDocument.exists=true'),
          headers: await Session.headers(json: true),
          body: json.encode(payload),
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Trạng thái hiện tại của từng đơn (chỉ đọc trường `status`); null nếu có đơn chưa đọc được.
  static Future<List<String>?> getBookingStatuses(List<String> bookingIds) async {
    try {
      final out = <String>[];
      for (final id in bookingIds) {
        final response = await http.get(Uri.parse('$baseUrl/bookings/$id?mask.fieldPaths=status'), headers: await Session.headers());
        if (response.statusCode != 200) return null;
        final fields = (json.decode(response.body) as Map<String, dynamic>)['fields'] as Map<String, dynamic>?;
        out.add(fields?['status']?['stringValue'] as String? ?? '');
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  /// Tạo đơn đặt sân. Đơn, dòng lịch bận công khai và phiếu thu được ghi trong một lần (được cả hoặc không).
  static Future<bool> createBooking({
    required String customer,
    required String phone,
    required String venueName,
    required String field,
    required String time,
    required String date,
    required String amount,
    required int venueId,
    String paymentMethod = 'Chuyển khoản VietQR',
    String ownerId = 'admin_super_01',
    String status = 'Chờ xác nhận',
    bool paid = false,
    String userId = '',
    String? id,
  }) async {
    try {
      final bookingId = id ?? 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final createdAt = DateTime.now().toIso8601String();
      Map<String, dynamic> text(String v) => {'stringValue': v};
      final venue = {'integerValue': '$venueId'};
      final booking = {
        'id': text(bookingId),
        'customer': text(customer),
        'phone': text(phone),
        'venueId': venue,
        'venueName': text(venueName),
        'ownerId': text(ownerId),
        'field': text(field),
        'time': text(time),
        'date': text(date),
        'amount': text(amount),
        'status': text(status),
        'paymentMethod': text(paymentMethod),
        'createdAt': text(createdAt),
        if (userId.isNotEmpty) 'userId': text(userId),
      };
      final slot = {
        'venueId': venue,
        'venueName': text(venueName),
        'field': text(field),
        'date': text(date),
        'time': text(time),
        'status': text('Đã đặt'),
        'paymentMethod': text(paymentMethod),
        'createdAt': text(createdAt),
      };
      // Phiếu thu ở trạng thái "Đang xử lý": chỉ chuyển "Thành công" khi nhận được tiền (webhook hoặc người duyệt).
      final payId = 'PAY-${bookingId.replaceFirst('BK-', '')}';
      final payment = PaymentItem(
        id: payId,
        bookingId: bookingId,
        customer: customer,
        amount: amount,
        method: paymentMethod,
        time: '$date $time',
        status: paid ? 'Thành công' : 'Đang xử lý',
        bankRef: '',
        userId: userId,
        ownerId: ownerId,
      );
      Map<String, dynamic> create(String path, Map<String, dynamic> fields) => {
            'update': {'name': '${FirebaseConfig.documentsPath}/$path', 'fields': fields},
            'currentDocument': {'exists': false},
          };
      final response = await http.post(
        Uri.parse('$baseUrl:commit'),
        headers: await Session.headers(json: true),
        body: json.encode({
          'writes': [
            create('bookings/$bookingId', booking),
            create('slots/$bookingId', slot),
            create('payments/$payId', payment.toFirestoreFields()),
          ]
        }),
      );
      if (response.statusCode != 200) return false;

      // Thông báo cho chủ sân của cụm sân được đặt
      await addNotification(NotificationItem(
        id: 'NOTIF-${bookingId.replaceFirst('BK-', '')}',
        userId: ownerId,
        title: 'Đơn đặt sân mới: $bookingId',
        message: 'Khách hàng $customer vừa đặt sân $venueName ($field - $time ngày $date).',
        type: 'booking',
      ));
      return true;
    } catch (e) {
      return false;
    }
  }


  // ==========================================
  // KHÁCH HÀNG (CUSTOMERS)
  // ==========================================

  /// Danh sách khách hàng: lấy từ collection `users` (vai trò customer).
  /// Số lượt đặt và tổng chi tiêu được tính từ đơn đặt thật bằng [enrichCustomers].
  static Future<List<CustomerItem>> getCustomers() async {
    final r = await _listDocs('users');
    final out = <CustomerItem>[];
    for (final doc in r.docs) {
      final id = (doc['name'] as String).split('/').last;
      final f = (doc['fields'] as Map<String, dynamic>?) ?? {};
      String v(String k) => (f[k]?['stringValue'] ?? '').toString();
      if (v('role') != 'customer') continue;
      final name = v('displayName').isNotEmpty ? v('displayName') : v('fullName');
      final rank = v('rank');
      out.add(CustomerItem(
        id: id,
        name: name.isEmpty ? 'Chưa cập nhật tên' : name,
        phone: v('phone'),
        email: v('email'),
        favoriteSport: v('favoriteSport').isEmpty ? '—' : v('favoriteSport'),
        rank: rank.isEmpty
            ? 'Đồng'
            : (rank == 'Kim Cương' || rank == 'Vàng' ? 'VIP $rank' : rank),
        status: v('status').isEmpty ? 'Hoạt động' : v('status'),
        joinDate: _fmtDate(v('createdAt')),
      ));
    }
    return out;
  }

  static String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static int _moneyToInt(String s) {
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? 0 : int.parse(digits);
  }

  static String _fmtMoney(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '$bđ';
  }

  /// Gán số lượt đặt và tổng chi tiêu thật cho từng khách (khớp theo số điện thoại, nếu thiếu thì theo tên).
  /// Chỉ tính đơn không hủy; tổng chi tiêu chỉ gồm đơn đã xác nhận/hoàn thành.
  static List<CustomerItem> enrichCustomers(List<CustomerItem> customers, List<BookingItem> bookings) {
    String digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
    for (final c in customers) {
      final cp = digits(c.phone);
      var count = 0;
      var spent = 0;
      for (final b in bookings) {
        final bp = digits(b.phone);
        final match = (cp.isNotEmpty && bp == cp) ||
            ((cp.isEmpty || bp.isEmpty) && b.customer.trim().toLowerCase() == c.name.trim().toLowerCase());
        if (!match) continue;
        final st = b.status.toLowerCase();
        if (st.contains('hủy')) continue;
        count++;
        if (!st.contains('chờ')) spent += _moneyToInt(b.amount);
      }
      c.bookingsCount = count;
      c.totalSpent = _fmtMoney(spent);
    }
    return customers;
  }

  /// Danh sách khách đã đặt, dựng từ chính các đơn (gộp theo số điện thoại, thiếu số thì theo tên).
  static List<CustomerItem> customersFromBookings(List<BookingItem> bookings) {
    final byKey = <String, CustomerItem>{};
    for (final b in bookings) {
      final digits = b.phone.replaceAll(RegExp(r'[^0-9]'), '');
      final key = digits.isNotEmpty ? digits : b.customer.trim().toLowerCase();
      if (key.isEmpty || b.status.toLowerCase().contains('hủy')) continue;
      byKey.putIfAbsent(
          key,
          () => CustomerItem(
                id: key,
                name: b.customer.isEmpty ? 'Chưa cập nhật tên' : b.customer,
                phone: b.phone,
                email: '',
                favoriteSport: b.field.replaceAll(RegExp(r'\s*\d+$'), ''),
                joinDate: _fmtDate(b.createdAt.toIso8601String()),
              ));
    }
    return enrichCustomers(byKey.values.toList(), bookings);
  }

  static Map<String, dynamic> _customerFields(CustomerItem c) => {
        'displayName': {'stringValue': c.name},
        'phone': {'stringValue': c.phone},
        'email': {'stringValue': c.email},
        'favoriteSport': {'stringValue': c.favoriteSport},
        'rank': {'stringValue': c.rank.replaceFirst('VIP ', '')},
        'status': {'stringValue': c.status},
      };

  /// Thêm hồ sơ khách (ví dụ khách đặt tại quầy). Không có mật khẩu nên không đăng nhập được.
  static Future<bool> addCustomer(CustomerItem customer) async {
    try {
      final fields = _customerFields(customer)
        ..['role'] = {'stringValue': 'customer'}
        ..['uid'] = {'stringValue': customer.id}
        ..['createdAt'] = {'stringValue': DateTime.now().toIso8601String()}
        ..['createdBy'] = {'stringValue': 'admin'};
      final res = await http.post(
        Uri.parse('$baseUrl/users?documentId=${Uri.encodeComponent(customer.id)}'),
        headers: await Session.headers(json: true),
        body: json.encode({'fields': fields}),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateCustomer(CustomerItem customer) async {
    try {
      final fields = _customerFields(customer);
      final mask = fields.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');
      final res = await http.patch(
        Uri.parse('$baseUrl/users/${Uri.encodeComponent(customer.id)}?$mask'),
        headers: await Session.headers(json: true),
        body: json.encode({'fields': fields}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteCustomer(String id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/users/${Uri.encodeComponent(id)}'), headers: await Session.headers());
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // THANH TOÁN (PAYMENTS)
  // ==========================================

  /// Lấy danh sách giao dịch thanh toán từ Firestore
  static Future<List<PaymentItem>> getPayments() async {
    return [
      for (final doc in await _visibleDocs('payments'))
        PaymentItem.fromFirestoreFields((doc['name'] as String).split('/').last, doc['fields'] as Map<String, dynamic>)
    ];
  }

  /// Thêm giao dịch thanh toán mới lên Firestore
  static Future<bool> addPayment(PaymentItem payment) async {
    try {
      final docId = payment.id;
      final payload = {'fields': payment.toFirestoreFields()};
      final response = await http.post(
        Uri.parse('$baseUrl/payments?documentId=$docId'),
        headers: await Session.headers(json: true),
        body: json.encode(payload),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Xác nhận đơn = đã nhận được tiền chuyển khoản: đổi trạng thái đơn sang "Đã xác nhận"
  /// và đối soát (chuyển "Thành công") các phiếu thu đang "Đang xử lý" của đơn đó.
  static Future<bool> confirmBooking(String bookingId) async {
    final ok = await updateBookingStatus(bookingId, 'Đã xác nhận');
    if (!ok) return false;
    final payments = await getPayments();
    for (final p in payments) {
      if (p.bookingId == bookingId && p.status.toLowerCase().contains('xử lý')) {
        await updatePaymentStatus(p.id, 'Thành công');
      }
    }
    return true;
  }

  /// Cập nhật trạng thái thanh toán trên Firestore
  static Future<bool> updatePaymentStatus(String id, String newStatus) async {
    try {
      final payload = {
        'fields': {
          'status': {'stringValue': newStatus},
        }
      };
      final response = await http.patch(
        Uri.parse('$baseUrl/payments/$id?updateMask.fieldPaths=status'),
        headers: await Session.headers(json: true),
        body: json.encode(payload),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // ĐÁNH GIÁ SÂN (REVIEWS)
  // ==========================================
  static Future<List<ReviewItem>> getReviews(int venueId) async {
    final r = await _listDocs('reviews');
    final list = <ReviewItem>[];
    for (final doc in r.docs) {
      final id = (doc['name'] as String).split('/').last;
      final item = ReviewItem.fromFirestoreFields(id, (doc['fields'] as Map<String, dynamic>?) ?? {});
      if (item.venueId == venueId) list.add(item);
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Toàn bộ đánh giá (mới nhất trước), dùng cho dòng tin ở mục Khám phá.
  static Future<List<ReviewItem>> getAllReviews() async {
    final r = await _listDocs('reviews');
    final list = <ReviewItem>[];
    for (final doc in r.docs) {
      final id = (doc['name'] as String).split('/').last;
      list.add(ReviewItem.fromFirestoreFields(id, (doc['fields'] as Map<String, dynamic>?) ?? {}));
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<bool> addReview(ReviewItem review) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/reviews?documentId=${Uri.encodeComponent(review.id)}'),
        headers: await Session.headers(json: true),
        body: json.encode({'fields': review.toFirestoreFields()}),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // TIN TỨC (NEWS) — do admin đăng, hiện ở mục Khám phá
  // ==========================================

  /// Tin đã đăng, mới nhất trước. Tải lỗi thì đặt [lastLoadFailed] và trả về danh sách rỗng.
  static Future<List<NewsPost>> getNews() async {
    final r = await _listDocs('news');
    final list = <NewsPost>[];
    for (final doc in r.docs) {
      final id = (doc['name'] as String).split('/').last;
      final p = NewsPost.tryFromFirestoreFields(id, (doc['fields'] as Map<String, dynamic>?) ?? {});
      if (p != null) list.add(p);
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Đăng tin mới.
  static Future<bool> addNews(NewsPost post) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/news?documentId=${Uri.encodeComponent(post.id)}'),
        headers: await Session.headers(json: true),
        body: json.encode({'fields': post.toFirestoreFields()}),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Sửa tin (ghi đè đúng các trường của bài, không đổi ngày đăng).
  static Future<bool> updateNews(NewsPost post) async {
    try {
      final fields = post.toFirestoreFields();
      final mask = fields.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');
      final res = await http.patch(
        Uri.parse('$baseUrl/news/${Uri.encodeComponent(post.id)}?$mask'),
        headers: await Session.headers(json: true),
        body: json.encode({'fields': fields}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteNews(String id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/news/${Uri.encodeComponent(id)}'), headers: await Session.headers());
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // THÔNG BÁO HỆ THỐNG (NOTIFICATIONS)
  // ==========================================

  /// Thông báo gửi cho tài khoản hiện tại (quản trị viên thêm hộp thư chung `admin_super_01`).
  static Future<List<NotificationItem>> getNotifications() async {
    final user = AuthService.currentUser;
    if (user == null || user.isGuest) return [];
    final list = <NotificationItem>[];
    for (final id in {user.uid, if (user.isAdmin) 'admin_super_01'}) {
      for (final doc in (await _queryDocs('notifications', 'userId', id)).docs) {
        list.add(NotificationItem.fromFirestoreFields((doc['name'] as String).split('/').last, doc['fields'] as Map<String, dynamic>));
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Gửi thông báo mới lên Firestore
  static Future<bool> addNotification(NotificationItem item) async {
    try {
      final docId = item.id;
      final payload = {'fields': item.toFirestoreFields()};
      final response = await http.post(
        Uri.parse('$baseUrl/notifications?documentId=$docId'),
        headers: await Session.headers(json: true),
        body: json.encode(payload),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Đánh dấu thông báo đã đọc
  static Future<bool> markNotificationAsRead(String notifId) async {
    try {
      final payload = {
        'fields': {
          'isRead': {'booleanValue': true},
        }
      };
      final response = await http.patch(
        Uri.parse('$baseUrl/notifications/$notifId?updateMask.fieldPaths=isRead'),
        headers: await Session.headers(json: true),
        body: json.encode(payload),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
