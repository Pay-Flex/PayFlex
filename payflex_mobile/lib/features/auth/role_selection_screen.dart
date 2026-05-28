import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import 'registration_screen.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  String? _selectedRole;

  final List<Map<String, dynamic>> _roles = [
    {
      'id': 'apprenti',
      'title': 'Apprenti en formation',
      'icon': Icons.school_rounded,
      'color': Color(0xFFE3F2FD),
      'iconColor': Color(0xFF1E88E5),
    },
    {
      'id': 'artisan_fin',
      'title': 'Artisan en fin de formation',
      'icon': Icons.engineering_rounded,
      'color': Color(0xFFFFF3E0),
      'iconColor': Color(0xFFFB8C00),
    },
    {
      'id': 'artisan_actif',
      'title': 'Artisan en activité',
      'icon': Icons.build_circle_rounded,
      'color': Color(0xFFF1F8E9),
      'iconColor': Color(0xFF7CB342),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 246, 246),
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        ),
        title: Text(
          'Quel est votre profil ?',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.content_cut_rounded, size: 16, color: AppColors.secondary.withOpacity(0.6)),
                    const SizedBox(width: 6),
                    Icon(Icons.face_retouching_natural_rounded, size: 16, color: AppColors.secondary.withOpacity(0.6)),
                    const SizedBox(width: 6),
                    Icon(Icons.carpenter_rounded, size: 16, color: AppColors.secondary.withOpacity(0.6)),
                    const SizedBox(width: 6),
                    Icon(Icons.construction_rounded, size: 16, color: AppColors.secondary.withOpacity(0.6)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Métiers concernés : couture, coiffure, menuiserie, maçonnerie…',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.secondary.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Vous êtes agent PayFlex (employé) ? Ne créez pas de compte ici : votre administrateur ou gestionnaire vous enregistre, puis vous vous connectez avec votre téléphone et votre code PIN.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    height: 1.35,
                    color: AppColors.secondary.withOpacity(0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
            itemCount: _roles.length,
            itemBuilder: (context, index) {
              final role = _roles[index];
              final isSelected = _selectedRole == role['id'];
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRole = role['id'];
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.1),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Role Icon Placeholder
                      Container(
                        width: 100,
                        height: 80,
                        decoration: BoxDecoration(
                          color: role['color'],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(role['icon'], size: 40, color: role['iconColor']),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          role['title'],
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    ],
                  ),
                ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1),
              );
            },
          ),
          
          // Bottom Continue Button
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: ElevatedButton(
              onPressed: _selectedRole == null 
                ? null 
                : () {
                    // Sauvegarde du rôle dans le provider temporaire
                    ref.read(tempRoleProvider.notifier).setRole('client');
                    ref.read(tempClientProfileProvider.notifier).setProfile(_selectedRole);

                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                    );
                  },
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: Colors.grey.shade200,
                disabledForegroundColor: Colors.grey,
              ),
              child: const Text('Continuer'),
            ).animate().fadeIn(delay: 600.ms),
          ),
        ],
      ),
    );
  }
}
