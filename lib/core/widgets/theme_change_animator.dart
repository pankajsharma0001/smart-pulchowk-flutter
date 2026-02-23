import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A global key for the [ThemeChangeAnimator].
/// Call [ThemeChangeAnimatorState.triggerAnimation] before changing theme.
final GlobalKey<ThemeChangeAnimatorState> themeAnimatorKey =
    GlobalKey<ThemeChangeAnimatorState>();

/// Wraps the app and intercepts theme changes to play a Telegram-style
/// circular reveal animation from the tapped widget's position.
class ThemeChangeAnimator extends StatefulWidget {
  final Widget child;

  const ThemeChangeAnimator({super.key, required this.child});

  @override
  State<ThemeChangeAnimator> createState() => ThemeChangeAnimatorState();
}

class ThemeChangeAnimatorState extends State<ThemeChangeAnimator>
    with SingleTickerProviderStateMixin {
  final _repaintKey = GlobalKey();
  ui.Image? _snapshot;
  Offset? _origin;
  bool _isDarkToLight = false;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _snapshot = null;
        });
        _controller.reset();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Changes the theme with a circular reveal animation.
  Future<void> changeTheme(VoidCallback toggle, Offset offset) async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        toggle();
        return;
      }

      final bool isCurrentlyDark =
          Theme.of(_repaintKey.currentContext!).brightness == Brightness.dark;

      if (isCurrentlyDark) {
        toggle();
        await Future.delayed(const Duration(milliseconds: 50));
        final image = await boundary.toImage(
          pixelRatio: View.of(context).devicePixelRatio,
        );
        setState(() {
          _snapshot = image;
          _origin = offset;
          _isDarkToLight = true;
        });
      } else {
        final image = await boundary.toImage(
          pixelRatio: View.of(context).devicePixelRatio,
        );
        setState(() {
          _snapshot = image;
          _origin = offset;
          _isDarkToLight = false;
        });
        toggle();
      }

      _controller.forward();
    } catch (e) {
      debugPrint('Failed to capture theme transition: $e');
      toggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: _repaintKey,
        child: Stack(
          children: [
            widget.child,
            if (_snapshot != null)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return ClipPath(
                      clipper: _CircularRevealClipper(
                        fraction: _controller.value,
                        center:
                            _origin ??
                            Offset(
                              MediaQuery.sizeOf(context).width / 2,
                              MediaQuery.sizeOf(context).height / 2,
                            ),
                        isDarkToLight: _isDarkToLight,
                      ),
                      child: CustomPaint(
                        painter: _SnapshotPainter(image: _snapshot!),
                        size: MediaQuery.sizeOf(context),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Clips to a circle of [radius] centered at [center].
/// When [inverted] is true, clips *outisde* the circle instead.
class _CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;
  final Offset center;
  final bool isDarkToLight;

  _CircularRevealClipper({
    required this.fraction,
    required this.center,
    required this.isDarkToLight,
  });

  @override
  Path getClip(Size size) {
    final Path path = Path();
    final double maxRadius = _calcMaxRadius(size, center);

    if (isDarkToLight) {
      // Dark → Light: Light theme EXPANDS from tap point
      final double radius = maxRadius * fraction;
      path.addOval(Rect.fromCircle(center: center, radius: radius));
    } else {
      // Light → Dark: Light theme SHRINKS into tap point
      final double radius = maxRadius * (1.0 - fraction);
      path.addOval(Rect.fromCircle(center: center, radius: radius));
    }

    return path;
  }

  double _calcMaxRadius(Size size, Offset center) {
    final double w = size.width;
    final double h = size.height;
    final double toTL = center.distance;
    final double toTR = (Offset(w, 0) - center).distance;
    final double toBL = (Offset(0, h) - center).distance;
    final double toBR = (Offset(w, h) - center).distance;
    return [toTL, toTR, toBL, toBR].reduce((a, b) => a > b ? a : b);
  }

  @override
  bool shouldReclip(_CircularRevealClipper old) => old.fraction != fraction;
}

/// Paints a [ui.Image] (the frozen screenshot) scaled to fill the canvas.
class _SnapshotPainter extends CustomPainter {
  final ui.Image image;

  _SnapshotPainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(_SnapshotPainter old) => old.image != image;
}
