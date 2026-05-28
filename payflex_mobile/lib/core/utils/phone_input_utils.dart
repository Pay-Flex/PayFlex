/// Validation et normalisation des numéros saisis avec indicatif pays.
class PayflexPhoneValidator {
  PayflexPhoneValidator._();

  static const int minDigits = 8;

  static String digitsOnly(String? value) {
    if (value == null) return '';
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static String? validate(String? completeNumber, {bool required = true}) {
    final trimmed = completeNumber?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? 'Numéro de téléphone requis' : null;
    }
    final digits = digitsOnly(trimmed);
    if (digits.length < minDigits) {
      return 'Numéro invalide ($minDigits chiffres minimum)';
    }
    return null;
  }
}
