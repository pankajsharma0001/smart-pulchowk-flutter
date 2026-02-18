import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';

class InteractiveWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final bool enableHaptics;
  final BorderRadius? borderRadius;
  final bool useInkWell;

  const InteractiveWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.96,
    this.enableHaptics = true,
    this.borderRadius,
    this.useInkWell = true,
  });

  @override
  State<InteractiveWrapper> createState() => _InteractiveWrapperState();
}

class _InteractiveWrapperState extends State<InteractiveWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown() {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.forward();
    }
  }

  void _handleTapUp() {
    _controller.reverse();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      if (widget.enableHaptics) {
        haptics.lightImpact();
      }
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );

    if (widget.useInkWell) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap != null ? _handleTap : null,
            onLongPress: widget.onLongPress,
            onTapDown: (_) => _handleTapDown(),
            onTapCancel: _handleTapUp,
            onTapUp: (_) => _handleTapUp(),
            borderRadius: widget.borderRadius,
            child: widget.child,
          ),
        ),
      );
    }

    return GestureDetector(
      onTapDown: (_) => _handleTapDown(),
      onTapUp: (_) => _handleTapUp(),
      onTapCancel: _handleTapUp,
      onTap: _handleTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}
