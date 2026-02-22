import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';

class AppRefresher extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const AppRefresher({super.key, required this.child, required this.onRefresh});

  @override
  State<AppRefresher> createState() => _AppRefresherState();
}

class _AppRefresherState extends State<AppRefresher>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late final ValueNotifier<double> _dragOffset;
  bool _isRefreshing = false;
  static const double _kTriggerOffset = 100.0;

  @override
  void initState() {
    super.initState();
    _dragOffset = ValueNotifier<double>(0.0);
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _dragOffset.dispose();
    _checkController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_isRefreshing) return false;

    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels < 0) {
        // High-frequency update: use ValueNotifier instead of setState
        _dragOffset.value = -notification.metrics.pixels;
      } else {
        if (_dragOffset.value != 0) {
          _dragOffset.value = 0;
        }
      }
    } else if (notification is ScrollEndNotification) {
      if (_dragOffset.value >= _kTriggerOffset) {
        _startRefresh();
      } else {
        _dragOffset.value = 0;
      }
    }
    return false;
  }

  Future<void> _startRefresh() async {
    // Structural change: setState is fine here as it's not during layout
    setState(() {
      _isRefreshing = true;
    });
    _dragOffset.value = _kTriggerOffset;
    _checkController.repeat();

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _checkController.stop();
        setState(() {
          _isRefreshing = false;
        });
        _dragOffset.value = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _dragOffset,
              builder: (context, offset, _) {
                final double currentHeight = math.max(
                  offset,
                  _isRefreshing ? _kTriggerOffset : 0,
                );
                if (currentHeight <= 0) return const SizedBox.shrink();

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  height: currentHeight,
                  child: ClipRect(
                    child: CustomPaint(
                      painter: _LiquidRefreshPainter(
                        progress: math.min(offset / _kTriggerOffset, 1.0),
                        isRefreshing: _isRefreshing,
                        rotation: _checkController,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidRefreshPainter extends CustomPainter {
  final double progress;
  final bool isRefreshing;
  final Animation<double> rotation;
  final Color color;

  _LiquidRefreshPainter({
    required this.progress,
    required this.isRefreshing,
    required this.rotation,
    required this.color,
  }) : super(repaint: rotation);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 && !isRefreshing) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final double pullAmount = progress.clamp(0.0, 1.0);
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    if (!isRefreshing) {
      // 1. Draw "Liquid Drop" stretching down
      final double radius = 15.0 + (5.0 * (1.0 - pullAmount));
      final double stretch = 40.0 * pullAmount;

      final path = Path();
      path.moveTo(centerX - radius, centerY - 10);
      path.quadraticBezierTo(
        centerX,
        centerY + stretch,
        centerX + radius,
        centerY - 10,
      );
      path.close();
      canvas.drawPath(path, paint);

      // 2. Draw circle that appears as it stretches
      canvas.drawCircle(
        Offset(centerX, centerY + stretch - 10),
        radius * pullAmount,
        paint,
      );
    } else {
      // 3. Draw "Spinning Bloom" when refreshing
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 3.0;

      final rect = Rect.fromCircle(
        center: Offset(centerX, centerY),
        radius: 15,
      );
      final double startAngle = rotation.value * 2 * math.pi;

      canvas.drawArc(rect, startAngle, 1.5 * math.pi, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidRefreshPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isRefreshing != isRefreshing;
  }
}
