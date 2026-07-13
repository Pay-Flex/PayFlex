import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../main_navigation_screen.dart';
import 'dart:ui';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Architecte de vos finances',
      description: 'Construisez votre héritage financier avec une précision rigoureuse et une vision moderne.',
      icon: Icons.architecture_rounded,
      color: AppColors.primary,
    ),
    OnboardingData(
      title: 'Zéro barrière, maximum de contrôle',
      description: 'Gérez vos cotisations sans smartphone ou avec, une expérience inclusive pour tous.',
      icon: Icons.security_rounded,
      color: const Color(0xFF1B6D24),
    ),
    OnboardingData(
      title: 'Progrès en temps réel',
      description: 'Suivez chaque étape de vos projets d\'épargne avec des visualisations premium.',
      icon: Icons.auto_graph_rounded,
      color: const Color(0xFF00314F),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Animated Shape
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: _pages[_currentPage].color.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            )
                .animate(key: ValueKey(_currentPage))
                .scale(duration: 1.seconds, curve: Curves.easeOutBack),
          ),
          
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return OnboardingPageWidget(data: _pages[index]);
            },
          ),
          
          // Bottom Navigation
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicator dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => Container(
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _currentPage == index 
                            ? AppColors.primary 
                            : Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ).animate(target: _currentPage == index ? 1 : 0).scaleX(begin: 1, end: 3),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Navigation Button
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: 600.ms,
                        curve: Curves.easeOutBack,
                      );
                    } else {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                      );
                    }
                  },
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'COMMENCER' : 'SUIVANT',
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Skip Button
                TextButton(
                  onPressed: () {
                     Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                      );
                  },
                  child: Text(
                    'PASSER',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class OnboardingPageWidget extends StatelessWidget {
  final OnboardingData data;

  const OnboardingPageWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Illustration
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(48),
            ),
            child: Icon(
              data.icon,
              size: 80,
              color: data.color,
            ),
          )
              .animate()
              .scale(duration: 800.ms, curve: Curves.elasticOut)
              .rotate(begin: 0.1, end: 0, duration: 1200.ms),
              
          const SizedBox(height: 60),
          
          Text(
            data.title.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: AppColors.primary,
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms)
              .slideX(begin: 0.2, end: 0, curve: Curves.easeOutBack),
              
          const SizedBox(height: 24),
          
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.6,
              color: AppColors.onSurfaceVariant,
            ),
          )
              .animate()
              .fadeIn(delay: 400.ms),
        ],
      ),
    );
  }
}
