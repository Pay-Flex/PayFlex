import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/finance_provider.dart';

class CalendarViewScreen extends ConsumerWidget {
  const CalendarViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financeState = ref.watch(financeProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          'SUIVI DES COTISATIONS',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w900, 
            letterSpacing: 2,
            fontSize: 14,
            color: AppColors.secondary,
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. Atmospheric Decors
          Positioned(
            top: 100,
            right: -100,
            child: _buildCalendarBlob(AppColors.primary, 300),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .move(duration: 10.seconds, begin: const Offset(-20, -20), end: const Offset(20, 20)),
          
          Positioned(
            bottom: 200,
            left: -150,
            child: _buildCalendarBlob(AppColors.secondary, 400),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .move(duration: 15.seconds, begin: const Offset(30, 30), end: const Offset(-30, -30)),

          // 2. Main content
          Column(
            children: [
              // Month Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {}, 
                        icon: const Icon(Icons.chevron_left_rounded, color: AppColors.secondary),
                      ),
                      Text(
                        'AVRIL 2024',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.secondary,
                          letterSpacing: 1,
                        ),
                      ),
                      IconButton(
                        onPressed: () {}, 
                        icon: const Icon(Icons.chevron_right_rounded, color: AppColors.secondary),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn().slideY(begin: -0.2),
              
              const SizedBox(height: 8),

              // Days Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM']
                      .map((day) => Expanded(
                            child: Center(
                              child: Text(
                                day,
                                style: GoogleFonts.manrope(
                                  color: AppColors.secondary.withOpacity(0.3),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Calendar Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: 31,
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    
                    // Fetch status from Riverpod!
                    final statusString = financeState.calendarStatuses[day] ?? 'gris';
                    final Color statusColor;
                    
                    switch (statusString) {
                      case 'vert': statusColor = AppColors.success; break;
                      case 'orange': statusColor = AppColors.warning; break;
                      case 'bleu': statusColor = AppColors.info; break; // Ou un beau bleu
                      default: statusColor = Colors.transparent; break;
                    }
                    
                    bool isToday = day == DateTime.now().day; 

                    return Container(
                      decoration: BoxDecoration(
                        color: isToday ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: isToday ? AppColors.primary : AppColors.secondary.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              '$day',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w900,
                                color: isToday ? AppColors.secondary : AppColors.secondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          // Status dot from algorithm
                          if (statusColor != Colors.transparent)
                            Positioned(
                              bottom: 6,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 4),
                                    ]
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (index * 15).ms).scale(begin: const Offset(0.8, 0.8));
                  },
                ),
              ),
              
              // Legend (Glassmorphism Card)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: AppColors.secondary.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      _legendItem(AppColors.success, 'Plan respecté', 'Vos cotisations sont à jour'),
                      const SizedBox(height: 16),
                      _legendItem(AppColors.info, 'En Avance', 'Vous avez payé pour les jours futurs'),
                      const SizedBox(height: 16),
                      _legendItem(AppColors.warning, 'Rattrapage', 'Nombre de jours en retard non complétés'),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
              
              const SizedBox(height: 100), // Space for bottom nav
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String title, String desc) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color, 
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, spreadRadius: 2),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title, 
                style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 13)
              ),
              Text(
                desc, 
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.secondary.withOpacity(0.5))
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarBlob(Color color, double size) {
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
