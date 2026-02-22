import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/image_viewer.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';

/// Bottom sheet that shows location details when a campus marker is tapped.
class LocationDetailsSheet extends StatefulWidget {
  final String title;
  final String? description;
  final dynamic images; // String, List, or stringified list
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
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  List<String> _parseImages() {
    if (widget.images == null) return [];

    List<String> urls = [];
    if (widget.images is List) {
      urls = (widget.images as List).map((e) => e.toString()).toList();
    } else {
      String raw = widget.images.toString().trim();
      if (raw.startsWith('[') && raw.endsWith(']')) {
        // Stringified list "[url1, url2]"
        String inner = raw.substring(1, raw.length - 1);
        urls = inner
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else if (raw.isNotEmpty) {
        urls = [raw];
      }
    }
    return urls;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Images Carousel
                  if (hasImage) ...[
                    Builder(
                      builder: (context) {
                        final imageUrls = _parseImages();
                        if (imageUrls.isEmpty) return const SizedBox.shrink();

                        return Column(
                          children: [
                            SizedBox(
                              height: 200,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  children: [
                                    PageView.builder(
                                      controller: _pageController,
                                      onPageChanged: (idx) {
                                        setState(
                                          () => _currentImageIndex = idx,
                                        );
                                      },
                                      itemCount: imageUrls.length,
                                      itemBuilder: (context, index) {
                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.of(
                                              context,
                                              rootNavigator: true,
                                            ).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    FullScreenImageViewer(
                                                      imageUrls: imageUrls,
                                                      initialIndex: index,
                                                    ),
                                              ),
                                            );
                                          },
                                          child: Hero(
                                            tag: imageUrls[index],
                                            child: SmartImage(
                                              imageUrl: imageUrls[index],
                                              width: double.infinity,
                                              height: 200,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    if (imageUrls.length > 1)
                                      Positioned(
                                        bottom: 12,
                                        left: 0,
                                        right: 0,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: List.generate(
                                            imageUrls.length,
                                            (index) => AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              width: _currentImageIndex == index
                                                  ? 20
                                                  : 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color:
                                                    _currentImageIndex == index
                                                    ? Colors.white
                                                    : Colors.white.withValues(
                                                        alpha: 0.5,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.2),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
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
