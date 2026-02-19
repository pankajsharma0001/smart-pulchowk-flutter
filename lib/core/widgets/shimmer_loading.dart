import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class Skeleton extends StatelessWidget {
  final double? height;
  final double? width;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;
  final BoxShape shape;

  const Skeleton({
    super.key,
    this.height,
    this.width,
    this.borderRadius = 8,
    this.margin,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.30)
            : Colors.black.withValues(alpha: 0.18),
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(borderRadius),
        shape: shape,
      ),
    );
  }
}

class ShimmerWrapper extends StatelessWidget {
  final Widget child;

  const ShimmerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF252538) : const Color(0xFFE0E0EA),
      highlightColor: isDark
          ? const Color(0xFF404060)
          : const Color(0xFFF8F8FF),
      period: const Duration(milliseconds: 1200),
      direction: ShimmerDirection.ltr,
      child: child,
    );
  }
}

/// Premium shimmer card that mirrors the ClubCard layout.
class ShimmerClubCard extends StatelessWidget {
  const ShimmerClubCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final sectionBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    // Card bg is OUTSIDE ShimmerWrapper so only skeleton shapes shimmer
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: ShimmerWrapper(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo area (flex 3)
            Expanded(
              flex: 3,
              child: Container(
                color: sectionBg,
                child: Center(
                  child: Skeleton(
                    width: 64,
                    height: 64,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            // Content area (flex 2)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 14, width: 110, borderRadius: 6),
                    const SizedBox(height: 8),
                    Skeleton(height: 10, borderRadius: 5),
                    const SizedBox(height: 4),
                    Skeleton(height: 10, width: 80, borderRadius: 5),
                    const Spacer(),
                    Row(
                      children: [
                        Skeleton(height: 10, width: 55, borderRadius: 5),
                        const SizedBox(width: 12),
                        Skeleton(height: 10, width: 60, borderRadius: 5),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Premium shimmer for a content info-card (used in club details).
class ShimmerInfoCard extends StatelessWidget {
  final double height;
  const ShimmerInfoCard({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: ShimmerWrapper(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Skeleton(width: 20, height: 20, shape: BoxShape.circle),
                const SizedBox(width: 10),
                Skeleton(width: 100, height: 14, borderRadius: 6),
              ],
            ),
            const SizedBox(height: 16),
            Skeleton(height: 10, borderRadius: 5),
            const SizedBox(height: 6),
            Skeleton(height: 10, width: 200, borderRadius: 5),
            const SizedBox(height: 6),
            Skeleton(height: 10, width: 150, borderRadius: 5),
          ],
        ),
      ),
    );
  }
}

/// Premium shimmer row for an event list item.
class ShimmerEventRow extends StatelessWidget {
  const ShimmerEventRow({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(14),
      child: ShimmerWrapper(
        child: Row(
          children: [
            // Date badge skeleton
            Skeleton(width: 48, height: double.infinity, borderRadius: 10),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Skeleton(height: 13, width: 160, borderRadius: 5),
                  const SizedBox(height: 8),
                  Skeleton(height: 10, width: 120, borderRadius: 5),
                  const SizedBox(height: 6),
                  Skeleton(height: 10, width: 80, borderRadius: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
