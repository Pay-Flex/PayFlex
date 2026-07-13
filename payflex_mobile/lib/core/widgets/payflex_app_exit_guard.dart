import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Intercepte le bouton retour Android sur les écrans racine connectés.
class PayflexAppExitGuard extends StatelessWidget {
  final Widget child;

  const PayflexAppExitGuard({super.key, required this.child});

  Future<bool> _confirmExit(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter PayFlex ?'),
        content: const Text('Voulez-vous vraiment quitter l\'application ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final quit = await _confirmExit(context);
        if (!quit) return;
        SystemNavigator.pop();
      },
      child: child,
    );
  }
}
