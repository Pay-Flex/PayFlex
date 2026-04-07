import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../auth/welcome_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Atmospheric Decors
          Positioned(
            top: 200,
            right: -100,
            child: _buildProfileBlob(AppColors.primary, 300),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .move(duration: 10.seconds, begin: const Offset(-20, -20), end: const Offset(20, 20)),
          
          Positioned(
            bottom: 100,
            left: -150,
            child: _buildProfileBlob(AppColors.secondary, 400),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .move(duration: 15.seconds, begin: const Offset(30, 30), end: const Offset(-30, -30)),

          // 2. Content
          CustomScrollView(
            slivers: [
              // Premium Profile Header
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                elevation: 0,
                automaticallyImplyLeading: false,
                backgroundColor: AppColors.secondary,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      // Gradient Background
                      Container(
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                        ),
                      ),
                      
                      // Decoration Icon
                      Positioned(
                        right: -50,
                        top: -50,
                        child: Icon(
                          Icons.person_rounded,
                          size: 300,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      
                      // User Info Area
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 60),
                            
                            // Avatar with Glass Halo
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const CircleAvatar(
                                radius: 50,
                                backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=payflex'),
                              ),
                            ).animate().scale(curve: Curves.easeOutBack, duration: 1.seconds),
                            
                            const SizedBox(height: 20),
                            
                            Text(
                              'Chaminade Don',
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                            
                            const SizedBox(height: 4),
                            
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Text(
                                'CLIENT PREMIUM',
                                style: GoogleFonts.manrope(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ).animate().fadeIn(delay: 600.ms).scale(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Settings List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'GESTION DU COMPTE',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppColors.secondary.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _profileItem(context, Icons.person_outline_rounded, 'Mon Compte', 'Gérer vos informations personnelles', 0),
                    _profileItem(context, Icons.notifications_none_rounded, 'Notifications', 'Préférences de alertes', 1),
                    _profileItem(context, Icons.security_rounded, 'Sécurité', 'Mot de passe et authentification', 2),
                    _profileItem(context, Icons.help_outline_rounded, 'Aide & Support', 'Centre d\'assistance PayFlex', 3),
                    
                    const SizedBox(height: 40),
                    
                    // Logout Area
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: AppColors.error.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.logout_rounded, color: AppColors.error.withOpacity(0.5), size: 40),
                          const SizedBox(height: 16),
                          Text(
                            'Souhaitez-vous vous déconnecter ?',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: AppColors.secondary.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                                (route) => false,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 56),
                              elevation: 0,
                            ),
                            child: const Text('SE DÉCONNECTER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),
                    
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileItem(BuildContext context, IconData icon, String title, String subtitle, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: AppColors.secondary.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          title, 
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary)
        ),
        subtitle: Text(
          subtitle, 
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.secondary.withOpacity(0.5))
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.secondary.withOpacity(0.3)),
      ),
    ).animate().fadeIn(delay: (200 + (index * 100)).ms).slideX(begin: 0.1);
  }

  Widget _buildProfileBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.03),
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
