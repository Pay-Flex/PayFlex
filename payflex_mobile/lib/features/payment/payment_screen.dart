import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'fedapay_checkout_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';
import '../../core/providers/finance_provider.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/payflex_phone_field.dart';
import '../../core/utils/phone_input_utils.dart';
import 'contribution_receipt_screen.dart';
import 'payment_success_screen.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedMethod = 'mobile_money';
  String _selectedMobileProvider = 'Flooz';
  String? _selectedProjectId;
  bool _isProcessing = false;
  bool _useAlternatePayerPhone = false;
  final TextEditingController _payerPhoneController = TextEditingController();
  final GlobalKey<FormState> _payerPhoneFormKey = GlobalKey<FormState>();

  final List<String> _presetsExtra = ['1000', '2500', '5000', '10000', '25000'];
  final _mobileApi = MobileApiService();

  @override
  void dispose() {
    _amountController.dispose();
    _payerPhoneController.dispose();
    super.dispose();
  }

  double get _dailyRate {
    final fin = ref.read(financeProvider);
    if (_selectedProjectId == null) return 0;
    try {
      return fin.projects.firstWhere((p) => p.id == _selectedProjectId).dailySuggested;
    } catch (_) {
      return fin.projects.isNotEmpty ? fin.projects.first.dailySuggested : 0;
    }
  }

  int get _casesCount {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final dailyRate = _dailyRate;
    if (dailyRate <= 0 || amount <= 0) return 0;
    return (amount / dailyRate).floor();
  }

  List<String> _presetAmounts(double daily) {
    final base = <String>{..._presetsExtra};
    if (daily > 0) {
      base.add(daily.ceil().toString());
      base.add((daily * 7).ceil().toString());
      base.add((daily * 30).ceil().toString());
    }
    final sorted = base.map((s) => int.tryParse(s) ?? 0).where((n) => n > 0).toSet().toList()..sort();
    return sorted.take(9).map((n) => n.toString()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final financeState = ref.watch(financeProvider);
    final auth = ref.watch(authProvider);
    final projects = financeState.projects;
    final ids = projects.map((p) => p.id).toList();
    if (_selectedProjectId == null || (_selectedProjectId != null && !ids.contains(_selectedProjectId))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedProjectId = ids.isNotEmpty ? ids.first : null);
      });
    }
    final daily = _dailyRate;
    final presets = _presetAmounts(daily);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true,
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
                if (projects.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        'Aucun projet d’épargne.\nChoisissez un produit dans le catalogue pour cotiser.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: AppColors.secondary.withOpacity(0.7)),
                      ),
                    ),
                  )
                else ...[
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
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primary.withOpacity(0.25),
                        child: Text(
                          (auth.name != null && auth.name!.trim().isNotEmpty)
                              ? auth.name!.trim()[0].toUpperCase()
                              : 'P',
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(auth.name ?? 'Client PayFlex',
                              style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                            Text(
                              auth.uniqueCode != null && auth.uniqueCode!.trim().isNotEmpty
                                  ? 'Code : ${auth.uniqueCode}'
                                  : (auth.phone ?? '—'),
                              style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 11),
                            ),
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
                          formatFcfaLong(financeState.balance),
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
                      value: _selectedProjectId != null && ids.contains(_selectedProjectId) ? _selectedProjectId : null,
                      isExpanded: true,
                      dropdownColor: AppColors.secondary,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white),
                      hint: Text('Choisir un projet', style: GoogleFonts.manrope(color: Colors.white54)),
                      items: projects
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p.id,
                              child: Text(p.title, style: const TextStyle(color: Colors.white)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) async {
                        setState(() => _selectedProjectId = v);
                        final uid = ref.read(authProvider).userId;
                        if (v != null && uid != null) {
                          await DatabaseService().setUserCurrentProject(uid, v);
                          await ref.read(financeProvider.notifier).reload();
                        }
                      },
                    ),
                  ),
                ).animate().fadeIn(delay: 100.ms),
                if (daily > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Référence plan : ~${formatFcfaLong(daily)} / jour pour ce projet.',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.secondary.withOpacity(0.45)),
                  ),
                ],

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
                        spacing: 10, runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: presets.map((p) {
                          final isSelected = _amountController.text == p;
                          return GestureDetector(
                            onTap: () => setState(() => _amountController.text = p),
                            child: AnimatedContainer(
                              duration: 200.ms,
                              constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : AppColors.secondary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
                              ),
                              child: Text(
                                formatFcfa(int.parse(p)),
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? AppColors.secondary : AppColors.secondary.withOpacity(0.6),
                                  fontSize: 15,
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
                if (_selectedMethod == 'mobile_money') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.secondary.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        _providerChip('Flooz'),
                        const SizedBox(width: 8),
                        _providerChip('Mix by Yas'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _payerPhoneSection(),
                ],

                const SizedBox(height: 36),

                // === BOUTON CONFIRMER ===
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: (projects.isEmpty || _amountController.text.isEmpty || _isProcessing)
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

    final paymentMode = _selectedMethod == 'mobile_money' ? 'mobile_money' : 'cash';

    String? payerPhone;
    if (paymentMode == 'mobile_money' && _useAlternatePayerPhone) {
      if (!(_payerPhoneFormKey.currentState?.validate() ?? false)) {
        return;
      }
      final entered = _payerPhoneController.text.trim();
      if (entered.isNotEmpty) payerPhone = entered;
    }

    setState(() => _isProcessing = true);

    final auth = ref.read(authProvider);
    final productIdApi = _selectedProjectId != null
        ? int.tryParse(_selectedProjectId!.replaceAll(RegExp(r'[^0-9]'), ''))
        : null;
    String? serverContributionId;
    var fedapayValidated = false;

    if (auth.userId != null && paymentMode == 'mobile_money') {
      final fedapayInit = await _mobileApi.initFedapayContribution(
        userId: auth.userId!,
        amount: amount,
        productId: productIdApi,
        payerPhone: payerPhone,
      );
      final fedapayOn = fedapayInit?['fedapayEnabled'] == true;
      if (fedapayOn && (fedapayInit?['paymentUrl']?.toString().isNotEmpty ?? false)) {
        final paymentUrl = fedapayInit?['paymentUrl']?.toString() ?? '';
        final contributionId = (fedapayInit?['contributionId'] as num?)?.toInt();
        serverContributionId = contributionId?.toString();
        if (paymentUrl.isNotEmpty && contributionId != null && context.mounted) {
          setState(() => _isProcessing = false);
          final checkout = await Navigator.of(context).push<FedapayCheckoutResult>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => FedapayCheckoutScreen(
                paymentUrl: paymentUrl,
                contributionId: contributionId,
                userId: auth.userId!,
                amountFcfa: amount.round(),
                callbackUrl: fedapayInit?['callbackUrl']?.toString() ?? '',
              ),
            ),
          );
          if (!context.mounted) return;
          if (checkout == null || checkout.outcome == FedapayCheckoutOutcome.cancelled) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Paiement annulé. Vous pouvez réessayer quand vous voulez.',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          if (checkout.outcome == FedapayCheckoutOutcome.rejected) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Paiement non confirmé par FedaPay.',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          fedapayValidated = checkout.outcome == FedapayCheckoutOutcome.validated;
        }
      } else {
        // FedaPay non configuré, erreur API ou lien absent → déclaration classique
        final apiRes = await _mobileApi.sendContribution(
          userId: auth.userId!,
          amount: amount,
          paymentMode: paymentMode,
          productId: productIdApi,
        );
        serverContributionId = apiRes?['id']?.toString();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);
    final recorded = await ref.read(financeProvider.notifier).addContribution(
      amount,
      paymentMode: paymentMode,
      contributorUserId: auth.userId,
      transactionId: serverContributionId,
    );
    if (!recorded && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aucun projet d’épargne actif. Choisissez d’abord un produit dans le catalogue.',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (auth.userId != null && paymentMode != 'mobile_money') {
      try {
        await _mobileApi.sendContribution(
          userId: auth.userId!,
          amount: amount,
          paymentMode: paymentMode,
          productId: productIdApi,
        );
      } catch (_) {}
    }
    if (!context.mounted) return;
    _showSuccessDialog(
      context,
      amount,
      awaitingAgentValidation: paymentMode == 'mobile_money' && !fedapayValidated,
      fedapayConfirmed: fedapayValidated,
    );
  }

  void _showSuccessDialog(
    BuildContext context,
    double amount, {
    required bool awaitingAgentValidation,
    bool fedapayConfirmed = false,
  }) {
    final fin = ref.read(financeProvider);
    double rate = 0;
    String? productName;
    if (_selectedProjectId != null) {
      try {
        final p = fin.projects.firstWhere((p) => p.id == _selectedProjectId);
        rate = p.dailySuggested;
        productName = p.title;
      } catch (_) {
        rate = fin.projects.isNotEmpty ? fin.projects.first.dailySuggested : 0;
        productName = fin.projects.isNotEmpty ? fin.projects.first.title : null;
      }
    }
    final slotsApprox = rate > 0 ? (amount / rate).floor() : _casesCount;
    final slotsLabel = slotsApprox > 0 ? slotsApprox : _casesCount;

    final refTx = 'PF-${DateTime.now().millisecondsSinceEpoch}';
    final paidAt = DateTime.now();
    final paymentModeLabel =
        _selectedMethod == 'mobile_money' ? 'Payé via $_selectedMobileProvider' : 'Payé en espèces (Agent)';

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (screenContext) => PaymentSuccessScreen(
          amount: amount,
          awaitingAgentValidation: awaitingAgentValidation,
          fedapayConfirmed: fedapayConfirmed,
          paymentModeLabel: paymentModeLabel,
          slotsCount: slotsLabel,
          productName: productName,
          onDone: () {
            ref.read(navigationIndexProvider.notifier).setIndex(0);
            Navigator.of(screenContext).pop();
          },
          onViewReceipt: () {
            Navigator.of(screenContext).pop();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContributionReceiptScreen(
                  amount: amount,
                  reference: refTx,
                  paidAt: paidAt,
                  paymentModeLabel: paymentModeLabel,
                  slotsCount: slotsLabel,
                  awaitingValidation: awaitingAgentValidation,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _payerPhoneSection() {
    final auth = ref.watch(authProvider);
    final accountPhone = (auth.phone != null && auth.phone!.trim().isNotEmpty)
        ? auth.phone!.trim()
        : 'Numéro du compte';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smartphone_rounded, size: 18, color: AppColors.secondary.withOpacity(0.6)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Numéro de paiement',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: AppColors.secondary,
                      ),
                    ),
                    Text(
                      _useAlternatePayerPhone ? 'Autre numéro Mobile Money' : accountPhone,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.secondary.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _useAlternatePayerPhone = !_useAlternatePayerPhone),
            child: Row(
              children: [
                Icon(
                  _useAlternatePayerPhone
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Utiliser un autre numéro',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_useAlternatePayerPhone) ...[
            const SizedBox(height: 12),
            Form(
              key: _payerPhoneFormKey,
              child: PayflexPhoneField(
                completeNumberController: _payerPhoneController,
                hint: 'Numéro du payeur (Flooz / Mixx by Yas)',
                validator: (v) => PayflexPhoneValidator.validate(v),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Le paiement Mobile Money sera demandé sur ce numéro.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.secondary.withOpacity(0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _providerChip(String label) {
    final isSelected = _selectedMobileProvider == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMobileProvider = label),
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.secondary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isSelected ? AppColors.secondary : AppColors.secondary.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}
