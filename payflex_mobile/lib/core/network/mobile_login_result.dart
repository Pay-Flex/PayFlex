import 'dart:convert';

import '../utils/user_visible_message.dart';

/// Résultat de [MobileApiService.login] : succès (profil serveur) ou échec avec message.
class MobileLoginResult {
  final bool success;
  final Map<String, dynamic>? profile;
  final String? message;
  /// Ex. invalid_identifier, invalid_secret, ambiguous_identity
  final String? errorCode;
  /// 200 si succès, 400/401 si refus serveur, null si erreur réseau / timeout.
  final int? httpStatus;

  const MobileLoginResult._({
    required this.success,
    this.profile,
    this.message,
    this.errorCode,
    this.httpStatus,
  });

  factory MobileLoginResult.ok(Map<String, dynamic> profile) {
    return MobileLoginResult._(success: true, profile: profile, httpStatus: 200);
  }

  /// Réponse HTTP d’erreur (corps JSON optionnel avec clé `message`).
  factory MobileLoginResult.httpError(int statusCode, String body) {
    final parsed = _parseErrorBody(body);
    final msg = parsed.message ?? _defaultHttpMessage(statusCode, parsed.errorCode);
    return MobileLoginResult._(
      success: false,
      message: msg,
      errorCode: parsed.errorCode,
      httpStatus: statusCode,
    );
  }

  factory MobileLoginResult.networkError(String message) {
    return MobileLoginResult._(
      success: false,
      message: message,
      httpStatus: null,
    );
  }

  static _ParsedError _parseErrorBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final code = decoded['errorCode']?.toString();
        final msg = decoded['message'] != null
            ? UserVisibleMessage.safeApiMessage(decoded['message'].toString())
            : null;
        return _ParsedError(message: msg, errorCode: code);
      }
    } catch (_) {}
    return const _ParsedError();
  }

  static String _defaultHttpMessage(int code, String? errorCode) {
    if (errorCode == 'invalid_identifier') {
      return 'Numéro ou e-mail incorrect. Utilisez votre téléphone (8 chiffres minimum) ou votre e-mail.';
    }
    if (errorCode == 'invalid_secret') {
      return 'Mot de passe ou code PIN incorrect.';
    }
    return switch (code) {
      400 => 'Donnée manquante ou invalide.',
      401 => 'Identifiants incorrects. Vérifiez numéro ou e-mail et mot de passe / code PIN.',
      409 => 'Plusieurs comptes correspondent. Contactez le support PayFlex.',
      403 => 'Accès refusé.',
      404 => 'Service indisponible pour le moment.',
      500 => 'Le service est surchargé. Réessayez dans quelques instants.',
      _ => 'Connexion impossible. Réessayez ou contactez le support.',
    };
  }

  bool get isInvalidIdentifier => errorCode == 'invalid_identifier';

  bool get isInvalidSecret => errorCode == 'invalid_secret';

  bool get isInvalidCredentials =>
      httpStatus == 401 || httpStatus == 400;

  /// Plusieurs comptes correspondent (nom/prénom ou numéro ambigu).
  bool get isAmbiguousIdentity =>
      errorCode == 'ambiguous_identity' || httpStatus == 409;

  bool get shouldTryLocalFallback =>
      !success && httpStatus == null;
}

class _ParsedError {
  final String? message;
  final String? errorCode;
  const _ParsedError({this.message, this.errorCode});
}
