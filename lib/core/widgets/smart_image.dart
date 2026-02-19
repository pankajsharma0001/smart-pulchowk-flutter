import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_pulchowk/core/constants/app_constants.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';

/// A premium image widget that handles optimized loading, 403-forbidden headers,
/// and consistent shimmer placeholders.
class SmartImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final BoxShape shape;
  final Widget? errorWidget;
  final bool useCloudinary;

  const SmartImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.shape = BoxShape.rectangle,
    this.errorWidget,
    this.useCloudinary = true,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildError(context);
    }

    // Apply Cloudinary/Drive optimization
    final processedUrl = useCloudinary
        ? ApiService.processImageUrl(imageUrl, width: width?.toInt())
        : imageUrl;

    if (processedUrl == null) return _buildError(context);

    return ClipRRect(
      borderRadius: shape == BoxShape.circle
          ? BorderRadius.zero
          : BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(shape: shape),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: processedUrl,
          httpHeaders: AppConstants.imageHeaders,
          width: width,
          height: height,
          fit: fit,
          placeholder: (context, url) => ShimmerWrapper(
            child: Skeleton(
              width: width,
              height: height,
              borderRadius: borderRadius,
              shape: shape,
            ),
          ),
          errorWidget: (context, url, error) =>
              errorWidget ?? _buildError(context),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(borderRadius),
        shape: shape,
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          color: isDark ? Colors.white24 : Colors.black26,
          size: (width != null && width! < 50) ? 16 : 24,
        ),
      ),
    );
  }
}
