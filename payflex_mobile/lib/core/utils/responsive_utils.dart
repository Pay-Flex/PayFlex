import 'package:flutter/material.dart';

extension ResponsiveUtils on BuildContext {
  /// Retourne la largeur totale moins 80px (marge de 40px de chaque côté).
  /// Idéal pour éviter les overflows et aérer l'interface. ✨📈
  double get gx => MediaQuery.of(this).size.width - 80;
  
  /// Retourne la largeur totale de l'écran.
  double get totalWidth => MediaQuery.of(this).size.width;

  /// Retourne un padding horizontal standard de 40px.
  EdgeInsets get hp40 => const EdgeInsets.symmetric(horizontal: 40);
}
