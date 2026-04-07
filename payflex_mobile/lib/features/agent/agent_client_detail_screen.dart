import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'agent_collect_screen.dart';

class AgentClientDetailScreen extends StatelessWidget {
  final String name;
  final String zone;
  final String img;
  final bool isPhysical;

  const AgentClientDetailScreen({
    super.key,
    required this.name,
    required this.zone,
    required this.img,
    this.isPhysical = true,
  });

  @override
  Widget build(BuildContext context) {
    // Données de démo pour l'UI "Elite"
    const double totalProject = 850000;
    const double collected = 245500;
    const double remaining = totalProject - collected;
    const double progress = collected / totalProject;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFinancialSummary(totalProject, collected, remaining, progress),
                  const SizedBox(height: 32),
                  _buildSectionHeader('ÉQUIPEMENTS SOUSCRITS'),
                  const SizedBox(height: 16),
                  _buildEquipmentList(),
                  const SizedBox(height: 32),
                  _buildSectionHeader('HISTORIQUE DES COLLECTES'),
                  const SizedBox(height: 16),
                  _buildCollectionHistory(),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildActionBottomBar(context),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: AppColors.secondary,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1557683311-eac922347aa1?w=800&q=80',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.secondary.withOpacity(0.8),
                    AppColors.secondary,
                  ],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Hero(
                    tag: 'client_img_$name',
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: CircleAvatar(radius: 45, backgroundImage: NetworkImage(img)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(name, 
                    style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text(zone, 
                    style: GoogleFonts.manrope(fontSize: 13, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummary(double total, double collected, double remaining, double progress) {
    return Container(
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _financeStat('TOTAL PROJET', '${total.toInt()} F', Colors.grey),
              _financeStat('DEJÀ PAYÉ', '${collected.toInt()} F', AppColors.primary),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF6366F1)]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ).animate().shimmer(duration: 1500.ms),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RESTE À COLLECTER', 
                style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
              Text('${remaining.toInt()} FCFA', 
                style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.redAccent)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _financeStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: color == Colors.grey ? AppColors.secondary : color)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, 
      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2));
  }

  Widget _buildEquipmentList() {
    final List<Map<String, String>> items = [
      {'name': 'Moto Jakarta 100cc', 'img': 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400&q=80'},
      {'name': 'Solaire Elite Pack', 'img': 'https://images.unsplash.com/photo-1509391366360-fe5bb65858cf?w=400&q=80'},
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, i) => Container(
          width: 200,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
          child: Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(items[i]['img']!, width: 45, height: 45, fit: BoxFit.cover)),
              const SizedBox(width: 12),
              Expanded(child: Text(items[i]['name']!, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionHistory() {
    return Column(
      children: List.generate(3, (i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Collecte Journalière', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: AppColors.secondary)),
                  Text('${12 + i} Mars 2026 • 16:30', style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Text('+2.500 F', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: const Color(0xFF22C55E))),
          ],
        ),
      )),
    );
  }

  Widget _buildActionBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
              label: const Text('APPELER'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 56),
                foregroundColor: AppColors.secondary,
                side: BorderSide(color: AppColors.secondary.withOpacity(0.1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AgentCollectScreen(clientName: name)),
                );
              },
              icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
              label: const Text('COLLECTER'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
