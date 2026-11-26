import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/avatar_expression.dart';
import '../../domain/avatar_mood.dart';
import '../controllers/avatar_frame.dart';
import '../controllers/avatar_motion_controller.dart';
import '../painters/avatar_effects_painter.dart';
import '../painters/chibi_body_painter.dart';
import '../painters/sprite_avatar_painter.dart';
import '../providers/avatar_controller.dart';
import '../providers/avatar_mood_provider.dart';
import '../providers/avatar_renderer_provider.dart';
import '../renderers/avatar_renderer.dart';
import '../renderers/chibi_procedural_renderer.dart';
import '../renderers/layered_sprite_renderer.dart';
import 'avatar_speech_bubble.dart';

/// Main interactive AI mascot widget ("Wynn").
/// Uses a single [Ticker] inside [AvatarMotionController] so per-frame motion
/// only repaints [CustomPaint] inside a [RepaintBoundary] without rebuilding widgets.
class WynnAiAvatar extends ConsumerStatefulWidget {
  const WynnAiAvatar({
    super.key,
    this.size = AvatarSize.md,
    this.customSize,
    this.interactive = true,
    this.animate = true,
    this.moodOverride,
    this.expressionOverride,
    this.pose = AvatarPoseMode.standing,
    this.heroTag,
    this.showSpeechBubble = false,
    this.initialBubbleText,
    this.preferGreetingBubble = false,
    this.showBubbleOnTap = false,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.renderer,
    this.debugReaction,
    this.debugReactionSeq = 0,
  });

  final AvatarSize size;
  final double? customSize;
  final bool interactive;
  final bool animate;
  final AvatarMood? moodOverride;

  /// Optional raw expression override used by [AvatarDebugPage] sliders.
  final AvatarExpression? expressionOverride;
  final AvatarPoseMode pose;
  final String? heroTag;
  final bool showSpeechBubble;
  final String? initialBubbleText;
  final bool preferGreetingBubble;
  final bool showBubbleOnTap;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final AvatarRenderer? renderer;

  /// Optional reaction trigger for debug gallery preview.
  final AvatarReaction? debugReaction;
  final int debugReactionSeq;

  @override
  ConsumerState<WynnAiAvatar> createState() => _WynnAiAvatarState();
}

