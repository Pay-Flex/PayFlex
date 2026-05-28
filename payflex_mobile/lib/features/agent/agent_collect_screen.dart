import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/auth_provider.dart';

class AgentCollectScreen extends ConsumerStatefulWidget {
  final String clientName;
  final int? clientId;
  final double initialDailyRate;

  const AgentCollectScreen({
    super.key,
    required this.clientName,
    this.clientId,
    this.initialDailyRate = 200,
  });

  @override
  ConsumerState<AgentCollectScreen> createState() => _AgentCollectScreenState();
}

class _AgentCollectScreenState extends ConsumerState<AgentCollectScreen> {
  final DatabaseService _db = DatabaseService();
  final MobileApiService _api = MobileApiService();
  final Set<int> _selectedDays = {};
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _secretCodeController = TextEditingController();

  double _dailyRate = 200;

  @override
  void initState() {
    super.initState();
    _dailyRate = widget.initialDailyRate;
    _hydrateDailyRate();
  }

  Future<void> _hydrateDailyRate() async {
    final cid = widget.clientId;
    if (cid == null) return;
    final v = await _db.getDailySuggestedForClient(cid);
    if (mounted && v != null && v > 0) {
      setState(() => _dailyRate = v);
    }
  }

  double get _calculatedAmount => _selectedDays.length * _dailyRate;

