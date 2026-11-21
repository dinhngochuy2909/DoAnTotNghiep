import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alobooking/models/venue.dart';
import 'package:alobooking/services/firestore_service.dart';

Venue _venue({DateTime? approvedAt}) => Venue(
      id: 77,
      name: 'Sân Thử',
      type: 'badminton',
      district: 'Cầu Giấy',
      distance: '',
      address: '1 Phố Thử',
      hours: '06:00 – 22:00',
      tags: const [],
      rating: 0,
      price: '80k - 100k/h',
      lat: 21.0,
      lng: 105.8,
      image: '',
      logo: '',
      courtCount: 3,
      source: '',
      approvedAt: approvedAt,
    );

void main() {
  final at = DateTime(2026, 11, 20, 9, 30);

  test('Duyệt sân ghi kèm ngày duyệt và đưa approvedAt vào updateMask', () async {
    http.Request? seen;
    final ok = await http.runWithClient(
      () => FirestoreService.updateVenueApproval(77, 'approved', '', at),
      () => MockClient((r) async {
        seen = r;
        return http.Response('{}', 200);
      }),
    );
    expect(ok, isTrue);
    expect(seen!.method, 'PATCH');
    expect(seen!.url.query, contains('updateMask.fieldPaths=approvalStatus'));
    expect(seen!.url.query, contains('updateMask.fieldPaths=approvedAt'));
    final f = jsonDecode(seen!.body)['fields'] as Map<String, dynamic>;
    expect(f['approvalStatus']['stringValue'], 'approved');
    expect(DateTime.parse(f['approvedAt']['stringValue']), at);
  });

  test('Từ chối sân hoặc duyệt không kèm ngày thì không đụng tới approvedAt', () async {
    final seen = <http.Request>[];
    await http.runWithClient(() async {
      await FirestoreService.updateVenueApproval(77, 'rejected', 'Thiếu giấy phép', at);
      await FirestoreService.updateVenueApproval(77, 'approved');
    }, () => MockClient((r) async {
          seen.add(r);
          return http.Response('{}', 200);
        }));
    expect(seen, hasLength(2));
    for (final r in seen) {
      expect(r.url.query, isNot(contains('approvedAt')));
      expect((jsonDecode(r.body)['fields'] as Map).containsKey('approvedAt'), isFalse);
    }
  });

  test('Sửa sân giữ ngày duyệt; sân chưa có ngày thì không ghi trường này', () async {
    final bodies = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await FirestoreService.updateVenue(_venue(approvedAt: at));
      await FirestoreService.updateVenue(_venue());
      await FirestoreService.addVenue(_venue(approvedAt: at));
    }, () => MockClient((r) async {
          bodies.add((jsonDecode(r.body)['fields'] as Map).cast<String, dynamic>());
          return http.Response('{}', 200);
        }));
    expect(DateTime.parse(bodies[0]['approvedAt']['stringValue']), at);
    expect(bodies[1].containsKey('approvedAt'), isFalse);
    expect(DateTime.parse(bodies[2]['approvedAt']['stringValue']), at);
    expect(bodies[0]['courtCount']['integerValue'], '3');
  });

  test('Tải sân đọc lại ngày duyệt; sân cũ không có trường này thì để trống', () async {
    Map<String, dynamic> doc(int id, {String? approvedAt}) => {
          'name': 'projects/x/databases/(default)/documents/venues/$id',
          'fields': {
            'id': {'integerValue': '$id'},
            'name': {'stringValue': 'Sân $id'},
            if (approvedAt != null) 'approvedAt': {'stringValue': approvedAt},
          },
        };
    final venues = await http.runWithClient(
      () => FirestoreService.getVenues(),
      () => MockClient((r) async => http.Response(
            jsonEncode({'documents': [doc(1, approvedAt: '2026-11-20T09:30:00.000'), doc(2)]}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );
    expect(venues.map((v) => v.id), [1, 2]);
    expect(venues[0].approvedAt, DateTime(2026, 11, 20, 9, 30));
    expect(venues[1].approvedAt, isNull);
  });
}
