import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Bảng màu Cyber HUD / Mecha Tech
  // Nền đen - xanh thẫm, điểm nhấn Cyan, màu phụ Đỏ Neon
  static const Color primaryColor = Color(0xFF00E5FF); // Cyber Cyan
  static const Color accentColor = Color(0xFF00F0FF); // Neon Aqua
  static const Color textColor = Color(0xFFE2E8F0); // Ice White
  static const Color secondaryTextColor = Color(0xFF94A3B8); // Muted Slate
  static const Color backgroundColor = Color(
    0xFF070B12,
  ); // Deep Space Black-Navy
  static const Color surfaceColor = Color(0xFF0F172A); // Tech Panel Navy
  static const Color errorColor = Color(0xFFFF1744); // Alert Crimson Red

  // Hằng số mở rộng cho phong cách Cyber/HUD
  static const Color secondaryColor = Color(0xFFFF1744); // Phụ đỏ
  static const Color cyanAccent = Color(0xFF00F0FF);
  static const Color darkBackground = Color(0xFF070B12);
  static const Color panelBackground = Color(0xFF0F172A);
  static const Color borderColor = Color(0xFF1E293B);

  // Tạo cấu hình ThemeData Cyber HUD thống nhất
  static ThemeData _buildCyberTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: Color(0xFF070B12),
        onSecondary: Color(0xFF070B12),
        onSurface: textColor,
        onBackground: textColor,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: backgroundColor,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textColor, letterSpacing: 0.3),
        bodyMedium: TextStyle(color: textColor, letterSpacing: 0.2),
        titleLarge: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
        titleMedium: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
        titleSmall: TextStyle(
          color: accentColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
      // Bo góc vát / cạnh (Beveled chamfer) phong cách cơ khí
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: const Color(0xFF070B12),
          elevation: 2,
          shape: const BeveledRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.2),
          shape: const BeveledRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Color(0xFF070B12),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: secondaryTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: const CardThemeData(
        color: surfaceColor,
        elevation: 2,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        labelStyle: const TextStyle(color: secondaryTextColor),
        hintStyle: const TextStyle(color: Color(0xFF475569)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surfaceColor,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          side: BorderSide(color: primaryColor, width: 1),
        ),
      ),
    );
  }

  // Cả lightTheme và darkTheme đều dùng phong cách Cyber HUD tối ưu cho botAi
  static final ThemeData lightTheme = _buildCyberTheme();
  static final ThemeData darkTheme = _buildCyberTheme();
}
