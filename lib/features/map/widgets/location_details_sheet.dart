import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';

/// Bottom sheet that shows location details when a campus marker is tapped.
class LocationDetailsSheet extends StatefulWidget {
  final String title;
  final String? description;
  final dynamic images; // String URL or null
  final VoidCallback? onNavigate;

  const LocationDetailsSheet({
    super.key,
    required this.title,
    this.description,
    this.images,
    this.onNavigate,
  });

  @override
  State<LocationDetailsSheet> createState() => _LocationDetailsSheetState();
}

class _LocationDetailsSheetState extends State<LocationDetailsSheet> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage =
        widget.images != null && widget.images.toString().isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header row: title + navigate button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: AppTextStyles.h4.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pulchowk Campus',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onNavigate != null)
                  FilledButton.icon(
                    onPressed: widget.onNavigate,
                    icon: const Icon(Icons.directions_rounded, size: 18),
                    label: const Text('Directions'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      textStyle: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Scrollable content area
          Flexible(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).padding.bottom + 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  if (hasImage) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Builder(
                        builder: (context) {
                          String imageUrl = '';
                          if (widget.images is List &&
                              (widget.images as List).isNotEmpty) {
                            imageUrl = widget.images[0].toString();
                          } else {
                            imageUrl = widget.images.toString();
                          }

                          // Clean up if it's still bracketed (e.g. stringified list "[url]")
                          if (imageUrl.startsWith('[') &&
                              imageUrl.endsWith(']')) {
                            imageUrl = imageUrl
                                .substring(1, imageUrl.length - 1)
                                .split(',')
                                .first
                                .trim();
                          }

                          return SmartImage(
                            imageUrl: imageUrl,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Description
                  if (widget.description != null &&
                      widget.description!.isNotEmpty) ...[
                    Text(
                      'About',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.description!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
