import 'package:shared_preferences/shared_preferences.dart';

/// Persistance du dernier moment d'activité utilisateur pour expirer la session après 30 min d'inactivité réelle.
///
/// Seuls les gestes, la navigation et la connexion prolongent la session — pas la mise en arrière-plan,
/// ni la sync push automatique.
class SessionTimeoutService {
  SessionTimeoutService._();

  static const Duration inactivityLimit = Duration(minutes: 30);
  static const String _kLastActiveAtMs = 'payflex_last_active_at_ms';

  static final SessionTimeoutService instance = SessionTimeoutService._();

  /// Cache mémoire pour éviter une expiration erronée si l'app est tuée avant l'écriture disque.
  int? _lastActiveAtMsCache;

  /// Message à afficher une fois après une expiration détectée au démarrage.
  bool pendingExpiredMessage = false;

  Future<void> recordActivity() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastActiveAtMsCache = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastActiveAtMs, now);
  }

  Future<DateTime?> lastActiveAt() async {
    final cached = _lastActiveAtMsCache;
    if (cached != null) {
      return DateTime.fromMillisecondsSinceEpoch(cached);
    }
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kLastActiveAtMs);
    if (ms == null) return null;
    _lastActiveAtMsCache = ms;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<bool> isExpired() async {
    final last = await lastActiveAt();
    if (last == null) return false;
    return DateTime.now().difference(last) >= inactivityLimit;
  }

  Future<void> clear() async {
    _lastActiveAtMsCache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastActiveAtMs);
    pendingExpiredMessage = false;
  }

  void markExpiredForMessage() {
    pendingExpiredMessage = true;
  }

  bool consumeExpiredMessage() {
    if (!pendingExpiredMessage) return false;
    pendingExpiredMessage = false;
    return true;
  }
}
