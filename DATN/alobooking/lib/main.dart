import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/navigator_key.dart';
import 'widgets/device_simulator_wrapper.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF16A34A),
          secondary: Color(0xFF10B981),
          surface: Colors.white,
        ),
        fontFamily: 'Be Vietnam Pro',
        textTheme: ThemeData().textTheme.apply(
          fontFamily: 'Be Vietnam Pro',
          bodyColor: const Color(0xFF0F172A),
          displayColor: const Color(0xFF0F172A),
        ),
      ),
      // Bọc toàn bộ ứng dụng bằng DeviceSimulatorWrapper để xem trước giao diện Điện Thoại ngay trên Máy Tính
      builder: (context, child) => DeviceSimulatorWrapper(child: child!),
      // Mở đầu bằng giao diện khách (trang chủ); đăng nhập khi cần đặt sân / quản trị
      home: const HomeScreen(),
    );
  }
}
