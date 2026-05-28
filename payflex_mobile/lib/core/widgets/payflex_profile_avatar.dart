import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../network/api_config.dart';

/// Avatar profil avec photo d'inscription, contour et badge selon validation admin.
class PayflexProfileAvatar extends StatelessWidget {
  const PayflexProfileAvatar({
    super.key,
    required this.letter,
    required this.awaitingAdminApproval,
    this.imageUrl,
    this.radius = 22,
    this.letterFontSize,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String letter;
  final bool awaitingAdminApproval;
  final String? imageUrl;
  final double radius;
  final double? letterFontSize;
  final Color? backgroundColor;
  final Color? foregroundColor;

  String? get _resolvedPhoto {
    final raw = imageUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    return ApiConfig.resolveMediaUrl(raw);
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = awaitingAdminApproval ? const Color(0xFFF6AD55) : const Color(0xFF48BB78);
    final badgeColor = awaitingAdminApproval ? const Color(0xFFDD6B20) : const Color(0xFF38A169);
    final badgeIcon = awaitingAdminApproval ? Icons.hourglass_top_rounded : Icons.verified_rounded;
    final photo = _resolvedPhoto;

    return SizedBox(
      width: radius * 2 + 10,
      height: radius * 2 + 10,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: radius * 2 + 6,
            height: radius * 2 + 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: ringColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: ClipOval(
              child: _buildInner(photo, ringColor),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: radius * 0.72,
              height: radius * 0.72,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(badgeIcon, color: Colors.white, size: radius * 0.38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInner(String? photo, Color ringColor) {
    final bg = backgroundColor ?? Colors.white.withValues(alpha: 0.22);
    final fg = foregroundColor ?? Colors.white;
    final size = radius * 2;

    if (photo != null) {
      return Image.network(
        photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _letterOrIcon(bg, fg),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: size,
            height: size,
            color: bg,
            alignment: Alignment.center,
            child: SizedBox(
              width: radius * 0.5,
              height: radius * 0.5,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: fg.withValues(alpha: 0.7),
              ),
            ),
          );
        },
      );
    }
    return _letterOrIcon(bg, fg);
  }

  Widget _letterOrIcon(Color bg, Color fg) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: awaitingAdminApproval && (imageUrl == null || imageUrl!.isEmpty)
          ? Icon(Icons.person_outline_rounded, color: fg, size: radius * 0.95)
          : Text(
              letter,
              style: GoogleFonts.manrope(
                color: fg,
                fontSize: letterFontSize ?? radius * 0.82,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}
