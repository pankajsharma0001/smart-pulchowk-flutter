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
  Offset _origin = Offset.zero;
  bool _isAnimating = false;

  late final AnimationController _controller;
  late final Animation<double> _radiusAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _radiusAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isAnimating = false;
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

  /// Call this BEFORE changing the theme, passing the tap position (global).
  ///
  /// [origin] is where the ripple should expand/contract from.
  /// [isDarkMode] is the CURRENT mode (before change), used to decide
  /// whether to do an expand (→ dark) or shrink (→ light) effect.
  Future<void> triggerAnimation(
    Offset origin, {
    bool isDarkMode = false,
  }) async {
    // Take a screenshot of the current state
    final boundary =
        _repaintKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(
      pixelRatio: View.of(context).devicePixelRatio,
    );

    if (!mounted) return;

    setState(() {
      _snapshot = image;
      _origin = origin;
      _isAnimating = true;
    });

    await _controller.forward();
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
            // Overlay the frozen snapshot during animation
            if (_isAnimating && _snapshot != null)
              AnimatedBuilder(
                animation: _radiusAnimation,
                builder: (context, _) {
                  // Compute max possible radius to fill screen
                  final size = MediaQuery.sizeOf(context);
                  final maxRadius = _computeMaxRadius(size, _origin);

                  return ClipPath(
                    clipper: _CircularRevealClipper(
                      center: _origin,
                      radius: maxRadius * _radiusAnimation.value,
                      // We clip away the OLD snapshot as the circle grows
                      // (revealing the new theme beneath)
                      inverted: false,
                    ),
                    child: SizedBox.expand(
                      child: CustomPaint(
                        painter: _SnapshotPainter(image: _snapshot!),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  double _computeMaxRadius(Size size, Offset origin) {
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    return corners.fold<double>(0, (prev, c) {
      final d = (c - origin).distance;
      return d > prev ? d : prev;
    });
  }
}

/// Clips to a circle of [radius] centered at [center].
/// When [inverted] is true, clips *outisde* the circle instead.
class _CircularRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  final bool inverted;

  _CircularRevealClipper({
    required this.center,
    required this.radius,
    required this.inverted,
  });

  @override
  Path getClip(Size size) {
    final circle = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    if (inverted) {
      return Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        circle,
      );
    }
    return circle;
  }

  @override
  bool shouldReclip(_CircularRevealClipper old) =>
      old.radius != radius || old.center != center || old.inverted != inverted;
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
