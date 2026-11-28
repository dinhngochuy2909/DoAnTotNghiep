import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/navigator_key.dart';
import 'widgets/app_scroll_behavior.dart';
import 'widgets/device_simulator_wrapper.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlobookingApp());
}

class AlobookingApp extends StatelessWidget {
  const AlobookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Alobooking - Đặt Sân Thể Thao Thông Minh',
      debugShowCheckedModeBanner: false,
      // Cho phép kéo bằng chuột để cuộn (dải chip môn, khung giờ...) như vuốt bằng ngón tay
      scrollBehavior: const AppScrollBehavior(),
      theme: AppTheme.light(),
      // Bọc toàn bộ ứng dụng bằng DeviceSimulatorWrapper để xem trước giao diện Điện Thoại ngay trên Máy Tính
      builder: (context, child) => DeviceSimulatorWrapper(child: child!),
      // Mở đầu bằng giao diện khách (trang chủ); đăng nhập khi cần đặt sân / quản trị
      home: const HomeScreen(),
    );
  }
}
