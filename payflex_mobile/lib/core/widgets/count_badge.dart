import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CountBadge extends StatelessWidget {
  final int count;
  final double top;
  final double right;

  const CountBadge({
    super.key,
    required this.count,
    this.top = 6,
    this.right = 6,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Positioned(
      top: top,
      right: right,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: const BoxDecoration(
          color: Color(0xFFE53E3E),
          shape: BoxShape.circle,
        ),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        child: Text(
          count > 9 ? '9+' : '$count',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
