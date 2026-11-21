import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Mặc định Flutter chỉ cho vuốt bằng ngón tay, còn chuột thì không kéo để cuộn được. Điều đó làm các dải
/// ngang (chip chọn môn, lọc, khung giờ...) bị cắt mép phải mà không có cách nào lướt tới trên máy tính
/// hay trong khung demo điện thoại. Hành vi này cho phép chuột, bàn di chuột và bút kéo để cuộn như ngón tay.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };
}

/// Cuộn bên trong khung điện thoại giả lập: giống máy thật, tức là không có thanh cuộn kiểu máy tính,
/// iPhone/iPad nảy ở mép còn Samsung thì dừng cứng.
class PhoneScrollBehavior extends AppScrollBehavior {
  /// true: vuốt kiểu iOS (nảy ở mép); false: kiểu Android.
  final bool ios;

  const PhoneScrollBehavior({this.ios = true});

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => ios ? const BouncingScrollPhysics() : const ClampingScrollPhysics();
}
