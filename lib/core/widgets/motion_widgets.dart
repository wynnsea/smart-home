import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import 'wynn_orb.dart';

/// Staggered fade + directional slide entrance using a single AnimationController
/// with Interval, honoring [MediaQuery.disableAnimationsOf] (T5.5).
class FadeSlideEntrance extends StatefulWidget {
  const FadeSlideEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 480),
    this.offset = const Offset(0, 18),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  State<FadeSlideEntrance> createState() => _FadeSlideEntranceState();
}

class _FadeSlideEntranceState extends State<FadeSlideEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final totalMs = widget.delay.inMilliseconds + widget.duration.inMilliseconds;
    final startFraction = totalMs == 0
        ? 0.0
        : (widget.delay.inMilliseconds / totalMs).clamp(0.0, 0.85);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: math.max(1, totalMs)),
    );
    _curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(startFraction, 1.0, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1.0;
      _started = true;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _curved,
      child: widget.child,
      builder: (context, child) {
        final v = _curved.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(
              widget.offset.dx * (1 - v),
              widget.offset.dy * (1 - v),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// Tactile press micro-interaction with optional Semantics button wrapper (T5.1).
class BouncyTap extends StatefulWidget {
  const BouncyTap({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.96,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final String? semanticLabel;

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: widget.onTap != null,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      child: Listener(
        onPointerDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onPointerUp: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        onPointerCancel: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.translucent,
          child: AnimatedScale(
            scale: (_pressed && !disableAnimations) ? widget.pressedScale : 1.0,
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 140),
            curve: Curves.easeOutBack,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Softly pulsing live status indicator dot honoring Reduce Motion.
class PulsingDot extends StatefulWidget {
  const PulsingDot({
    super.key,
    this.color = AppColors.tintGreenFg,
    this.size = 8,
  });

  final Color color;
  final double size;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: widget.size * 2.1,
      height: widget.size * 2.1,
      child: disableAnimations
          ? Center(
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            )
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final ringScale = 1.0 + _controller.value * 1.1;
                final ringOpacity = (1.0 - _controller.value) * 0.45;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: ringScale,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color.withValues(alpha: ringOpacity),
                        ),
                      ),
                    ),
                    Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

/// Animated 3-dot wave indicator while the AI agent streams an investigation.
class TypingWaveDots extends StatefulWidget {
  const TypingWaveDots({
    super.key,
    this.color = AppColors.primary,
  });

  final Color color;

  @override
  State<TypingWaveDots> createState() => _TypingWaveDotsState();
}

class _TypingWaveDotsState extends State<TypingWaveDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: 5.5,
              height: 5.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value * 2 * math.pi) - (i * 0.85);
            final dy = math.sin(phase) * 3.0;
            final alpha = 0.45 + ((math.sin(phase) + 1) * 0.275);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Container(
                  width: 5.5,
                  height: 5.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: alpha),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Animated voice equalizer bars kept ready for future speech-to-text integration.
class VoiceWaveBars extends StatefulWidget {
  const VoiceWaveBars({super.key, this.color = AppColors.primary});

  final Color color;

  @override
  State<VoiceWaveBars> createState() => _VoiceWaveBarsState();
}

class _VoiceWaveBarsState extends State<VoiceWaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(4, (i) {
            final t = (_controller.value * 2 * math.pi) + i * 1.1;
            final height = disableAnimations
                ? 10.0
                : 6 + ((math.sin(t) + 1) * 5.5);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.4),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Floating AI Orb with gentle levitation bob and aura rings, honoring Reduce Motion.
class LevitationOrb extends StatefulWidget {
  const LevitationOrb({
    super.key,
    required this.size,
    this.heroTag,
    this.showAuraRings = true,
  });

  final double size;
  final String? heroTag;
  final bool showAuraRings;

  @override
  State<LevitationOrb> createState() => _LevitationOrbState();
}

class _LevitationOrbState extends State<LevitationOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final orb = WynnOrb(size: widget.size);
    final heroWrapped = widget.heroTag != null
        ? Hero(tag: widget.heroTag!, child: orb)
        : orb;

    if (disableAnimations) {
      return SizedBox(
        width: widget.size * 1.24,
        height: widget.size * 1.24,
        child: Center(child: heroWrapped),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      child: heroWrapped,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;
        final floatY = math.sin(t) * 6.5;
        final ring1Scale = 1.0 + _controller.value * 0.34;
        final ring1Alpha = (1.0 - _controller.value) * 0.28;
        final ring2Val = (_controller.value + 0.5) % 1.0;
        final ring2Scale = 1.0 + ring2Val * 0.34;
        final ring2Alpha = (1.0 - ring2Val) * 0.22;

        return SizedBox(
          width: widget.size * 1.38,
          height: widget.size * 1.34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.showAuraRings) ...[
                Transform.scale(
                  scale: ring1Scale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryLight.withValues(
                          alpha: ring1Alpha,
                        ),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: ring2Scale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF7CB8FF).withValues(
                          alpha: ring2Alpha,
                        ),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
              Transform.translate(
                offset: Offset(0, floatY),
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Fluid fade + gentle scale/slide route that respects Reduce Motion.
class EtherealPageRoute<T> extends PageRouteBuilder<T> {
  EtherealPageRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context)) {
            return child;
          }
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.045),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved),
                child: child,
              ),
            ),
          );
        },
      );
}
