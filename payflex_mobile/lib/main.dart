import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: PayFlexApp(),
    ),
  );
}

class PayFlexApp extends StatelessWidget {
  const PayFlexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PayFlex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen().animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.95, 0.95)),
    );
  }
}
