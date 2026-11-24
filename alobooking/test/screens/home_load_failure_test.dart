import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alobooking/main.dart';
import 'package:alobooking/services/firestore_service.dart';
import 'package:alobooking/services/venue_cache.dart';

/// Font mặc định của test (Ahem) rất rộng nên báo tràn giả; nạp Segoe UI làm font của ứng dụng để đo gần thực tế.
Future<void> _loadRealFont() async {
  final f = File('C:/Windows/Fonts/segoeui.ttf');
  if (!f.existsSync()) return;
  final loader = FontLoader('Be Vietnam Pro')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
}

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _venueDoc(int id) => {
      'name': 'projects/x/databases/(default)/documents/venues/$id',
      'fields': {
        'id': {'integerValue': '$id'},
        'name': {'stringValue': 'Sân Thử Nghiệm $id'},
        'type': {'stringValue': 'badminton'},
        'approvalStatus': {'stringValue': 'approved'},
        'price': {'stringValue': '80k - 100k/h'},
      },
    };

/// Không dùng pumpAndSettle: nút chat AI nổi có hoạt ảnh lặp vô hạn nên không bao giờ "yên".
Future<void> _wait(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  setUpAll(_loadRealFont);

  setUp(() {
    VenueCache.clear();
    FirestoreService.lastLoadFailed = false;
  });

  tearDown(() {
    VenueCache.clear();
    FirestoreService.lastLoadFailed = false;
  });

  testWidgets('Hết hạn mức: trang chủ báo đúng lý do (không đổ cho mạng); "Thử lại" đọc lại và hiện sân', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var quotaExceeded = true;
    var venueReads = 0;
    final client = MockClient((r) async {
      if (r.method == 'GET' && r.url.path.endsWith('/venues')) {
        venueReads++;
        return quotaExceeded ? http.Response('{}', 429) : http.Response(jsonEncode({'documents': [_venueDoc(1)]}), 200, headers: _json);
      }
      return http.Response(jsonEncode({'documents': []}), 200, headers: _json);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const AlobookingApp());
      await _wait(tester);

      expect(find.textContaining('Không tải được danh sách sân'), findsOneWidget);
      expect(find.textContaining('hết lượt đọc dữ liệu'), findsOneWidget, reason: 'nói đúng nguyên nhân là hết hạn mức');
      expect(find.textContaining('kiểm tra mạng', findRichText: true), findsNothing, reason: 'không bảo người dùng kiểm tra mạng khi lỗi không phải do mạng');
      expect(venueReads, 1);

      quotaExceeded = false; // hạn mức đã được tính lại
      await tester.tap(find.text('Thử lại'));
      await _wait(tester);
      expect(venueReads, 2, reason: '"Thử lại" phải đọc lại từ máy chủ');
      expect(find.textContaining('Sân Thử Nghiệm 1'), findsWidgets);
    }, () => client);
  });

  testWidgets('Mất mạng: trang chủ nhắc kiểm tra mạng', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await http.runWithClient(() async {
      await tester.pumpWidget(const AlobookingApp());
      await _wait(tester);
      expect(find.textContaining('Không tải được danh sách sân'), findsOneWidget);
      expect(find.textContaining('kiểm tra mạng'), findsOneWidget);
    }, () => MockClient((r) async => throw const SocketException('mất mạng')));
  });

  testWidgets('Mở lại trang chủ trong 30 phút không đọc lại danh sách sân', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var venueReads = 0;
    final client = MockClient((r) async {
      if (r.method == 'GET' && r.url.path.endsWith('/venues')) {
        venueReads++;
        return http.Response(jsonEncode({'documents': [_venueDoc(1), _venueDoc(2)]}), 200, headers: _json);
      }
      return http.Response(jsonEncode({'documents': []}), 200, headers: _json);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const AlobookingApp());
      await _wait(tester);
      expect(venueReads, 1);
      expect(find.textContaining('Sân Thử Nghiệm 1'), findsWidgets);

      // đóng rồi mở lại (như vào lại trang chủ): dùng bản nhớ
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const AlobookingApp());
      await _wait(tester);
      expect(venueReads, 1, reason: 'mở lại không tốn thêm lượt đọc nào');
      expect(find.textContaining('Sân Thử Nghiệm 1'), findsWidgets);
    }, () => client);
  });
}
