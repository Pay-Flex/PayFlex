import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';

/// Onglet bloqué tant que l'inscription n'est pas approuvée par le centre.
class RegistrationLockedTab extends ConsumerWidget {
  final String featureName;

  const RegistrationLockedTab({super.key, required this.featureName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checking = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top_rounded, size: 56, color: Colors.amber.shade800),
              const SizedBox(height: 20),
              Text(
                'En attente de validation',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'La section « $featureName » sera disponible après validation de votre inscription par PayFlex. En attendant, parcourez l’accueil, le catalogue et votre profil.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade700, height: 1.45),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: checking
                    ? null
                    : () async {
                        final ok = await ref.read(authProvider.notifier).tryActivateApprovedAccount();
                        if (!context.mounted) return;
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Compte activé — bienvenue sur PayFlex !')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Votre dossier n\'est pas encore validé. Réessayez plus tard.'),
                            ),
                          );
                        }
                      },
                icon: checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(checking ? 'Vérification…' : 'Vérifier mon activation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
