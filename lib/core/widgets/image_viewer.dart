import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_pulchowk/core/widgets/interactive_wrapper.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';
import 'dart:ui';

class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isUiVisible = true;
  static const int _kInfiniteMultiplier = 10000;
  late int _initialPage;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    if (widget.imageUrls.length > 1) {
      _initialPage =
          ((_kInfiniteMultiplier ~/ 2) * widget.imageUrls.length) +
          widget.initialIndex;
    } else {
      _initialPage = widget.initialIndex;
    }
    _pageController = PageController(initialPage: _initialPage);
    // Hide status and navigation bars for immersive viewing
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Restore status and navigation bars
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-apply immersive mode in build to ensure it stays hidden
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => setState(() => _isUiVisible = !_isUiVisible),
        child: Stack(
          children: [
            // Background Blur
            Positioned.fill(
              child: SmartImage(
                imageUrl: widget.imageUrls[_currentIndex],
                fit: BoxFit.cover,
                useCloudinary: false, // Don't optimize background blur
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(color: Colors.black.withValues(alpha: 0.7)),
              ),
            ),

            // Main Image Gallery
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length > 1
                  ? _kInfiniteMultiplier * widget.imageUrls.length
                  : widget.imageUrls.length,
              onPageChanged: (index) => setState(
                () => _currentIndex = index % widget.imageUrls.length,
              ),
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final actualIndex = index % widget.imageUrls.length;
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: Hero(
                      tag: widget.imageUrls[actualIndex],
                      child: SmartImage(
                        imageUrl: widget.imageUrls[actualIndex],
                        fit: BoxFit.contain,
                        showProgress: true,
                        errorWidget: const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white54,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Top Controls
            if (_isUiVisible)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InteractiveWrapper(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (widget.imageUrls.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.imageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 40), // spacer for balance
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
