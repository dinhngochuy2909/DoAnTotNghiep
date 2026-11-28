import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final index = File('web/index.html').readAsStringSync();
  final map = File('web/map.html').readAsStringSync();

  test('Trang web không chứa khóa API và không nạp Google Maps', () {
    for (final page in [index, map]) {
      expect(page, isNot(contains('AIza')));
      expect(page, isNot(contains('maps.googleapis.com')));
    }
  });

  test('Bản đồ dùng ảnh nền OpenStreetMap và luôn ghi nguồn', () {
    expect(map, contains('https://tile.openstreetmap.org/{z}/{x}/{y}.png'));
    expect(map, contains('openstreetmap.org/copyright'));
  });

  test('Ứng dụng nạp đúng tệp bản đồ', () {
    final dart = File('lib/widgets/web_map_view_web.dart').readAsStringSync();
    expect(dart, contains("'map.html'"));
    expect(File('web/google_map.html').existsSync(), isFalse);
  });
}
