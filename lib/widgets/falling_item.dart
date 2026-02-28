import 'package:flutter/material.dart';
import 'dart:math' as math;

class FallingItem extends StatefulWidget {
  final Widget child;
  final Offset initialPosition;
  final Size size;
  final VoidCallback onFinished;
  final Color? backgroundColor;

  const FallingItem({
    super.key,
    required this.child,
    required this.initialPosition,
    required this.size,
    required this.onFinished,
    this.backgroundColor,
  });

  @override
  State<FallingItem> createState() => _FallingItemState();
}

class _FallingItemState extends State<FallingItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _xAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));

    // Dramatic gravity
    _yAnimation = Tween<double>(begin: 0, end: 2000).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInQuad));

    // Kick it out sideways
    final drift = (math.Random().nextDouble() - 0.5) * 450;
    _xAnimation = Tween<double>(begin: 0, end: drift).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Tumbling
    final rotation = (math.Random().nextDouble() - 0.5) * 6.0;
    _rotationAnimation = Tween<double>(begin: 0, end: rotation).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInCubic));

    // Fade out
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0)));

    // Scale pop then shrink
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 0.4), weight: 85),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward().then((_) => widget.onFinished());
    debugPrint('FallingItem: Started at ${widget.initialPosition}, Size: ${widget.size}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.initialPosition.dx,
      top: widget.initialPosition.dy,
      width: widget.size.width,
      height: widget.size.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.translate(
              offset: Offset(_xAnimation.value, _yAnimation.value),
              child: Transform.rotate(
                angle: _rotationAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 25,
                spreadRadius: 3,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Helper to trigger the falling animation from an existing widget's context
void triggerFallingItem(
  BuildContext context, 
  Widget tileWidget, 
  {Color? backgroundColor, Offset? manualPosition, Size? manualSize}
) {
  Offset position;
  Size size;

  if (manualPosition != null && manualSize != null) {
    position = manualPosition;
    size = manualSize;
  } else {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      debugPrint('triggerFallingItem: renderBox is null!');
      return;
    }
    position = renderBox.localToGlobal(Offset.zero);
    size = renderBox.size;
  }
  
  // Correction: Ensure X is 0 if it looks like it's been swiped away
  // Most lists started at the edge.
  if (position.dx < -20 || position.dx > 20) {
    position = Offset(0, position.dy);
  }

  final overlay = Overlay.of(context, rootOverlay: true);
  debugPrint('triggerFallingItem: Found overlay: $overlay, Position: $position');

  late OverlayEntry overlayEntry;
  // Capture theme here
  final themeData = Theme.of(context);
  
  overlayEntry = OverlayEntry(
    builder: (overlayContext) => Theme(
      data: themeData,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: FallingItem(
          initialPosition: position,
          size: size,
          backgroundColor: backgroundColor,
          onFinished: () {
            overlayEntry.remove();
          },
          child: Material(
            type: MaterialType.transparency,
            child: tileWidget,
          ),
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);
}
