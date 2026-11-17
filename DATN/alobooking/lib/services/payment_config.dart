/// Thông tin tài khoản nhận tiền và mã QR chuyển khoản VietQR (chuẩn NAPAS 247).
///
/// Ứng dụng chỉ nhận thanh toán bằng chuyển khoản. Tài khoản nhận tiền KHÔNG ghi trong mã nguồn:
/// khai báo trong `dart_defines.json` (đã nằm trong .gitignore) rồi chạy với
/// `--dart-define-from-file=dart_defines.json`. Xem `dart_defines.example.json`.
class PaymentConfig {
  /// Mã BIN ngân hàng 6 số theo NAPAS (ví dụ Vietcombank 970436, MB 970422, Techcombank 970407).
  static const bankBin = String.fromEnvironment('PAY_BANK_BIN');
  static const bankName = String.fromEnvironment('PAY_BANK_NAME');
  static const accountNo = String.fromEnvironment('PAY_ACCOUNT_NO');
  static const accountName = String.fromEnvironment('PAY_ACCOUNT_NAME');

  /// Đã khai báo đủ tài khoản nhận tiền chưa.
  static bool get configured => isValidBin(bankBin) && isValidAccount(accountNo);

  static bool isValidBin(String s) => RegExp(r'^\d{6}$').hasMatch(s);
  static bool isValidAccount(String s) => RegExp(r'^[0-9A-Za-z]{6,19}$').hasMatch(s);

  /// Nội dung chuyển khoản gắn với mã đơn: "BK-123456" -> "BK123456" (ngân hàng thường bỏ ký tự đặc biệt).
  static String transferContent(String bookingCode) =>
      bookingCode.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');

  /// Chuỗi payload VietQR để vẽ thành mã QR. Trả về null nếu chưa cấu hình tài khoản nhận tiền.
  static String? qrPayload({required int amount, required String content}) {
    if (!configured) return null;
    return buildVietQr(bin: bankBin, account: accountNo, amount: amount, content: content);
  }

  /// Dựng payload VietQR (EMVCo) cho chuyển khoản nhanh 24/7 tới số tài khoản.
  static String buildVietQr({
    required String bin,
    required String account,
    required int amount,
    required String content,
  }) {
    String tlv(String id, String value) => '$id${value.length.toString().padLeft(2, '0')}$value';
    final info = tlv('00', 'A000000727') + tlv('01', tlv('00', bin) + tlv('01', account)) + tlv('02', 'QRIBFTTA');
    final safe = content.replaceAll(RegExp(r'[^0-9A-Za-z \-]'), '');
    final body = StringBuffer()
      ..write(tlv('00', '01'))
      ..write(tlv('01', amount > 0 ? '12' : '11'))
      ..write(tlv('38', info))
      ..write(tlv('53', '704'))
      ..write(amount > 0 ? tlv('54', amount.toString()) : '')
      ..write(tlv('58', 'VN'))
      ..write(safe.isEmpty ? '' : tlv('62', tlv('08', safe)))
      ..write('6304');
    final text = body.toString();
    return '$text${crc16(text)}';
  }

  /// CRC-16/CCITT-FALSE (đa thức 0x1021, khởi tạo 0xFFFF) viết hoa 4 ký tự hex.
  static String crc16(String data) {
    var crc = 0xFFFF;
    for (final unit in data.codeUnits) {
      crc ^= (unit & 0xFF) << 8;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
