import 'dart:math' as math;

import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_theme.dart';

/// Ring-spinner loading indicator built from the SehatSatli globe mark: a
/// rotating dashed ring around a gently pulsing logo mark. Matches the
/// "in-app loading indicator" spec (ring spinner variant) and is meant for
/// data-fetch loading states inside the app, as opposed to the native splash
/// screen shown before the Flutter engine boots (see flutter_native_splash
/// config in pubspec.yaml).
class AppLoadingIndicator extends StatefulWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = 72.0,
    this.ringColor,
    this.assetPath = 'assets/images/branding/icon-mark.png',
  });

  final double size;
  final Color? ringColor;
  final String assetPath;

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    final pulseCurve =
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(pulseCurve);
    _pulseOpacity = Tween<double>(begin: 1.0, end: 0.85).animate(pulseCurve);
  }

  @override
  void dispose() {
    _spinController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.ringColor ?? FlutterFlowTheme.of(context).primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _spinController,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _DashedRingPainter(color: color.withValues(alpha: 0.55)),
            ),
          ),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) => Opacity(
              opacity: _pulseOpacity.value,
              child: Transform.scale(scale: _pulseScale.value, child: child),
            ),
            child: Image.asset(
              widget.assetPath,
              width: widget.size * 0.62,
              height: widget.size * 0.62,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter({required this.color});

  final Color color;

  static const _dashDegrees = 28.0;
  static const _gapDegrees = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    final strokeWidth = math.max(2.0, size.width * 0.045);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    var angleDegrees = -90.0;
    while (angleDegrees < 270.0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angleDegrees * math.pi / 180,
        _dashDegrees * math.pi / 180,
        false,
        paint,
      );
      angleDegrees += _dashDegrees + _gapDegrees;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
