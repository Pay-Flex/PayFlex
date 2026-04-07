import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';

class AuthWaveBackground extends StatelessWidget {
  final Widget child;
  const AuthWaveBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Blanc premium, zéro éblouissement
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Contenu principal
          child,
          
          // 2. Fintech Flat Vectors (Design exact de votre image)
          Positioned(
            bottom: -50, // Immersion totale pour garantir 0 pixel d'espace blanc 
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: 200, // Top 150px est visible, Bottom 50px est caché
                child: CustomPaint(
                  painter: FintechCurvesPainter(),
                ),
              ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1, curve: Curves.easeOutQuart),
            ),
          ),
        ],
      ),
    );
  }
}

class FintechCurvesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height; // Vaut 200 (les 50 derniers pixels sont invisibles en bas)

    // 1. Grande courbe jaune (comme l'image)
    final paintYellow = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final pathYellow = Path();
    pathYellow.moveTo(-10, height); 
    pathYellow.lineTo(-10, 50); // Départ en haut à gauche
    // Plongeon majestueux au milieu repiquant vers le haut droit
    pathYellow.quadraticBezierTo(width * 0.45, 160, width + 10, 20); 
    pathYellow.lineTo(width + 10, height);
    pathYellow.close();
    
    canvas.drawPath(pathYellow, paintYellow);

    // 2. Coin biseauté bleu nuit (comme l'image)
    final paintBlue = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.fill;

    final pathBlue = Path();
    pathBlue.moveTo(width * 0.20, 170); // Départ plus bas et plus à gauche
    // Creux plus prononcé : point de contrôle tiré vers le bas
    pathBlue.quadraticBezierTo(width * 0.55, 200, width + 10, 30); 
    pathBlue.lineTo(width + 10, height); // Plonge en bas à droite
    pathBlue.lineTo(width * 0.20, height); // Retourne au point X de départ
    pathBlue.close();

    canvas.drawPath(pathBlue, paintBlue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
