import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/venue.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../models/notification_item.dart';
import '../data/venues_data.dart';

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
  }) : createdAt = createdAt ?? DateTime.now();

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
    );
  }
}

class FirestoreService {
  static const String projectId = 'alobooking-b2484';
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
                  tags: (fields?['tags']?['arrayValue']?['values'] as List<dynamic>?)
                          ?.map((v) => v['stringValue']?.toString() ?? '')
                          .toList() ??
                      ['Đơn ngày'],
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
                ));
              }
            }
          }
          pageToken = data['nextPageToken'] as String?;
        } else {
          break;
        }
      } while (pageToken != null && pageToken.isNotEmpty);

      if (allVenues.isNotEmpty) {
        allVenues.sort((a, b) => a.id.compareTo(b.id));
        return allVenues;
      }
    } catch (e) {
      // Fallback local data
    }
    return sampleVenues;
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
  static Future<bool> updateVenueApproval(int venueId, String newStatus, [String rejectReason = '']) async {
    try {
      final payload = {
        'fields': {
          'approvalStatus': {'stringValue': newStatus},
          'rejectReason': {'stringValue': rejectReason},
        }
      };
      final response = await http.patch(
        Uri.parse('$baseUrl/venues/$venueId?updateMask.fieldPaths=approvalStatus&updateMask.fieldPaths=rejectReason'),
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
          break;
        }
      } while (pageToken != null && pageToken.isNotEmpty);

      if (allBookings.isNotEmpty) {
        allBookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return allBookings;
      }
    } catch (e) {
      // Fallback
    }
    return _defaultBookings;
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
    String paymentMethod = 'Chuyển khoản QR',
  }) async {
    try {
      final bookingId = 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
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
          'status': {'stringValue': 'Chờ xác nhận'},
          'paymentMethod': {'stringValue': paymentMethod},
          'createdAt': {'stringValue': DateTime.now().toIso8601String()},
        }
      };

      final response = await http.post(
        Uri.parse('$baseUrl/bookings?documentId=$bookingId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      final isSuccess = response.statusCode == 200 || response.statusCode == 201;
      if (isSuccess) {
        // Tự động sinh phiếu thu thanh toán đồng bộ lên Firestore
        final payId = 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
        final newPayment = PaymentItem(
          id: payId,
          bookingId: bookingId,
          customer: customer,
          amount: amount,
          method: paymentMethod,
          time: '$date $time',
          status: 'Thành công',
          bankRef: 'MBB-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        );
        addPayment(newPayment);

        // Tự động gửi thông báo thời gian thực lên Firestore
        final notif = NotificationItem(
          id: 'NOTIF-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
          userId: 'owner_chuan_01',
          title: 'Đơn đặt sân mới: $bookingId 🎾',
          message: 'Khách hàng $customer vừa đặt sân $venueName ($field - $time ngày $date).',
          type: 'booking',
        );
        addNotification(notif);
      }

      return isSuccess;
    } catch (e) {
      return false;
    }
  }

  static final List<BookingItem> _defaultBookings = [
    BookingItem(
      id: 'BK-1029',
      customer: 'Nguyễn Văn An',
      phone: '0901234567',
      venueName: 'Pickleball Cổng B Ga Hà Nội',
      field: 'Sân #2',
      time: '18:00 - 19:30',
      date: '31/10/2026',
      amount: '220,000đ',
      status: 'Chờ xác nhận',
      paymentMethod: 'Chuyển khoản VietQR',
    ),
    BookingItem(
      id: 'BK-1030',
      customer: 'Trần Thị Bích',
      phone: '0912345678',
      venueName: 'Phúc Long Pickleball & Badminton',
      field: 'Sân Cầu Lông #3',
      time: '19:30 - 21:00',
      date: '31/10/2026',
      amount: '180,000đ',
      status: 'Đã xác nhận',
      paymentMethod: 'Ví MoMo',
    ),
    BookingItem(
      id: 'BK-1031',
      customer: 'Lê Hoàng Nam',
      phone: '0987654321',
      venueName: 'Sân Bóng Đá Mini Nam Từ Liêm',
      field: 'Sân 7 người VIP',
      time: '17:00 - 18:30',
      date: '01/11/2026',
      amount: '450,000đ',
      status: 'Hoàn thành',
      paymentMethod: 'Tiền mặt',
    ),
    BookingItem(
      id: 'BK-1032',
      customer: 'Phạm Minh Đức',
      phone: '0933445566',
      venueName: 'City Pickleball Chùa Bộc',
      field: 'Sân #1',
      time: '20:00 - 21:30',
      date: '01/11/2026',
      amount: '200,000đ',
      status: 'Chờ xác nhận',
      paymentMethod: 'Chuyển khoản VietQR',
    ),
  ];

  // ==========================================
  // KHÁCH HÀNG (CUSTOMERS)
  // ==========================================
  static final List<CustomerItem> _defaultCustomers = [
    CustomerItem(
      id: 'CUST-01',
      name: 'Nguyễn Văn An',
      phone: '0901234567',
      email: 'an.nguyen@gmail.com',
      bookingsCount: 18,
      totalSpent: '4.250.000đ',
      favoriteSport: 'Pickleball',
      rank: 'VIP Vàng',
      status: 'Hoạt động',
      joinDate: '12/03/2026',
    ),
    CustomerItem(
      id: 'CUST-02',
      name: 'Trần Thị Bích',
      phone: '0912345678',
      email: 'bich.tran@gmail.com',
      bookingsCount: 12,
      totalSpent: '2.800.000đ',
      favoriteSport: 'Cầu lông',
      rank: 'Bạc',
      status: 'Hoạt động',
      joinDate: '24/04/2026',
    ),
    CustomerItem(
      id: 'CUST-03',
      name: 'Lê Hoàng Nam',
      phone: '0987654321',
      email: 'nam.le@yahoo.com',
      bookingsCount: 25,
      totalSpent: '7.600.000đ',
      favoriteSport: 'Bóng đá',
      rank: 'VIP Kim Cương',
      status: 'Hoạt động',
      joinDate: '05/01/2026',
    ),
    CustomerItem(
      id: 'CUST-04',
      name: 'Phạm Minh Đức',
      phone: '0933445566',
      email: 'duc.pham@outlook.com',
      bookingsCount: 8,
      totalSpent: '1.600.000đ',
      favoriteSport: 'Pickleball',
      rank: 'Đồng',
      status: 'Hoạt động',
      joinDate: '15/06/2026',
    ),
    CustomerItem(
      id: 'CUST-05',
      name: 'Hoàng Anh Tuấn',
      phone: '0977889900',
      email: 'tuan.hoang@gmail.com',
      bookingsCount: 15,
      totalSpent: '5.200.000đ',
      favoriteSport: 'Tennis',
      rank: 'VIP Vàng',
      status: 'Hoạt động',
      joinDate: '20/02/2026',
    ),
    CustomerItem(
      id: 'CUST-06',
      name: 'Đỗ Thùy Trang',
      phone: '0944556677',
      email: 'trang.do@gmail.com',
      bookingsCount: 4,
      totalSpent: '920.000đ',
      favoriteSport: 'Cầu lông',
      rank: 'Đồng',
      status: 'Tạm khóa',
      joinDate: '10/08/2026',
    ),
  ];

  static Future<List<CustomerItem>> getCustomers() async {
    return List.from(_defaultCustomers);
  }

  static void addCustomer(CustomerItem customer) {
    _defaultCustomers.insert(0, customer);
  }

  static void updateCustomer(CustomerItem customer) {
    final idx = _defaultCustomers.indexWhere((c) => c.id == customer.id);
    if (idx != -1) {
      _defaultCustomers[idx] = customer;
    }
  }

  static void deleteCustomer(String id) {
    _defaultCustomers.removeWhere((c) => c.id == id);
  }

  // ==========================================
  // THANH TOÁN (PAYMENTS)
  // ==========================================
  static final List<PaymentItem> _defaultPayments = [
    PaymentItem(
      id: 'PAY-8921',
      bookingId: 'BK-1029',
      customer: 'Nguyễn Văn An',
      amount: '220.000đ',
      method: 'VietQR Pro',
      time: '31/10/2026 18:02',
      status: 'Thành công',
      bankRef: 'MBB-8491823',
    ),
    PaymentItem(
      id: 'PAY-8922',
      bookingId: 'BK-1030',
      customer: 'Trần Thị Bích',
      amount: '180.000đ',
      method: 'Ví MoMo',
      time: '31/10/2026 19:15',
      status: 'Thành công',
      bankRef: 'MOMO-910248',
    ),
    PaymentItem(
      id: 'PAY-8923',
      bookingId: 'BK-1031',
      customer: 'Lê Hoàng Nam',
      amount: '450.000đ',
      method: 'Tiền mặt',
      time: '31/10/2026 16:55',
      status: 'Thành công',
      bankRef: 'CASH-POS-01',
    ),
    PaymentItem(
      id: 'PAY-8924',
      bookingId: 'BK-1032',
      customer: 'Phạm Minh Đức',
      amount: '200.000đ',
      method: 'VietQR Pro',
      time: '31/10/2026 19:50',
      status: 'Đang xử lý',
      bankRef: 'VCB-Pending',
    ),
    PaymentItem(
      id: 'PAY-8925',
      bookingId: 'BK-1033',
      customer: 'Hoàng Anh Tuấn',
      amount: '350.000đ',
      method: 'VNPay QR',
      time: '30/10/2026 21:10',
      status: 'Thành công',
      bankRef: 'VNPAY-38190',
    ),
    PaymentItem(
      id: 'PAY-8926',
      bookingId: 'BK-1034',
      customer: 'Đỗ Thùy Trang',
      amount: '240.000đ',
      method: 'VietQR Pro',
      time: '29/10/2026 17:30',
      status: 'Đã hoàn tiền',
      bankRef: 'REFUND-8201',
    ),
  ];

  /// Lấy danh sách giao dịch thanh toán từ Firestore
  static Future<List<PaymentItem>> getPayments() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/payments?pageSize=100'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List<dynamic>?;
        if (documents != null && documents.isNotEmpty) {
          final List<PaymentItem> list = [];
          for (final doc in documents) {
            final name = (doc['name'] as String).split('/').last;
            final fields = doc['fields'] as Map<String, dynamic>;
            list.add(PaymentItem.fromFirestoreFields(name, fields));
          }
          if (list.isNotEmpty) {
            return list;
          }
        }
      }
    } catch (_) {}
    return List.from(_defaultPayments);
  }

  /// Thêm giao dịch thanh toán mới lên Firestore
  static Future<bool> addPayment(PaymentItem payment) async {
    _defaultPayments.insert(0, payment);
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

  /// Cập nhật trạng thái thanh toán trên Firestore
  static Future<bool> updatePaymentStatus(String id, String newStatus) async {
    final idx = _defaultPayments.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _defaultPayments[idx] = _defaultPayments[idx].copyWith(status: newStatus);
    }
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
  // THÔNG BÁO HỆ THỐNG (NOTIFICATIONS)
  // ==========================================
  static final List<NotificationItem> _defaultNotifications = [
    NotificationItem(
      id: 'NOTIF-001',
      userId: 'owner_chuan_01',
      title: 'Sân đã được phê duyệt 🎉',
      message: 'Cụm sân Pickleball Ga Hà Nội đã được Super Admin phê duyệt và đưa lên hệ thống mở bán.',
      type: 'venue_approval',
    ),
    NotificationItem(
      id: 'NOTIF-002',
      userId: 'owner_chuan_01',
      title: 'Thanh toán thành công 💰',
      message: 'Đơn đặt sân BK-1029 đã được thanh toán 220.000đ qua VietQR Pro.',
      type: 'payment',
    ),
  ];

  /// Lấy danh sách thông báo từ Firestore
  static Future<List<NotificationItem>> getNotifications([String? userId]) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/notifications?pageSize=50'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List<dynamic>?;
        if (documents != null && documents.isNotEmpty) {
          final List<NotificationItem> list = [];
          for (final doc in documents) {
            final name = (doc['name'] as String).split('/').last;
            final fields = doc['fields'] as Map<String, dynamic>;
            list.add(NotificationItem.fromFirestoreFields(name, fields));
          }
          if (list.isNotEmpty) {
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          }
        }
      }
    } catch (_) {}
    return List.from(_defaultNotifications);
  }

  /// Gửi thông báo mới lên Firestore
  static Future<bool> addNotification(NotificationItem item) async {
    _defaultNotifications.insert(0, item);
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
    final idx = _defaultNotifications.indexWhere((n) => n.id == notifId);
    if (idx != -1) {
      _defaultNotifications[idx].isRead = true;
    }
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
