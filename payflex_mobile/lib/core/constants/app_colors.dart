import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors - PayFlex Yellow & Blue
  static const Color primary = Color(0xFFF9A825); // Golden Yellow
  static const Color secondary = Color(0xFF00314F); // Deep Navy Blue
  static const Color accent = Color(0xFF1A4480);
  
  // Neutral Colors (Light Mode)
  static const Color background = Color(0xFFFDFDFD);
  static const Color surface = Colors.white;
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF434750);
  
  // Dark Mode Palette
  static const Color darkBackground = Color(0xFF0A0E12);
  static const Color darkSurface = Color(0xFF14181F);
  static const Color darkOnSurface = Color(0xFFE2E2E6);
  static const Color darkOnSurfaceVariant = Color(0xFF9EA3AF);
  
  // Functional Colors (Status)
  static const Color error = Color(0xFFBA1A1A);
  static const Color success = Color(0xFF4CAF50); // 🟢 Full
  static const Color warning = Color(0xFFFFC107); // 🟡 Partial
  static const Color info = Color(0xFF2196F3);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFFFFB300)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, Color(0xFF001F33)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
