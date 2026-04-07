import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class AgentRegistryScreen extends StatelessWidget {
  const AgentRegistryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Registre des Collectes',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Récapitulatif Hebdomadaire
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.secondary, Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.2), blurRadius: 20)],
              ),
              child: Column(
                children: [
                   Text('TOTAL COLLECTÉ (7 JOURS)', 
                    style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.5), letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Text('1.455.000 FCFA', 
                    style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary)),
                  const SizedBox(height: 16),
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem('Lundi', '145.5k'),
                      _statItem('Mardi', '120.0k'),
                      _statItem('Mercredi', '155.0k'),
                      _statItem('Jeudi', '10.5k'),
                      _statItem('Ven', '-'),
                    ],
                   ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 10,
              itemBuilder: (context, index) {
                return _buildCollectionRecord(index);
              },
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _statItem(String day, String amount) {
    return Column(
      children: [
        Text(day, style: GoogleFonts.manrope(fontSize: 10, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(amount, style: GoogleFonts.manrope(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildCollectionRecord(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mamadou Koné', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: AppColors.secondary)),
                Text('Hier, 16:45 • Cas 1', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text('+', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: const Color(0xFF16A34A), fontSize: 16)),
          Text(' 15.000 F', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: AppColors.secondary, fontSize: 16)),
        ],
      ),
    );
  }
}
