import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;

enum ToastType { success, error, info }

class MusicToast extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismissed;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isBottom;

  const MusicToast({
    super.key,
    required this.message,
    required this.type,
    required this.onDismissed,
    this.actionLabel,
    this.onAction,
    this.isBottom = false,
  });

  @override
  State<MusicToast> createState() => _MusicToastState();
}

class _MusicToastState extends State<MusicToast> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  // New: For the "collapsing" effect
  late AnimationController _eqFlattenController;
  late Animation<double> _eqHeightFactor;

  // For the equalizer animation
  late AnimationController _eqController;
  
  // For the error shake animation
  late AnimationController _shakeController;

  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    
    // DIFFERENT ENTRANCE: Bottom popup doesn't slide, it POPS in
    _slideAnimation = Tween<Offset>(
      begin: widget.isBottom ? Offset.zero : const Offset(0, -1.2), 
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController, 
      curve: widget.isBottom ? Curves.linear : Curves.elasticOut,
    ));

    // Flick-away rotation for exit
    _rotateAnimation = Tween<double>(begin: 0.0, end: -0.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInQuad),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: widget.isBottom ? 0.4 : 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController, 
        curve: widget.isBottom ? Curves.easeOutBack : Curves.easeOutBack
      ),
    );

    // FLATTEN EFFECT: Before removed toast disappears, bars go flat
    _eqFlattenController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
    _eqHeightFactor = Tween<double>(begin: 1.0, end: 0.1).animate(
      CurvedAnimation(parent: _eqFlattenController, curve: Curves.easeInOut),
    );

    // Equalizer animation
    _eqController = AnimationController(
        vsync: this, 
        duration: Duration(milliseconds: widget.type == ToastType.success ? 500 : 800)
    )..repeat(reverse: true);

    // Shake animation (Error)
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    _animationController.forward().then((_) {
      if (widget.type == ToastType.error) {
         _shakeController.forward(from: 0.0);
      }
      
      final duration = widget.actionLabel != null ? 5 : 3;
      _dismissTimer = Timer(Duration(seconds: duration), () async {
        if (mounted) {
          if (widget.isBottom) {
            // "Removed" logic: first flatten the music bars symbols
            await _eqFlattenController.forward();
            // Then FLICK AWAY to the right
            _slideAnimation = Tween<Offset>(
              begin: Offset.zero, 
              end: const Offset(1.5, 0.0), // Fast slide right
            ).animate(CurvedAnimation(
              parent: _animationController, 
              curve: Curves.fastOutSlowIn,
            ));
            _animationController.reverse().then((_) => widget.onDismissed());
          } else {
            _animationController.reverse().then((_) => widget.onDismissed());
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animationController.dispose();
    _eqFlattenController.dispose();
    _eqController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor = Colors.white;

    switch (widget.type) {
      case ToastType.success:
        bgColor = const Color(0xFF4CAF50);
        break;
      case ToastType.error:
        bgColor = const Color(0xFFF44336);
        break;
      case ToastType.info:
        // Slightly "muted" coral for removals to distinguish from "Added" orange
        bgColor = widget.isBottom ? const Color(0xFFE57373) : const Color(0xFFFF6600);
        break;
    }

    Widget content = Container(
      margin: widget.isBottom 
          ? const EdgeInsets.fromLTRB(24, 0, 24, 110)
          : const EdgeInsets.fromLTRB(24, 48, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: widget.isBottom ? const Offset(0, -4) : const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.type == ToastType.error)
            Icon(Icons.warning_amber_rounded, color: textColor, size: 24)
          else
            SizedBox(
              width: 24,
              height: 24,
              child: AnimatedBuilder(
                animation: Listenable.merge([_eqController, _eqFlattenController]),
                builder: (context, child) {
                   final bool isSuccess = widget.type == ToastType.success;
                   final f = _eqHeightFactor.value;
                   return Row(
                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                       _buildEqBar(isSuccess ? (0.4 + (math.sin(_eqController.value * math.pi) * 0.6)) : 0.6 * f),
                       _buildEqBar((0.2 + (math.cos(_eqController.value * math.pi) * 0.8)) * f),
                       _buildEqBar(isSuccess ? (0.5 + (math.sin(_eqController.value * math.pi * math.pi) * 0.5)) : 0.4 * f),
                     ],
                   );
                },
              ),
            ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              widget.message,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          if (widget.actionLabel != null && widget.onAction != null) ...[
            const SizedBox(width: 8),
            Container(
              height: 24,
              width: 1,
              color: Colors.white24,
            ),
            TextButton(
              onPressed: () async {
                widget.onAction!();
                _dismissTimer?.cancel();
                if (widget.isBottom) {
                   await _eqFlattenController.forward();
                   _slideAnimation = Tween<Offset>(
                    begin: Offset.zero, 
                    end: const Offset(1.5, 0.0),
                  ).animate(CurvedAnimation(
                    parent: _animationController, 
                    curve: Curves.fastOutSlowIn,
                  ));
                }
                _animationController.reverse().then((_) => widget.onDismissed());
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                widget.actionLabel!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (widget.type == ToastType.error) {
       content = AnimatedBuilder(
         animation: _shakeController,
         builder: (context, child) {
           final sineValue = math.sin(_shakeController.value * 4 * math.pi);
           return Transform.translate(
             offset: Offset(sineValue * 8, 0),
             child: child,
           );
         },
         child: content,
       );
    }

    return SafeArea(
      child: Align(
        alignment: widget.isBottom ? Alignment.bottomCenter : Alignment.topCenter,
        child: AnimatedBuilder(
          animation: _rotateAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: widget.isBottom ? _rotateAnimation.value : 0.0,
              child: child,
            );
          },
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEqBar(double heightPercentage) {
    final safeHeight = math.max(2.0, 20 * heightPercentage);
    return Container(
      width: 4,
      height: safeHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _ToastAction {
  final BuildContext context;
  final String message;
  final ToastType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isBottom;
  
  _ToastAction(this.context, this.message, this.type, {
    this.actionLabel, 
    this.onAction,
    this.isBottom = false,
  });
}

final List<_ToastAction> _toastQueue = [];
bool _isToastShowing = false;

void showMusicToast(BuildContext context, String message, {
  ToastType type = ToastType.info,
  String? actionLabel,
  VoidCallback? onAction,
  bool isBottom = false,
}) {
  _toastQueue.add(_ToastAction(
    context, 
    message, 
    type, 
    actionLabel: actionLabel, 
    onAction: onAction,
    isBottom: isBottom,
  ));
  _showNextToast();
}

void _showNextToast() {
  if (_isToastShowing || _toastQueue.isEmpty) return;
  
  _isToastShowing = true;
  final action = _toastQueue.removeAt(0);
  
  if (!action.context.mounted) {
    _isToastShowing = false;
    _showNextToast();
    return;
  }

  final overlayState = Overlay.of(action.context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) {
      return MusicToast(
        message: action.message,
        type: action.type,
        actionLabel: action.actionLabel,
        onAction: action.onAction,
        isBottom: action.isBottom,
        onDismissed: () {
          overlayEntry.remove();
          _isToastShowing = false;
          _showNextToast();
        },
      );
    },
  );

  overlayState.insert(overlayEntry);
}
