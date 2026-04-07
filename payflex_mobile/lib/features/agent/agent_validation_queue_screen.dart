import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';

class AgentValidationQueueScreen extends StatefulWidget {
  const AgentValidationQueueScreen({super.key});

  @override
  State<AgentValidationQueueScreen> createState() => _AgentValidationQueueScreenState();
}

class _AgentValidationQueueScreenState extends State<AgentValidationQueueScreen> {
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    final res = await DatabaseService().getPendingTransactions();
    setState(() {
      _pendingRequests = res;
      _isLoading = false;
    });
  }

  Future<void> _validate(String id) async {
    await DatabaseService().updateTransactionStatus(id, 'validated');
    _loadPending();
  }

  Future<void> _reject(String id, String reason) async {
    await DatabaseService().updateTransactionStatus(id, 'rejected', reason: reason);
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
          'Validation Requise',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _pendingRequests.isEmpty
          ? Center(child: Text('Aucune demande en attente.', style: GoogleFonts.manrope(color: Colors.grey)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cotisations smartphone en attente', 
                    style: GoogleFonts.manrope(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 24),
                  
                  ..._pendingRequests.map((req) => _buildValidationCard(req)).toList(),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildValidationCard(Map<String, dynamic> req) {
    // Incohérence simulée : si montant finit par 50 (démo)
    final bool incoherent = (req['amount'] ?? 0) % 200 != 0;

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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Header (Type & Time)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: incoherent ? Colors.red.withOpacity(0.1) : const Color(0xFFC6F6D5).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'UTILISATEUR SMARTPHONE',
                        style: GoogleFonts.manrope(
                          fontSize: 9, 
                          fontWeight: FontWeight.w900, 
                          color: incoherent ? Colors.red : const Color(0xFF38A169),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('INITIÉ', style: GoogleFonts.manrope(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey)),
                        Text('${req['time']} ${req['date']}', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Client Info
                Row(
                  children: [
                    Text(req['name'] ?? 'Client Inconnu', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                    const Spacer(),
                    Text('ID: ${req['id']}', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Amount Area
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _amountDetail('COTISATION DEMANDÉE', '${(req['amount'] ?? 0).toInt()} FCFA', AppColors.secondary),
                          _amountDetail('REÇU (${req['type'] ?? 'Mobile'})', '${(req['amount'] ?? 0).toInt()} FCFA', incoherent ? Colors.red : AppColors.secondary),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Progress bar cases
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDF2F7),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: FractionallySizedBox(
                                widthFactor: 1.0, // Démo relative
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: incoherent ? Colors.red.withOpacity(0.3) : const Color(0xFF38A169),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${((req['amount'] ?? 0) / 200).toInt()} Cases', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: incoherent ? Colors.red.withOpacity(0.6) : const Color(0xFF38A169))),
                        ],
                      ),
                    ],
                  ),
                ),
                
                if (incoherent) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.withOpacity(0.3), style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ALERTE : Montant Insuffisant', style: GoogleFonts.manrope(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w800)),
                              Text('Le montant reçu ne correspond pas au nombre de cases déclarées.', style: GoogleFonts.manrope(color: Colors.red.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().shake(),
                ],
                
                const SizedBox(height: 24),
                
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRejectionReasonModal(context, req),
                        icon: const Icon(Icons.cancel_outlined, size: 20),
                        label: const Text('Rejeter avec motif'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: Colors.grey.shade600,
                          side: BorderSide(color: Colors.grey.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: incoherent ? null : () => _validate(req['id']),
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
        ],
      ),
    );
  }

  Widget _amountDetail(String label, String amount, Color color) {
    return Column(
      crossAxisAlignment: color == Colors.red ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(amount, style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  void _showRejectionReasonModal(BuildContext context, Map<String, dynamic> req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 24),
            Text('MOTIF DE REJET', 
              style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.red, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text('Pourquoi rejetez-vous cette cotisation ?', 
              style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.secondary)),
            const SizedBox(height: 8),
            Text('Le client recevra cette explication sur son application.', style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey)),
            
            const SizedBox(height: 32),
            
            _rejectionOption('Montant reçu insuffisant'),
            _rejectionOption('Erreur sur le mode de paiement'),
            _rejectionOption('Fraude suspectée sur le ticket'),
            _rejectionOption('Autre raison technique'),
            
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Saisissez un motif personnalisé...',
                hintStyle: GoogleFonts.manrope(fontSize: 13, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF7FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 3,
            ),
            
            const Spacer(),
            
            ElevatedButton(
              onPressed: () {
                _reject(req['id'], 'Montant reçu insuffisant'); // Simplification pour la démo
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text('Confirmer le rejet', style: GoogleFonts.manrope(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rejectionOption(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.radio_button_unchecked, color: Colors.grey.shade300, size: 20),
          const SizedBox(width: 12),
          Text(title, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.secondary)),
        ],
      ),
    );
  }
}
