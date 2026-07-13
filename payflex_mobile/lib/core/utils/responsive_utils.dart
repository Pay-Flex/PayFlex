import 'package:flutter/material.dart';

/// Cible tactile minimale recommandée (Material / accessibilité) : 48dp.
const double kMinTouchTarget = 48.0;

extension ResponsiveUtils on BuildContext {
  /// Retourne la largeur totale moins 80px (marge de 40px de chaque côté).
  /// Idéal pour éviter les overflows et aérer l'interface. ✨📈
  double get gx => MediaQuery.of(this).size.width - 80;

  /// Retourne la largeur totale de l'écran.
  double get totalWidth => MediaQuery.of(this).size.width;

  /// Retourne un padding horizontal standard de 40px.
  EdgeInsets get hp40 => const EdgeInsets.symmetric(horizontal: 40);

  /// `true` si l'écran est étroit (petits téléphones ~320-360px).
  bool get isCompactWidth => MediaQuery.of(this).size.width < 360;

  /// Padding horizontal adaptatif : réduit sur les petits écrans pour laisser
  /// respirer le contenu (grilles, calendrier) sans rogner les cibles tactiles.
  ///
  /// [max] est utilisé sur les grands écrans, [min] sur les plus étroits.
  double responsiveHPadding({double max = 40, double min = 16}) {
    final w = MediaQuery.of(this).size.width;
    if (w >= 400) return max;
    if (w <= 320) return min;
    // Interpolation linéaire entre 320 et 400px.
    final t = (w - 320) / (400 - 320);
    return min + (max - min) * t;
  }
}
