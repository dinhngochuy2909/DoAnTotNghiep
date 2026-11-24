import 'package:flutter/material.dart';
import '../models/venue.dart';

class GoogleMapViewWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Text(
          'Bản đồ Google Maps chỉ hỗ trợ trên nền tảng Web',
          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

void openMapInNewTab() {}

void triggerLocateUser() {}
