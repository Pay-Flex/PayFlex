import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/auth_provider.dart';

class AgentValidationQueueScreen extends ConsumerStatefulWidget {
  const AgentValidationQueueScreen({super.key});

  @override
  ConsumerState<AgentValidationQueueScreen> createState() => _AgentValidationQueueScreenState();
}

class _AgentValidationQueueScreenState extends ConsumerState<AgentValidationQueueScreen> {
  final _api = MobileApiService();
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;
  bool _usingServer = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final auth = ref.read(authProvider);
    if (auth.userId != null && auth.phone != null && auth.pin != null) {
      final items = await _api.fetchPendingContributionsForAgent(
        validatorUserId: auth.userId!,
        phone: auth.phone!,
        pin: auth.pin!,
      );
      if (items.isNotEmpty) {
        setState(() {
          _pendingRequests = items.map(_mapServerItem).toList();
          _usingServer = true;
          _isLoading = false;
        });
        return;
      }
    }
    final local = await DatabaseService().getPendingTransactions();
    setState(() {
      _pendingRequests = local;
      _usingServer = false;
      _isLoading = false;
      if (local.isEmpty && auth.userId != null) {
        _loadError = 'Aucune cotisation smartphone en attente sur le serveur.';
      }
    });
  }

  Map<String, dynamic> _mapServerItem(Map<String, dynamic> item) {
    return {
      'id': item['id'],
      'client_name': item['client_name'] ?? 'Client',
      'project_title': item['product_name'] ?? 'Projet',
      'amount': item['amount'],
      'date': item['created_at'],
      'type': item['payment_mode'] ?? 'mobile_money',
      '_server': true,
    };
  }

  Future<void> _validate(Map<String, dynamic> req) async {
    final auth = ref.read(authProvider);
    final id = req['id'];
    if (_usingServer && auth.userId != null && auth.phone != null && auth.pin != null) {
      final err = await _api.validateContributionOnServer(
        validatorUserId: auth.userId!,
        phone: auth.phone!,
        pin: auth.pin!,
        contributionId: int.parse(id.toString()),
      );
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
        );
        return;
      }
    } else {
      await DatabaseService().updateTransactionStatus(id.toString(), 'validated');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cotisation validée — le client sera notifié sur son application.',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF38A169),
        ),
      );
    }
    _loadPending();
  }

  Future<void> _reject(String id, String reason, {required bool server}) async {
    final auth = ref.read(authProvider);
    if (server && auth.userId != null && auth.phone != null && auth.pin != null) {
      final err = await _api.rejectContributionOnServer(
        validatorUserId: auth.userId!,
        phone: auth.phone!,
        pin: auth.pin!,
        contributionId: int.parse(id),
        reason: reason,
      );
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
        );
        return;
      }
    } else {
      await DatabaseService().updateTransactionStatus(id, 'rejected', reason: reason);
    }
    _loadPending();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.secondary),
        ),
        title: Text(
          'Validation requise',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadPending,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.secondary),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingRequests.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _loadError ?? 'Aucune demande en attente.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(color: Colors.grey.shade600),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPending,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _usingServer
                              ? 'Cotisations smartphone (serveur PayFlex)'
                              : 'Cotisations en attente (mode hors ligne)',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Validez après vérification du paiement. Le centre (gestionnaire/admin) peut valider à votre place si vous êtes indisponible.',
                          style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey.shade500, height: 1.35),
                        ),
                        const SizedBox(height: 24),
                        ..._pendingRequests.map(_buildValidationCard),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  String _prettyTxDate(dynamic iso) {
    if (iso == null) return '—';
    final s = iso.toString();
    try {
      final d = DateTime.parse(s);
      return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return s;
    }
  }

  Widget _buildValidationCard(Map<String, dynamic> req) {
    final amt = (req['amount'] as num?)?.toDouble() ?? 0;
    final daily = (req['project_daily'] as num?)?.toDouble();
    final isServer = req['_server'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.04),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC6F6D5).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'COTISATION MOBILE',
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF38A169),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(_prettyTxDate(req['date']),
                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondary)),
              ],
            ),
            const SizedBox(height: 16),
            Text(req['client_name'] ?? 'Client',
                style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.secondary)),
            Text(req['project_title'] ?? 'Projet',
                style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Text('${amt.toInt()} FCFA',
                style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.secondary)),
            if (daily != null && daily > 0)
              Text('Réf. ~ ${daily.toInt()} F/jour',
                  style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectionReasonModal(context, req, isServer),
                    icon: const Icon(Icons.cancel_outlined, size: 20),
                    label: const Text('Rejeter'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _validate(req),
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text('Valider'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.secondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectionReasonModal(BuildContext context, Map<String, dynamic> req, bool isServer) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Motif de rejet', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              Text('Le client verra ce message dans l’application.',
                  style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ex. montant non reçu sur Mobile Money…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final reason = controller.text.trim().isEmpty
                      ? 'Versement non confirmé.'
                      : controller.text.trim();
                  Navigator.pop(ctx);
                  _reject(req['id'].toString(), reason, server: isServer);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Confirmer le rejet', style: GoogleFonts.manrope(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
