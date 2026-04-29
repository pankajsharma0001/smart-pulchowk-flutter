import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final double imageSize;
  final IconData? icon;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.imagePath = 'assets/images/empty_search.png',
    this.imageSize = 200,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale icon/image down when vertical space is limited
        final availableHeight = constraints.maxHeight;
        final isCompact = availableHeight < 280;
        final iconSize = isCompact ? 48.0 : 64.0;
        final iconPadding = isCompact ? 16.0 : 24.0;
        final scaledImageSize = isCompact
            ? (imageSize * 0.6).clamp(80.0, 150.0)
            : imageSize;

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  Container(
                    padding: EdgeInsets.all(iconPadding),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: iconSize, color: AppColors.primary),
                  )
                else
                  Image.asset(
                    imagePath,
                    width: scaledImageSize,
                    height: scaledImageSize,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback icon if image fails to load
                      return Container(
                        padding: EdgeInsets.all(iconPadding),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.search_off_rounded,
                          size: iconSize,
                          color: AppColors.primary,
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: AppTextStyles.h4.copyWith(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
