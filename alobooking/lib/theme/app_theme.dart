import 'package:flutter/material.dart';

/// Màu dùng chung của AloBooking: chủ đạo là xanh biển, điểm nhấn hành động là vàng hổ phách.
/// Xanh lá chỉ dành cho nghĩa "thành công, đang mở, đã xác nhận".
class AppColors {
  AppColors._();

  static const primary = Color(0xFF0284C7);
  static const primaryDark = Color(0xFF0369A1);
  static const primaryDeep = Color(0xFF075985);
  static const primarySoft = Color(0xFFE0F2FE);
  static const primaryMist = Color(0xFFF0F9FF);

  /// Nút hành động chính trên thẻ (Đặt lịch): chữ tối trên nền vàng để đủ độ tương phản.
  static const cta = Color(0xFFF59E0B);
  static const ctaPressed = Color(0xFFD97706);

  static const bg = Color(0xFFF4F7FB);
  static const surface = Colors.white;
  static const ink = Color(0xFF0F172A);
  static const body = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);
  static const line = Color(0xFFE2E8F0);
  static const lineSoft = Color(0xFFEEF2F7);

  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFDCFCE7);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const dangerSoft = Color(0xFFFEE2E2);

  /// Nền chuyển sắc của thanh đầu trang.
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF075985), Color(0xFF0284C7), Color(0xFF0EA5E9)],
  );
}

/// Bo góc theo bậc, để mọi thẻ, nút, ô nhập cùng một nhịp.
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;
}

/// Đổ bóng mềm hai lớp: một lớp rộng nhạt cho độ nổi, một lớp sát mỏng cho đường viền.
class AppShadows {
  AppShadows._();

  static const card = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 18, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const soft = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static const floating = [
    BoxShadow(color: Color(0x330F172A), blurRadius: 14, offset: Offset(0, 6)),
  ];
}

class AppTheme {
  AppTheme._();

  static const fontFamily = 'Be Vietnam Pro';

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.primaryDark,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          outline: AppColors.line,
          error: AppColors.danger,
          surfaceTint: Colors.transparent,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      fontFamily: fontFamily,
    );

    final text = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: text,
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: shape,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape,
          side: const BorderSide(color: AppColors.line),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: shape,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(
          color: AppColors.faint,
          fontWeight: FontWeight.w400,
        ),
        // Chỉ đặt `border` chung: ô nào khai báo InputBorder.none (ô tìm kiếm...) vẫn không có viền.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        // Thông báo nổi, chừa lề phải 96px để nút chat nổi ở góc dưới bên phải không che mất nút hành động ("Thử lại"...).
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 96, 16),
        shape: shape,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
