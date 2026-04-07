import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';

class AgentCollectScreen extends StatefulWidget {
  final String clientName;
  final double dailyRate;
  
  const AgentCollectScreen({
    super.key, 
    required this.clientName, 
    this.dailyRate = 200.0,
  });

  @override
  State<AgentCollectScreen> createState() => _AgentCollectScreenState();
}

class _AgentCollectScreenState extends State<AgentCollectScreen> {
  final Set<int> _selectedDays = {};
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _secretCodeController = TextEditingController();
  
  double get _calculatedAmount => _selectedDays.length * widget.dailyRate;
  
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
          'Collecte de Cotisations',
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
              
              // Profil Client
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=mako'),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.clientName, 
                        style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                      Text('Taux journalier : ${widget.dailyRate.toInt()}F / jour', 
                        style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Calendrier de Collecte
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('CALENDRIER DE COLLECTE', 
                    style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.secondary.withOpacity(0.5), letterSpacing: 1)),
                  Text('Mai 2024', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                ],
              ),
              const SizedBox(height: 16),
              
              // Grille de jours (Heatmap Elite)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: 14, // Démo : 14 jours
                itemBuilder: (context, index) {
                  final day = index + 1;
                  final isSelected = _selectedDays.contains(day);
                  final isAlreadyPaid = index < 4; // Démo jours déjà payés
                  
                  return GestureDetector(
                    onTap: isAlreadyPaid ? null : () => _toggleDay(day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isAlreadyPaid 
                          ? const Color(0xFF2D3748) // Foncé pour payé
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
              
              // Saisie Montant en Espèces
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
                    Text('MONTANT EN ESPÈCES', 
                      style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.secondary.withOpacity(0.5), letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setState(() {}),
                            style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.secondary),
                            decoration: InputDecoration(
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
              
              // Alerte Incohérence
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
                          'MONTANT INCOHÉRENT : Le montant saisi ne correspond pas aux ${_selectedDays.length} jours sélectionnés (${_calculatedAmount.toInt()}F requis).',
                          style: GoogleFonts.manrope(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ).animate().shake(),
                
              const SizedBox(height: 40),
              
              // Bouton Valider
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
                    Text('Valider la collecte (${_selectedDays.length} jours)', 
                      style: GoogleFonts.manrope(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
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

  void _showSecretCodeModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            Text('VALIDATION CLIENT', 
              style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text('Saisissez votre Code Secret', 
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.secondary)),
            const SizedBox(height: 12),
            Text('Demandé par l\'agent pour confirmer la réception de ${_amountController.text} FCFA', 
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
            
            const SizedBox(height: 40),
            
            // Password Field style PIN
            TextField(
              controller: _secretCodeController,
              keyboardType: TextInputType.number,
              obscureText: true,
              textAlign: TextAlign.center,
              maxLength: 4,
              style: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 20, color: AppColors.secondary),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                hintStyle: GoogleFonts.manrope(color: Colors.grey.shade200, letterSpacing: 20),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
              ),
            ),
            
            const Spacer(),
            
            ElevatedButton(
              onPressed: () async {
                final String secretCode = _secretCodeController.text;
                // Dans un cas réel, on vérifierait le secretCode en base via le client ID
                
                final String transId = DateTime.now().millisecondsSinceEpoch.toString();
                final double amount = double.tryParse(_amountController.text) ?? 0.0;
                
                await DatabaseService().addTransaction(
                  transId, 
                  '1', // ID projet démo par défaut
                  amount, 
                  'Aujourd\'hui', 
                  'cash', 
                  'validated'
                );

                if (context.mounted) {
                  Navigator.pop(context); // Fermer modale
                  _showSuccessAnimation();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text('Confirmer le paiement', style: GoogleFonts.manrope(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
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
              Text('Collecte Validée !', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.secondary)),
              const SizedBox(height: 8),
              Text('Reçu envoyé au client', style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ).animate().scale().fadeIn(),
      ),
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // Fermer Succès
      Navigator.pop(context); // Retour Dashboard
    });
  }
}
