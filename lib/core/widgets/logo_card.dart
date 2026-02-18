import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/constants/app_constants.dart';

class LogoCard extends StatelessWidget {
  final double width;
  final double height;
  final bool useHero;

  const LogoCard({
    super.key,
    required this.width,
    required this.height,
    this.useHero = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Image.asset(
          AppConstants.logoPath,
          width: width * 0.85,
          height: height * 0.85,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.auto_awesome_rounded,
              size: width * 0.6,
              color: AppColors.primary,
            );
          },
        ),
      ),
    );

    if (useHero) {
      return Hero(tag: 'app_logo', child: content);
    }

    return content;
  }
}
