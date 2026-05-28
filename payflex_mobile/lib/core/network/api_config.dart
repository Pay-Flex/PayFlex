import 'dart:io';
import 'package:flutter/foundation.dart';

/// URL du backend PayFlex.
///
/// Priorité :
/// 1. `--dart-define=PAYFLEX_API_BASE=https://...` (override ponctuel)
/// 2. Téléphone USB + `adb reverse` → [useAdbReverseOnAndroid] + `http://127.0.0.1:8088`
/// 3. Wi‑Fi / debug physique → en mode debug : `http://[devPcIpv4]:8088` par défaut
/// 4. `--dart-define=PAYFLEX_USE_TUNNEL=true` + [defaultTunnelBase] → tunnel Cloudflare (optionnel)
/// 5. Sinon → localhost / LAN (pas de Cloudflare requis)
///
/// Téléphone physique + câble USB (recommandé si pas de Wi‑Fi) :
/// ```text
/// adb reverse tcp:8088 tcp:8088
/// flutter run --dart-define=PAYFLEX_USB_REVERSE=true
/// ```
///
/// Téléphone + PC sur le même Wi‑Fi (mode debug par défaut depuis cette révision) :
/// ```text
/// flutter run --dart-define=PAYFLEX_API_HOST=192.168.x.x
/// ```
class ApiConfig {
  static const String _fromEnv = String.fromEnvironment('PAYFLEX_API_BASE', defaultValue: '');

  /// URL publique HTTPS (tunnel ou prod). Laisser vide en dev local — utiliser LAN / USB.
  /// Activer le tunnel : `--dart-define=PAYFLEX_USE_TUNNEL=true` + mettre l’URL ici.
  static const String defaultTunnelBase = String.fromEnvironment(
    'PAYFLEX_TUNNEL_BASE',
    defaultValue: 'http://127.0.0.1:8088',
  );

  /// `flutter run --dart-define=PAYFLEX_USB_REVERSE=true` après `adb reverse tcp:8088 tcp:8088`.
  static const bool useAdbReverseOnAndroid = bool.fromEnvironment('PAYFLEX_USB_REVERSE', defaultValue: false);

  /// Forcer le tunnel même en debug : `--dart-define=PAYFLEX_USE_TUNNEL=true`
  static const bool useTunnelOnMobile = bool.fromEnvironment('PAYFLEX_USE_TUNNEL', defaultValue: false);

  /// Wi‑Fi explicite : `flutter run --dart-define=PAYFLEX_USE_LAN=true` (redondant en debug).
  static const bool useLanOnMobile = bool.fromEnvironment('PAYFLEX_USE_LAN', defaultValue: false);

  /// Mettre à `true` pour forcer localhost sur Windows/macOS/Linux (sans tunnel).
  static const bool useLocalhostOnDesktop = bool.fromEnvironment('PAYFLEX_USE_LOCALHOST', defaultValue: false);

  /// IPv4 du PC sur le Wi‑Fi (téléphone et PC sur le même réseau).
  static const String devPcIpv4 = String.fromEnvironment(
    'PAYFLEX_API_HOST',
    defaultValue: '192.168.1.68',
  );

  static const int backendPort = int.fromEnvironment('PAYFLEX_API_PORT', defaultValue: 8088);

  static String get baseUrl {
    if (_fromEnv.isNotEmpty) {
      return _normalizeBase(_fromEnv);
    }
    if (!kIsWeb && Platform.isAndroid && useAdbReverseOnAndroid) {
      return 'http://127.0.0.1:$backendPort';
    }
    if (useLocalhostOnDesktop && !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return 'http://localhost:$backendPort';
    }
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      if (kDebugMode && !useTunnelOnMobile) {
        return 'http://localhost:$backendPort';
      }
      return useTunnelOnMobile ? defaultTunnelBase : 'http://localhost:$backendPort';
    }
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      if (useTunnelOnMobile) {
        return defaultTunnelBase;
      }
      // Debug sur téléphone physique : LAN par défaut (évite un tunnel Cloudflare mort).
      if (kDebugMode || useLanOnMobile) {
        return 'http://$devPcIpv4:$backendPort';
      }
      return defaultTunnelBase;
    }
    return defaultTunnelBase;
  }

  static String get connectionMode {
    if (_fromEnv.isNotEmpty) return 'PAYFLEX_API_BASE';
    if (!kIsWeb && Platform.isAndroid && useAdbReverseOnAndroid) return 'USB adb reverse (127.0.0.1)';
    if (useLocalhostOnDesktop && !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return 'localhost desktop';
    }
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return useTunnelOnMobile ? 'tunnel Cloudflare' : 'localhost ($backendPort)';
    }
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      if (useTunnelOnMobile) return 'tunnel Cloudflare';
      if (kDebugMode || useLanOnMobile) return 'LAN Wi‑Fi ($devPcIpv4)';
      return 'tunnel Cloudflare (release)';
    }
    return 'inconnu';
  }

  static String debugSummary() {
    final buf = StringBuffer()
      ..writeln('baseUrl: $baseUrl')
      ..writeln('mode: $connectionMode')
      ..writeln('port: $backendPort')
      ..writeln('kDebugMode: $kDebugMode')
      ..writeln('plateforme: ${!kIsWeb ? Platform.operatingSystem : "web"}');
    if (!kIsWeb && Platform.isAndroid) {
      buf.writeln('PAYFLEX_USB_REVERSE: $useAdbReverseOnAndroid');
    }
    buf
      ..writeln('PAYFLEX_USE_TUNNEL: $useTunnelOnMobile')
      ..writeln('PAYFLEX_USE_LAN: $useLanOnMobile')
      ..writeln('PAYFLEX_API_HOST: $devPcIpv4');
    if (_fromEnv.isNotEmpty) {
      buf.writeln('PAYFLEX_API_BASE: (défini)');
    }
    if (kDebugMode && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      if (connectionMode.startsWith('LAN')) {
        buf.writeln('');
        buf.writeln('Astuce USB sans Wi‑Fi : adb reverse tcp:8088 tcp:8088');
        buf.writeln('puis flutter run --dart-define=PAYFLEX_USB_REVERSE=true');
      }
    }
    return buf.toString();
  }

  static String _normalizeBase(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// URL absolue pour les médias renvoyés par l’API (chemins relatifs `uploads/...` ou URLs complètes).
  static String resolveMediaUrl(String? pathOrUrl) {
    final s = pathOrUrl?.trim() ?? '';
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    final path = s.startsWith('/') ? s.substring(1) : s;
    return '$baseUrl/$path';
  }
}
