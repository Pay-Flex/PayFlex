import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';
import 'agent_collect_screen.dart';
import 'agent_validation_queue_screen.dart';
import 'agent_enrollment_screen.dart';
import 'agent_client_detail_screen.dart';

class AgentDashboardScreen extends ConsumerStatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  ConsumerState<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends ConsumerState<AgentDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  // Données de démo pour l'UI
  final double _todayCollected = 145500;
  final double _targetAmount = 180000;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Header Background avec léger dégradé
          Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              slivers: [
                // AppBar Agent (Toujours en haut)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=agent1'),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ARCHITECTE FINANCIER',
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.secondary.withOpacity(0.5),
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              'Jean Dupont',
                              style: GoogleFonts.manrope(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.secondary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        _buildHeaderAction(Icons.notifications_none_rounded),
                      ],
                    ),
                  ),
                ),

                // Stats Card "Elite" (Barre de progression)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withOpacity(0.06),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Collecté aujourd\'hui',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.secondary.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '145.500 FCFA',
                                    style: GoogleFonts.manrope(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.secondary,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7FAFC),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(Icons.analytics_outlined, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Barre de progression
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDF2F7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: _todayCollected / _targetAmount,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF48BB78), Color(0xFF68D391)],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${((_todayCollected / _targetAmount) * 100).toInt()}%',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF48BB78),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'DE L\'OBJECTIF JOURNALIER',
                            style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Statistiques de l'agent (Collecté / Objectif en second)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildStatCard('COLLECTÉ', '15.400 F', Icons.account_balance_wallet_rounded)
                          .animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                        const SizedBox(width: 12),
                        _buildStatCard('OBJECTIF', '25.000 F', Icons.flag_rounded)
                          .animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                      ],
                    ),
                  ),
                ),

                // Button Enregistrer Client
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AgentEnrollmentScreen()),
                        );
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                      label: const Text('Enregistrer un nouveau client'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(18),
                        side: BorderSide(color: AppColors.secondary.withOpacity(0.1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        foregroundColor: AppColors.secondary,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),

                // Section List Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Clients assignés',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondary,
                          ),
                        ),
                        Text(
                          '12 RESTANTS',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Recherche Client
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF2F7).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher par Nom ou ID Client',
                          hintStyle: GoogleFonts.manrope(color: Colors.grey, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ),
                ),

                // Liste des clients (Cas 1 & Cas 2 intégrés)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildClientCard(
                        context,
                        'Mamadou Koné',
                        'Zone A, Secteur 4',
                        'Hier, 16:45',
                        'https://i.pravatar.cc/150?u=mako',
                        true, // Is physical collect (Cas 1)
                      ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.05),
                      const SizedBox(height: 16),
                      _buildClientCard(
                        context,
                        'Awa Traoré',
                        'Marché Central, Allée 2',
                        'Il y a 3 jours',
                        'https://i.pravatar.cc/150?u=awa',
                        false, // Pending Smartphone (Cas 2)
                        hasAlert: true,
                      ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.05),
                      const SizedBox(height: 16),
                      _buildClientCard(
                        context,
                        'Ibrahim Diallo',
                        'Zone B, Entrée Sud',
                        'Mardi, 09:15',
                        'https://i.pravatar.cc/150?u=ibra',
                        true,
                        amountIncoherent: true,
                      ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.05),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.secondary, size: 22),
    );
  }

  Widget _buildClientCard(BuildContext context, String name, String zone, String lastPay, String img, bool isPhysical, {bool hasAlert = false, bool amountIncoherent = false}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AgentClientDetailScreen(
              name: name,
              zone: zone,
              img: img,
              isPhysical: isPhysical,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: amountIncoherent ? Colors.red.withOpacity(0.3) : Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(img, width: 48, height: 48, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 15)),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(zone, style: GoogleFonts.manrope(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('DERNIER PAIEMENT', style: GoogleFonts.manrope(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey)),
                    Text(lastPay, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: lastPay.contains('Hier') ? const Color(0xFF48BB78) : Colors.redAccent)),
                  ],
                ),
              ],
            ),
          ),
          
          if (amountIncoherent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'MONTANT INCOHÉRENT : 1500F ne correspond pas à un nombre entier de jours (200F/j)',
                      style: GoogleFonts.manrope(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('Corriger', style: GoogleFonts.manrope(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w900, decoration: TextDecoration.underline)),
                ],
              ),
            ),

          if (isPhysical && !amountIncoherent)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AgentCollectScreen(clientName: name)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Valider la collecte', style: GoogleFonts.manrope(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            )
          else if (!isPhysical)
             Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AgentValidationQueueScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEDF2F7),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Voir la demande smartphone', style: GoogleFonts.manrope(color: AppColors.secondary, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
