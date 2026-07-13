import 'dart:io';
import 'package:flutter/foundation.dart';

import 'api_config_store.dart';

/// URL du backend PayFlex.
///
/// Priorité (debug) :
/// 1. Override persistant ([ApiConfigStore], SharedPreferences) — dev uniquement
/// 2. `--dart-define=PAYFLEX_API_BASE=https://...` (build prod ou override ponctuel)
/// 3. USB / LAN / tunnel selon dart-define ci-dessous
///
/// Production (`flutter build --release -Mode prod`) :
/// - URL figée via `PAYFLEX_API_BASE` au build — pas d’override SharedPreferences.
///
/// Dev sans recompilation après changement de Wi‑Fi :
/// - USB (recommandé) : `adb reverse` + `scripts/run-usb.ps1` ou override `127.0.0.1` dans l’app
/// - Wi‑Fi : appui long sur le logo (écran connexion) → saisir l’IP du PC
class ApiConfig {
  static const String _fromEnv = String.fromEnvironment('PAYFLEX_API_BASE', defaultValue: '');

  /// URL publique HTTPS (tunnel ou prod). Laisser vide en dev local — utiliser LAN / USB.
  /// Activer le tunnel : `--dart-define=PAYFLEX_USE_TUNNEL=true` + mettre l’URL ici.
  /// LocalTunnel dev (`npx localtunnel --port 8088 --subdomain payflex-app`).
  static const String defaultTunnelBase = String.fromEnvironment(
    'PAYFLEX_TUNNEL_BASE',
    defaultValue: 'https://payflex-app.loca.lt',
  );

  /// `true` si l’URL prod a été compilée (`build-apk.ps1 -Mode prod -ApiBase …`).
  static const bool isProductionBuild = bool.fromEnvironment(
    'PAYFLEX_PROD_BUILD',
    defaultValue: false,
  );

  /// `flutter run --dart-define=PAYFLEX_USB_REVERSE=true` après `adb reverse tcp:8088 tcp:8088`.
  static const bool useAdbReverseOnAndroid = bool.fromEnvironment('PAYFLEX_USB_REVERSE', defaultValue: false);

  /// Forcer le tunnel même en debug : `--dart-define=PAYFLEX_USE_TUNNEL=true`
  static const bool useTunnelOnMobile = bool.fromEnvironment('PAYFLEX_USE_TUNNEL', defaultValue: false);

  /// Wi‑Fi explicite : `flutter run --dart-define=PAYFLEX_USE_LAN=true` (redondant en debug).
  static const bool useLanOnMobile = bool.fromEnvironment('PAYFLEX_USE_LAN', defaultValue: false);

  /// Mettre à `true` pour forcer localhost sur Windows/macOS/Linux (sans tunnel).
  static const bool useLocalhostOnDesktop = bool.fromEnvironment('PAYFLEX_USE_LOCALHOST', defaultValue: false);

  /// `true` si [devPcIpv4] a été passé via `--dart-define` (ex. scripts/run-wifi.ps1).
  static const bool devLanHostConfigured = bool.fromEnvironment(
    'PAYFLEX_API_HOST_SET',
    defaultValue: false,
  );

  /// IPv4 du PC sur le Wi‑Fi (téléphone et PC sur le même réseau).
  /// Ne pas hardcoder une IP : utiliser `scripts/run-wifi.ps1` après chaque changement de réseau.
  static const String devPcIpv4 = String.fromEnvironment(
    'PAYFLEX_API_HOST',
    defaultValue: '',
  );

  static bool get baseUrlFromEnv => _fromEnv.isNotEmpty;

  /// Debug mobile LAN sans IP explicite ni override prefs.
  static bool get needsDevLanHostWarning =>
      kDebugMode &&
      !ApiConfigStore.hasOverride &&
      !baseUrlFromEnv &&
      !useAdbReverseOnAndroid &&
      !useTunnelOnMobile &&
      !kIsWeb &&
      (Platform.isAndroid || Platform.isIOS) &&
      !devLanHostConfigured;

