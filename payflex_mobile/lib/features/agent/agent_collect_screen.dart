import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';
import '../../core/models/allocation_result.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/agent_provider.dart';
import '../../core/providers/auth_provider.dart';

const _moisFr = [
  '',
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

class AgentCollectScreen extends ConsumerStatefulWidget {
  final String clientName;
  final int? clientId;
  final double initialDailyRate;
  final List<Map<String, dynamic>> products;
  final int? initialProductId;
  final bool catchupMode;
  final List<int> paidDays;
  final List<int> catchupDays;
  final int calendarYear;
  final int calendarMonth;

  AgentCollectScreen({
    super.key,
    required this.clientName,
    this.clientId,
    this.initialDailyRate = 200,
    this.products = const [],
    this.initialProductId,
    this.catchupMode = false,
    this.paidDays = const [],
    this.catchupDays = const [],
    int? calendarYear,
    int? calendarMonth,
  }) : calendarYear = calendarYear ?? 0,
       calendarMonth = calendarMonth ?? 0;

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
  int? _selectedProductId;

  @override
  void initState() {
    super.initState();
    _dailyRate = widget.initialDailyRate;
    _selectedProductId = widget.initialProductId ??
        (widget.products.isNotEmpty ? (widget.products.first['product_id'] as num?)?.toInt() : null);
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

  int get _year => widget.calendarYear > 0 ? widget.calendarYear : DateTime.now().year;
  int get _month => widget.calendarMonth > 0 ? widget.calendarMonth : DateTime.now().month;

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  double get _calculatedAmount => _selectedDays.length * _dailyRate;

  void _toggleDay(int day) {
    if (widget.catchupMode) {
      setState(() {
        _selectedDays.clear();
        _selectedDays.add(day);
        _amountController.text = _dailyRate.toInt().toString();
      });
      return;
    }
    if (widget.paidDays.contains(day)) return;
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
    final isAmountCorrect = (double.tryParse(_amountController.text) ?? 0) == _calculatedAmount;
    final hasProduct = _selectedProductId != null;

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
          widget.catchupMode ? 'Rattrapage cotisation' : 'Collecte de cotisations',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(widget.clientName, style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.secondary)),
            Text('Taux : ${_dailyRate.toInt()} F / jour', style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Text('ARTICLE À CRÉDITER', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 10),
            if (widget.products.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFFFF8E6), borderRadius: BorderRadius.circular(14)),
                child: Text(
                  'Aucun article au dossier. Ajoutez un produit avant de collecter.',
                  style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              )
            else
              ...widget.products.map((p) {
                final id = (p['product_id'] as num?)?.toInt();
                final name = p['name']?.toString() ?? 'Article';
                final remaining = (p['remaining_fcfa'] as num?)?.toInt() ?? 0;
                final progress = (p['progress_percent'] as num?)?.toInt() ?? 0;
                final selected = id == _selectedProductId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: id == null ? null : () => setState(() => _selectedProductId = id),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade200, width: selected ? 2 : 1),
                      ),
                      child: Row(
                        children: [
                          Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded, color: selected ? AppColors.primary : Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 14)),
                                Text('Reste $remaining F · $progress%', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('CALENDRIER', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                Text('${_moisFr[_month]} $_year', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
              itemCount: _daysInMonth,
              itemBuilder: (context, index) {
                final day = index + 1;
                final isPaid = widget.paidDays.contains(day);
                final isCatchup = widget.catchupDays.contains(day);
                final isSelected = _selectedDays.contains(day);
                final canTap = widget.catchupMode ? isCatchup : !isPaid;

                Color bg;
                if (isPaid) {
                  bg = const Color(0xFF2D3748);
                } else if (isSelected) {
                  bg = widget.catchupMode ? Colors.orange.shade700 : const Color(0xFF48BB78);
                } else if (isCatchup && widget.catchupMode) {
                  bg = Colors.orange.shade200;
                } else {
                  bg = const Color(0xFFEDF2F7);
                }

                return GestureDetector(
                  onTap: canTap ? () => _toggleDay(day) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: isSelected ? Border.all(color: Colors.white, width: 2) : null),
                    child: Center(
                      child: Text('$day', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: (isPaid || isSelected) ? Colors.white : AppColors.secondary)),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isAmountCorrect ? Colors.transparent : Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MONTANT EN ESPÈCES', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.secondary),
                          decoration: const InputDecoration(border: InputBorder.none, hintText: '0'),
                        ),
                      ),
                      Text('FCFA', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
            ),
            if (!isAmountCorrect && _amountController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Montant attendu : ${_calculatedAmount.toInt()} F (${_selectedDays.length} jour(s))', style: GoogleFonts.manrope(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: (_selectedDays.isEmpty || !isAmountCorrect || !hasProduct) ? null : () => _showSecretCodeModal(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(
                widget.catchupMode ? 'Valider le rattrapage' : 'Valider la collecte (${_selectedDays.length} j)',
                style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 40),
          ],
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
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Code PIN du client', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _secretCodeController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    maxLength: 8,
                    onChanged: (_) {
                      if (errorText != null) setModalState(() => errorText = null);
                    },
                    decoration: const InputDecoration(counterText: '', hintText: '••••'),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(errorText!, style: GoogleFonts.manrope(color: Colors.red, fontSize: 12)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      await _confirmPayment(
                        sheetContext,
                        rootContext,
                        onError: (msg) => setModalState(() => errorText = msg),
                        getAttempts: () => attempts,
                        setAttempts: (v) => attempts = v,
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, minimumSize: const Size(double.infinity, 52)),
                    child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmPayment(
    BuildContext sheetContext,
    BuildContext rootContext, {
    required void Function(String) onError,
    required int Function() getAttempts,
    required void Function(int) setAttempts,
  }) async {
    final cid = widget.clientId;
    if (cid == null) return;

    final secret = _secretCodeController.text.trim();
    if (secret.length < 4) {
      onError('Le code doit contenir au moins 4 caractères.');
      return;
    }

    final authCollect = ref.read(authProvider);
    final agentUserId = authCollect.userId;
    var ok = false;
    if (agentUserId != null && authCollect.phone != null && authCollect.pin != null) {
      ok = await _api.verifyClientPin(
        agentUserId: agentUserId,
        phone: authCollect.phone!,
        pin: authCollect.pin!,
        clientUserId: cid,
        clientPin: secret,
      );
    }
    if (!ok) {
      ok = await _db.verifyClientSecretCode(clientId: cid, submitted: secret);
    }
    if (!ok) {
      final nextAttempts = getAttempts() + 1;
      setAttempts(nextAttempts);
      if (nextAttempts >= _maxSecretAttempts) {
        if (sheetContext.mounted) Navigator.pop(sheetContext);
        return;
      }
      onError('Code incorrect ($nextAttempts/$_maxSecretAttempts).');
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final productId = _selectedProductId;
    final days = _selectedDays.toList()..sort();
    var allSynced = true;
    var anyPending = false;
    var anyValidated = false;
    String? serverMessage;
    final allocations = <AllocationResult>[];

    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final transId = '${DateTime.now().millisecondsSinceEpoch}_$day';
      final dayAmount = widget.catchupMode || days.length == 1 ? amount : _dailyRate;
      final projectId = productId != null ? 'prod_$productId' : await _db.resolveProjectIdForContribution(clientUserId: cid);

      if (projectId != null && projectId.isNotEmpty) {
        await _db.addTransaction(transId, projectId, dayAmount, DateTime.now().toIso8601String(), 'cash', 'pending', agentId: agentUserId, clientUserId: cid);
      }

      if (agentUserId != null && authCollect.phone != null && authCollect.pin != null) {
        final clientPhone = await _db.getUserPhone(cid);
        final syncRes = await _api.sendAgentCashContribution(
          clientUserId: cid,
          clientPhone: clientPhone,
          clientPin: secret,
          amount: dayAmount,
          referenceCode: transId,
          collectorUserId: agentUserId,
          collectorPhone: authCollect.phone!,
          collectorPin: authCollect.pin!,
          productId: productId,
          catchupYear: widget.catchupMode ? _year : null,
          catchupMonth: widget.catchupMode ? _month : null,
          catchupDay: widget.catchupMode ? day : null,
        );
        if (syncRes == null) {
          allSynced = false;
        } else {
          serverMessage = syncRes['message']?.toString();
          final st = syncRes['status']?.toString();
          if (st == 'validated') {
            anyValidated = true;
            await _db.updateTransactionStatus(transId, 'validated');
            final alloc = AllocationResult.tryParse(syncRes);
            if (alloc != null) allocations.add(alloc);
          } else {
            anyPending = true;
          }
        }
      }
    }

    if (sheetContext.mounted) Navigator.pop(sheetContext);
    if (!rootContext.mounted) return;

    await ref.read(agentDataProvider.notifier).refresh(silent: true);

    if (!allSynced) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('Collecte enregistrée localement. Synchronisation partielle avec le serveur.')),
      );
    }

    _showSuccessAnimation(
      rootContext,
      pendingAtCentre: anyPending && !anyValidated,
      subtitle: serverMessage,
      allocations: allocations,
    );
  }

  void _showSuccessAnimation(
    BuildContext rootContext, {
    required bool pendingAtCentre,
    String? subtitle,
    List<AllocationResult> allocations = const [],
  }) {
    final split = allocations.any((a) => a.wasSplit);
    final title = split
        ? 'Répartition automatique'
        : pendingAtCentre
            ? 'Collecte saisie'
            : 'Collecte enregistrée';
    final detail = split
        ? allocations.map((a) => a.toFrenchMessage()).join('\n\n')
        : subtitle?.trim().isNotEmpty == true
            ? subtitle!.trim()
            : pendingAtCentre
                ? 'En attente de validation au centre (rapprochement fin de journée). Mode : espèces.'
                : 'Cotisation confirmée côté centre.';
    showDialog<void>(
      context: rootContext,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
        child: Container(
          width: split ? 320 : 280,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                split
                    ? Icons.call_split_rounded
                    : pendingAtCentre
                        ? Icons.schedule_rounded
                        : Icons.check_circle_rounded,
                color: split
                    ? AppColors.primary
                    : pendingAtCentre
                        ? Colors.orange.shade700
                        : const Color(0xFF48BB78),
                size: 88,
              ),
              const SizedBox(height: 16),
              Text(title, style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(detail, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.35)),
            ],
          ),
        ).animate().scale().fadeIn(),
      ),
    );

    Future.delayed(Duration(milliseconds: split ? 3200 : 1500), () {
      if (!rootContext.mounted) return;
      Navigator.of(rootContext).pop();
      Navigator.of(rootContext).pop(true);
    });
  }
}