  /// Aligné sur les ids catalogue `prod_123` côté API PayFlex.
  int? _catalogProductIdFromProjectId(String projectId) {
    if (!projectId.startsWith('prod_')) return null;
    return int.tryParse(projectId.replaceFirst('prod_', ''));
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
      _amountController.text = _calculatedAmount.toInt().toString();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _secretCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAmountCorrect = (double.tryParse(_amountController.text) ?? 0) == _calculatedAmount;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: AppColors.secondary),
        ),
        title: Text(
          'Collecte de cotisations',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              if (widget.clientId == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFB7791F).withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFB7791F), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Associez un client enregistré pour vérifier son code PIN et créditer le bon projet.',
                            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${widget.clientId ?? 'guest'}'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.clientName,
                            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                        Text('Taux journalier : ${_dailyRate.toInt()} F / jour',
                            style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CALENDRIER DE COLLECTE',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.secondary.withOpacity(0.5),
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'Mai 2026',
                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.secondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: 14,
                itemBuilder: (context, index) {
                  final day = index + 1;
                  final isSelected = _selectedDays.contains(day);
                  final isAlreadyPaid = index < 4;

                  return GestureDetector(
                    onTap: isAlreadyPaid ? null : () => _toggleDay(day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isAlreadyPaid
                            ? const Color(0xFF2D3748)
                            : (isSelected ? const Color(0xFF48BB78) : const Color(0xFFEDF2F7)),
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: (isSelected || isAlreadyPaid) ? Colors.white : AppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isAmountCorrect ? Colors.transparent : Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MONTANT EN ESPÈCES',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.secondary.withOpacity(0.5),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.secondary),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '0',
                            ),
                          ),
                        ),
                        Text('FCFA', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!isAmountCorrect && _amountController.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Montant incohérent : ${_selectedDays.length} jour(s) sélectionné(s) = ${_calculatedAmount.toInt()} F requis.',
                          style: GoogleFonts.manrope(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ).animate().shake(),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: (_selectedDays.isEmpty || !isAmountCorrect) ? null : () => _showSecretCodeModal(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  disabledBackgroundColor: Colors.grey.shade200,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Valider la collecte (${_selectedDays.length} jours)',
                      style: GoogleFonts.manrope(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_rounded, color: Colors.white),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  static const int _maxSecretAttempts = 5;

  void _showSecretCodeModal(BuildContext rootContext) {
    _secretCodeController.clear();
    var attempts = 0;
    String? errorText;

    showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.62),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'VALIDATION CLIENT',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Code PIN du client',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.secondary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Le client ou vous-même saisissez son code pour confirmer ${_amountController.text} FCFA.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _secretCodeController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    maxLength: 8,
                    onChanged: (_) {
                      if (errorText != null) setModalState(() => errorText = null);
                    },
                    style: GoogleFonts.manrope(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 14,
                      color: AppColors.secondary,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••',
                      hintStyle: GoogleFonts.manrope(color: Colors.grey.shade200, letterSpacing: 14),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () async {
                      final cid = widget.clientId;
                      if (cid == null) {
                        Navigator.pop(sheetContext);
                        if (rootContext.mounted) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Client non relié à la base locale — ouvrez la collecte depuis la liste de vos clients.',
                                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      final secret = _secretCodeController.text;
                      if (secret.trim().length < 4) {
                        setModalState(() => errorText = 'Le code doit contenir au moins 4 caractères.');
                        return;
                      }

                      final ok = await _db.verifyClientSecretCode(clientId: cid, submitted: secret);
                      if (!ok) {
                        attempts++;
                        if (attempts >= _maxSecretAttempts) {
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          if (rootContext.mounted) {
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Trop de tentatives. Réessayez plus tard ou vérifiez le code avec le client.',
                                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                                ),
                              ),
                            );
                          }
                          return;
                        }
                        final maxS = _maxSecretAttempts;
                        setModalState(() => errorText = 'Code incorrect ($attempts/$maxS).');
                        return;
                      }

                      final authCollect = ref.read(authProvider);
                      final agentUserId = authCollect.userId;
                      final projectId = await _db.resolveProjectIdForContribution(clientUserId: cid);
                      if (projectId == null || projectId.isEmpty) {
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (rootContext.mounted) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Ce client n’a pas de projet actif (catalogue). Créez d’abord une épargne depuis le catalogue.',
                                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      final transId = DateTime.now().millisecondsSinceEpoch.toString();
                      final amount = double.tryParse(_amountController.text) ?? 0.0;
                      final dateStr = DateTime.now().toIso8601String();

                      await _db.addTransaction(
                        transId,
                        projectId,
                        amount,
                        dateStr,
                        'cash',
                        'pending',
                        agentId: agentUserId,
                        clientUserId: cid,
                      );

                      final clientPhone = await _db.getUserPhone(cid);
                      final productIdApi = _catalogProductIdFromProjectId(projectId);
                      var synced = false;
                      var syncAttempted = false;
                      if (agentUserId != null &&
                          authCollect.phone != null &&
                          authCollect.pin != null &&
                          clientPhone != null) {
                        syncAttempted = true;
                        final syncRes = await _api.sendAgentCashContribution(
                          clientPhone: clientPhone,
                          amount: amount,
                          referenceCode: transId,
                          collectorUserId: agentUserId,
                          collectorPhone: authCollect.phone!,
                          collectorPin: authCollect.pin!,
                          productId: productIdApi,
                        );
                        synced = syncRes != null;
                        if (syncRes?['status']?.toString() == 'validated') {
                          await _db.updateTransactionStatus(transId, 'validated');
                        }
                      }

                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (rootContext.mounted) {
                        if (syncAttempted && !synced) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Collecte enregistrée sur l’appareil. La base centrale n’a pas pu être mise à jour — réessayez (réseau) ou vérifiez que le client est validé et bien rattaché à vous en centre.',
                                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        } else if (!syncAttempted && clientPhone == null) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Collecte enregistrée localement. Ajoutez un numéro de téléphone sur la fiche client pour synchroniser avec le centre.',
                                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                        _showSuccessAnimation(rootContext);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(
                      'Confirmer le paiement',
                      style: GoogleFonts.manrope(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSuccessAnimation(BuildContext rootContext) {
    showDialog<void>(
      context: rootContext,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF48BB78), size: 100),
              const SizedBox(height: 16),
              Text(
                'Collecte enregistrée',
                style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.secondary),
              ),
              const SizedBox(height: 8),
              Text(
                'En attente de validation au centre (rapprochement fin de journée).',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ).animate().scale().fadeIn(),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (!rootContext.mounted) return;
      Navigator.of(rootContext).pop();
      Navigator.of(rootContext).pop();
    });
  }
}
