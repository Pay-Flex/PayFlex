import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférence d'accessibilité « Texte plus grand ».
///
/// Quand elle est active, l'app applique un facteur d'agrandissement du texte
/// (combiné et borné avec le réglage système Android pour éviter les overflows).
/// La valeur est persistée localement.
class UiScaleNotifier extends Notifier<bool> {
  static const _prefKey = 'payflex_large_text';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool(_prefKey) ?? false;
      if (value != state) state = value;
    } catch (_) {}
  }

  Future<void> toggle() => set(!state);

  Future<void> set(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }

  /// Facteur d'agrandissement supplémentaire appliqué lorsque l'option est
  /// activée (au-dessus du réglage système). ~15 % suffit pour améliorer la
  /// lisibilité sans casser les mises en page.
  double get boostFactor => state ? 1.15 : 1.0;
}

final uiScaleProvider = NotifierProvider<UiScaleNotifier, bool>(UiScaleNotifier.new);
