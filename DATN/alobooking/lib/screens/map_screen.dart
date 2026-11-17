import '../widgets/venue_image_view.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../widgets/web_map_view.dart';
import 'visual_booking_screen.dart';

/// Màn hình BẢN ĐỒ — hiển thị sân trên Google Maps & định vị GPS người dùng
class MapScreen extends StatefulWidget {
  final List<Venue> venues;
  const MapScreen({super.key, required this.venues});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Venue? _selectedVenue;
  String _selectedType = 'all';
  bool _isFullScreenMap = false;
  double? _userLat;
  double? _userLng;

  final List<Map<String, dynamic>> _typeFilters = [
    {'key': 'all', 'label': 'Tất cả', 'emoji': '🏆', 'icon': Icons.sports},
    {'key': 'badminton', 'label': 'Cầu lông', 'emoji': '🏸', 'icon': Icons.sports},
    {'key': 'pickleball', 'label': 'Pickleball', 'emoji': '🏓', 'icon': Icons.sports_tennis},
    {'key': 'football', 'label': 'Bóng đá', 'emoji': '⚽', 'icon': Icons.sports_soccer},
    {'key': 'tennis', 'label': 'Tennis', 'emoji': '🎾', 'icon': Icons.sports_tennis},
  ];

  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  String _formatDistance(double km) {
    if (km < 1.0) {
      return '${(km * 1000).round()} m';
    } else {
      return '${km.toStringAsFixed(1)} km';
    }
  }

  List<Venue> get _filteredVenues {
    var list = _selectedType == 'all'
        ? List<Venue>.from(widget.venues)
        : widget.venues.where((v) => v.type == _selectedType).toList();

    if (_userLat != null && _userLng != null) {
      list.sort((a, b) {
        final distA = _calculateDistanceKm(_userLat!, _userLng!, a.lat, a.lng);
        final distB = _calculateDistanceKm(_userLat!, _userLng!, b.lat, b.lng);
        return distA.compareTo(distB);
      });
    }
    return list;
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'football':
        return const Color(0xFF15803D);
      case 'tennis':
        return const Color(0xFF0284C7);
      case 'pickleball':
        return const Color(0xFF7C3AED);
      case 'basketball':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF047857);
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'football':
        return '⚽ Bóng đá';
      case 'tennis':
        return '🎾 Tennis';
      case 'pickleball':
        return '🏓 Pickleball';
      case 'basketball':
        return '🏀 Bóng rổ';
      default:
        return '🏸 Cầu lông';
    }
  }

  String _typeEmoji(String type) {
    switch (type) {
      case 'football':
        return '⚽';
      case 'tennis':
        return '🎾';
      case 'pickleball':
        return '🏓';
      case 'basketball':
        return '🏀';
      default:
        return '🏸';
    }
  }

  void _onVenueSelected(int venueId) {
    final v = widget.venues.where((item) => item.id == venueId).firstOrNull;
    if (v != null) {
      setState(() => _selectedVenue = v);
    }
  }

  void _onBookVenue(int venueId) {
    final v = widget.venues.where((item) => item.id == venueId).firstOrNull;
    if (v != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VisualBookingScreen(venue: v)),
      );
    }
  }

  void _locateUserNow() {
    triggerLocateUser();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎯 Đang kích hoạt định vị GPS... Vui lòng cho phép quyền vị trí trên trình duyệt!'),
        backgroundColor: Color(0xFF15803D),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15803D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bản đồ sân thể thao',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              _userLat != null
                  ? '📍 Đã định vị vị trí của bạn'
                  : 'Google Maps API • ${widget.venues.length} điểm sân sẵn sàng',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          // GPS Location Action Button
          IconButton(
            tooltip: 'Định vị vị trí của tôi (GPS)',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _userLat != null ? const Color(0xFF22C55E) : Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.my_location_rounded, size: 18, color: Colors.white),
            ),
            onPressed: _locateUserNow,
          ),
          IconButton(
            tooltip: 'Mở bản đồ tab riêng',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: openMapInNewTab,
          ),
          IconButton(
            tooltip: _isFullScreenMap ? 'Thu nhỏ bản đồ' : 'Bản đồ toàn màn hình',
            icon: Icon(_isFullScreenMap ? Icons.view_agenda_outlined : Icons.fullscreen),
            onPressed: () => setState(() => _isFullScreenMap = !_isFullScreenMap),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          _buildTypeFilter(),

          // Main View (Full Map or Split Map + List)
          Expanded(
            child: _isFullScreenMap
                ? _buildMapSection()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 3, child: _buildMapSection()),
                            Expanded(flex: 2, child: _buildVenueList()),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 380,
                              child: _buildMapSection(),
                            ),
                            Expanded(child: _buildVenueList()),
                          ],
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
      // Floating Action Button for GPS
      floatingActionButton: _isFullScreenMap
          ? FloatingActionButton.extended(
              onPressed: _locateUserNow,
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Vị trí của tôi', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  Widget _buildTypeFilter() {
    return Container(
      color: Colors.white,
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _typeFilters.length,
        itemBuilder: (ctx, i) {
          final f = _typeFilters[i];
          final selected = _selectedType == f['key'];
          return GestureDetector(
            onTap: () => setState(() => _selectedType = f['key'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF16A34A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? const Color(0xFF15803D) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    f['emoji'] as String,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    f['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFE2E8F0),
      child: GoogleMapViewWidget(
        venues: widget.venues,
        selectedType: _selectedType,
        onVenueSelected: _onVenueSelected,
        onBookVenue: _onBookVenue,
        onUserLocated: (lat, lng) {
          setState(() {
            _userLat = lat;
            _userLng = lng;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '📍 Đã xác định vị trí của bạn: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)} • Đang hiển thị các sân từ gần đến xa nhất!',
              ),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 3),
            ),
          );
        },
        onFilterChanged: (sport) {
          setState(() => _selectedType = sport);
        },
      ),
    );
  }

  Widget _buildVenueList() {
    return Column(
      children: [
        // GPS Active Banner if user is located
        if (_userLat != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF15803D), Color(0xFF16A34A)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16A34A).withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.my_location_rounded, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đã định vị vị trí của bạn',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Tọa độ: ${_userLat!.toStringAsFixed(4)}, ${_userLng!.toStringAsFixed(4)} • Sắp xếp gần nhất',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _userLat = null;
                      _userLng = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Bỏ lọc',
                    style: TextStyle(fontSize: 11, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: _filteredVenues.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'Không tìm thấy sân phù hợp',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredVenues.length,
                  itemBuilder: (ctx, i) => _buildMapVenueCard(_filteredVenues[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildMapVenueCard(Venue v) {
    final isSelected = _selectedVenue?.id == v.id;
    final color = _typeColor(v.type);

    String? distanceStr;
    if (_userLat != null && _userLng != null) {
      final km = _calculateDistanceKm(_userLat!, _userLng!, v.lat, v.lng);
      distanceStr = _formatDistance(km);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? const Color(0xFF16A34A).withOpacity(0.12) : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() => _selectedVenue = v);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      VenueImageView(
                        imageUrl: v.image,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            _typeLabel(v.type),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      if (distanceStr != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.near_me_rounded, size: 10, color: Color(0xFF15803D)),
                              const SizedBox(width: 3),
                              Text(
                                'Cách bạn $distanceStr',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Text(
                            _typeEmoji(v.type),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              v.address.isNotEmpty ? v.address : v.district,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 2),
                          Text(
                            v.ratingLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF059669)),
                          const SizedBox(width: 3),
                          Text(
                            v.hours,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            v.price,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => VisualBookingScreen(venue: v)),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Đặt sân',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