  static const int backendPort = int.fromEnvironment('PAYFLEX_API_PORT', defaultValue: 8088);

  static String get baseUrl {
    if (kDebugMode) {
      final prefsOverride = ApiConfigStore.overrideUrl;
      if (prefsOverride != null && prefsOverride.isNotEmpty) {
        return _normalizeBase(prefsOverride);
      }
    }
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
      // Debug sur téléphone physique : LAN (IP via run-wifi.ps1 ou PAYFLEX_API_HOST).
      if (kDebugMode || useLanOnMobile) {
        final host = _resolveDevLanHost();
        return 'http://$host:$backendPort';
      }
      return defaultTunnelBase;
    }
    return defaultTunnelBase;
  }

  static String get connectionMode {
    if (kDebugMode && ApiConfigStore.hasOverride) return 'prefs dev (${ApiConfigStore.overrideUrl})';
    if (_fromEnv.isNotEmpty) return isProductionBuild ? 'prod ($_fromEnv)' : 'PAYFLEX_API_BASE';
    if (!kIsWeb && Platform.isAndroid && useAdbReverseOnAndroid) return 'USB adb reverse (127.0.0.1)';
    if (useLocalhostOnDesktop && !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return 'localhost desktop';
    }
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return useTunnelOnMobile ? 'tunnel ($defaultTunnelBase)' : 'localhost ($backendPort)';
    }
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      if (useTunnelOnMobile) return 'tunnel ($defaultTunnelBase)';
      if (kDebugMode || useLanOnMobile) {
        final host = _resolveDevLanHost();
        return devLanHostConfigured ? 'LAN Wi‑Fi ($host)' : 'LAN Wi‑Fi (IP non configurée → $host)';
      }
      return 'tunnel release ($defaultTunnelBase)';
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
      ..writeln('PAYFLEX_API_HOST_SET: $devLanHostConfigured')
      ..writeln('PAYFLEX_API_HOST: ${devPcIpv4.isEmpty ? "(vide)" : devPcIpv4}')
      ..writeln('prefs override: ${ApiConfigStore.hasOverride ? ApiConfigStore.overrideUrl : "(aucun)"}');
    if (_fromEnv.isNotEmpty) {
      buf.writeln('PAYFLEX_API_BASE: (défini)');
    }
    if (needsDevLanHostWarning) {
      buf.writeln('');
      buf.writeln('⚠ IP LAN non configurée : appui long sur le logo (connexion)');
      buf.writeln('  ou .\\scripts\\run-usb.ps1 (USB, IP stable 127.0.0.1).');
    }
    if (kDebugMode && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      buf.writeln('');
      buf.writeln('Changement de Wi‑Fi : modifier l’IP dans l’app (logo), sans rebuild.');
      if (!ApiConfigStore.hasOverride && !useAdbReverseOnAndroid) {
        buf.writeln('USB : adb reverse tcp:8088 tcp:8088 puis .\\scripts\\run-usb.ps1');
      }
    }
    return buf.toString();
  }

  static String _normalizeBase(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Hôte LAN effectif : IP explicite, sinon 127.0.0.1 (émulateur / dernier recours).
  static String _resolveDevLanHost() {
    final trimmed = devPcIpv4.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return '127.0.0.1';
  }

  /// LocalTunnel affiche une page « saisir l’IP » sans cet en-tête.
  static bool get usesLocalTunnel {
    final u = baseUrl.toLowerCase();
    return u.contains('loca.lt') || u.contains('localtunnel.me');
  }

  static Map<String, String> get localTunnelHeaders {
    if (!usesLocalTunnel) return const {};
    return const {
      'Bypass-Tunnel-Reminder': 'true',
      'User-Agent': 'PayFlex-Mobile',
    };
  }

  static bool urlNeedsLocalTunnelBypass(String url) {
    final u = url.toLowerCase();
    return u.contains('loca.lt') || u.contains('localtunnel.me');
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

