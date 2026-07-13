import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Messages destinés à l’interface : jamais de pile technique, d’exception ou de code HTTP brut.
abstract final class UserVisibleMessage {
  UserVisibleMessage._();

  static const network =
      'Impossible de joindre PayFlex. Vérifiez votre connexion internet et réessayez.';

  /// Bandeau debug uniquement (développeurs) — pas pour SnackBars / dialogs utilisateur.
  static const devBackendUnreachable =
      'Serveur de développement injoignable. Appui long sur le logo (connexion) '
      'ou sur le bandeau orange pour configurer l’adresse du PC.';

  static const timeout =
      'Le serveur met trop longtemps à répondre. Réessayez dans quelques instants.';

  static const unexpected =
      'Une erreur est survenue. Réessayez ou contactez le support PayFlex.';

  static const serverUnavailable =
      'Le service est momentanément indisponible. Réessayez dans quelques instants.';

  static const registrationFailed =
      'Impossible d’enregistrer l’inscription pour le moment. Vérifiez votre connexion ou contactez le support.';

  static String forNetworkError() => network;

  /// Erreur HTTP côté API (502, 503, 5xx…).
  static String forHttpStatus(int status, {String? fallback, String? apiMessage}) {
    if (status == 502 || status == 503 || status == 504) {
      return apiOrFallback(apiMessage, serverUnavailable);
    }
    if (status >= 500) {
      return apiOrFallback(apiMessage, serverUnavailable);
    }
    return apiOrFallback(apiMessage, fallback ?? unexpected);
  }

  /// Erreur inconnue côté app (catch) : ne jamais afficher [e] directement.
  static String forException(Object e) {
    if (e is TimeoutException) return timeout;
    if (e is SocketException) return forNetworkError();
    if (e is http.ClientException) return forNetworkError();
    if (e is HttpException) return forNetworkError();
    if (e is HandshakeException) return forNetworkError();
    if (e is TlsException) return forNetworkError();
    if (e is FormatException) return unexpected;
    if (_looksLikeNetworkError(e.toString())) return forNetworkError();
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

  static bool _looksLikeNetworkError(String s) {
    final lower = s.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection timed out') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection reset') ||
        lower.contains('software caused connection abort') ||
        lower.contains('handshakeexception');
  }

  static bool _looksTechnical(String s) {
    final lower = s.toLowerCase();
    if (s.length > 400) return true;
    if (lower.contains('exception')) return true;
    if (lower.contains('stack trace')) return true;
    if (lower.contains('stacktrace')) return true;
    if (_looksLikeNetworkError(lower)) return true;
    if (lower.contains('os error')) return true;
    if (lower.contains('errno')) return true;
    if (lower.contains('dart-define')) return true;
    if (lower.contains('127.0.0.1')) return true;
    if (lower.contains('localhost')) return true;
    if (lower.contains('http://') || lower.contains('https://')) return true;
    if (RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}\b').hasMatch(s)) return true;
    if (RegExp(r'\bat\s+\S+\.dart\b', caseSensitive: false).hasMatch(s)) return true;
    if (RegExp(r'\bat\s+io\.', caseSensitive: false).hasMatch(s)) return true;
    if (RegExp(r'\b(502|503|504)\b').hasMatch(s)) return true;
    return false;
  }
}
