import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';

/// Full-body 3D Wynn perched cleanly (absolute-positioned, zero chat gap) on
/// the top-left of her latest AI chat bubble with living idle animations:
/// - Soft breathing & gentle sway anchored at her sneakers
/// - Spontaneous cute idle emotes (shy wiggle, curious tilt, happy mini-hop)
/// - Tap-interactive expression cycle with bouncy hop & mini speech chip
class WynnBubblePeeker extends StatefulWidget {
  const WynnBubblePeeker({
    super.key,
    required this.isStreaming,
    required this.isError,
    required this.isLiked,
    this.hasFileChanges = false,
  });

  final bool isStreaming;
  final bool isError;
  final bool isLiked;
  final bool hasFileChanges;

  @override
  State<WynnBubblePeeker> createState() => _WynnBubblePeekerState();
}

class _WynnBubblePeekerState extends State<WynnBubblePeeker>
    with SingleTickerProviderStateMixin {
  static const _tapCycle = <(String asset, String line)>[
    ('assets/avatar/wynn_3d/pout.png', 'Hmph! Jangan dicolek mulu~'),
    ('assets/avatar/wynn_3d/happy.png', 'Hehe semangat, Wayan! ✨'),
    ('assets/avatar/wynn_3d/talking.png', 'Ada yang mau diubah lagi?'),
    ('assets/avatar/wynn_3d/thinking.png', 'Hmm... lagi mikir nih'),
    ('assets/avatar/wynn_3d/sleepy.png', 'Hoamm... ngantuk dikit~'),
  ];

  static const _idleEmotes = <String>[
    'assets/avatar/wynn_3d/happy.png',
    'assets/avatar/wynn_3d/pout.png',
    'assets/avatar/wynn_3d/thinking.png',
    'assets/avatar/wynn_3d/sleepy.png',
  ];

  late final AnimationController _idleController;
  final math.Random _rng = math.Random();

  int _tapIndex = -1;
  bool _hopping = false;
  String? _spontaneousAsset;
  bool _shyWiggle = false;
  Timer? _hopTimer;
  Timer? _resetTimer;
  Timer? _emoteLoopTimer;
  Timer? _emoteClearTimer;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _idleController.stop();
      _emoteLoopTimer?.cancel();
    } else {
      if (!_idleController.isAnimating) {
        _idleController.repeat();
      }
      _scheduleNextEmote();
    }
  }

  void _scheduleNextEmote() {
    _emoteLoopTimer?.cancel();
    final delaySec = 4 + _rng.nextInt(4); // every 4..7 seconds
    _emoteLoopTimer = Timer(Duration(seconds: delaySec), () {
      if (!mounted) return;
      if (_tapIndex == -1 && !widget.isStreaming && !widget.isError) {
        final pick = _idleEmotes[_rng.nextInt(_idleEmotes.length)];
        setState(() {
          _spontaneousAsset = pick;
          _shyWiggle = pick.contains('pout') || pick.contains('happy');
        });
        _emoteClearTimer?.cancel();
        _emoteClearTimer = Timer(const Duration(milliseconds: 2200), () {
          if (!mounted) return;
          setState(() {
            _spontaneousAsset = null;
            _shyWiggle = false;
          });
        });
      }
      _scheduleNextEmote();
    });
  }

  @override
  void dispose() {
    _hopTimer?.cancel();
    _resetTimer?.cancel();
    _emoteLoopTimer?.cancel();
    _emoteClearTimer?.cancel();
    _idleController.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    _hopTimer?.cancel();
    _resetTimer?.cancel();
    _emoteClearTimer?.cancel();
    setState(() {
      _spontaneousAsset = null;
      _shyWiggle = false;
      _tapIndex = (_tapIndex + 1) % _tapCycle.length;
      _hopping = true;
    });
    _hopTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _hopping = false);
    });
    _resetTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _tapIndex = -1);
    });
  }

  String _resolveAsset() {
    if (_tapIndex >= 0) return _tapCycle[_tapIndex].$1;
    if (widget.isError) return 'assets/avatar/wynn_3d/pout.png';
    if (widget.isStreaming) return 'assets/avatar/wynn_3d/thinking.png';
    if (widget.isLiked || widget.hasFileChanges) {
      return 'assets/avatar/wynn_3d/happy.png';
    }
    if (_spontaneousAsset != null) return _spontaneousAsset!;
    return 'assets/avatar/wynn_3d/idle.png';
  }

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    final asset = _resolveAsset();
    final reactionLine = _tapIndex >= 0 ? _tapCycle[_tapIndex].$2 : null;
    const figurineSize = 86.0;

    final imageNode = AnimatedSwitcher(
      duration: disableAnim
          ? Duration.zero
          : const Duration(milliseconds: 220),
      child: Image.asset(
        asset,
        key: ValueKey<String>(asset),
        width: figurineSize,
        height: figurineSize,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      ),
    );

    final animatedFigurine = disableAnim
        ? imageNode
        : RepaintBoundary(
            child: AnimatedBuilder(
              animation: _idleController,
              child: imageNode,
              builder: (context, child) {
                final t = _idleController.value * 2 * math.pi;
                // Gentle breathing & sway (faster wiggle when shy/streaming/error)
                final breatheY = 1.0 + math.sin(t * 4.0) * 0.026;
                final breatheX = 1.0 - math.sin(t * 4.0) * 0.014;
                final swayAngle = widget.isError
                    ? math.sin(t * 14.0) * 0.055
                    : _shyWiggle
                    ? math.sin(t * 10.0) * 0.085
                    : math.sin(t * 2.0) * 0.042;
                final floatDy = widget.isStreaming
                    ? -math.sin(t * 8.0).abs() * 4.5
                    : _shyWiggle
                    ? -math.sin(t * 6.0).abs() * 3.0
                    : math.sin(t * 4.0) * 1.6;

                return Transform.translate(
                  offset: Offset(0, floatDy),
                  child: Transform.rotate(
                    alignment: Alignment.bottomCenter,
                    angle: swayAngle,
                    child: Transform.scale(
                      alignment: Alignment.bottomCenter,
                      scaleX: breatheX,
                      scaleY: breatheY,
                      child: child,
                    ),
                  ),
                );
              },
            ),
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedSlide(
            offset: _hopping ? const Offset(0, -0.16) : Offset.zero,
            duration: disableAnim
                ? Duration.zero
                : const Duration(milliseconds: 170),
            curve: Curves.easeOutBack,
            child: AnimatedScale(
              scale: _hopping ? 1.09 : 1.0,
              duration: disableAnim
                  ? Duration.zero
                  : const Duration(milliseconds: 170),
              curve: Curves.easeOutBack,
              child: animatedFigurine,
            ),
          ),
        ),
        if (reactionLine != null) ...[
          const SizedBox(width: 2),
          IgnorePointer(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 165),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.isDark(context)
                    ? const Color(0xEE232846)
                    : Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                reactionLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.adaptiveTextPrimary(context),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
