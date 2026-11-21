import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/venue.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../models/notification_item.dart';
import '../models/news_post.dart';

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
  }) : createdAt = createdAt ?? DateTime.now();

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

class FirestoreService {
  static const String projectId = 'alobooking-b2484';

  /// true nếu một lần tải gần nhất từ Firestore thất bại (mất mạng/lỗi máy chủ).
  /// Giao diện dùng cờ này để báo lỗi rõ ràng thay vì hiển thị dữ liệu mẫu.
  static bool lastLoadFailed = false;

  /// Liệt kê toàn bộ tài liệu của một collection (có phân trang).
  static Future<({bool ok, List<Map<String, dynamic>> docs})> _listDocs(String collection, {int pageSize = 300}) async {
    final docs = <Map<String, dynamic>>[];
    String? pageToken;
    try {
      do {
        final q = pageToken != null && pageToken.isNotEmpty ? '&pageToken=$pageToken' : '';
        final res = await http.get(Uri.parse('$baseUrl/$collection?pageSize=$pageSize$q'));
        if (res.statusCode != 200) {
          // 404/rỗng được coi là collection chưa có dữ liệu, các lỗi khác là lỗi tải
          if (res.statusCode == 404) return (ok: true, docs: docs);
          lastLoadFailed = true;
          return (ok: false, docs: docs);
        }
        final data = json.decode(res.body);
        final list = data['documents'] as List<dynamic>?;
        if (list != null) docs.addAll(list.cast<Map<String, dynamic>>());
        pageToken = data['nextPageToken'] as String?;
      } while (pageToken != null && pageToken.isNotEmpty);
      return (ok: true, docs: docs);
    } catch (_) {
      lastLoadFailed = true;
      return (ok: false, docs: docs);
    }
  }
  static const String baseUrl =
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  /// Lấy danh sách sân thể thao từ Firestore alobooking-b2484 (hỗ trợ phân trang đầy đủ)
  static Future<List<Venue>> getVenues() async {
    try {
      final List<Venue> allVenues = [];
      String? pageToken;

      do {
        final queryParam = pageToken != null ? '&pageToken=$pageToken' : '';
        final response = await http.get(Uri.parse('$baseUrl/venues?pageSize=300$queryParam'));

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
          if (response.statusCode != 404) lastLoadFailed = true;
          break;
        }
      } while (pageToken != null && pageToken.isNotEmpty);

      if (allVenues.isNotEmpty) {
        allVenues.sort((a, b) => a.id.compareTo(b.id));
        return allVenues;
      }
    } catch (e) {
      lastLoadFailed = true;
    }
    return <Venue>[];
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
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      return response.statusCode == 200 || response.statusCode == 201;
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
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Xóa sân thể thao khỏi Firestore
  static Future<bool> deleteVenue(int venueId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/venues/$venueId'));
      return response.statusCode == 200;
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
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      return response.statusCode == 200;
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

  /// Lấy danh sách đơn đặt sân từ Firestore (hỗ trợ phân trang)
  static Future<List<BookingItem>> getBookings() async {
    try {
      final List<BookingItem> allBookings = [];
      String? pageToken;

      do {
        final queryParam = pageToken != null ? '&pageToken=$pageToken' : '';
        final response = await http.get(Uri.parse('$baseUrl/bookings?pageSize=100$queryParam'));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final documents = data['documents'] as List<dynamic>?;
          if (documents != null && documents.isNotEmpty) {
            for (final doc in documents) {
              final name = (doc['name'] as String).split('/').last;
              final fields = doc['fields'] as Map<String, dynamic>;
              allBookings.add(BookingItem.fromFirestoreFields(name, fields));
            }
          }
          pageToken = data['nextPageToken'] as String?;
        } else {
          if (response.statusCode != 404) lastLoadFailed = true;
          break;
        }
      } while (pageToken != null && pageToken.isNotEmpty);

      if (allBookings.isNotEmpty) {
        allBookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return allBookings;
      }
    } catch (e) {
      lastLoadFailed = true;
    }
    return <BookingItem>[];
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
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Tạo đơn đặt sân lưu trực tiếp lên Firestore alobooking-b2484
  static Future<bool> createBooking({
    required String customer,
    required String phone,
    required String venueName,
    required String field,
    required String time,
    required String date,
    required String amount,
    String paymentMethod = 'Chuyển khoản VietQR',
    String ownerId = 'admin_super_01',
    String status = 'Chờ xác nhận',
    bool paid = false,
    String userId = '',
    String? id,
  }) async {
    try {
      final bookingId = id ?? 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final payload = {
        'fields': {
          'id': {'stringValue': bookingId},
          'customer': {'stringValue': customer},
          'phone': {'stringValue': phone},
          'venueName': {'stringValue': venueName},
          'field': {'stringValue': field},
          'time': {'stringValue': time},
          'date': {'stringValue': date},
          'amount': {'stringValue': amount},
          'status': {'stringValue': status},
          'paymentMethod': {'stringValue': paymentMethod},
          'createdAt': {'stringValue': DateTime.now().toIso8601String()},
          if (userId.isNotEmpty) 'userId': {'stringValue': userId},
        }
      };

      final response = await http.post(
        Uri.parse('$baseUrl/bookings?documentId=$bookingId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      final isSuccess = response.statusCode == 200 || response.statusCode == 201;
      if (isSuccess) {
        // Phiếu thu ở trạng thái "Đang xử lý": chỉ chuyển "Thành công" khi chủ sân/admin xác nhận đã nhận tiền.
        // (Không có cổng thanh toán nên không được tự khẳng định đã thanh toán.)
        final payId = 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
        final newPayment = PaymentItem(
          id: payId,
          bookingId: bookingId,
          customer: customer,
          amount: amount,
          method: paymentMethod,
          time: '$date $time',
          status: paid ? 'Thành công' : 'Đang xử lý',
          bankRef: '',
        );
        await addPayment(newPayment);

        // Thông báo cho chủ sân của cụm sân được đặt
        final notif = NotificationItem(
          id: 'NOTIF-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
          userId: ownerId,
          title: 'Đơn đặt sân mới: $bookingId',
          message: 'Khách hàng $customer vừa đặt sân $venueName ($field - $time ngày $date).',
          type: 'booking',
        );
        await addNotification(notif);
      }

      return isSuccess;
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
    return '${b}đ';
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
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fields': fields}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteCustomer(String id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/users/${Uri.encodeComponent(id)}'));
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
    final r = await _listDocs('payments', pageSize: 100);
    final list = <PaymentItem>[];
    for (final doc in r.docs) {
      final name = (doc['name'] as String).split('/').last;
      final fields = doc['fields'] as Map<String, dynamic>;
      list.add(PaymentItem.fromFirestoreFields(name, fields));
    }
    return list;
  }

  /// Thêm giao dịch thanh toán mới lên Firestore
  static Future<bool> addPayment(PaymentItem payment) async {
    try {
      final docId = payment.id;
      final payload = {'fields': payment.toFirestoreFields()};
      final response = await http.post(
        Uri.parse('$baseUrl/payments?documentId=$docId'),
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fields': fields}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteNews(String id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/news/${Uri.encodeComponent(id)}'));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // THÔNG BÁO HỆ THỐNG (NOTIFICATIONS)
  // ==========================================

  /// Lấy danh sách thông báo từ Firestore
  static Future<List<NotificationItem>> getNotifications([String? userId]) async {
    final r = await _listDocs('notifications', pageSize: 50);
    final list = <NotificationItem>[];
    for (final doc in r.docs) {
      final name = (doc['name'] as String).split('/').last;
      final fields = doc['fields'] as Map<String, dynamic>;
      list.add(NotificationItem.fromFirestoreFields(name, fields));
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
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
