import 'dart:io';
import 'dart:typed_data';
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
    final isFiniteWidth = width != null && width!.isFinite;
    final processedUrl = useCloudinary
        ? ApiService.processImageUrl(
            imageUrl,
            width: isFiniteWidth ? width!.toInt() : null,
          )
        : ApiService.processImageUrl(imageUrl, optimizeCloudinary: false);

    if (processedUrl == null) return _buildError(context);

    final uri = Uri.tryParse(processedUrl);
    final isPortalTu =
        uri != null &&
        uri.host.toLowerCase() == 'portal.tu.edu.np' &&
        uri.scheme == 'https';

    if (isPortalTu) {
      return _PortalTlsFallbackImage(
        imageUrl: processedUrl,
        width: width,
        height: height,
        fit: fit,
        borderRadius: borderRadius,
        shape: shape,
        errorWidget: errorWidget ?? _buildError(context),
      );
    }

    // Social media CDNs often block requests with custom User-Agents or specific headers
    final isSocial = ApiService.isSocialMediaDomain(processedUrl);
    final headers = isSocial ? null : AppConstants.imageHeaders;

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
          httpHeaders: headers,
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
          errorListener: (error) {
            debugPrint('SmartImage Error [$processedUrl]: $error');
          },
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

class _PortalTlsFallbackImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final BoxShape shape;
  final Widget errorWidget;

  const _PortalTlsFallbackImage({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.fit,
    required this.borderRadius,
    required this.shape,
    required this.errorWidget,
  });

  @override
  State<_PortalTlsFallbackImage> createState() =>
      _PortalTlsFallbackImageState();
}

class _PortalTlsFallbackImageState extends State<_PortalTlsFallbackImage> {
  static final Map<String, Uint8List> _memoryCache = {};
  late Future<Uint8List?> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = _fetchBytes();
  }

  Future<Uint8List?> _fetchBytes() async {
    final cached = _memoryCache[widget.imageUrl];
    if (cached != null) return cached;

    final uri = Uri.parse(widget.imageUrl);
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    client.badCertificateCallback = (certificate, host, port) =>
        host == 'portal.tu.edu.np';
    try {
      final req = await client.getUrl(uri);
      final res = await req.close();
      if (res.statusCode != HttpStatus.ok) return null;

      final bytesBuilder = BytesBuilder(copy: false);
      await for (final chunk in res) {
        bytesBuilder.add(chunk);
      }
      final bytes = bytesBuilder.takeBytes();
      _memoryCache[widget.imageUrl] = bytes;
      return bytes;
    } catch (e) {
      debugPrint('SmartImage TLS fallback error [${widget.imageUrl}]: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ShimmerWrapper(
            child: Skeleton(
              width: widget.width,
              height: widget.height,
              borderRadius: widget.borderRadius,
              shape: widget.shape,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return widget.errorWidget;
        }

        return ClipRRect(
          borderRadius: widget.shape == BoxShape.circle
              ? BorderRadius.zero
              : BorderRadius.circular(widget.borderRadius),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(shape: widget.shape),
            clipBehavior: Clip.antiAlias,
            child: Image.memory(
              snapshot.data!,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              gaplessPlayback: true,
            ),
          ),
        );
      },
    );
  }
}
