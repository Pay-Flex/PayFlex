import 'package:flutter/material.dart';
import 'package:payflex_mobile/core/constants/app_colors.dart';

/// Logo officiel PayFlex (icône + wordmark).
class PayFlexLogo extends StatelessWidget {
  final double size;
  final bool circularBorder;

  const PayFlexLogo({
    super.key,
    this.size = 100,
    this.circularBorder = false,
  });

  static const String assetPath = 'assets/icons/logo.png';

  static const double _borderWidth = 2.5;

  Widget _logoImage(double imageSize) {
    return Image.asset(
      assetPath,
      height: imageSize,
      width: imageSize,
      fit: BoxFit.contain,
      semanticLabel: 'PayFlex',
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.image_not_supported_outlined,
        size: imageSize * 0.5,
        color: Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!circularBorder) {
      return _logoImage(size);
    }

    final innerPadding = size * 0.14;
    final imageSize = size - (_borderWidth * 2) - (innerPadding * 2);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: AppColors.primary,
          width: _borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(innerPadding),
          child: Center(child: _logoImage(imageSize)),
        ),
      ),
    );
  }
}
