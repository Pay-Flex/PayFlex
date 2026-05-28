import 'package:flutter/material.dart';

/// Logo officiel PayFlex (icône + wordmark).
class PayFlexLogo extends StatelessWidget {
  final double size;
  const PayFlexLogo({super.key, this.size = 100});

  static const String assetPath = 'assets/icons/logo.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'PayFlex',
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.image_not_supported_outlined,
        size: size * 0.5,
        color: Colors.grey,
      ),
    );
  }
}
