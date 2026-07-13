import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/catalogue_provider.dart';
import '../../core/providers/finance_provider.dart';

/// Configuration du rythme de cotisation après validation du panier (spec PDF §13–15).
class ContributionConfigScreen extends ConsumerStatefulWidget {
  const ContributionConfigScreen({super.key});

  @override
  ConsumerState<ContributionConfigScreen> createState() => _ContributionConfigScreenState();
}

class _ContributionConfigScreenState extends ConsumerState<ContributionConfigScreen> {
  static const _presets = [200.0, 500.0, 1000.0, 3000.0];
  double _daily = 500;
  bool _custom = false;
  final _customCtrl = TextEditingController(text: '500');

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  int get _daysNeeded {
    if (_daily <= 0) return 0;
    return (ref.read(catalogueProvider).cartTotal / _daily).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(catalogueProvider);
    final cart = catalogue.cart;
    final total = catalogue.cartTotal;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Rythme de cotisation', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.secondary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _summaryCard(total, cart.length),
          const SizedBox(height: 20),
          Text('Montant par versement', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((p) {
              final sel = !_custom && _daily == p;
              return ChoiceChip(
                label: Text('${p.toInt()} F', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                selected: sel,
                onSelected: (_) => setState(() {
                  _custom = false;
                  _daily = p;
                  _customCtrl.text = p.toInt().toString();
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Montant personnalisé (FCFA)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) {
              final n = double.tryParse(v.replaceAll(' ', ''));
              if (n != null && n > 0) {
                setState(() {
                  _custom = true;
                  _daily = n;
                });
              }
            },
          ),
          const SizedBox(height: 20),
          Slider(
            value: _daily.clamp(200, 10000),
            min: 200,
            max: 10000,
            divisions: 98,
            label: '${_daily.toInt()} F',
            onChanged: (v) => setState(() {
              _daily = v;
              _custom = true;
              _customCtrl.text = v.toInt().toString();
            }),
          ),
          _estimateCard(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Votre discipline vous rapproche de vos outils !',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: cart.isEmpty ? null : () => _validateCart(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Valider la configuration', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(double total, int lines) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Panier', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
          Text('$lines article(s) — ${total.toInt()} FCFA', style: GoogleFonts.inter(color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _estimateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Total outils', '${ref.read(catalogueProvider).cartTotal.toInt()} FCFA'),
          _row('Cotisation choisie', '${_daily.toInt()} FCFA'),
          _row('Nombre de versements', '$_daysNeeded'),
          _row('Durée estimée', _daysNeeded > 0 ? '~$_daysNeeded jours (1/jour)' : '—'),
        ],
      ),
    );
  }

  Future<void> _validateCart(BuildContext context) async {
    final catalogue = ref.read(catalogueProvider);
    final cart = catalogue.cart;
    if (cart.isEmpty) return;
    final db = DatabaseService();
    final uid = ref.read(authProvider).userId;
    final total = catalogue.cartTotal;
    for (final line in cart) {
      final share = total > 0 ? (_daily * line.lineTotal / total) : _daily;
      await db.addProject(
        line.product.id,
        line.quantity > 1 ? '${line.product.name} (×${line.quantity})' : line.product.name,
        line.lineTotal,
        share,
      );
    }
    if (uid != null) {
      await db.setUserCurrentProject(uid, cart.first.product.id);
    }
    await ref.read(financeProvider.notifier).reload();
    ref.read(catalogueProvider.notifier).clearCart();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${cart.length} projet(s) démarré(s). Votre panier a été vidé.',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF38A169),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700)),
            Text(v, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 13)),
          ],
        ),
      );
}
