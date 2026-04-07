import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'agent_collect_screen.dart';
import 'agent_client_detail_screen.dart';

class AgentClientListScreen extends StatelessWidget {
  const AgentClientListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Mes Clients',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Barre de recherche simplifiée
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher un client...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 15,
              itemBuilder: (context, index) {
                return _buildClientTile(context, index);
              },
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildClientTile(BuildContext context, int index) {
    final name = index % 2 == 0 ? 'Mamadou Koné' : 'Awa Traoré';
    final zone = index % 2 == 0 ? 'Zone A' : 'Marché Central';
    final img = index % 2 == 0 ? 'https://i.pravatar.cc/150?u=mako' : 'https://i.pravatar.cc/150?u=awa';
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AgentClientDetailScreen(
              name: name,
              zone: zone,
              img: img,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(img, width: 44, height: 44, fit: BoxFit.cover),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: AppColors.secondary)),
                  Text(zone, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AgentCollectScreen(clientName: name)),
                );
              },
              icon: const Icon(Icons.payments_outlined, color: AppColors.primary),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.phone_outlined, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
