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

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 64, color: AppColors.primary),
              )
            else
              Image.asset(
                imagePath,
                width: imageSize,
                height: imageSize,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback icon if image fails to load
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search_off_rounded,
                      size: 64,
                      color: AppColors.primary,
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTextStyles.h4.copyWith(
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
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
  }
}
