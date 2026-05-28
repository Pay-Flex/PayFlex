/// Résultat de la demande de récupération de compte (étape vérification).
class RecoveryRequestOutcome {
  final bool ok;
  final String? resetToken;
  final String? message;

  RecoveryRequestOutcome._({required this.ok, this.resetToken, this.message});

  factory RecoveryRequestOutcome.ok(String token) {
    return RecoveryRequestOutcome._(ok: true, resetToken: token, message: null);
  }

  factory RecoveryRequestOutcome.fail(String message) {
    return RecoveryRequestOutcome._(ok: false, resetToken: null, message: message);
  }
}
