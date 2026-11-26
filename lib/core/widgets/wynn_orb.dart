import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Iridescent luminous glass orb representing the WynnDiff AI coding agent,
/// inspired by the centerpiece plasma sphere in the visual reference.
class WynnOrb extends StatefulWidget {
  const WynnOrb({
    super.key,
    this.size = 152,
    this.animate = true,
    this.pulseFast = false,
  });

  final double size;
  final bool animate;
  final bool pulseFast;

  @override
  State<WynnOrb> createState() => _WynnOrbState();
}

class _WynnOrbState extends State<WynnOrb>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _appPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.pulseFast ? 2200 : 6500),
    );
  }

  void _syncAnimation() {
    if (!mounted) return;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (!widget.animate || disableAnimations || _appPaused) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant WynnOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulseFast != widget.pulseFast) {
      _controller.duration = Duration(
        milliseconds: widget.pulseFast ? 2200 : 6500,
      );
    }
    _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appPaused =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;
    _syncAnimation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 2 * math.pi;
          final scale = (widget.animate && !disableAnimations)
              ? 1.0 + math.sin(t) * 0.025
              : 1.0;

          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _WynnOrbPainter(phase: t),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WynnOrbPainter extends CustomPainter {
  _WynnOrbPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Soft outer halo shadow
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF819CFF).withValues(alpha: 0.34),
          const Color(0xFF9C7AFF).withValues(alpha: 0.14),
          Colors.transparent,
        ],
        stops: const [0.45, 0.78, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.28));
    canvas.drawCircle(center, radius * 1.24, haloPaint);

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    // Base cool-blue / periwinkle spherical gradient
    final basePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.22, -0.35),
        radius: 1.05,
        colors: [
          Color(0xFFB5C7FF),
          Color(0xFF6B96E8),
          Color(0xFF4F7AD4),
          Color(0xFF83B1F2),
        ],
        stops: [0.0, 0.45, 0.78, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, basePaint);

    // Floating warm coral/peach luminescence inside the orb
    final peachCenter = Offset(
      radius * (0.62 + 0.16 * math.cos(phase)),
      radius * (1.16 + 0.14 * math.sin(phase)),
    );
    final peachPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD6C2).withValues(alpha: 0.92),
          const Color(0xFFFFB2C2).withValues(alpha: 0.65),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: peachCenter, radius: radius * 0.92));
    canvas.drawCircle(peachCenter, radius * 0.92, peachPaint);

    // Floating cyan / ice specular wave on bottom-right
    final cyanCenter = Offset(
      radius * (1.42 + 0.12 * math.sin(phase)),
      radius * (1.36 + 0.12 * math.cos(phase)),
    );
    final cyanPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.95),
          const Color(0xFFA7E0FF).withValues(alpha: 0.70),
          Colors.transparent,
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(Rect.fromCircle(center: cyanCenter, radius: radius * 0.78));
    canvas.drawCircle(cyanCenter, radius * 0.78, cyanPaint);

    // Violet swirl top-left
    final violetCenter = Offset(
      radius * (0.55 + 0.14 * math.sin(phase + 1.2)),
      radius * (0.45 + 0.12 * math.cos(phase + 1.2)),
    );
    final violetPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF9F84FF).withValues(alpha: 0.75),
          const Color(0xFF6B8BFF).withValues(alpha: 0.25),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: violetCenter, radius: radius * 0.78),
      );
    canvas.drawCircle(violetCenter, radius * 0.78, violetPaint);

    // Soft white upper glass specular highlight
    final highlightCenter = Offset(radius * 0.78, radius * 0.42);
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.52),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: highlightCenter, radius: radius * 0.55),
      );
    canvas.drawCircle(highlightCenter, radius * 0.55, highlightPaint);

    // Crisp rim sheen
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.8),
          const Color(0xFF96B8FF).withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.7),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius - size.width * 0.012, rimPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WynnOrbPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}
