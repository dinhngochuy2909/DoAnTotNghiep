import 'package:flutter/material.dart';
import 'floating_chat_button.dart';

/// Danh sách thiết bị mẫu để giả lập giao diện
enum DeviceType {
  iphone18ProMax('iPhone 18 Pro Max', 430, 932, 52, 'iOS 20 Pro'),
  iphone18('iPhone 18', 393, 852, 46, 'iOS 20'),
  galaxyS25('Samsung Galaxy S25', 360, 800, 34, 'One UI 7'),
  ipadPro('iPad Pro 11"', 834, 1194, 28, 'iPadOS');

  final String name;
  final double width;
  final double height;
  final double cornerRadius;
  final String os;

  const DeviceType(this.name, this.width, this.height, this.cornerRadius, this.os);
}

/// Wrapper cho phép trải nghiệm trực tiếp giao diện Điện Thoại iPhone 18 trên màn hình Máy Tính (PC/Laptop)
class DeviceSimulatorWrapper extends StatefulWidget {
  final Widget child;

  const DeviceSimulatorWrapper({
    super.key,
    required this.child,
  });

  @override
  State<DeviceSimulatorWrapper> createState() => _DeviceSimulatorWrapperState();
}

class _DeviceSimulatorWrapperState extends State<DeviceSimulatorWrapper> {
  // Mặc định mở toàn màn hình máy tính (khớp chuẩn ảnh desktop) và có nút bấm chuyển sang iPhone 18 Pro Max
  bool _isSimulatorActive = false;
  DeviceType _selectedDevice = DeviceType.iphone18ProMax;
  bool _isLandscape = false;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final realScreenWidth = mediaQuery.size.width;
    final isRealMobile = realScreenWidth < 850;

    // Nếu người dùng đang mở trên điện thoại thật thì hiển thị 100% toàn màn hình tự nhiên
    if (isRealMobile) {
      return Stack(
        children: [
          widget.child,
          // Nút chat kéo thả được trên toàn màn hình điện thoại
          const Positioned.fill(
            child: FloatingChatButton(defaultRight: 16, defaultBottom: 86),
          ),
        ],
      );
    }

