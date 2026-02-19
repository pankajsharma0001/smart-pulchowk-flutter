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
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: 0.20),
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
      baseColor: isDark
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.black.withValues(alpha: 0.15),
      highlightColor: isDark
          ? Colors.white.withValues(alpha: 0.25)
          : Colors.black.withValues(alpha: 0.10),
      period: const Duration(milliseconds: 1500),
      child: child,
    );
  }
}
