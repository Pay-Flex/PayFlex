/// Formatage monétaire FCFA pour le Togo.
///
/// Règles : nombres entiers (pas de décimales), séparateur de milliers = espace
/// insécable fine, suffixe « F » par défaut. Exemples : `25 000 F`, `1 500 000 F`.
///
/// Utiliser [formatFcfa] partout où un montant est affiché (paiement, tableau de
/// bord, reçus…) afin d'avoir un rendu cohérent et lisible pour tous les profils.
library;

/// Espace insécable fine (U+202F) : évite les retours à la ligne au milieu
/// d'un montant et reste lisible pour les personnes peu à l'aise avec l'écrit.
const String _kThinNbsp = '\u202F';

/// Retourne un montant FCFA formaté, ex. `25 000 F`.
///
/// [amount] est arrondi à l'entier le plus proche (aucune décimale).
/// [suffix] : `'F'` par défaut ; passer `'FCFA'` pour la forme longue.
/// [withSuffix] : mettre à `false` pour n'obtenir que le nombre groupé.
String formatFcfa(
  num amount, {
  String suffix = 'F',
  bool withSuffix = true,
}) {
  final rounded = amount.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();

  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) {
      buffer.write(_kThinNbsp);
    }
    buffer.write(digits[i]);
  }

  final grouped = '${negative ? '-' : ''}$buffer';
  if (!withSuffix) return grouped;
  return '$grouped$_kThinNbsp$suffix';
}

/// Variante longue : `25 000 FCFA`.
String formatFcfaLong(num amount) => formatFcfa(amount, suffix: 'FCFA');
