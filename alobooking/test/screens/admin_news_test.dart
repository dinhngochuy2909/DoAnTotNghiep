import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alobooking/data/venue_photos.dart';
import 'package:alobooking/data/venues_data.dart';
import 'package:alobooking/screens/admin_screen.dart';

Future<bool> _loadRealFont() async {
  final f = File('C:/Windows/Fonts/segoeui.ttf');
  if (!f.existsSync()) return false;
  final loader = FontLoader('Be Vietnam Pro')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
  return true;
}

/// Máy chủ giả cho collection `news`: nhớ các tin đã đăng và ghi lại mọi yêu cầu.
class _FakeNewsServer {
  final Map<String, Map<String, dynamic>> docs = {};
  final List<http.Request> requests = [];
  bool failWrites = false;

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    final path = r.url.path;
    final isNews = path.contains('/documents/news');
    if (isNews && r.method == 'GET') {
      return http.Response(
        jsonEncode({
          'documents': [
            for (final e in docs.entries) {'name': 'projects/x/databases/(default)/documents/news/${e.key}', 'fields': e.value},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (isNews && failWrites) return http.Response('{}', 500);
    if (isNews && r.method == 'POST') {
      docs[r.url.queryParameters['documentId']!] = (jsonDecode(r.body)['fields'] as Map).cast<String, dynamic>();
      return http.Response('{}', 200);
    }
    if (isNews && r.method == 'PATCH') {
      final id = Uri.decodeComponent(path.split('/').last);
      docs[id] = {...?docs[id], ...(jsonDecode(r.body)['fields'] as Map).cast<String, dynamic>()};
      return http.Response('{}', 200);
    }
    if (isNews && r.method == 'DELETE') {
      docs.remove(Uri.decodeComponent(path.split('/').last));
      return http.Response('{}', 200);
    }
    return http.Response('{}', 404);
  }

  void seed(String id, {String title = 'Tin có sẵn', String body = 'Nội dung có sẵn', String category = 'event', bool pinned = false}) {
    docs[id] = {
      'title': {'stringValue': title},
      'body': {'stringValue': body},
      'category': {'stringValue': category},
      'imageUrl': {'stringValue': ''},
      'venueId': {'integerValue': '0'},
      'pinned': {'booleanValue': pinned},
      'author': {'stringValue': 'AloBooking'},
      'createdAt': {'stringValue': '2026-11-20T09:00:00.000'},
    };
  }
}

Finder _k(String key) => find.byKey(ValueKey(key));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openTab(WidgetTester tester, {Size size = const Size(1440, 1100)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: AdminScreen(initialVenues: sampleVenues, initialTabIndex: 5)));
  await _settle(tester);
}

Future<void> _type(WidgetTester tester, String boxKey, String text) async {
  final field = find.descendant(of: _k(boxKey), matching: find.byType(TextField));
  await tester.enterText(field.evaluate().isEmpty ? _k(boxKey) : field, text);
  await tester.pump();
}

void main() {
  var realFont = false;
  setUpAll(() async {
    realFont = await _loadRealFont();
  });

  testWidgets('Tab Tin tức trống: báo chưa có tin và có nút Đăng tin mới', (tester) async {
    final server = _FakeNewsServer();
    await http.runWithClient(() async {
      await _openTab(tester);
      expect(find.text('Tin tức'), findsWidgets);
      expect(find.textContaining('Chưa có tin nào'), findsOneWidget);
      expect(_k('admin-news-add'), findsOneWidget);
      expect(find.text('Tin tự động'), findsOneWidget);
      if (realFont) expect(tester.takeException(), isNull);
    }, () => MockClient(server.handle));
  });

  testWidgets('Đăng tin: kiểm tra đầu vào, rồi lưu đúng trường lên Firestore và hiện trong danh sách', (tester) async {
    final server = _FakeNewsServer();
    await http.runWithClient(() async {
      await _openTab(tester);
      await tester.tap(_k('admin-news-add'));
      await _settle(tester);
      expect(find.text('Đăng tin mới'), findsNWidgets(2)); // nút + tiêu đề hộp thoại

      // bỏ trống
      await tester.tap(_k('admin-news-save'));
      await _settle(tester);
      expect(find.text('Nhập tiêu đề (ít nhất 3 ký tự).'), findsOneWidget);

      await _type(tester, 'admin-news-title', 'Giảm 20% giờ vàng');
      await tester.tap(_k('admin-news-save'));
      await _settle(tester);
      expect(find.text('Nhập nội dung tin.'), findsOneWidget);

      await tester.enterText(_k('admin-news-body'), 'Áp dụng mọi cuối tuần tại các sân đối tác.');
      await _type(tester, 'admin-news-image', 'abc');
      await tester.tap(_k('admin-news-save'));
      await _settle(tester);
      expect(find.textContaining('Ảnh phải là đường dẫn'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty, reason: 'chưa hợp lệ thì chưa gửi');

      await _type(tester, 'admin-news-image', 'https://example.com/a.jpg');
      await tester.tap(_k('admin-news-cat-event'));
      await tester.pump();
      await tester.tap(_k('admin-news-pinned'));
      await tester.pump();
      await tester.tap(_k('admin-news-save'));
      await _settle(tester);

      final posts = server.requests.where((r) => r.method == 'POST').toList();
      expect(posts, hasLength(1));
      expect(posts.single.url.path, contains('/documents/news'));
      final f = (jsonDecode(posts.single.body)['fields'] as Map).cast<String, dynamic>();
      expect(f['title']['stringValue'], 'Giảm 20% giờ vàng');
      expect(f['body']['stringValue'], 'Áp dụng mọi cuối tuần tại các sân đối tác.');
      expect(f['category']['stringValue'], 'event');
      expect(f['imageUrl']['stringValue'], 'https://example.com/a.jpg');
      expect(f['pinned']['booleanValue'], true);
      expect(f['venueId']['integerValue'], '0');
      expect(DateTime.tryParse(f['createdAt']['stringValue']), isNotNull);

      // hộp thoại đóng, tin hiện trong danh sách
      expect(find.text('Đăng tin mới'), findsOneWidget);
      expect(find.text('Giảm 20% giờ vàng'), findsOneWidget);
      expect(find.textContaining('Chưa có tin nào'), findsNothing);
      expect(find.text('Tin đã đăng (1)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4)); // thanh thông báo tự tắt
    }, () => MockClient(server.handle));
  });

  testWidgets('Lưu thất bại: hộp thoại giữ nguyên, báo lỗi, không thêm tin giả vào danh sách', (tester) async {
    final server = _FakeNewsServer()..failWrites = true;
    await http.runWithClient(() async {
      await _openTab(tester);
      await tester.tap(_k('admin-news-add'));
      await _settle(tester);
      await _type(tester, 'admin-news-title', 'Tin sẽ lỗi');
      await tester.enterText(_k('admin-news-body'), 'Nội dung');
      await tester.tap(_k('admin-news-save'));
      await _settle(tester);
      expect(find.text('Không lưu được. Kiểm tra kết nối rồi thử lại.'), findsOneWidget);
      expect(_k('admin-news-save'), findsOneWidget, reason: 'hộp thoại còn mở để thử lại');
      await tester.tap(find.text('Hủy'));
      await _settle(tester);
      expect(find.text('Tin sẽ lỗi'), findsNothing);
      expect(find.text('Tin đã đăng (0)'), findsOneWidget);
    }, () => MockClient(server.handle));
  });

  testWidgets('Tin đã có hiện lên; ghim nằm trước; sửa gửi đúng các trường và cập nhật dòng tin', (tester) async {
    final server = _FakeNewsServer()
      ..seed('a', title: 'Tin thường', pinned: false)
      ..seed('b', title: 'Tin ghim', pinned: true);
    await http.runWithClient(() async {
      await _openTab(tester);
      expect(find.text('Tin đã đăng (2)'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Tin ghim')).dy, lessThan(tester.getTopLeft(find.text('Tin thường')).dy));

      await tester.tap(_k('admin-news-edit-a'));
      await _settle(tester);
      expect(find.text('Sửa tin'), findsOneWidget);
      await _type(tester, 'admin-news-title', 'Tin thường đã sửa');
      await tester.tap(_k('admin-news-save'));
      await _settle(tester);

      final patches = server.requests.where((r) => r.method == 'PATCH').toList();
      expect(patches, hasLength(1));
      expect(patches.single.url.path, endsWith('/news/a'));
      expect(patches.single.url.query, contains('updateMask.fieldPaths=title'));
      expect(patches.single.url.query, contains('updateMask.fieldPaths=createdAt'));
      expect(server.docs['a']!['title']['stringValue'], 'Tin thường đã sửa');
      expect(server.docs['a']!['createdAt']['stringValue'], '2026-11-20T09:00:00.000', reason: 'sửa không đổi ngày đăng');
      expect(find.text('Tin thường đã sửa'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    }, () => MockClient(server.handle));
  });

  testWidgets('Xóa tin: hỏi xác nhận, gửi DELETE rồi bỏ khỏi danh sách', (tester) async {
    final server = _FakeNewsServer()..seed('a', title: 'Tin sắp xóa');
    await http.runWithClient(() async {
      await _openTab(tester);
      expect(find.text('Tin sắp xóa'), findsOneWidget);

      await tester.tap(_k('admin-news-delete-a'));
      await _settle(tester);
      expect(find.text('Xóa tin này?'), findsOneWidget);

      await tester.tap(find.text('Hủy'));
      await _settle(tester);
      expect(server.requests.where((r) => r.method == 'DELETE'), isEmpty);
      expect(find.text('Tin sắp xóa'), findsOneWidget);

      await tester.tap(_k('admin-news-delete-a'));
      await _settle(tester);
      await tester.tap(_k('admin-news-confirm-delete'));
      await _settle(tester);
      expect(server.requests.where((r) => r.method == 'DELETE'), hasLength(1));
      expect(server.docs, isEmpty);
      expect(find.text('Tin sắp xóa'), findsNothing);
      expect(find.text('Tin đã đăng (0)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    }, () => MockClient(server.handle));
  });

  testWidgets('Gắn tin với một sân: tìm theo tên, chọn, lưu venueId và hiện tên sân ở danh sách', (tester) async {
    final server = _FakeNewsServer();
    final target = sampleVenues.first;
    await http.runWithClient(() async {
      await _openTab(tester);
      await tester.tap(_k('admin-news-add'));
      await _settle(tester);

      await tester.enterText(_k('admin-news-venue-search'), target.name.substring(0, 4));
      await _settle(tester);
      await tester.tap(find.text(target.name).first);
      await _settle(tester);
      expect(_k('admin-news-linked'), findsOneWidget);

      await _type(tester, 'admin-news-title', 'Ưu đãi tại sân');
      await tester.enterText(_k('admin-news-body'), 'Giảm giá');
      await tester.tap(_k('admin-news-save'));
      await _settle(tester);

      final f = (jsonDecode(server.requests.firstWhere((r) => r.method == 'POST').body)['fields'] as Map).cast<String, dynamic>();
      expect(f['venueId']['integerValue'], '${target.id}');
      expect(find.textContaining('Gắn sân: ${target.name}'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    }, () => MockClient(server.handle));
  });

  for (final size in const [Size(1440, 900), Size(390, 844)]) {
    testWidgets('Tab Tin tức và hộp thoại đăng tin không tràn bố cục ở ${size.width.toInt()}px', (tester) async {
      final server = _FakeNewsServer()
        ..seed('a', title: 'Một tin có tiêu đề khá dài để kiểm tra việc cắt chữ trong danh sách tin đã đăng của quản trị viên', pinned: true);
      await http.runWithClient(() async {
        await _openTab(tester, size: size);
        expect(find.textContaining('Một tin có tiêu đề'), findsOneWidget);
        if (realFont) expect(tester.takeException(), isNull);
        await tester.tap(_k('admin-news-add'));
        await _settle(tester);
        expect(_k('admin-news-save'), findsOneWidget);
        if (realFont) expect(tester.takeException(), isNull);
      }, () => MockClient(server.handle));
    });
  }

  testWidgets('Chọn ảnh minh họa có sẵn: bấm một ảnh thì điền vào ô ảnh và lưu đúng đường dẫn', (tester) async {
    final server = _FakeNewsServer();
    await http.runWithClient(() async {
      await _openTab(tester);
      await tester.tap(_k('admin-news-add'));
      await _settle(tester);
      await _type(tester, 'admin-news-title', 'Giải bóng đá cuối tuần');
      await tester.enterText(_k('admin-news-body'), 'Đăng ký tại quầy.');

      await tester.ensureVisible(_k('admin-news-photo-sport-football'));
      await tester.tap(_k('admin-news-photo-sport-football'));
      await tester.pump();
      await tester.ensureVisible(_k('admin-news-photo-2'));
      await tester.tap(_k('admin-news-photo-2'));
      await tester.pump();

      final expected = VenuePhotos.forSport('football')[2];
      final box = tester.widget<TextField>(find.descendant(of: _k('admin-news-image'), matching: find.byType(TextField)));
      expect(box.controller!.text, expected, reason: 'bấm ảnh thì điền đường dẫn ảnh vào ô');

      await tester.tap(_k('admin-news-save'));
      await _settle(tester);
      final post = server.requests.singleWhere((r) => r.method == 'POST');
      final f = (jsonDecode(post.body)['fields'] as Map).cast<String, dynamic>();
      expect(f['imageUrl']['stringValue'], expected);
      expect(VenuePhotos.isStock(f['imageUrl']['stringValue'] as String), isTrue, reason: 'ảnh kho nên Khám phá sẽ dán nhãn minh họa');
    }, () => MockClient(server.handle));
  });
}
