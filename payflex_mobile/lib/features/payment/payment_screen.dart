import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/finance_provider.dart';
import '../../core/providers/navigation_provider.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedMethod = 'mobile_money';
  String _selectedProject = 'Moto Jakarta 100cc';
  bool _isProcessing = false;

  final List<String> _presets = ['1000', '2500', '5000', '10000', '25000'];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int get _casesCount {
    final amount = double.tryParse(_amountController.text) ?? 0;
    const dailyRate = 1500.0;
    if (dailyRate <= 0 || amount <= 0) return 0;
    return (amount / dailyRate).floor();
  }

  @override
  Widget build(BuildContext context) {
    final financeState = ref.watch(financeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // PAS de flèche retour automatique
        title: Text(
          'VALIDER COTISATION',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 15,
            color: AppColors.secondary,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Décor atmosphérique
          Positioned(
            top: 100, left: -80,
            child: _blob(AppColors.primary, 280),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .move(duration: 12.seconds, begin: const Offset(-20, -20), end: const Offset(20, 20)),

          Positioned(
            bottom: 200, right: -100,
            child: _blob(AppColors.secondary, 320),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .move(duration: 10.seconds, begin: const Offset(20, 10), end: const Offset(-20, -10)),

          // Contenu scrollable
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // === CARTE CLIENT ===
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.secondary, Color(0xFF1A2E5A)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: AppColors.secondary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 26,
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=payflex'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Chaminade Don',
                              style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                            Text('ID: PF-2024-8890',
                              style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                          ],
                        ),
                      ),
                      // Badge solde
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${financeState.balance.toInt()} FCFA',
                          style: GoogleFonts.manrope(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: 0.1),

                const SizedBox(height: 28),

                // === SÉLECTION PROJET ===
                _sectionTitle('PROJET CIBLE'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary, // Fond premium
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedProject,
                      isExpanded: true,
                      dropdownColor: AppColors.secondary, // Fond de la liste aussi en premium
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white), 
                      items: [
                        _selectedProject,
                        if (_selectedProject != 'Moto Jakarta 100cc') 'Moto Jakarta 100cc',
                      ].map((p) => DropdownMenuItem(
                        value: p, 
                        child: Text(p, style: const TextStyle(color: Colors.white)), // Texte blanc dans la liste
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedProject = v!),
                    ),
                  ),
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 24),

                // === SAISIE MONTANT ===
                _sectionTitle('MONTANT DE LA COTISATION'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
                    border: Border.all(color: AppColors.secondary.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.manrope(
                          fontSize: 44, fontWeight: FontWeight.w900,
                          color: AppColors.primary, // Montant en jaune PayFlex
                          letterSpacing: -1,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(color: AppColors.secondary.withOpacity(0.1)),
                          suffixText: 'FCFA',
                          suffixStyle: GoogleFonts.manrope(
                            fontWeight: FontWeight.w900, color: AppColors.secondary.withOpacity(0.3), fontSize: 14,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Presets
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _presets.map((p) {
                          final isSelected = _amountController.text == p;
                          return GestureDetector(
                            onTap: () => setState(() => _amountController.text = p),
                            child: AnimatedContainer(
                              duration: 200.ms,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : AppColors.secondary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
                              ),
                              child: Text(
                                '${int.parse(p) >= 1000 ? "${int.parse(p) ~/ 1000}k" : p} F',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? AppColors.secondary : AppColors.secondary.withOpacity(0.5),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),

                // Indicateur de cases cochées
                if (_casesCount > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FFF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF38A169).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF38A169), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.manrope(color: const Color(0xFF38A169), fontSize: 13),
                              children: [
                                TextSpan(
                                  text: '$_casesCount case${_casesCount > 1 ? "s" : ""} ',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                                const TextSpan(text: 'seront cochées dans votre carnet'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
                ],

                const SizedBox(height: 24),

                // === MODE DE PAIEMENT ===
                _sectionTitle('MODE DE PAIEMENT'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _paymentMethodCard(
                      'mobile_money',
                      Icons.phone_android_rounded,
                      'Mobile Money',
                      'Orange / MTN',
                    ),
                    const SizedBox(width: 12),
                    _paymentMethodCard(
                      'cash',
                      Icons.payments_rounded,
                      'Espèces',
                      'Via Agent',
                    ),
                  ],
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 36),

                // === BOUTON CONFIRMER ===
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: (_amountController.text.isEmpty || _isProcessing)
                      ? null
                      : () => _processPayment(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.secondary,
                      disabledBackgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                      shadowColor: AppColors.primary.withOpacity(0.4),
                    ),
                    child: _isProcessing
                      ? const CircularProgressIndicator(color: AppColors.secondary)
                      : Text(
                          'CONFIRMER LE PAIEMENT',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 15),
                        ),
                  ),
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentMethodCard(String id, IconData icon, String title, String subtitle) {
    final isSelected = _selectedMethod == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMethod = id),
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondary : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppColors.secondary : AppColors.secondary.withOpacity(0.08),
              width: 2,
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
          ),
          child: Column(
            children: [
              Icon(icon, size: 30, color: isSelected ? AppColors.primary : AppColors.secondary.withOpacity(0.5)),
              const SizedBox(height: 8),
              Text(title, style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppColors.secondary,
                fontSize: 13,
              )),
              Text(subtitle, style: GoogleFonts.inter(
                color: isSelected ? Colors.white.withOpacity(0.6) : Colors.grey,
                fontSize: 10,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
      style: GoogleFonts.manrope(
        fontSize: 10, fontWeight: FontWeight.w900,
        letterSpacing: 2, color: AppColors.secondary.withOpacity(0.4),
      ));
  }

  Widget _blob(Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color.withOpacity(0.04), shape: BoxShape.circle),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Future<void> _processPayment(BuildContext context) async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 800)); // Simulation paiement
    if (!mounted) return;
    setState(() => _isProcessing = false);

    ref.read(financeProvider.notifier).addTransaction(amount, _selectedProject);
    _showSuccessDialog(context, amount);
  }

  void _showSuccessDialog(BuildContext context, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FFF4), shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Color(0xFF38A169), size: 56),
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              Text('Cotisation Validée !',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 22, color: AppColors.secondary)),
              const SizedBox(height: 8),
              Text(
                '${amount.toInt()} FCFA ajoutés à votre carnet\n(${ _casesCount > 0 ? _casesCount : (amount / 1500).floor()} case${_casesCount != 1 ? "s" : ""} cochées)',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.secondary.withOpacity(0.6), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 8),
              // Mode de paiement confirmé
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _selectedMethod == 'mobile_money' ? Icons.phone_android_rounded : Icons.payments_rounded,
                      size: 16, color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedMethod == 'mobile_money' ? 'Payé via Mobile Money' : 'Payé en espèces (Agent)',
                      style: GoogleFonts.manrope(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // 1. Switch vers onglet 0 (Dashboard) D'ABORD
                  ref.read(navigationIndexProvider.notifier).setIndex(0);
                  
                  // 2. Ferme le dialog de succès
                  Navigator.of(dialogContext).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('RETOUR AU TABLEAU DE BORD',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
