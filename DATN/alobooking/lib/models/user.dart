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

  bool get isAdmin => role == 'admin' || email.toLowerCase().contains('admin') || email.toLowerCase().contains('dinhngochuy');
  bool get isOwner => role == 'owner' || role == 'court_owner' || role == 'manager' || email.toLowerCase().contains('chusan');
  bool get isGuest => role == 'guest' || role == 'viewer' || email.toLowerCase().contains('guest') || email.toLowerCase().contains('khachxem');
  bool get canBook => !isGuest;

  factory AppUser.fromFirestoreFields(String docId, Map<String, dynamic> fields) {
    final email = fields['email']?['stringValue'] ?? '';
    final rawRole = fields['role']?['stringValue'] ?? '';
    final role = rawRole.isNotEmpty
        ? rawRole
        : (email.toLowerCase().contains('admin') || email.toLowerCase().contains('dinhngochuy')
            ? 'admin'
            : (email.toLowerCase().contains('chusan') || email.toLowerCase().contains('manager')
                ? 'owner'
                : (email.toLowerCase().contains('guest') || email.toLowerCase().contains('khachxem')
                    ? 'guest'
                    : 'customer')));
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
      role: json['role'] ??
          (email.toLowerCase().contains('admin')
              ? 'admin'
              : (email.toLowerCase().contains('chusan')
                  ? 'owner'
                  : (email.toLowerCase().contains('guest') || email.toLowerCase().contains('khachxem')
                      ? 'guest'
                      : 'customer'))),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
