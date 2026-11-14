import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/visual_booking_screen.dart';
import 'data/venues_data.dart';
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
    // Sân Pickleball mẫu chuẩn theo ảnh giao diện mẫu người dùng yêu cầu
    final sampleVenue = sampleVenues.firstWhere(
      (v) => v.type.toLowerCase().contains('pickle') || v.name.toLowerCase().contains('pickle'),
      orElse: () => sampleVenues[0],
    );

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
      // Truy cập thẳng màn hình Đặt Lịch Theo Sân - Trực Quan đúng 100% như ảnh mẫu
      home: VisualBookingScreen(venue: sampleVenue),
    );
  }
}
