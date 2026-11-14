class NotificationItem {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // 'venue_approval' | 'booking' | 'payment' | 'system'
  bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.type = 'system',
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory NotificationItem.fromFirestoreFields(String docId, Map<String, dynamic> fields) {
    return NotificationItem(
      id: fields['id']?['stringValue'] ?? docId,
      userId: fields['userId']?['stringValue'] ?? '',
      title: fields['title']?['stringValue'] ?? '',
      message: fields['message']?['stringValue'] ?? '',
      type: fields['type']?['stringValue'] ?? 'system',
      isRead: fields['isRead']?['booleanValue'] ?? false,
      createdAt: DateTime.tryParse(fields['createdAt']?['stringValue'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestoreFields() {
    return {
      'id': {'stringValue': id},
      'userId': {'stringValue': userId},
      'title': {'stringValue': title},
      'message': {'stringValue': message},
      'type': {'stringValue': type},
      'isRead': {'booleanValue': isRead},
      'createdAt': {'stringValue': createdAt.toIso8601String()},
    };
  }
}

