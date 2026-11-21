import '../data/venue_photos.dart';

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

  /// Số sân con của cụm (0 = chưa khai báo, dùng mặc định theo môn).
  final int courtCount;

  /// Nguồn dữ liệu của cụm sân: '' = do chủ sân/admin nhập; 'osm' = nhập từ OpenStreetMap;
  /// 'overture' = nhập từ Overture Maps (dữ liệu mở về địa điểm);
  /// 'demo' = sân minh họa do hệ thống tạo để trình diễn, KHÔNG phải cơ sở có thật.
  final String source;

  /// Lúc sân được duyệt lần đầu (null = không rõ, ví dụ sân nhập từ dữ liệu mở). Dùng để đưa "Sân mới" lên mục Khám phá.
  final DateTime? approvedAt;

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
    this.courtCount = 0,
    this.source = '',
    this.approvedAt,
  });

  /// Số sân con mặc định cho một cụm sân theo môn, dùng khi chủ sân chưa khai báo số sân thật.
  static int defaultCourtCount(String type) {
    switch (type) {
      case 'badminton':
        return 8;
      case 'pickleball':
        return 6;
      case 'football':
        return 4;
      case 'tennis':
        return 4;
      case 'basketball':
        return 2;
      default:
        return 4;
    }
  }

  /// Số sân con dùng để dựng sơ đồ đặt sân.
  int get courts => courtCount > 0 ? courtCount : defaultCourtCount(type);

  /// Tên gọi một sân con theo môn: "Cầu lông 1", "Pickleball 2", "Sân bóng 3"...
  static String courtLabel(String type) {
    switch (type) {
      case 'badminton':
        return 'Cầu lông';
      case 'pickleball':
        return 'Pickleball';
      case 'football':
        return 'Sân bóng';
      case 'tennis':
        return 'Tennis';
      case 'basketball':
        return 'Bóng rổ';
      default:
        return 'Sân';
    }
  }

  List<String> get courtNames => [for (var i = 1; i <= courts; i++) '${courtLabel(type)} $i'];

  /// Giá có dạng "100k - 200k/h" thì mới đặt online được; "Liên hệ" hay để trống thì chưa niêm yết giá.
  bool get hasListedPrice => RegExp(r'\d+\s*k\s*-\s*\d+\s*k', caseSensitive: false).hasMatch(price);

  bool get fromOpenStreetMap => source == 'osm';

  /// Sân nhập từ dữ liệu mở (OpenStreetMap hoặc Overture Maps): giá, giờ mở cửa và số sân chỉ là mức tham khảo,
  /// chưa được cơ sở xác nhận trên AloBooking.
  bool get isImportedListing => source == 'osm' || source == 'overture';

  /// Sân minh họa (dữ liệu demo): không phải cơ sở có thật nên không cho đặt/thanh toán.
  bool get isDemo => source == 'demo';

  /// Ảnh để hiển thị: sân chưa có ảnh thì dùng một ảnh minh họa đúng môn (ổn định theo id).
  String get displayImage => image.trim().isNotEmpty ? image : VenuePhotos.forVenue(type, id);

  /// Ảnh đang hiển thị là ảnh minh họa (kho Pexels/Unsplash), không phải ảnh thật do chủ sân đăng.
  bool get hasStockImage => VenuePhotos.isStock(displayImage);

  /// Điểm đánh giá để hiển thị: chưa có đánh giá thì ghi "Mới" thay vì số giả.
  String get ratingLabel => rating > 0 ? rating.toStringAsFixed(1) : 'Mới';

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
    int? courtCount,
    String? source,
    DateTime? approvedAt,
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
      courtCount: courtCount ?? this.courtCount,
      source: source ?? this.source,
      approvedAt: approvedAt ?? this.approvedAt,
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
      courtCount: (json['courtCount'] as num?)?.toInt() ?? 0,
      source: json['source'] ?? '',
      approvedAt: DateTime.tryParse((json['approvedAt'] ?? '').toString()),
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
      'courtCount': courtCount,
      'source': source,
      if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
    };
  }
}
