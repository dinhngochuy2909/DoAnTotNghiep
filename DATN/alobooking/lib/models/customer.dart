class CustomerItem {
  final String id;
  String name;
  String phone;
  String email;
  int bookingsCount;
  String totalSpent;
  String favoriteSport;
  String rank; // 'VIP Kim Cương' | 'VIP Vàng' | 'Bạc' | 'Đồng'
  String status; // 'Hoạt động' | 'Tạm khóa'
  final String joinDate;

  CustomerItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.bookingsCount = 0,
    this.totalSpent = '0đ',
    this.favoriteSport = 'Cầu lông',
    this.rank = 'Đồng',
    this.status = 'Hoạt động',
    required this.joinDate,
  });

  CustomerItem copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    int? bookingsCount,
    String? totalSpent,
    String? favoriteSport,
    String? rank,
    String? status,
    String? joinDate,
  }) {
    return CustomerItem(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      bookingsCount: bookingsCount ?? this.bookingsCount,
      totalSpent: totalSpent ?? this.totalSpent,
      favoriteSport: favoriteSport ?? this.favoriteSport,
      rank: rank ?? this.rank,
      status: status ?? this.status,
      joinDate: joinDate ?? this.joinDate,
    );
  }
}

