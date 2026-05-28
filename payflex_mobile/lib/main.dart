import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'core/logging/payflex_error_logger.dart';
import 'core/network/api_config.dart';
import 'core/network/mobile_api_service.dart';
import 'core/network/payflex_api_logger.dart';
import 'core/services/local_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PayflexErrorLogger.init();
  await LocalNotificationService.init();
  if (kDebugMode) {
    PayflexApiLogger.logConfig(ApiConfig.debugSummary());
    unawaited(_probeBackendAtStartup());
  }
  runApp(
    const ProviderScope(
      child: PayFlexApp(),
    ),
  );
}

Future<void> _probeBackendAtStartup() async {
  final ok = await MobileApiService().checkHealth();
  if (ok) {
    PayflexApiLogger.info('Backend joignable ✓ (${ApiConfig.baseUrl})');
  } else {
    PayflexApiLogger.warn(
      'Backend INJOIGNABLE à ${ApiConfig.baseUrl} (${ApiConfig.connectionMode}).\n'
      '  • PC + téléphone même Wi‑Fi : vérifiez PAYFLEX_API_HOST (ipconfig → IPv4).\n'
      '  • USB seul : adb reverse tcp:8088 tcp:8088 puis --dart-define=PAYFLEX_USB_REVERSE=true\n'
      '  • Backend démarré : .\\payflex_backend\\run-local.ps1',
    );
  }
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
