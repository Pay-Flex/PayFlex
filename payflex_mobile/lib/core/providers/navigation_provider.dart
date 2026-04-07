import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier pour gérer l'index de navigation (Compatible Riverpod 3.x)
class NavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

/// Provider global pour la navigation client
final navigationIndexProvider = NotifierProvider<NavigationNotifier, int>(() {
  return NavigationNotifier();
});

/// Provider global pour la navigation agent
final agentNavigationIndexProvider = NotifierProvider<NavigationNotifier, int>(() {
  return NavigationNotifier();
});
