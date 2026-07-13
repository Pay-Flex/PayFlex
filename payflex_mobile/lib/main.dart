import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'core/logging/payflex_error_logger.dart';
import 'core/navigation/payflex_navigator.dart';
import 'core/network/api_config.dart';
import 'core/network/api_config_store.dart';
import 'core/network/mobile_api_service.dart';
import 'core/network/payflex_api_logger.dart';
import 'core/providers/ui_scale_provider.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/payflex_background_push.dart';
import 'core/services/payflex_fcm_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/dev_backend_banner.dart';
import 'core/widgets/payflex_push_lifecycle.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await PayflexErrorLogger.init();
  await LocalNotificationService.init();
  await initPayflexBackgroundPush();
  // Push réel FCM (gardé : sans google-services.json, retombe sur le poll).
  await PayflexFcmService.instance.init();
  if (kDebugMode) {
    await ApiConfigStore.init(seedLanHost: ApiConfig.devPcIpv4);
  }
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
      '  • Wi‑Fi changé ? Appui long sur le logo (connexion) → modifier l’IP PC.\n'
      '  • USB : payflex_mobile\\scripts\\run-usb.ps1 (127.0.0.1 stable)\n'
      '  • Backend démarré : payflex_backend\\run-local.ps1',
    );
  }
}

class PayFlexApp extends ConsumerWidget {
  const PayFlexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final largeText = ref.watch(uiScaleProvider);
    final boost = ref.read(uiScaleProvider.notifier).boostFactor;

    return PayflexPushLifecycle(
      child: MaterialApp(
        navigatorKey: payflexRootNavigatorKey,
        navigatorObservers: [PayflexSessionActivityObserver()],
        title: 'PayFlex',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        home: const SplashScreen(),
        builder: (context, child) {
          // Honore le réglage système « grande police » d'Android tout en le
          // bornant pour éviter les débordements ; ajoute le boost in-app si
          // l'utilisateur a activé « Texte plus grand ».
          final systemScale = MediaQuery.textScalerOf(context).scale(1.0);
          final effective = (systemScale * (largeText ? boost : 1.0))
              .clamp(1.0, largeText ? 1.35 : 1.25);
          return MediaQuery.withClampedTextScaling(
            minScaleFactor: effective,
            maxScaleFactor: effective,
            child: DevBackendBanner(child: child),
          );
        },
      ),
    );
  }
}
