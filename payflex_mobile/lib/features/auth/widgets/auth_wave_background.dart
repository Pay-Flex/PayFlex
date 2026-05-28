import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AuthWaveBackground extends StatelessWidget {
  final Widget child;
  const AuthWaveBackground({super.key, required this.child});

  static const double decorHeight = 110;

  @override
  Widget build(BuildContext context) {
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      // Le body garde la hauteur plein écran : le décor reste collé au bas physique.
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          // Contenu scrollable : seul lui remonte quand le clavier s'ouvre.
          Padding(
            padding: EdgeInsets.only(bottom: keyboardBottom),
            child: child,
          ),
          // Vagues toujours visibles, position fixe en bas de l'écran.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: SizedBox(
                height: decorHeight,
                width: double.infinity,
                child: CustomPaint(
                  painter: FintechCurvesPainter(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau décoratif bas : une seule courbe supérieure lisse, sans « pointe » verticale.
class FintechCurvesPainter extends CustomPainter {
  const FintechCurvesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bleu nuit (arrière-plan)
    final pathBlue = Path()
      ..moveTo(0, h)
      ..lineTo(w, h)
      ..lineTo(w, h - 36)
      ..quadraticBezierTo(w * 0.72, h - 8, w * 0.28, h - 32)
      ..quadraticBezierTo(w * 0.06, h - 48, 0, h - 28)
      ..close();

    canvas.drawPath(
      pathBlue,
      Paint()
        ..color = AppColors.secondary
        ..style = PaintingStyle.fill,
    );

    // Orange (devant) — bord supérieur = une courbe, pas de trait vertical à gauche
    final pathYellow = Path()
      ..moveTo(0, h)
      ..lineTo(w, h)
      ..lineTo(w, h - 48)
      ..quadraticBezierTo(w * 0.58, h - 62, w * 0.14, h - 40)
      ..quadraticBezierTo(0, h - 44, 0, h - 24)
      ..close();

    canvas.drawPath(
      pathYellow,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
