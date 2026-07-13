import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistance debug de l’URL backend (SharedPreferences) — ignorée en release / prod build.
///
/// Priorité dans `ApiConfig.baseUrl` : override prefs → dart-define → défauts.
class ApiConfigStore {
  ApiConfigStore._();

  static const _prefsKey = 'payflex_dev_api_base_url';
  static const int _backendPort = int.fromEnvironment('PAYFLEX_API_PORT', defaultValue: 8088);

  static String? _overrideUrl;
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  /// URL sauvegardée (vide si aucun override actif).
  static String? get overrideUrl {
    final v = _overrideUrl?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static bool get hasOverride => overrideUrl != null;

  static Future<void> init({String seedLanHost = ''}) async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey)?.trim();
    if (saved != null && saved.isNotEmpty) {
      _overrideUrl = _normalizeBase(saved);
    } else if (kDebugMode && seedLanHost.trim().isNotEmpty) {
      // Première install : enregistre l’IP passée par run-wifi.ps1 (dart-define).
      final seeded = 'http://${seedLanHost.trim()}:$_backendPort';
      await _persist(seeded);
    }
    _initialized = true;
  }

  static Future<void> setOverride(String url) async {
    final normalized = _normalizeBase(url.trim());
    if (normalized.isEmpty) {
      await clearOverride();
      return;
    }
    await _persist(normalized);
  }

  /// Saisie utilisateur : IP seule (`192.168.0.42`) ou URL complète.
  static Future<void> setFromUserInput(String input) async {
    final raw = input.trim();
    if (raw.isEmpty) {
      await clearOverride();
      return;
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      await setOverride(raw);
      return;
    }
    final host = raw.split('/').first.split(':').first.trim();
    await setOverride('http://$host:$_backendPort');
  }

  static Future<void> setUsbReverseDefault() async {
    await setOverride('http://127.0.0.1:$_backendPort');
  }

  static Future<void> clearOverride() async {
    _overrideUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static Future<void> _persist(String normalized) async {
    _overrideUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, normalized);
  }

  static String _normalizeBase(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