    // Nếu người dùng tắt giả lập để xem bản Desktop toàn màn hình
    if (!_isSimulatorActive) {
      return Stack(
        children: [
          widget.child,

          // Nút nổi ChatBot AI dự báo nhu cầu đặt sân (mặc định ở góc phải, kéo thả được khắp màn hình)
          const Positioned.fill(
            child: FloatingChatButton(defaultRight: 24, defaultBottom: 86),
          ),

          // Nút nổi ở góc dưới bên phải để bật lại chế độ Xem iPhone 18
          Positioned(
            bottom: 24,
            right: 24,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _isSimulatorActive = true),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_iphone, color: Color(0xFF34D399), size: 20),
                      SizedBox(width: 8),
                      Text(
                        '📱 Xem Demo iPhone 18 Pro Max',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Kích thước của khung điện thoại
    final deviceW = _isLandscape ? _selectedDevice.height : _selectedDevice.width;
    final deviceH = _isLandscape ? _selectedDevice.width : _selectedDevice.height;

    // Giao diện Giả Lập iPhone 18 Trên Máy Tính (Studio Phone Mockup)
    return Scaffold(
      backgroundColor: const Color(0xFF070B19), // Nền studio không gian vũ trụ siêu sang
      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // 1. THANH ĐIỀU KHIỂN GIẢ LẬP TRÊN MÁY TÍNH (TOP CONTROL BAR)
            // ==========================================
            _buildTopControlBar(),

            // ==========================================
            // 2. KHUNG ĐIỆN THOẠI TRUNG TÂM (CENTERED PHONE FRAME)
            // ==========================================
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Các nút bấm vật lý bên sườn iPhone 18 (Action button, Volume, Power, Camera Control)
                      if (!_isLandscape && (_selectedDevice == DeviceType.iphone18ProMax || _selectedDevice == DeviceType.iphone18)) ...[
                        // Phím Action Button (trên cùng bên trái)
                        Positioned(
                          left: 17,
                          top: 135,
                          child: Container(
                            width: 3.5,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF475569),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(2)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 2)],
                            ),
                          ),
                        ),
                        // Phím Tăng âm lượng
                        Positioned(
                          left: 17,
                          top: 175,
                          child: Container(
                            width: 3.5,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF475569),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(2)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 2)],
                            ),
                          ),
                        ),
                        // Phím Giảm âm lượng
                        Positioned(
                          left: 17,
                          top: 235,
                          child: Container(
                            width: 3.5,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF475569),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(2)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 2)],
                            ),
                          ),
                        ),
                        // Phím Nguồn Power Button (bên phải)
                        Positioned(
                          right: 17,
                          top: 190,
                          child: Container(
                            width: 3.5,
                            height: 75,
                            decoration: BoxDecoration(
                              color: const Color(0xFF475569),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 2)],
                            ),
                          ),
                        ),
                        // Phím Chụp ảnh Camera Control (bên phải phía dưới)
                        Positioned(
                          right: 17,
                          bottom: 220,
                          child: Container(
                            width: 3.5,
                            height: 55,
                            decoration: BoxDecoration(
                              color: const Color(0xFF64748B),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 2)],
                            ),
                          ),
                        ),
                      ],

                      // Thân máy iPhone 18 viền Titan
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                        padding: const EdgeInsets.all(10), // Viền titan mỏng chuẩn viền siêu tràn
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF334155), Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(_selectedDevice.cornerRadius + 10),
                          border: Border.all(color: const Color(0xFF475569), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.75),
                              blurRadius: 42,
                              spreadRadius: 10,
                              offset: const Offset(0, 16),
                            ),
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.2),
                              blurRadius: 35,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(_selectedDevice.cornerRadius),
                          child: Container(
                            width: deviceW,
                            height: deviceH,
                            color: Colors.white,
                            child: Stack(
                              children: [
                                // Ứng dụng chạy bên trong với MediaQuery giả lập kích thước điện thoại
                                MediaQuery(
                                  data: mediaQuery.copyWith(
                                    size: Size(deviceW, deviceH),
                                    padding: EdgeInsets.only(
                                      top: _isLandscape ? 0 : 42,
                                      bottom: _isLandscape ? 0 : 24,
                                    ),
                                    viewPadding: EdgeInsets.only(
                                      top: _isLandscape ? 0 : 42,
                                      bottom: _isLandscape ? 0 : 24,
                                    ),
                                  ),
                                  child: widget.child,
                                ),

                                // Thanh trạng thái Status Bar chuẩn iOS 20
                                if (!_isLandscape && (_selectedDevice == DeviceType.iphone18ProMax || _selectedDevice == DeviceType.iphone18))
                                  Positioned(
                                    top: 12,
                                    left: 28,
                                    right: 28,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Giờ hệ thống
                                        const Text(
                                          '09:41',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const Spacer(),
                                        // Biểu tượng sóng 5G / Wifi / Pin
                                        Row(
                                          children: [
                                            const Icon(Icons.signal_cellular_4_bar, color: Colors.white, size: 14),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.wifi, color: Colors.white, size: 14),
                                            const SizedBox(width: 6),
                                            Container(
                                              width: 22,
                                              height: 11,
                                              padding: const EdgeInsets.all(1.5),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.white, width: 1.2),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF22C55E),
                                                  borderRadius: BorderRadius.circular(1.5),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                // Dynamic Island 2.0 (Micro Punch Capsule)
                                if (!_isLandscape && (_selectedDevice == DeviceType.iphone18ProMax || _selectedDevice == DeviceType.iphone18))
                                  Positioned(
                                    top: 10,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        width: 108,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.5),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            const SizedBox(width: 12),
                                            // Camera trước ống kính tráng phủ
                                            Container(
                                              width: 9,
                                              height: 9,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF1E293B),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Container(
                                                  width: 3.5,
                                                  height: 3.5,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF0369A1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            // Đèn cảm biến FaceID / microphone
                                            Container(
                                              width: 6,
                                              height: 6,
                                              margin: const EdgeInsets.only(right: 12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF047857).withOpacity(0.8),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                // Camera đục lỗ cho Samsung Galaxy S25
                                if (!_isLandscape && _selectedDevice == DeviceType.galaxyS25)
                                  Positioned(
                                    top: 10,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        width: 11,
                                        height: 11,
                                        decoration: const BoxDecoration(
                                          color: Colors.black,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Thanh điều hướng vuốt ngang ở đáy iPhone 18 (Home Indicator)
                                if (!_isLandscape)
                                  Positioned(
                                    bottom: 7,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        width: 130,
                                        height: 4.5,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ),

                                // Nút ChatBot AI nổi trong khung điện thoại (kéo thả được trong khung)
                                const Positioned.fill(
                                  child: FloatingChatButton(defaultRight: 14, defaultBottom: 86),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nút chọn một mẫu máy (thay cho DropdownButton vì thanh này không có Navigator/Overlay)
  Widget _buildDeviceChip(DeviceType dev) {
    final selected = dev == _selectedDevice;
    return Semantics(
      button: true,
      selected: selected,
      label: '${dev.name} (${dev.width.toInt()} x ${dev.height.toInt()})',
      child: InkWell(
        key: ValueKey('device-${dev.name}'),
        onTap: () => setState(() => _selectedDevice = dev),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF065F46) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? const Color(0xFF10B981) : const Color(0xFF334155)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                dev == DeviceType.ipadPro ? Icons.tablet_mac : Icons.phone_iphone,
                size: 14,
                color: selected ? const Color(0xFF6EE7B7) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 5),
              Text(
                dev.name,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFFCBD5E1),
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Thanh điều khiển trên máy tính
  Widget _buildTopControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1.5)),
      ),
      // Dùng Wrap để thanh tự xuống dòng khi cửa sổ hẹp. Thanh này nằm ngoài Navigator của ứng dụng
      // (MaterialApp.builder) nên KHÔNG có Overlay/Navigator: không dùng Tooltip, DropdownButton, PopupMenu ở đây.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          // Logo & Tên chế độ
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF047857)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone_iphone, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'DEMO iPHONE 18 PRO MAX',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'MỚI NHẤT ✨',
                          style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Màn hình Super Retina XDR 120Hz · Viền Titan siêu tràn · Trải nghiệm như máy thật',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),

          // Chọn mẫu điện thoại (iPhone 18 Pro Max / iPhone 18 / Samsung S25 / iPad): dãy nút chọn, không cần Overlay
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final dev in DeviceType.values) ...[
                _buildDeviceChip(dev),
                const SizedBox(width: 6),
              ],
            ],
          ),

          // Nút Xoay Màn Hình (Rotate)
          Semantics(
            button: true,
            label: _isLandscape ? 'Chuyển về màn hình dọc' : 'Xoay màn hình ngang',
            child: IconButton(
              onPressed: () => setState(() => _isLandscape = !_isLandscape),
              icon: Icon(
                Icons.screen_rotation,
                color: _isLandscape ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                size: 20,
              ),
              splashRadius: 20,
            ),
          ),

          // Nút Chuyển Về Bản Desktop Máy Tính
          ElevatedButton.icon(
            onPressed: () => setState(() => _isSimulatorActive = false),
            icon: const Icon(Icons.desktop_windows, size: 15),
            label: const Text(
              '💻 XEM BẢN MÁY TÍNH',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7), // Sky blue
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
