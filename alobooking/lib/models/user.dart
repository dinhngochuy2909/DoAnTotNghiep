class AppUser {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String avatarUrl;
  final String role; // 'admin' | 'customer'
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    this.avatarUrl = '',
    this.role = 'customer',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Quyền chỉ dựa vào vai trò được lưu (role), KHÔNG suy ra từ địa chỉ email:
  // nếu không, ai đăng ký email có chữ "admin" cũng thành quản trị viên.
  bool get isAdmin => role == 'admin';
  bool get isOwner => role == 'owner' || role == 'court_owner' || role == 'manager';
  bool get isGuest => role == 'guest' || role == 'viewer';
  bool get canBook => !isGuest;

  factory AppUser.fromFirestoreFields(String docId, Map<String, dynamic> fields) {
    final email = fields['email']?['stringValue'] ?? '';
    // Vai trò chỉ lấy từ trường `role` đã lưu; thiếu thì là khách hàng thường.
    // Tuyệt đối không đoán từ email (ai đăng ký email có chữ "admin" sẽ thành quản trị viên).
    final rawRole = fields['role']?['stringValue'] ?? '';
    final role = rawRole.isNotEmpty ? rawRole : 'customer';
    return AppUser(
      uid: docId,
      fullName: fields['fullName']?['stringValue'] ?? fields['displayName']?['stringValue'] ?? '',
      email: email,
      phone: fields['phone']?['stringValue'] ?? '',
      avatarUrl: fields['avatarUrl']?['stringValue'] ?? fields['avatar']?['stringValue'] ?? '',
      role: role,
      createdAt: DateTime.tryParse(
            fields['createdAt']?['stringValue'] ?? '',
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestoreFields() {
    return {
      'fullName': {'stringValue': fullName},
      'email': {'stringValue': email},
      'phone': {'stringValue': phone},
      'avatarUrl': {'stringValue': avatarUrl},
      'role': {'stringValue': role},
      'createdAt': {'stringValue': createdAt.toIso8601String()},
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final email = json['email'] ?? '';
    return AppUser(
      uid: json['uid'] ?? '',
      fullName: json['fullName'] ?? '',
      email: email,
      phone: json['phone'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      // Giống fromFirestoreFields: thiếu vai trò thì là khách hàng thường, không đoán từ email.
      role: (json['role'] as String?)?.isNotEmpty == true ? json['role'] as String : 'customer',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
