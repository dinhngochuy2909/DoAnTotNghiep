import 'package:flutter_test/flutter_test.dart';
import 'package:alobooking/services/payment_config.dart';

void main() {
  test('CRC-16/CCITT-FALSE đúng vector chuẩn "123456789" = 29B1', () {
    expect(PaymentConfig.crc16('123456789'), '29B1');
  });

  group('Payload VietQR', () {
    final payload = PaymentConfig.buildVietQr(
      bin: '970422',
      account: '0123456789',
      amount: 250000,
      content: 'BK123456',
    );

    test('có đủ các trường bắt buộc của chuẩn NAPAS 247', () {
      expect(payload, startsWith('000201010212'));
      expect(payload, contains('A000000727'));
      expect(payload, contains('0006970422'));
      expect(payload, contains('01100123456789'));
      expect(payload, contains('QRIBFTTA'));
      expect(payload, contains('5303704'));
      expect(payload, contains('5406250000'));
      expect(payload, contains('5802VN'));
      expect(payload, contains('0808BK123456'));
    });

    test('CRC ở cuối khớp với nội dung phía trước', () {
      final body = payload.substring(0, payload.length - 4);
      expect(body, endsWith('6304'));
      expect(payload.substring(payload.length - 4), PaymentConfig.crc16(body));
    });

    test('đổi số tiền thì mã CRC đổi theo', () {
      final other = PaymentConfig.buildVietQr(bin: '970422', account: '0123456789', amount: 260000, content: 'BK123456');
      expect(other.substring(other.length - 4), isNot(payload.substring(payload.length - 4)));
    });

    test('nội dung chuyển khoản bỏ dấu và ký tự đặc biệt', () {
      expect(PaymentConfig.transferContent('BK-123456'), 'BK123456');
      final p = PaymentConfig.buildVietQr(bin: '970422', account: '0123456789', amount: 1000, content: 'Đặt sân #1');
      expect(p, isNot(contains('Đ')));
    });
  });

  test('chưa khai báo tài khoản nhận tiền thì không dựng mã QR (không bịa tài khoản)', () {
    expect(PaymentConfig.configured, isFalse);
    expect(PaymentConfig.qrPayload(amount: 100000, content: 'BK1'), isNull);
  });

  test('kiểm tra định dạng BIN và số tài khoản', () {
    expect(PaymentConfig.isValidBin('970422'), isTrue);
    expect(PaymentConfig.isValidBin('9704'), isFalse);
    expect(PaymentConfig.isValidAccount('0123456789'), isTrue);
    expect(PaymentConfig.isValidAccount('12'), isFalse);
  });
}
