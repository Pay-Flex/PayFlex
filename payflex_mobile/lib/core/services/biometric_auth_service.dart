import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférences biométriques locales (activation + identifiants de session rapide).
class BiometricAuthService {
  BiometricAuthService._();

  static const _kEnabled = 'payflex_biometric_enabled';
  static const _kPhone = 'payflex_biometric_phone';
  static const _kPin = 'payflex_biometric_pin';
  static const _kUserId = 'payflex_biometric_user_id';
  static const _kRole = 'payflex_biometric_role';

  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
    if (!enabled) {
      await prefs.remove(_kPhone);
      await prefs.remove(_kPin);
      await prefs.remove(_kUserId);
      await prefs.remove(_kRole);
    }
  }

  static Future<bool> authenticate({String reason = 'Confirmez votre identité'}) async {
    try {
      return await _auth.authenticate(localizedReason: reason);
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveCredentials({
    required int userId,
    required String phone,
    required String pin,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUserId, userId);
    await prefs.setString(_kPhone, phone);
    await prefs.setString(_kPin, pin);
    await prefs.setString(_kRole, role);
    await prefs.setBool(_kEnabled, true);
  }

  static Future<Map<String, dynamic>?> storedCredentials() async {
    if (!await isEnabled()) return null;
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_kPhone);
    final pin = prefs.getString(_kPin);
    final userId = prefs.getInt(_kUserId);
    final role = prefs.getString(_kRole);
    if (phone == null || pin == null || userId == null) return null;
    return {
      'userId': userId,
      'phone': phone,
      'pin': pin,
      'role': role ?? 'agent',
    };
  }

  static Future<void> updateStoredPin(String newPin) async {
    if (!await isEnabled()) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPin, newPin);
  }
}
