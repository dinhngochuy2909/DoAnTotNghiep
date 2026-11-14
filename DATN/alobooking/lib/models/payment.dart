class PaymentItem {
  final String id;
  final String bookingId;
  final String customer;
  final String amount;
  final String method; // 'VietQR Pro' | 'Ví MoMo' | 'VNPay QR' | 'Tiền mặt'
  final String time;
  String status; // 'Thành công' | 'Đang xử lý' | 'Đã hoàn tiền'
  final String bankRef;

  PaymentItem({
    required this.id,
    required this.bookingId,
    required this.customer,
    required this.amount,
    required this.method,
    required this.time,
    required this.status,
    required this.bankRef,
  });

  PaymentItem copyWith({
    String? id,
    String? bookingId,
    String? customer,
    String? amount,
    String? method,
    String? time,
    String? status,
    String? bankRef,
  }) {
    return PaymentItem(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      customer: customer ?? this.customer,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      time: time ?? this.time,
      status: status ?? this.status,
      bankRef: bankRef ?? this.bankRef,
    );
  }

  factory PaymentItem.fromFirestoreFields(String docId, Map<String, dynamic> fields) {
    return PaymentItem(
      id: fields['id']?['stringValue'] ?? docId,
      bookingId: fields['bookingId']?['stringValue'] ?? '',
      customer: fields['customer']?['stringValue'] ?? '',
      amount: fields['amount']?['stringValue'] ?? '0đ',
      method: fields['method']?['stringValue'] ?? 'VietQR Pro',
      time: fields['time']?['stringValue'] ?? '',
      status: fields['status']?['stringValue'] ?? 'Thành công',
      bankRef: fields['bankRef']?['stringValue'] ?? '',
    );
  }

  Map<String, dynamic> toFirestoreFields() {
    return {
      'id': {'stringValue': id},
      'bookingId': {'stringValue': bookingId},
      'customer': {'stringValue': customer},
      'amount': {'stringValue': amount},
      'method': {'stringValue': method},
      'time': {'stringValue': time},
      'status': {'stringValue': status},
      'bankRef': {'stringValue': bankRef},
      'createdAt': {'stringValue': DateTime.now().toIso8601String()},
    };
  }
}