class _WynnAiAvatarState extends ConsumerState<WynnAiAvatar>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AvatarMotionController _motionController;
  late ChibiBodyPainter _bodyPainter;
  late AvatarEffectsPainter _effectsPainter;
  final math.Random _tipRandom = math.Random();
  final LayerLink _layerLink = LayerLink();
  bool _appPaused = false;

  // Consecutive tap chain: tap1 -> boop, tap2 (<=1.5s) -> wink, tap3 -> giggle
  DateTime? _lastTapAt;
  int _tapChainCount = 0;

  // Inline speech bubble (when showSpeechBubble == true)
  AvatarSpeechPayload? _inlinePayload;
  bool _inlineBubbleVisible = false;

  // Floating overlay speech bubble (for long-press / showBubbleOnTap so it never overflows cards!)
  OverlayEntry? _overlayEntry;
  Timer? _bubbleHideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final AvatarMood initialMood =
        widget.moodOverride ?? ref.read<AvatarMood>(avatarMoodProvider);
    _motionController = AvatarMotionController(
      vsync: this,
      initialMood: initialMood,
      avatarSize: widget.size,
      poseMode: widget.pose,
      customExpression: widget.expressionOverride,
    );
    _rebuildPainters();

    if (widget.showSpeechBubble) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.initialBubbleText != null) {
          setState(() {
            _inlinePayload = AvatarSpeechPayload(
              text: widget.initialBubbleText!,
            );
            _inlineBubbleVisible = true;
          });
        } else {
          final payload = buildContextualSpeech(
            ref,
            preferGreeting: widget.preferGreetingBubble,
            random: _tipRandom,
          );
          setState(() {
            _inlinePayload = payload;
            _inlineBubbleVisible = true;
          });
        }
      });
    }
  }

  void _rebuildPainters() {
    _bodyPainter = ChibiBodyPainter(
      motionController: _motionController,
      avatarSize: widget.size,
      poseMode: widget.pose,
    );
    _effectsPainter = AvatarEffectsPainter(
      motionController: _motionController,
    );
  }

  void _syncTicker() {
    if (!mounted) return;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    _motionController.setRunning(
      shouldRun: widget.animate && tickerEnabled && !_appPaused,
      reduceMotion: disableAnimations,
    );
  }

  void _removeOverlayBubble() {
    _bubbleHideTimer?.cancel();
    _bubbleHideTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showContextualBubble({bool autoDismiss = true}) {
    final payload = buildContextualSpeech(
      ref,
      preferGreeting: false,
      random: _tipRandom,
    );

    if (widget.showSpeechBubble) {
      _bubbleHideTimer?.cancel();
      setState(() {
        _inlinePayload = payload;
        _inlineBubbleVisible = true;
      });
      if (autoDismiss) {
        _bubbleHideTimer = Timer(const Duration(milliseconds: 3500), () {
          if (mounted) {
            setState(() => _inlineBubbleVisible = false);
          }
        });
      }
      return;
    }

    // Use OverlayEntry for compact cards (like HostHeroCard) so bubble floats cleanly above!
    _removeOverlayBubble();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final side = widget.customSize ?? widget.size.dp;
    _overlayEntry = OverlayEntry(
      builder: (overlayCtx) => Positioned(
        width: math.max(200, side * 1.9),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topCenter,
          followerAnchor: Alignment.bottomCenter,
          offset: const Offset(0, -6),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: AvatarSpeechBubble(
                text: payload.text,
                actionHint: payload.actionHint,
                visible: true,
                maxWidth: math.max(196, side * 1.85),
                onTap: () {
                  final action = payload.onTap;
                  _removeOverlayBubble();
                  if (mounted) action?.call(context);
                },
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);

    if (autoDismiss) {
      _bubbleHideTimer = Timer(
        const Duration(milliseconds: 3500),
        _removeOverlayBubble,
      );
    }
  }

  void _dismissInlineBubble() {
    _bubbleHideTimer?.cancel();
    if (_inlineBubbleVisible && mounted) {
      setState(() => _inlineBubbleVisible = false);
    }
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    ref.read(avatarControllerProvider.notifier).registerInteraction();
    final effectiveMood = _motionController.effectiveMood;

    if (effectiveMood == AvatarMood.sleepy ||
        _motionController.isLocallySleepy) {
      _tapChainCount = 0;
      _motionController.registerLocalInteraction();
      _motionController.triggerLocalReaction(
        AvatarReaction.startle,
        duration: const Duration(milliseconds: 300),
      );
    } else {
      final now = DateTime.now();
      if (_lastTapAt != null &&
          now.difference(_lastTapAt!) <= const Duration(milliseconds: 1500)) {
        _tapChainCount = (_tapChainCount % 3) + 1;
      } else {
        _tapChainCount = 1;
      }
      _lastTapAt = now;

      final reaction = switch (_tapChainCount) {
        1 => AvatarReaction.boop,
        2 => AvatarReaction.wink,
        _ => AvatarReaction.giggle,
      };
      _motionController.triggerLocalReaction(reaction);
    }

    if (widget.showBubbleOnTap) {
      _showContextualBubble(autoDismiss: true);
    }
    widget.onTap?.call();
  }

  void _handleLongPress() {
    HapticFeedback.lightImpact();
    ref.read(avatarControllerProvider.notifier).registerInteraction();
    _motionController.triggerLocalReaction(AvatarReaction.wave);
    _showContextualBubble(autoDismiss: true);
    widget.onLongPress?.call();
  }

  void _handlePanStart(DragStartDetails details, double side) {
    ref.read(avatarControllerProvider.notifier).registerInteraction();
    _motionController.updateDrag(
      details.localPosition,
      Size.square(side),
      Offset.zero,
    );
  }

  void _handlePanUpdate(DragUpdateDetails details, double side) {
    final petted = _motionController.updateDrag(
      details.localPosition,
      Size.square(side),
      details.delta,
    );
    if (petted) {
      HapticFeedback.lightImpact();
    }
  }

  void _handlePanEnd([DragEndDetails? _]) {
    _motionController.endDrag();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant WynnAiAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.size != widget.size || oldWidget.pose != widget.pose) {
      _rebuildPainters();
    }
    final AvatarMood mood =
        widget.moodOverride ?? ref.read<AvatarMood>(avatarMoodProvider);
    _motionController.updateConfig(
      mood: mood,
      avatarSize: widget.size,
      poseMode: widget.pose,
      customExpression: widget.expressionOverride,
    );
    if (widget.debugReaction != null &&
        widget.debugReactionSeq != oldWidget.debugReactionSeq) {
      _motionController.triggerLocalReaction(widget.debugReaction!);
    }
    _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appPaused =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;
    _syncTicker();
  }

  @override
  void dispose() {
    _removeOverlayBubble();
    WidgetsBinding.instance.removeObserver(this);
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AvatarMood effectiveMood =
        widget.moodOverride ?? ref.watch<AvatarMood>(avatarMoodProvider);

    if (widget.moodOverride == null) {
      ref.listen<AvatarMood>(avatarMoodProvider, (prev, next) {
        _motionController.updateConfig(
          mood: next,
          avatarSize: widget.size,
          poseMode: widget.pose,
          customExpression: widget.expressionOverride,
        );
        if (widget.animate && prev != next) {
          if (next == AvatarMood.error ||
              next == AvatarMood.success ||
              next == AvatarMood.offline) {
            final view = View.maybeOf(context);
            if (view != null) {
              SemanticsService.sendAnnouncement(
                view,
                'Wynn: ${next.semanticLabel}',
                Directionality.of(context),
              );
            }
          }
        }
      });

      ref.listen<DateTime>(
        avatarControllerProvider.select((s) => s.lastInteraction),
        (_, next) {
          _motionController.updateConfig(
            mood: ref.read(avatarMoodProvider),
            avatarSize: widget.size,
            poseMode: widget.pose,
            customExpression: widget.expressionOverride,
            lastInteraction: next,
          );
        },
      );
    }

    if (widget.moodOverride == null && widget.animate) {
      ref.listen<int>(
        avatarControllerProvider.select((s) => s.chunkPulseSeq),
        (_, _) => _motionController.pulseChunk(),
      );

      ref.listen<int>(
        avatarControllerProvider.select((s) => s.userMessageSeq),
        (_, _) => _motionController.lookAtTemporary(
          const Offset(0.032, 0.004),
          duration: const Duration(milliseconds: 800),
        ),
      );

      ref.listen<(AvatarReaction?, int)>(
        avatarControllerProvider.select(
          (s) => (s.activeReaction, s.reactionSeq),
        ),
        (_, next) {
          final reaction = next.$1;
          if (reaction != null) {
            _motionController.triggerLocalReaction(reaction);
          }
        },
      );
    }

    final side = widget.customSize ?? widget.size.dp;
    final supportsDrag =
        widget.interactive &&
        (widget.size == AvatarSize.md || widget.size == AvatarSize.lg);

    final effectiveRenderer =
        widget.renderer ??
        ref.watch(avatarRendererProvider).asData?.value ??
        const ChibiProceduralRenderer();

    final renderedAvatar = effectiveRenderer.build(
      context,
      AvatarRenderInput(
        mood: effectiveMood,
        expression: _motionController.expression,
        tilt: _motionController.tiltNotifier.value,
        lookAt: _motionController.frame.pupilOffset,
        reaction: _motionController.activeLocalReaction,
        size: side,
        avatarSize: widget.size,
        poseMode: widget.pose,
        motionController: _motionController,
        bodyPainter: _bodyPainter,
        effectsPainter: _effectsPainter,
      ),
    );

    Widget avatarVisual = RepaintBoundary(
      child: ValueListenableBuilder<Offset>(
        valueListenable: _motionController.tiltNotifier,
        builder: (context, tilt, child) {
          if (tilt == Offset.zero) return child!;
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateX(tilt.dx)
            ..rotateY(tilt.dy);
          return Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: child,
          );
        },
        child: renderedAvatar,
      ),
    );

    if (widget.heroTag != null) {
      final staticExpr = _motionController.expression;
      final staticFrame = AvatarFrame.staticForPose(
        staticExpr.armPose,
        headTilt: staticExpr.headTilt,
        isQuestionAhoge: effectiveMood == AvatarMood.error,
      );
      final CustomPainter shuttlePainter =
          (effectiveRenderer is LayeredSpriteRenderer &&
              effectiveRenderer.isReady)
          ? SpriteAvatarPainter(
              manifest: effectiveRenderer.manifest,
              images: effectiveRenderer.images,
              staticExpression: staticExpr,
              staticFrame: staticFrame,
              avatarSize: AvatarSize.lg,
              poseMode: widget.pose,
            )
          : ChibiBodyPainter(
              staticExpression: staticExpr,
              staticFrame: staticFrame,
              avatarSize: AvatarSize.lg,
              poseMode: widget.pose,
            );
      avatarVisual = Hero(
        tag: widget.heroTag!,
        flightShuttleBuilder: (context, animation, direction, from, to) {
          return RepaintBoundary(
            child: SizedBox.expand(
              child: CustomPaint(painter: shuttlePainter),
            ),
          );
        },
        child: avatarVisual,
      );
    }

    if (widget.interactive) {
      // Ensure >= 48x48 accessible touch target even for xs (34dp) avatars
      final needsHitPad = side < 48.0;
      final hitChild = needsHitPad
          ? ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(child: avatarVisual),
            )
          : avatarVisual;

      avatarVisual = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onLongPress:
            (widget.size == AvatarSize.md ||
                widget.size == AvatarSize.lg ||
                widget.onLongPress != null)
            ? _handleLongPress
            : null,
        onPanStart: supportsDrag ? (d) => _handlePanStart(d, side) : null,
        onPanUpdate: supportsDrag ? (d) => _handlePanUpdate(d, side) : null,
        onPanEnd: supportsDrag ? _handlePanEnd : null,
        onPanCancel: supportsDrag ? _handlePanEnd : null,
        child: hitChild,
      );
    }

    avatarVisual = CompositedTransformTarget(
      link: _layerLink,
      child: avatarVisual,
    );

    Widget result = avatarVisual;
    if (_inlinePayload != null && widget.showSpeechBubble) {
      final payload = _inlinePayload!;
      result = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AvatarSpeechBubble(
            text: payload.text,
            actionHint: payload.actionHint,
            visible: _inlineBubbleVisible,
            maxWidth: math.max(180, side * 1.65),
            onTap: () {
              final action = payload.onTap;
              _dismissInlineBubble();
              action?.call(context);
            },
          ),
          const SizedBox(height: 6),
          avatarVisual,
        ],
      );
    }

    final label =
        widget.semanticLabel ??
        'Wynn, asisten AI. ${effectiveMood.semanticLabel}.'
            '${widget.interactive ? ' Ketuk untuk berinteraksi' : ''}';

    return Semantics(
      label: label,
      button: widget.interactive,
      child: result,
    );
  }
}
