import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PayFlexLogo extends StatelessWidget {
  final double size;
  const PayFlexLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Top Yellow Shape
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: size * 0.6,
              height: size * 0.4,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomRight: Radius.circular(24),
                ),
              ),
            ),
          ),
          // Bottom Blue Shape
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.6,
              height: size * 0.6,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomRight: Radius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
