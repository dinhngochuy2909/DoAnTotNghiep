import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import '../models/venue.dart';

bool _isViewRegistered = false;

class GoogleMapViewWidget extends StatefulWidget {
  final List<Venue> venues;
  final String selectedType;
  final Function(int venueId)? onVenueSelected;
  final Function(int venueId)? onBookVenue;
  final Function(String sport)? onFilterChanged;
  final Function(double lat, double lng)? onUserLocated;

  const GoogleMapViewWidget({
    super.key,
    required this.venues,
    this.selectedType = 'all',
    this.onVenueSelected,
    this.onBookVenue,
    this.onFilterChanged,
    this.onUserLocated,
  });

  @override
  State<GoogleMapViewWidget> createState() => _GoogleMapViewWidgetState();
}

class _GoogleMapViewWidgetState extends State<GoogleMapViewWidget> {
  StreamSubscription? _messageSub;
  final String _viewId = 'alobooking-google-map';

  @override
  void initState() {
    super.initState();
    _registerView();
    _saveVenuesToLocalStorage();
    _listenToMapMessages();
  }

  void _registerView() {
    if (!_isViewRegistered) {
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int id) {
          final iframe = html.IFrameElement()
            ..src = 'google_map.html'
            ..id = 'google-maps-frame'
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..allow = 'geolocation *; fullscreen *';
          return iframe;
        },
      );
      _isViewRegistered = true;
    }
  }

  void _saveVenuesToLocalStorage() {
    try {
      final list = widget.venues.map((v) => v.toJson()).toList();
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
      final iframe = html.document.getElementById('google-maps-frame') as html.IFrameElement?;
      if (iframe != null && iframe.contentWindow != null) {
        final list = widget.venues.map((v) => v.toJson()).toList();
        iframe.contentWindow!.postMessage({'type': 'SET_VENUES', 'venues': list}, '*');
      }
    } catch (e) {
      debugPrint('Error sending venues to iframe: $e');
    }
  }

  @override
  void didUpdateWidget(covariant GoogleMapViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedType != widget.selectedType) {
      _sendFilterToIframe(widget.selectedType);
    }
  }

  void _sendFilterToIframe(String sport) {
    try {
      final iframe = html.document.getElementById('google-maps-frame') as html.IFrameElement?;
      if (iframe != null && iframe.contentWindow != null) {
        iframe.contentWindow!.postMessage({'type': 'FILTER_SPORT', 'sport': sport}, '*');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}

void openMapInNewTab() {
  html.window.open('google_map.html', '_blank');
}

void triggerLocateUser() {
  try {
    final iframe = html.document.getElementById('google-maps-frame') as html.IFrameElement?;
    if (iframe != null && iframe.contentWindow != null) {
      iframe.contentWindow!.postMessage({'type': 'LOCATE_USER'}, '*');
    }
  } catch (_) {}
}
