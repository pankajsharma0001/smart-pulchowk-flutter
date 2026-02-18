import 'package:flutter/material.dart';

class StaggeredScaleFade extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final double initialScale;
  final double verticalOffset;

  const StaggeredScaleFade({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 400),
    this.initialScale = 0.9,
    this.verticalOffset = 20.0,
  });

  @override
  State<StaggeredScaleFade> createState() => _StaggeredScaleFadeState();
}

class _StaggeredScaleFadeState extends State<StaggeredScaleFade>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(
      begin: widget.initialScale,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.verticalOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Stagger start based on index, capped at 10 items to avoid long delays
    final staggerIndex = widget.index % 10;
    Future.delayed(Duration(milliseconds: 50 * staggerIndex), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: Transform.scale(scale: _scaleAnimation.value, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}
