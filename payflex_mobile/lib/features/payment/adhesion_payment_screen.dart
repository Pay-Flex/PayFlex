import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/utils/user_visible_message.dart';
import 'fedapay_checkout_screen.dart';

/// Paiement de l’adhésion PayFlex (250 FCFA) via FedaPay ou consigne espèces agent.
class AdhesionPaymentScreen extends ConsumerStatefulWidget {
  const AdhesionPaymentScreen({super.key});

  @override
  ConsumerState<AdhesionPaymentScreen> createState() => _AdhesionPaymentScreenState();
}

class _AdhesionPaymentScreenState extends ConsumerState<AdhesionPaymentScreen> {
  final _api = MobileApiService();
  bool _loading = false;

  Future<void> _payWithFedaPay() async {
    final auth = ref.read(authProvider);
    final uid = auth.userId;
    final phone = auth.phone?.trim() ?? '';
    final pin = auth.pin?.trim() ?? '';
    if (uid == null || phone.isEmpty || pin.isEmpty) {
      _snack('Session invalide. Reconnectez-vous.');
      return;
    }
    setState(() => _loading = true);
    final init = await _api.initFedapayAdhesion(userId: uid, phone: phone, pin: pin);
    if (!mounted) return;
    setState(() => _loading = false);
    if (init == null) {
      _snack(UserVisibleMessage.network);
      return;
    }
    if (init['fedapayEnabled'] != true) {
      _snack(
        UserVisibleMessage.apiOrFallback(
          init['message']?.toString(),
          'Paiement mobile indisponible. Réglez en espèces auprès de votre agent.',
        ),
      );
      return;
    }
    final url = init['paymentUrl']?.toString();
    if (url == null || url.isEmpty) {
      _snack('Lien de paiement indisponible.');
      return;
    }
    final amount = (init['amountFcfa'] as num?)?.toInt() ?? auth.adhesionFeeFcfa;
    final result = await Navigator.push<FedapayCheckoutResult>(
      context,
      MaterialPageRoute(
        builder: (_) => FedapayCheckoutScreen(
          paymentUrl: url,
          userId: uid,
          amountFcfa: amount,
          adhesionMode: true,
          phone: phone,
          pin: pin,
          callbackUrl: init['callbackUrl']?.toString() ?? '',
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result.outcome == FedapayCheckoutOutcome.validated) {
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      ref.read(navigationIndexProvider.notifier).setIndex(0);
      _snack('Adhésion confirmée ! Cotisations et paiements sont activés.', success: true);
      Navigator.pop(context, true);
    } else if (result.outcome == FedapayCheckoutOutcome.rejected) {
      _snack('Paiement refusé ou annulé.');
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? const Color(0xFF38A169) : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final hasAgent = auth.assignedAgentName != null && auth.assignedAgentName!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Adhésion PayFlex',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.secondary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.verified_user_rounded, size: 48, color: Colors.orange.shade800),
                  const SizedBox(height: 12),
                  Text(
                    '${auth.adhesionFeeFcfa} FCFA',
                    style: GoogleFonts.manrope(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'L’adhésion active les cotisations et les paiements produits.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 14, height: 1.45, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (hasAgent) ...[
              Text(
                'Option 1 — Espèces',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Remettez ${auth.adhesionFeeFcfa} FCFA en espèces à ${auth.assignedAgentName!.trim()}'
                  '${auth.assignedAgentPhone != null && auth.assignedAgentPhone!.trim().isNotEmpty ? ' (${auth.assignedAgentPhone})' : ''}. '
                  'Il confirmera l’adhésion dans son application agent.',
                  style: GoogleFonts.inter(fontSize: 13, height: 1.45),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Option 2 — Mobile money',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary),
              ),
              const SizedBox(height: 8),
            ],
            ElevatedButton(
              onPressed: _loading ? null : _payWithFedaPay,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      hasAgent ? 'Payer par mobile money (FedaPay)' : 'Payer l’adhésion (FedaPay)',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                    ),
            ),
            if (!hasAgent) ...[
              const SizedBox(height: 16),
              Text(
                'Sans agent parrain, le paiement mobile money est le moyen le plus rapide. '
                'Un agent peut aussi vous être assigné plus tard par PayFlex.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
