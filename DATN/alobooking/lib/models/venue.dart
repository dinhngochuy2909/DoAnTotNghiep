class Venue {
  final int id;
  final String name;
  final String type; // 'pickleball', 'badminton', 'football', 'tennis'
  final String district;
  final String distance;
  final String address;
  final String hours;
  final List<String> tags;
  final double rating;
  final String price;
  final double lat;
  final double lng;
  final String image;
  final String logo;
  final String ownerId;
  final String ownerName;
  final String approvalStatus; // 'approved' | 'pending' | 'rejected'
  final String rejectReason;

  Venue({
    required this.id,
    required this.name,
    required this.type,
    required this.district,
    required this.distance,
    required this.address,
    required this.hours,
    required this.tags,
    required this.rating,
    required this.price,
    required this.lat,
    required this.lng,
    required this.image,
    required this.logo,
    this.ownerId = 'admin_super_01',
    this.ownerName = 'Hệ Thống Alobooking',
    this.approvalStatus = 'approved',
    this.rejectReason = '',
  });

  bool get isApproved => approvalStatus == 'approved';
  bool get isPending => approvalStatus == 'pending';
  bool get isRejected => approvalStatus == 'rejected';

  Venue copyWith({
    int? id,
    String? name,
    String? type,
    String? district,
    String? distance,
    String? address,
    String? hours,
    List<String>? tags,
    double? rating,
    String? price,
    double? lat,
    double? lng,
    String? image,
    String? logo,
    String? ownerId,
    String? ownerName,
    String? approvalStatus,
    String? rejectReason,
  }) {
    return Venue(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      district: district ?? this.district,
      distance: distance ?? this.distance,
      address: address ?? this.address,
      hours: hours ?? this.hours,
      tags: tags ?? this.tags,
      rating: rating ?? this.rating,
      price: price ?? this.price,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      image: image ?? this.image,
      logo: logo ?? this.logo,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      rejectReason: rejectReason ?? this.rejectReason,
    );
  }

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? 'badminton',
      district: json['district'] ?? '',
      distance: json['distance'] ?? '',
      address: json['address'] ?? '',
      hours: json['hours'] ?? '06:00 – 23:00',
      tags: List<String>.from(json['tags'] ?? []),
      rating: (json['rating'] ?? 4.5).toDouble(),
      price: json['price'] ?? '',
      lat: (json['lat'] ?? 21.0).toDouble(),
      lng: (json['lng'] ?? 105.8).toDouble(),
      image: json['image'] ?? '',
      logo: json['logo'] ?? '',
      ownerId: json['ownerId'] ?? 'admin_super_01',
      ownerName: json['ownerName'] ?? 'Hệ Thống Alobooking',
      approvalStatus: json['approvalStatus'] ?? 'approved',
      rejectReason: json['rejectReason'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'district': district,
      'distance': distance,
      'address': address,
      'hours': hours,
      'tags': tags,
      'rating': rating,
      'price': price,
      'lat': lat,
      'lng': lng,
      'image': image,
      'logo': logo,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'approvalStatus': approvalStatus,
      'rejectReason': rejectReason,
    };
  }
}
