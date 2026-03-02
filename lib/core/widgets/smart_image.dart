import 'dart:collection';
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
  final bool showProgress;

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
    this.showProgress = false,
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
    final String url = processedUrl;

    final uri = Uri.tryParse(url);
    final isPortalTu =
        uri != null &&
        uri.host.toLowerCase() == 'portal.tu.edu.np' &&
        uri.scheme == 'https';

    // Social media CDNs often block requests with custom User-Agents or specific headers
    final isSocial = ApiService.isSocialMediaDomain(url);
    final headers = isSocial ? null : AppConstants.imageHeaders;

    return ClipRRect(
      borderRadius: shape == BoxShape.circle
          ? BorderRadius.zero
          : BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(shape: shape),
        clipBehavior: Clip.hardEdge,
        child: isPortalTu
            ? _ProgressiveImage(
                imageUrl: url,
                headers: headers,
                width: width,
                height: height,
                fit: fit,
                borderRadius: borderRadius,
                shape: shape,
                errorWidget: errorWidget ?? _buildError(context),
              )
            : CachedNetworkImage(
                imageUrl: url,
                httpHeaders: headers,
                width: width,
                height: height,
                fit: fit,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                progressIndicatorBuilder: showProgress
                    ? (context, url, progress) => _ImageLoadingOverlay(
                        width: width,
                        height: height,
                        borderRadius: borderRadius,
                        shape: shape,
                        progress: progress.progress,
                      )
                    : null,
                placeholder: showProgress
                    ? null
                    : (context, url) => ShimmerWrapper(
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

/// A specialized widget that handles manual byte fetching with progress tracking
/// to avoid the "double download" and "white flash" issues.
class _ProgressiveImage extends StatefulWidget {
  final String imageUrl;
  final Map<String, String>? headers;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final BoxShape shape;
  final Widget errorWidget;

  const _ProgressiveImage({
    required this.imageUrl,
    this.headers,
    this.width,
    this.height,
    required this.fit,
    required this.borderRadius,
    required this.shape,
    required this.errorWidget,
  });

  @override
  State<_ProgressiveImage> createState() => _ProgressiveImageState();
}

class _ProgressiveImageState extends State<_ProgressiveImage> {
  /// LRU cache: max 50 entries. LinkedHashMap maintains insertion order;
  /// we move accessed entries to the end, and evict from the front.
  static const int _maxCacheSize = 50;
  static final LinkedHashMap<String, Uint8List> _imageCache =
      LinkedHashMap<String, Uint8List>();

  static Uint8List? _cacheGet(String key) {
    final value = _imageCache.remove(key);
    if (value != null) {
      _imageCache[key] = value; // Move to end (most recently used)
    }
    return value;
  }

  static void _cachePut(String key, Uint8List value) {
    _imageCache.remove(key); // Remove if exists to re-insert at end
    _imageCache[key] = value;
    while (_imageCache.length > _maxCacheSize) {
      _imageCache.remove(_imageCache.keys.first); // Evict oldest
    }
  }

  late Future<Uint8List?> _imageFuture;
  Uint8List? _resolvedBytes;
  double _progress = 0.0;
  bool _hasStartedDownloading = false;

  @override
  void initState() {
    super.initState();
    _resolvedBytes = _cacheGet(widget.imageUrl);
    _imageFuture = _fetchImage();
  }

  @override
  void didUpdateWidget(_ProgressiveImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      setState(() {
        _resolvedBytes = _cacheGet(widget.imageUrl);
        _progress = 0;
        _hasStartedDownloading = false;
        _imageFuture = _fetchImage();
      });
    }
  }

  Future<Uint8List?> _fetchImage() async {
    // 1. Check in-memory cache first
    final cached = _cacheGet(widget.imageUrl);
    if (cached != null) {
      if (mounted) setState(() => _resolvedBytes = cached);
      return cached;
    }

    final uri = Uri.tryParse(widget.imageUrl);
    if (uri == null) return null;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);

    // Handle TU Portal bad certificates
    if (uri.host == 'portal.tu.edu.np') {
      client.badCertificateCallback = (certificate, host, port) => true;
    }

    try {
      final request = await client.getUrl(uri);
      widget.headers?.forEach((key, value) {
        request.headers.add(key, value);
      });

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return null;

      final contentLength = response.contentLength;
      final bytesBuilder = BytesBuilder(copy: false);
      int downloaded = 0;

      if (mounted) {
        setState(() => _hasStartedDownloading = true);
      }

      await for (final chunk in response) {
        bytesBuilder.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0 && mounted) {
          setState(() => _progress = downloaded / contentLength);
        }
      }

      final bytes = bytesBuilder.takeBytes();
      _cachePut(widget.imageUrl, bytes);
      if (mounted) setState(() => _resolvedBytes = bytes);
      return bytes;
    } catch (e) {
      debugPrint('ProgressiveImage Error [${widget.imageUrl}]: $e');
      return null;
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Priority 1: If we have bytes (resolved or cached), show them IMMEDIATELY
    if (_resolvedBytes != null) {
      return _buildImage(_resolvedBytes!);
    }

    // Priority 2: Use FutureBuilder for the first load
    return FutureBuilder<Uint8List?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return _buildImage(snapshot.data!);
        }
        if (snapshot.hasError) return widget.errorWidget;

        // Still loading/downloading
        return _buildLoading(context);
      },
    );
  }

  Widget _buildLoading(BuildContext context) {
    return _ImageLoadingOverlay(
      width: widget.width,
      height: widget.height,
      borderRadius: widget.borderRadius,
      shape: widget.shape,
      progress: _hasStartedDownloading ? _progress : null,
    );
  }

  Widget _buildImage(Uint8List bytes) {
    return Image.memory(
      bytes,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
    );
  }
}

/// Internal shared loading overlay for SmartImage.
class _ImageLoadingOverlay extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;
  final double? progress;

  const _ImageLoadingOverlay({
    this.width,
    this.height,
    required this.borderRadius,
    required this.shape,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final pColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : Theme.of(context).primaryColor;

    return Stack(
      fit: StackFit.expand,
      children: [
        ShimmerWrapper(
          child: Skeleton(
            width: width,
            height: height,
            borderRadius: borderRadius,
            shape: shape,
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(pColor),
              ),
              if (progress != null && progress! > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${(progress! * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: pColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
