import 'dart:async';
import 'dart:convert';
// TODO: chuyển sang package:web + dart:js_interop (dart:html đã bị đánh dấu lỗi thời)
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import '../models/venue.dart';

bool _isViewRegistered = false;

/// Được gọi khi trang bản đồ (iframe) tải xong, để gửi danh sách sân sang ngay.
void Function()? _onMapFrameLoaded;

/// Chỉ gửi sang bản đồ những trường cần thiết (nhẹ hơn nhiều so với toJson đầy đủ, nhất là khi sân có ảnh dạng base64).
Map<String, dynamic> _mapJson(Venue v) => {
      'id': v.id,
      'name': v.name,
      'type': v.type,
      'district': v.district,
      'address': v.address,
      'hours': v.hours,
      'price': v.price,
      'rating': v.rating,
      'lat': v.lat,
      'lng': v.lng,
      // ảnh dạng base64 không đưa sang bản đồ; thẻ sân sẽ dùng ảnh minh họa theo môn
      'image': v.displayImage.startsWith('http') ? v.displayImage : '',
    };

class VenueMapViewWidget extends StatefulWidget {
  final List<Venue> venues;
  final String selectedType;
  final Function(int venueId)? onVenueSelected;
  final Function(int venueId)? onBookVenue;
  final Function(String sport)? onFilterChanged;
  final Function(double lat, double lng)? onUserLocated;

  const VenueMapViewWidget({
    super.key,
    required this.venues,
    this.selectedType = 'all',
    this.onVenueSelected,
    this.onBookVenue,
    this.onFilterChanged,
    this.onUserLocated,
  });

  @override
  State<VenueMapViewWidget> createState() => _VenueMapViewWidgetState();
}

class _VenueMapViewWidgetState extends State<VenueMapViewWidget> {
  StreamSubscription? _messageSub;
  final String _viewId = 'alobooking-venue-map';

  @override
  void initState() {
    super.initState();
    _registerView();
    _saveVenuesToLocalStorage();
    _listenToMapMessages();
    _onMapFrameLoaded = _sendVenuesToIframe;
  }

  void _registerView() {
    if (!_isViewRegistered) {
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int id) {
          final iframe = html.IFrameElement()
            ..src = 'map.html'
            ..id = 'venue-map-frame'
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..allow = 'geolocation *; fullscreen *';
          // Trước đây không bao giờ gửi danh sách sân sang trang bản đồ, nên bản đồ chỉ hiện sân mẫu cố định
          iframe.onLoad.listen((_) => _onMapFrameLoaded?.call());
          return iframe;
        },
      );
      _isViewRegistered = true;
    }
  }

  void _saveVenuesToLocalStorage() {
    try {
      final list = widget.venues.map(_mapJson).toList();
      html.window.localStorage['alobooking_venues'] = jsonEncode(list);
    } catch (e) {
      debugPrint('Error saving venues to localStorage: $e');
    }
  }

  void _listenToMapMessages() {
    _messageSub = html.window.onMessage.listen((event) {
      final data = event.data;
      if (data == null) return;

      try {
        final type = data['type'];
        if (type == 'VENUE_SELECTED') {
          final venueId = data['venueId'];
          if (venueId != null && widget.onVenueSelected != null) {
            widget.onVenueSelected!(venueId as int);
          }
        } else if (type == 'BOOK_VENUE') {
          final venueId = data['venueId'];
          if (venueId != null && widget.onBookVenue != null) {
            widget.onBookVenue!(venueId as int);
          }
        } else if (type == 'FILTER_CHANGED') {
          final sport = data['sport'];
          if (sport != null && widget.onFilterChanged != null) {
            widget.onFilterChanged!(sport as String);
          }
        } else if (type == 'REQUEST_VENUES') {
          _sendVenuesToIframe();
        } else if (type == 'USER_LOCATED') {
          final lat = (data['lat'] as num?)?.toDouble();
          final lng = (data['lng'] as num?)?.toDouble();
          if (lat != null && lng != null && widget.onUserLocated != null) {
            widget.onUserLocated!(lat, lng);
          }
        }
      } catch (e) {
        debugPrint('Error handling map message: $e');
      }
    });
  }

  void _sendVenuesToIframe() {
    try {
      final iframe = html.document.getElementById('venue-map-frame') as html.IFrameElement?;
      if (iframe != null && iframe.contentWindow != null) {
        final list = widget.venues.map(_mapJson).toList();
        iframe.contentWindow!.postMessage({'type': 'SET_VENUES', 'venues': list}, '*');
      }
    } catch (e) {
      debugPrint('Error sending venues to iframe: $e');
    }
  }

  @override
  void didUpdateWidget(covariant VenueMapViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.venues, widget.venues) || oldWidget.venues.length != widget.venues.length) {
      // Danh sách sân thay đổi (vừa tải xong, thêm/sửa sân): cập nhật lại ghim trên bản đồ
      _saveVenuesToLocalStorage();
      _sendVenuesToIframe();
    }
    if (oldWidget.selectedType != widget.selectedType) {
      _sendFilterToIframe(widget.selectedType);
    }
  }

  void _sendFilterToIframe(String sport) {
    try {
      final iframe = html.document.getElementById('venue-map-frame') as html.IFrameElement?;
      if (iframe != null && iframe.contentWindow != null) {
        iframe.contentWindow!.postMessage({'type': 'FILTER_SPORT', 'sport': sport}, '*');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _onMapFrameLoaded = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}

void openMapInNewTab() {
  html.window.open('map.html', '_blank');
}

void triggerLocateUser() {
  try {
    final iframe = html.document.getElementById('venue-map-frame') as html.IFrameElement?;
    if (iframe != null && iframe.contentWindow != null) {
      iframe.contentWindow!.postMessage({'type': 'LOCATE_USER'}, '*');
    }
  } catch (_) {}
}
