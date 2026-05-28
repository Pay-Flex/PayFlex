import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Messages destinés à l’interface : jamais de pile technique, d’exception ou de code HTTP brut.
abstract final class UserVisibleMessage {
  UserVisibleMessage._();

  static const network =
      'Connexion instable. Vérifiez le Wi‑Fi ou les données mobiles, puis réessayez.';

  static const timeout =
      'Le serveur met trop longtemps à répondre. Réessayez dans un instant.';

  static const unexpected =
      'Une erreur est survenue. Réessayez ou contactez le support PayFlex.';

  static const serverUnavailable =
      'Le service est momentanément indisponible. Réessayez plus tard.';

  static const registrationFailed =
      'Impossible d’enregistrer l’inscription pour le moment. Vérifiez votre connexion ou contactez le support.';

  /// Erreur inconnue côté app (catch) : ne jamais afficher [e] directement.
  static String forException(Object e) {
    if (e is TimeoutException) return timeout;
    if (e is SocketException) return network;
    if (e is http.ClientException) return network;
    if (e is HttpException) return network;
    if (e is FormatException) return unexpected;
    return unexpected;
  }

  /// Filtre les réponses JSON `message` qui ressemblent à une erreur système.
  static String? safeApiMessage(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (_looksTechnical(t)) return null;
    return t;
  }

  static String apiOrFallback(String? raw, String fallback) =>
      safeApiMessage(raw) ?? fallback;

  static bool _looksTechnical(String s) {
    final lower = s.toLowerCase();
    if (s.length > 400) return true;
    if (lower.contains('exception')) return true;
    if (lower.contains('stack trace')) return true;
    if (lower.contains('failed host lookup')) return true;
    if (lower.contains('connection refused')) return true;
    if (lower.contains('socketexception')) return true;
    if (RegExp(r'\bat\s+\S+\.dart\b', caseSensitive: false).hasMatch(s)) return true;
    if (RegExp(r'\bat\s+io\.', caseSensitive: false).hasMatch(s)) return true;
    return false;
  }
}
