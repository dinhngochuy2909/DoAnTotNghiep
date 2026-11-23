import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/services/firestore_service.dart';
import 'package:alobooking/services/venue_cache.dart';

/// Máy chủ Firestore giả: phát sân theo từng trang, đếm số yêu cầu, và có thể giả lập lỗi.
class _FakeServer {
  _FakeServer({this.perPage = 2, int venues = 5}) {
    for (var i = 1; i <= venues; i++) {
      docs.add(_doc(i));
    }
  }

  final int perPage;
  final List<Map<String, dynamic>> docs = [];
  final List<http.Request> requests = [];

  /// Mã trả về cho trang thứ n (từ 1) của yêu cầu danh sách sân; thiếu thì 200.
  final Map<int, int> pageStatus = {};
  bool throwNetwork = false;
  int writeStatus = 200;

  static Map<String, dynamic> _doc(int id, {String status = 'approved'}) => {
        'name': 'projects/x/databases/(default)/documents/venues/$id',
        'fields': {
          'id': {'integerValue': '$id'},
          'name': {'stringValue': 'Sân $id'},
          'type': {'stringValue': 'badminton'},
          'approvalStatus': {'stringValue': status},
        },
      };

  int get venueListRequests => requests.where((r) => r.method == 'GET' && r.url.path.endsWith('/venues')).length;

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    if (throwNetwork) throw const SocketException('mất mạng');
    if (r.method != 'GET') return http.Response('{}', writeStatus);
    if (r.url.path.endsWith('/venues')) {
      final token = int.tryParse(r.url.queryParameters['pageToken'] ?? '0') ?? 0;
      final page = token ~/ perPage + 1;
      final status = pageStatus[page] ?? 200;
      if (status != 200) return http.Response(jsonEncode({'error': {'status': 'RESOURCE_EXHAUSTED'}}), status);
      final slice = docs.skip(token).take(perPage).toList();
      final next = token + perPage;
      return http.Response(
        jsonEncode({'documents': slice, if (next < docs.length) 'nextPageToken': '$next'}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response(jsonEncode({'documents': []}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
  }
}

Future<T> _with<T>(_FakeServer s, Future<T> Function() body) => http.runWithClient(body, () => MockClient(s.handle));

Venue _venue(int id, {String name = 'Sân mới', String status = 'approved'}) => Venue(
      id: id,
      name: name,
      type: 'badminton',
      district: 'Cầu Giấy',
      distance: '',
      address: 'Địa chỉ',
      hours: '06:00 – 22:00',
      tags: const [],
      rating: 4.5,
      price: '80k - 100k/h',
      lat: 21.0,
      lng: 105.8,
      image: '',
      logo: '',
      approvalStatus: status,
    );

void main() {
  var now = DateTime(2026, 11, 23, 10, 0);

  setUp(() {
    now = DateTime(2026, 11, 23, 10, 0);
    VenueCache.clock = () => now;
    VenueCache.clear();
    FirestoreService.lastLoadFailed = false;
  });

  tearDown(() {
    VenueCache.clock = DateTime.now;
    VenueCache.clear();
    FirestoreService.lastLoadFailed = false;
  });

  group('Bộ nhớ đệm giảm số lượt đọc', () {
    test('lần đầu đọc đủ các trang; lần sau trong 30 phút không hỏi máy chủ nữa', () async {
      final s = _FakeServer();
      await _with(s, () async {
        final a = await FirestoreService.getVenues();
        expect(a.map((v) => v.id), [1, 2, 3, 4, 5]);
        expect(s.venueListRequests, 3, reason: '5 sân, 2 sân mỗi trang = 3 trang');

        final b = await FirestoreService.getVenues();
        expect(b.map((v) => v.id), [1, 2, 3, 4, 5]);
        expect(s.venueListRequests, 3, reason: 'dùng bản nhớ, không đọc thêm lượt nào');
      });
    });

    test('quá 30 phút thì đọc lại', () async {
      final s = _FakeServer();
      await _with(s, () async {
        await FirestoreService.getVenues();
        now = now.add(const Duration(minutes: 31));
        await FirestoreService.getVenues();
        expect(s.venueListRequests, 6);
      });
    });

    test('forceRefresh bỏ qua bản nhớ và cập nhật bản nhớ bằng dữ liệu mới', () async {
      final s = _FakeServer();
      await _with(s, () async {
        await FirestoreService.getVenues();
        s.docs.add(_FakeServer._doc(6));
        final fresh = await FirestoreService.getVenues(forceRefresh: true);
        expect(fresh.length, 6);
        expect(s.venueListRequests, 6);
        expect((await FirestoreService.getVenues()).length, 6, reason: 'bản nhớ đã được cập nhật');
        expect(s.venueListRequests, 6);
      });
    });

    test('bản nhớ còn sau khi tải lại trang (quên bộ nhớ trong) thì không đọc lại', () async {
      final s = _FakeServer();
      await _with(s, () async {
        await FirestoreService.getVenues();
        VenueCache.forgetMemoryForTest(); // như tải lại trang: chỉ còn bản lưu trong trình duyệt
        final again = await FirestoreService.getVenues();
        expect(again.length, 5);
        expect(s.venueListRequests, 3);
      });
    });

    test('danh sách rỗng trên máy chủ không bị nhớ lại (để lần sau còn đọc)', () async {
      final s = _FakeServer(venues: 0);
      await _with(s, () async {
        expect(await FirestoreService.getVenues(), isEmpty);
        expect(VenueCache.read(), isNull);
        await FirestoreService.getVenues();
        expect(s.venueListRequests, 2);
      });
    });
  });

  group('Khi máy chủ lỗi', () {
    test('có bản nhớ (kể cả đã cũ): dùng bản nhớ, không báo lỗi, không hiện danh sách rỗng', () async {
      final s = _FakeServer();
      await _with(s, () async {
        await FirestoreService.getVenues();
        now = now.add(const Duration(hours: 5)); // đã hết hạn
        s.pageStatus[1] = 429; // hết hạn mức đọc
        final venues = await FirestoreService.getVenues();
        expect(venues.length, 5);
        expect(FirestoreService.lastLoadFailed, isFalse);
      });
    });

    test('đọc dở dang (trang 2 hết hạn mức) mà có bản nhớ: dùng bản nhớ đầy đủ, không dùng bản dở', () async {
      final s = _FakeServer();
      await _with(s, () async {
        await FirestoreService.getVenues();
        now = now.add(const Duration(hours: 1));
        s.pageStatus[2] = 429;
        final venues = await FirestoreService.getVenues();
        expect(venues.length, 5);
        expect(FirestoreService.lastLoadFailed, isFalse);
      });
    });

    test('không có bản nhớ + hết hạn mức: danh sách rỗng, báo đúng lý do "hết hạn mức"', () async {
      final s = _FakeServer()..pageStatus[1] = 429;
      await _with(s, () async {
        expect(await FirestoreService.getVenues(), isEmpty);
        expect(FirestoreService.lastLoadFailed, isTrue);
        expect(FirestoreService.lastFailure, LoadFailure.quota);
        expect(FirestoreService.failureMessage(), contains('hết lượt đọc dữ liệu'));
        expect(FirestoreService.failureMessage(), isNot(contains('mạng')), reason: 'không đổ lỗi cho mạng của người dùng');
      });
    });

    test('đọc dở dang và không có bản nhớ: trả phần đã có, báo lỗi và KHÔNG nhớ bản dở', () async {
      final s = _FakeServer()..pageStatus[2] = 429;
      await _with(s, () async {
        final venues = await FirestoreService.getVenues();
        expect(venues.map((v) => v.id), [1, 2]);
        expect(FirestoreService.lastFailure, LoadFailure.quota);
        expect(VenueCache.read(), isNull, reason: 'bản dở không được lưu thành bản nhớ');
      });
    });

    test('mất mạng: báo lỗi mạng, câu báo lỗi nhắc kiểm tra mạng', () async {
      final s = _FakeServer()..throwNetwork = true;
      await _with(s, () async {
        expect(await FirestoreService.getVenues(), isEmpty);
        expect(FirestoreService.lastFailure, LoadFailure.network);
        expect(FirestoreService.failureMessage(), contains('kiểm tra mạng'));
      });
    });

    test('máy chủ lỗi 500: báo lỗi máy chủ', () async {
      final s = _FakeServer()..pageStatus[1] = 500;
      await _with(s, () async {
        await FirestoreService.getVenues();
        expect(FirestoreService.lastFailure, LoadFailure.server);
        expect(FirestoreService.failureMessage(), contains('sự cố'));
      });
    });

    test('sau khi lỗi được khắc phục, lần đọc kế tiếp đọc lại bình thường và nhớ lại', () async {
      final s = _FakeServer()..pageStatus[1] = 429;
      await _with(s, () async {
        expect(await FirestoreService.getVenues(), isEmpty);
        s.pageStatus.clear();
        FirestoreService.lastLoadFailed = false;
        expect((await FirestoreService.getVenues()).length, 5);
        expect(VenueCache.read(), isNotNull);
      });
    });
  });

  group('Phân loại lỗi các collection khác', () {
    test('tin tức, đánh giá, đơn đặt: 429 là hết hạn mức; mất mạng là lỗi mạng', () async {
      final s = _FakeServer();
      await http.runWithClient(() async {
        FirestoreService.lastLoadFailed = false;
        await FirestoreService.getNews();
        expect(FirestoreService.lastFailure, LoadFailure.quota);
        FirestoreService.lastLoadFailed = false;
        await FirestoreService.getAllReviews();
        expect(FirestoreService.lastFailure, LoadFailure.quota);
        FirestoreService.lastLoadFailed = false;
        await FirestoreService.getBookings();
        expect(FirestoreService.lastFailure, LoadFailure.quota);
      }, () => MockClient((r) async {
            s.requests.add(r);
            return http.Response('{}', 429);
          }));

      await http.runWithClient(() async {
        FirestoreService.lastLoadFailed = false;
        await FirestoreService.getNews();
        expect(FirestoreService.lastFailure, LoadFailure.network);
        FirestoreService.lastLoadFailed = false;
        await FirestoreService.getBookings();
        expect(FirestoreService.lastFailure, LoadFailure.network);
      }, () => MockClient((r) async => throw const SocketException('mất mạng')));
    });

    test('nhiều lỗi cùng lúc: giữ lý do nặng nhất (hết hạn mức hơn máy chủ hơn mất mạng)', () async {
      await http.runWithClient(() async {
        FirestoreService.lastLoadFailed = false;
        await FirestoreService.getNews(); // 500
        expect(FirestoreService.lastFailure, LoadFailure.server);
      }, () => MockClient((r) async => http.Response('{}', 500)));
      await http.runWithClient(() async {
        await FirestoreService.getNews(); // 429 sau 500
        expect(FirestoreService.lastFailure, LoadFailure.quota);
      }, () => MockClient((r) async => http.Response('{}', 429)));
      await http.runWithClient(() async {
        await FirestoreService.getNews(); // mất mạng sau 429 không hạ cấp
        expect(FirestoreService.lastFailure, LoadFailure.quota);
      }, () => MockClient((r) async => throw const SocketException('mất mạng')));
    });

    test('404 (collection chưa có dữ liệu) không phải lỗi', () async {
      await http.runWithClient(() async {
        expect(await FirestoreService.getNews(), isEmpty);
        expect(FirestoreService.lastLoadFailed, isFalse);
      }, () => MockClient((r) async => http.Response('{}', 404)));
    });
  });

  group('Cờ lastLoadFailed và câu báo lỗi', () {
    test('gán true/false vẫn chạy như trước; gán false xóa lý do', () {
      FirestoreService.lastLoadFailed = true;
      expect(FirestoreService.lastLoadFailed, isTrue);
      expect(FirestoreService.lastFailure, LoadFailure.server);
      FirestoreService.lastLoadFailed = false;
      expect(FirestoreService.lastLoadFailed, isFalse);
      expect(FirestoreService.lastFailure, LoadFailure.none);
    });

    test('gán true không hạ cấp lý do đã rõ', () {
      FirestoreService.lastFailure = LoadFailure.quota;
      FirestoreService.lastLoadFailed = true;
      expect(FirestoreService.lastFailure, LoadFailure.quota);
    });

    test('ba câu báo lỗi khác nhau; không lỗi thì rỗng', () {
      expect(FirestoreService.failureMessage(LoadFailure.none), isEmpty);
      final m = {for (final f in [LoadFailure.network, LoadFailure.server, LoadFailure.quota]) f: FirestoreService.failureMessage(f)};
      expect(m.values.toSet().length, 3);
      expect(m[LoadFailure.quota], contains('hết lượt đọc'));
      expect(m[LoadFailure.network], contains('mạng'));
    });
  });

  group('Ghi sân sửa bản nhớ tại chỗ, không phải đọc lại hơn một nghìn sân', () {
    test('thêm, sửa, xóa, duyệt sân: bản nhớ khớp và không có thêm yêu cầu đọc danh sách', () async {
      final s = _FakeServer();
      await _with(s, () async {
        await FirestoreService.getVenues();
        final reads = s.venueListRequests;

        expect(await FirestoreService.addVenue(_venue(10, status: 'pending')), isTrue);
        expect((await FirestoreService.getVenues()).map((v) => v.id), [1, 2, 3, 4, 5, 10]);

        expect(await FirestoreService.updateVenue(_venue(10, name: 'Đã đổi tên', status: 'pending')), isTrue);
        expect((await FirestoreService.getVenues()).firstWhere((v) => v.id == 10).name, 'Đã đổi tên');

        final stamp = DateTime(2026, 11, 23, 9, 0);
        expect(await FirestoreService.updateVenueApproval(10, 'approved', '', stamp), isTrue);
        final approved = (await FirestoreService.getVenues()).firstWhere((v) => v.id == 10);
        expect(approved.approvalStatus, 'approved');
        expect(approved.approvedAt, stamp);

        expect(await FirestoreService.updateVenueApproval(1, 'rejected', 'Thiếu ảnh'), isTrue);
        final rejected = (await FirestoreService.getVenues()).firstWhere((v) => v.id == 1);
        expect(rejected.approvalStatus, 'rejected');
        expect(rejected.rejectReason, 'Thiếu ảnh');

        expect(await FirestoreService.deleteVenue(10), isTrue);
        expect((await FirestoreService.getVenues()).map((v) => v.id), [1, 2, 3, 4, 5]);

        expect(s.venueListRequests, reads, reason: 'toàn bộ thao tác trên không đọc lại danh sách');
      });
    });

    test('ghi thất bại (máy chủ trả lỗi) thì bản nhớ giữ nguyên', () async {
      final s = _FakeServer();
      await _with(s, () async {
        await FirestoreService.getVenues();
        s.writeStatus = 500;
        expect(await FirestoreService.addVenue(_venue(10)), isFalse);
        expect(await FirestoreService.updateVenue(_venue(1, name: 'Không được lưu')), isFalse);
        expect(await FirestoreService.updateVenueApproval(2, 'rejected'), isFalse);
        expect(await FirestoreService.deleteVenue(3), isFalse);
        final venues = await FirestoreService.getVenues();
        expect(venues.map((v) => v.id), [1, 2, 3, 4, 5]);
        expect(venues.first.name, 'Sân 1');
        expect(venues.firstWhere((v) => v.id == 2).approvalStatus, 'approved');
      });
    });

    test('ghi sân khi chưa có bản nhớ thì không tạo ra bản nhớ thiếu sân', () async {
      final s = _FakeServer();
      await _with(s, () async {
        expect(await FirestoreService.addVenue(_venue(10)), isTrue);
        expect(VenueCache.read(), isNull);
        expect((await FirestoreService.getVenues()).length, 5, reason: 'lần đọc đầu lấy đủ từ máy chủ');
      });
    });
  });
}
