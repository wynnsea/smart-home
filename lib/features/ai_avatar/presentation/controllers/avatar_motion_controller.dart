import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/avatar_expression.dart';
import '../../domain/avatar_mood.dart';
import '../painters/avatar_body_painter.dart';
import 'avatar_frame.dart';

/// Local per-widget animation engine holding a SINGLE [Ticker] for all
/// breathing, blinking, glances, squash & stretch, spring-lagged antenna,
/// expression interpolation, particles, idle fidgets, sleepy detection,
/// and 3D drag tilt spring physics.
class AvatarMotionController extends ChangeNotifier {
  AvatarMotionController({
    required TickerProvider vsync,
    required AvatarMood initialMood,
    required AvatarSize avatarSize,
    AvatarPoseMode poseMode = AvatarPoseMode.standing,
    AvatarExpression? customExpression,
    int? seed,
  }) : _mood = initialMood,
       _sizeConfig = avatarSize,
       _poseMode = poseMode,
       _customExpression = customExpression,
       _random = math.Random(
         seed ??
             (DateTime.now().microsecondsSinceEpoch ^
                 identityHashCode(vsync)),
       ) {
    final initExpr =
        customExpression ?? expressionForMood(initialMood, poseMode: poseMode);
    _fromExpression = initExpr;
    _targetExpression = initExpr;
    _currentExpression = initExpr;
    final (lh, rh) = handTargetsForPose(initExpr.armPose);
    _leftHandPos = lh;
    _rightHandPos = rh;
    _frame = AvatarFrame.staticForPose(initExpr.armPose);
    _scheduleNextBlink();
    _scheduleNextGlance();
    _scheduleNextFidget();
    _ticker = vsync.createTicker(_onTick);
  }

  late final Ticker _ticker;
  final math.Random _random;

  AvatarMood _mood;
  AvatarSize _sizeConfig;
  AvatarPoseMode _poseMode;
  AvatarExpression? _customExpression;

  bool _isRunning = false;
  bool _reduceMotion = false;
  double _elapsed = 0.0;
  double _lastTickSeconds = 0.0;
  int _effectsVersion = 0;

  // Expression transition (280ms easeOutCubic)
  late AvatarExpression _fromExpression;
  late AvatarExpression _targetExpression;
  late AvatarExpression _currentExpression;
  double _exprTransitionElapsed = 1.0;
  static const double _exprTransitionDuration = 0.28;

  // Mood enter timer (for success jump, error shake, etc.)
  double _moodAge = 0.0;

  // Transient local reaction (tap boop, wink, giggle, pet, wave, startle)
  AvatarReaction? _localReaction;
  double _localReactionRemaining = 0.0;
  double _localReactionAge = 0.0;

  // Squash & stretch impulse
  double _squashElapsed = 1.0;
  double _squashDuration = 0.22;
  double _squashPeakX = 1.04;
  double _squashPeakY = 0.94;

  // Blink state
  double _nextBlinkAt = 3.0;
  double _blinkElapsed = -1.0;
  bool _pendingDoubleBlink = false;
  static const double _blinkDuration = 0.14;

  // Random gaze glances & temporary content look-at
  double _nextGlanceAt = 5.0;
  double _glanceRemaining = 0.0;
  Offset _glanceTarget = Offset.zero;
  Offset _currentPupil = Offset.zero;
  Offset? _contentLookTarget;
  double _contentLookRemaining = 0.0;

  // Streaming mouth kick & chunk bob
  double _chunkKick = 0.0;

  // Idle fidgets
  double _nextFidgetAt = 24.0;
  int _activeFidgetKind = -1; // 0=wave, 1=cheek, 2=antennaSpin, 3=yawn
  double _fidgetRemaining = 0.0;

  // Sleepy tracking (checked inside ticker without Timer.periodic)
  DateTime _lastInteraction = DateTime.now();
  bool _isLocallySleepy = false;
  static const Duration _sleepyThreshold = Duration(seconds: 45);
  double _sleepyYawnRemaining = 0.0;
  double _nextYawnAt = 12.0;

  // Antenna spring physics (1-frame lag behind body movement & tilt)
  Offset _antennaPos = Offset.zero;
  Offset _antennaVel = Offset.zero;

  // Smoothly interpolated hand positions
  late Offset _leftHandPos;
  late Offset _rightHandPos;

  // 3D drag tilt + spring return (local-only, never in Riverpod)
  final ValueNotifier<Offset> tiltNotifier = ValueNotifier<Offset>(Offset.zero);
  bool _isDragging = false;
  Offset _dragFingerPupil = Offset.zero;
  SpringSimulation? _springTiltX;
  SpringSimulation? _springTiltY;
  double _springElapsed = 0.0;
  static const SpringDescription _tiltSpring = SpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 14.0,
  );

  // Horizontal pet detection (>= 3 direction reversals in 1.2s)
  double _lastDragDxSign = 0.0;
  final List<double> _petReversalTimes = [];

  // Particle pool (max 8 active)
  final List<AvatarParticle> _particles = [];
  double _ambientParticleCooldown = 0.0;

  late AvatarFrame _frame;

  // Public getters for painters & widgets
  AvatarExpression get expression => _currentExpression;
  AvatarFrame get frame => _frame;
  AvatarMood get effectiveMood =>
      (_mood == AvatarMood.idle && _isLocallySleepy) ? AvatarMood.sleepy : _mood;
  AvatarReaction? get activeLocalReaction => _localReaction;
  List<AvatarParticle> get particles => _particles;
  int get effectsVersion => _effectsVersion;
  bool get isLocallySleepy => _isLocallySleepy;

  void setRunning({required bool shouldRun, required bool reduceMotion}) {
    _reduceMotion = reduceMotion;
    if (!shouldRun || reduceMotion) {
      if (_ticker.isActive) {
        _ticker.stop();
      }
      _isRunning = false;
      _snapToStaticState();
      notifyListeners();
      return;
    }

    if (!_isRunning) {
      _isRunning = true;
      _lastTickSeconds = 0.0;
      if (!_ticker.isActive) {
        _ticker.start();
      }
    }
  }

  void updateConfig({
    required AvatarMood mood,
    required AvatarSize avatarSize,
    required AvatarPoseMode poseMode,
    AvatarExpression? customExpression,
    DateTime? lastInteraction,
  }) {
    final moodChanged = mood != _mood;
    final poseChanged = poseMode != _poseMode;
    final customChanged = customExpression != _customExpression;

    _sizeConfig = avatarSize;
    _poseMode = poseMode;
    _customExpression = customExpression;

    if (lastInteraction != null && lastInteraction.isAfter(_lastInteraction)) {
      _lastInteraction = lastInteraction;
      if (_isLocallySleepy) {
        _isLocallySleepy = false;
      }
    }

    if (moodChanged) {
      _mood = mood;
      _moodAge = 0.0;
      if (mood != AvatarMood.idle) {
        _isLocallySleepy = false;
      }
      _triggerSquash();
      _onMoodEntered(mood);
    }

    if (moodChanged || poseChanged || customChanged) {
      _recomputeTargetExpression();
      if (!_isRunning || _reduceMotion) {
        _snapToStaticState();
      }
      notifyListeners();
    }
  }

  void pulseChunk() {
    _chunkKick = 1.0;
    if (_isRunning && !_reduceMotion) {
      notifyListeners();
    }
  }

  void lookAtTemporary(
    Offset normalizedTarget, {
    Duration duration = const Duration(milliseconds: 800),
  }) {
    _contentLookTarget = Offset(
      normalizedTarget.dx.clamp(-0.035, 0.035),
      normalizedTarget.dy.clamp(-0.035, 0.035),
    );
    _contentLookRemaining = duration.inMilliseconds / 1000.0;
  }

  void registerLocalInteraction() {
    _lastInteraction = DateTime.now();
    if (_isLocallySleepy) {
      _isLocallySleepy = false;
      triggerLocalReaction(
        AvatarReaction.startle,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  void triggerLocalReaction(
    AvatarReaction reaction, {
    Duration? duration,
  }) {
    _lastInteraction = DateTime.now();
    _isLocallySleepy = false;
    _localReaction = reaction;
    _localReactionAge = 0.0;
    _localReactionRemaining = (duration ?? _defaultReactionDuration(reaction))
            .inMilliseconds /
        1000.0;
    _triggerSquash(
      peakX: reaction == AvatarReaction.boop ? 1.10 : 1.06,
      peakY: reaction == AvatarReaction.boop ? 0.89 : 0.93,
    );
    _spawnReactionParticles(reaction);
    _recomputeTargetExpression();
    if (!_isRunning || _reduceMotion) {
      _snapToStaticState();
    }
    notifyListeners();
  }

  /// Updates 3D drag tilt and eye-tracking from pointer local coordinates.
  /// Returns `true` on the frame a horizontal "pet" gesture is detected!
  bool updateDrag(Offset localPosition, Size boxSize, Offset delta) {
    if (boxSize.isEmpty) return false;
    _lastInteraction = DateTime.now();
    _isLocallySleepy = false;
    _isDragging = true;
    _springTiltX = null;
    _springTiltY = null;

    final nx = ((localPosition.dx / boxSize.width) * 2.0 - 1.0).clamp(-1.0, 1.0);
    final ny = ((localPosition.dy / boxSize.height) * 2.0 - 1.0).clamp(-1.0, 1.0);

    // Tilt towards finger (max ±0.35 rad)
    final nextTilt = Offset(-ny * 0.35, nx * 0.35);
    tiltNotifier.value = nextTilt;
    _dragFingerPupil = Offset(nx * 0.035, ny * 0.035);

    // Detect horizontal petting (>= 3 direction flips within 1.2s)
    var petTriggered = false;
    if (delta.dx.abs() > 2.2) {
      final sign = delta.dx > 0 ? 1.0 : -1.0;
      if (_lastDragDxSign != 0 && sign != _lastDragDxSign) {
        _petReversalTimes.add(_elapsed);
        _petReversalTimes.removeWhere((t) => _elapsed - t > 1.2);
        if (_petReversalTimes.length >= 3) {
          _petReversalTimes.clear();
          triggerLocalReaction(
            AvatarReaction.pet,
            duration: const Duration(milliseconds: 1200),
          );
          petTriggered = true;
        }
      }
      _lastDragDxSign = sign;
    }

    if (!_isRunning) {
      notifyListeners();
    }
    return petTriggered;
  }

  /// Releases 3D drag tilt back to neutral with an underdamped spring simulation.
  void endDrag() {
    if (!_isDragging) return;
    _isDragging = false;
    _lastDragDxSign = 0.0;
    final current = tiltNotifier.value;
    if (_reduceMotion || !_isRunning) {
      tiltNotifier.value = Offset.zero;
      _dragFingerPupil = Offset.zero;
      notifyListeners();
      return;
    }
    _springElapsed = 0.0;
    _springTiltX = SpringSimulation(_tiltSpring, current.dx, 0.0, 0.0);
    _springTiltY = SpringSimulation(_tiltSpring, current.dy, 0.0, 0.0);
  }

  Duration _defaultReactionDuration(AvatarReaction r) {
    return switch (r) {
      AvatarReaction.boop => const Duration(milliseconds: 350),
      AvatarReaction.wink => const Duration(milliseconds: 700),
      AvatarReaction.giggle => const Duration(milliseconds: 950),
      AvatarReaction.pet => const Duration(milliseconds: 1200),
      AvatarReaction.wave => const Duration(milliseconds: 1200),
      AvatarReaction.nod => const Duration(milliseconds: 550),
      AvatarReaction.success => const Duration(milliseconds: 2400),
      AvatarReaction.errorShake => const Duration(milliseconds: 550),
      AvatarReaction.startle => const Duration(milliseconds: 300),
    };
  }

  void _triggerSquash({
    double peakX = 1.04,
    double peakY = 0.94,
    double duration = 0.22,
  }) {
    _squashElapsed = 0.0;
    _squashDuration = duration;
    _squashPeakX = peakX;
    _squashPeakY = peakY;
  }

  void _recomputeTargetExpression() {
    AvatarExpression next;
    if (_customExpression != null) {
      next = _customExpression!;
    } else {
      final base = expressionForMood(effectiveMood, poseMode: _poseMode);
      if (_localReaction != null) {
        next = expressionForReaction(_localReaction!, base);
      } else {
        next = base;
      }
    }

    if (next != _targetExpression) {
      _fromExpression = _currentExpression;
      _targetExpression = next;
      _exprTransitionElapsed = 0.0;
    }
  }

  void _snapToStaticState() {
    _recomputeTargetExpression();
    _currentExpression = _targetExpression;
    _exprTransitionElapsed = _exprTransitionDuration;
    final (lh, rh) = handTargetsForPose(_currentExpression.armPose);
    _leftHandPos = lh;
    _rightHandPos = rh;
    _antennaPos = Offset.zero;
    _antennaVel = Offset.zero;
    tiltNotifier.value = Offset.zero;
    _particles
      ..clear()
      ..addAll(
        _sizeConfig.maxParticles > 0
            ? staticParticlesForMood(effectiveMood)
                .take(_sizeConfig.maxParticles)
            : const [],
      );
    _effectsVersion++;
    _frame = AvatarFrame(
      leftHandPos: _leftHandPos,
      rightHandPos: _rightHandPos,
      pupilOffset: effectiveMood == AvatarMood.listening
          ? const Offset(0, 0.025)
          : effectiveMood == AvatarMood.thinking
          ? const Offset(0.022, -0.02)
          : Offset.zero,
      bodyScale: effectiveMood == AvatarMood.listening ? 1.04 : 1.0,
    );
  }

  void _onMoodEntered(AvatarMood mood) {
    if (_sizeConfig.maxParticles <= 0 || _reduceMotion) return;
    switch (mood) {
      case AvatarMood.listening:
        _spawnParticle(
          AvatarParticle(
            kind: AvatarParticleKind.sparkle,
            position: const Offset(0.84, 0.22),
            velocity: const Offset(0.04, -0.10),
            age: 0,
            lifetime: 0.75,
            scale: 0.9,
            color: AppColors.tintBlueFg,
          ),
        );
      case AvatarMood.success:
        final count = math.min(5, _sizeConfig.maxParticles);
        const colors = [
          AppColors.tintGreenFg,
          AppColors.primary,
          AppColors.tintAmberFg,
          AppColors.avatarBlush,
          AppColors.tintBlueFg,
        ];
        for (var i = 0; i < count; i++) {
          final angle = -math.pi * 0.85 + (i / math.max(1, count - 1)) * math.pi * 0.7;
          final speed = 0.22 + _random.nextDouble() * 0.14;
          _spawnParticle(
            AvatarParticle(
              kind: AvatarParticleKind.sparkle,
              position: Offset(0.5 + math.cos(angle) * 0.25, 0.32),
              velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
              age: 0,
              lifetime: 0.95 + _random.nextDouble() * 0.35,
              scale: 0.8 + _random.nextDouble() * 0.45,
              color: colors[i % colors.length],
              rotation: _random.nextDouble() * math.pi,
            ),
          );
        }
      case AvatarMood.error:
        _spawnParticle(
          AvatarParticle(
            kind: AvatarParticleKind.sweat,
            position: const Offset(0.79, 0.34),
            velocity: const Offset(0.01, 0.10),
            age: 0,
            lifetime: 1.25,
            scale: 1.0,
            color: AppColors.tintBlueFg,
          ),
        );
      default:
        break;
    }
  }

  void _spawnReactionParticles(AvatarReaction reaction) {
    if (_sizeConfig.maxParticles <= 0 || _reduceMotion) return;
    switch (reaction) {
      case AvatarReaction.boop:
        _spawnParticle(
          AvatarParticle(
            kind: AvatarParticleKind.heart,
            position: Offset(0.56 + (_random.nextDouble() - 0.5) * 0.2, 0.22),
            velocity: const Offset(0.03, -0.18),
            age: 0,
            lifetime: 0.9,
            scale: 1.0,
            color: AppColors.avatarBlush,
          ),
        );
      case AvatarReaction.pet:
        for (var i = 0; i < math.min(3, _sizeConfig.maxParticles); i++) {
          _spawnParticle(
            AvatarParticle(
              kind: AvatarParticleKind.heart,
              position: Offset(0.32 + i * 0.18, 0.25 - i * 0.03),
              velocity: Offset((i - 1) * 0.06, -0.18 - i * 0.03),
              age: 0,
              lifetime: 1.05 + i * 0.12,
              scale: 0.85 + i * 0.12,
              color: i.isEven ? AppColors.avatarBlush : AppColors.primaryLight,
            ),
          );
        }
      case AvatarReaction.giggle:
      case AvatarReaction.success:
        for (var i = 0; i < math.min(3, _sizeConfig.maxParticles); i++) {
          _spawnParticle(
            AvatarParticle(
              kind: i == 1
                  ? AvatarParticleKind.heart
                  : AvatarParticleKind.sparkle,
              position: Offset(0.24 + i * 0.26, 0.24),
              velocity: Offset((i - 1) * 0.10, -0.20),
              age: 0,
              lifetime: 0.95,
              scale: 0.95,
              color: i == 1 ? AppColors.avatarBlush : AppColors.primary,
            ),
          );
        }
      case AvatarReaction.wink:
      case AvatarReaction.wave:
        _spawnParticle(
          AvatarParticle(
            kind: AvatarParticleKind.sparkle,
            position: const Offset(0.82, 0.20),
            velocity: const Offset(0.05, -0.12),
            age: 0,
            lifetime: 0.8,
            scale: 0.9,
            color: AppColors.primaryLight,
          ),
        );
      case AvatarReaction.errorShake:
        _spawnParticle(
          AvatarParticle(
            kind: AvatarParticleKind.sweat,
            position: const Offset(0.80, 0.34),
            velocity: const Offset(0.01, 0.10),
            age: 0,
            lifetime: 1.1,
            scale: 0.95,
            color: AppColors.tintBlueFg,
          ),
        );
      default:
        break;
    }
  }

  void _spawnParticle(AvatarParticle p) {
    final limit = _sizeConfig.maxParticles;
    if (limit <= 0) return;
    while (_particles.length >= limit) {
      _particles.removeAt(0);
    }
    _particles.add(p);
    _effectsVersion++;
  }

  void _scheduleNextBlink() {
    _nextBlinkAt = _elapsed + 2.5 + _random.nextDouble() * 3.5;
  }

  void _scheduleNextGlance() {
    _nextGlanceAt = _elapsed + 4.0 + _random.nextDouble() * 5.0;
  }

  void _scheduleNextFidget() {
    _nextFidgetAt = _elapsed + 20.0 + _random.nextDouble() * 20.0;
  }

  void _onTick(Duration elapsedDuration) {
    final nowSeconds = elapsedDuration.inMicroseconds / 1e6;
    final dt = (_lastTickSeconds == 0.0
            ? 0.016
            : (nowSeconds - _lastTickSeconds))
        .clamp(0.001, 0.05);
    _lastTickSeconds = nowSeconds;
    _elapsed += dt;
    _moodAge += dt;

    // 1. Check sleepy threshold when idle (no Timer.periodic!)
    if (_mood == AvatarMood.idle && _customExpression == null) {
      final shouldSleep =
          DateTime.now().difference(_lastInteraction) > _sleepyThreshold;
      if (shouldSleep != _isLocallySleepy) {
        _isLocallySleepy = shouldSleep;
        _recomputeTargetExpression();
      }
    }

    // 2. Advance transient local reaction
    if (_localReaction != null) {
      _localReactionAge += dt;
      _localReactionRemaining -= dt;
      if (_localReactionRemaining <= 0) {
        _localReaction = null;
        _recomputeTargetExpression();
      }
    }

    // 3. Interpolate expression (280ms easeOutCubic)
    if (_exprTransitionElapsed < _exprTransitionDuration) {
      _exprTransitionElapsed = math.min(
        _exprTransitionDuration,
        _exprTransitionElapsed + dt,
      );
      final rawT = _exprTransitionElapsed / _exprTransitionDuration;
      final curvedT = Curves.easeOutCubic.transform(rawT);
      _currentExpression = AvatarExpression.lerp(
        _fromExpression,
        _targetExpression,
        curvedT,
      );
    }

    final mood = effectiveMood;

    // 4. Blinking
    var blinkAmount = 0.0;
    if (_blinkElapsed >= 0) {
      _blinkElapsed += dt;
      if (_blinkElapsed >= _blinkDuration) {
        _blinkElapsed = -1.0;
        if (_pendingDoubleBlink) {
          _pendingDoubleBlink = false;
          _nextBlinkAt = _elapsed + 0.11;
        } else {
          _scheduleNextBlink();
        }
      } else {
        final p = _blinkElapsed / _blinkDuration;
        blinkAmount = math.sin(p * math.pi);
      }
    } else if (_elapsed >= _nextBlinkAt &&
        mood != AvatarMood.offline &&
        mood != AvatarMood.sleepy &&
        _currentExpression.eyeShape != EyeShape.happy &&
        _currentExpression.eyeShape != EyeShape.squeeze) {
      _blinkElapsed = 0.0;
      _pendingDoubleBlink = _random.nextDouble() < 0.20;
    }

    // 5. Idle fidgets (every 20–40s in idle)
    if (mood == AvatarMood.idle && _localReaction == null) {
      if (_fidgetRemaining > 0) {
        _fidgetRemaining -= dt;
        if (_fidgetRemaining <= 0) _activeFidgetKind = -1;
      } else if (_elapsed >= _nextFidgetAt) {
        _activeFidgetKind = _random.nextInt(4);
        _fidgetRemaining = _activeFidgetKind == 3 ? 0.9 : 1.3;
        _scheduleNextFidget();
      }
    } else {
      _activeFidgetKind = -1;
      _fidgetRemaining = 0.0;
    }

    // Occasional sleepy yawn (900ms)
    if (mood == AvatarMood.sleepy) {
      if (_sleepyYawnRemaining > 0) {
        _sleepyYawnRemaining -= dt;
      } else if (_elapsed >= _nextYawnAt) {
        _sleepyYawnRemaining = 0.9;
        _nextYawnAt = _elapsed + 9.0 + _random.nextDouble() * 7.0;
      }
    } else {
      _sleepyYawnRemaining = 0.0;
    }

    // 6. Breathing, floating, head tilt, shake & mood body motion
    final breathPeriod = switch (mood) {
      AvatarMood.listening => 2.2,
      AvatarMood.offline || AvatarMood.sleepy => 5.0,
      AvatarMood.streaming => 2.0,
      _ => 3.2,
    };
    final breatheScaleY =
        1.0 + math.sin((_elapsed * 2 * math.pi) / breathPeriod) * 0.02;

    var floatY = math.sin((_elapsed * 2 * math.pi) / 4.0) * 0.03;
    if (mood == AvatarMood.offline || mood == AvatarMood.sleepy) {
      floatY = floatY * 0.45 + 0.024;
    }

    // Success double hop
    var extraSquashX = 1.0;
    var extraSquashY = 1.0;
    if (mood == AvatarMood.success || _localReaction == AvatarReaction.success) {
      final t = _localReaction == AvatarReaction.success
          ? _localReactionAge
          : _moodAge;
      if (t < 0.9) {
        final hopPhase = (t / 0.45) % 1.0;
        final hop = math.sin(hopPhase * math.pi);
        floatY -= hop * 0.085;
        extraSquashY = 1.0 + hop * 0.06 - (hop < 0.15 ? 0.06 : 0.0);
        extraSquashX = 1.0 / extraSquashY;
      }
    }

    // Streaming chunk bob & talking mouth kick
    _chunkKick = math.max(0.0, _chunkKick - dt * 4.5);
    if (_chunkKick > 0) {
      floatY -= _chunkKick * 0.022;
    }

    var mouthTalkBoost = 0.0;
    if (mood == AvatarMood.streaming) {
      final wave = (math.sin(_elapsed * 7.0 * 2 * math.pi) + 1) * 0.5;
      mouthTalkBoost = 0.10 + wave * 0.30 + _chunkKick * 0.25 - _currentExpression.mouthOpen;
      mouthTalkBoost = mouthTalkBoost.clamp(-0.2, 0.55);
    } else if (_sleepyYawnRemaining > 0 ||
        (_activeFidgetKind == 3 && _fidgetRemaining > 0)) {
      mouthTalkBoost = 0.78;
    } else if (_localReaction == AvatarReaction.giggle) {
      mouthTalkBoost = (math.sin(_elapsed * 16.0) + 1) * 0.12;
    }

    // Head tilt & horizontal shake
    var headTiltZ = 0.0;
    if (mood == AvatarMood.thinking) {
      headTiltZ = math.sin(_elapsed * 1.15) * 0.105; // ±6 degrees
    } else if (_localReaction == AvatarReaction.pet) {
      headTiltZ = math.sin(_elapsed * 6.5) * 0.11;
    } else if (_localReaction == AvatarReaction.nod) {
      floatY += math.sin(_localReactionAge * 12.0) * 0.028;
    }

    var shakeX = 0.0;
    if ((mood == AvatarMood.error && _moodAge < 0.32) ||
        _localReaction == AvatarReaction.errorShake) {
      final decay = (1.0 - (_moodAge / 0.32)).clamp(0.2, 1.0);
      shakeX = math.sin(_elapsed * 46.0) * 0.032 * decay;
    } else if (_localReaction == AvatarReaction.giggle) {
      shakeX = math.sin(_elapsed * 38.0) * 0.012;
    }

    // Mood-switch squash & stretch impulse
    var squashX = extraSquashX;
    var squashY = extraSquashY;
    if (_squashElapsed < _squashDuration) {
      _squashElapsed += dt;
      final p = (_squashElapsed / _squashDuration).clamp(0.0, 1.0);
      final envelope = math.sin(p * math.pi);
      squashX *= lerpDouble(1.0, _squashPeakX, envelope)!;
      squashY *= lerpDouble(1.0, _squashPeakY, envelope)!;
    }

    // 7. 3D drag tilt spring return
    if (!_isDragging && (_springTiltX != null || _springTiltY != null)) {
      _springElapsed += dt;
      final sx = _springTiltX?.x(_springElapsed) ?? 0.0;
      final sy = _springTiltY?.x(_springElapsed) ?? 0.0;
      tiltNotifier.value = Offset(sx, sy);
      final doneX = _springTiltX?.isDone(_springElapsed) ?? true;
      final doneY = _springTiltY?.isDone(_springElapsed) ?? true;
      if (doneX && doneY) {
        tiltNotifier.value = Offset.zero;
        _springTiltX = null;
        _springTiltY = null;
      }
    }

    // 8. Pupil gaze target (drag > content look-at > mood > idle glance)
    Offset desiredPupil = Offset.zero;
    if (_isDragging) {
      desiredPupil = _dragFingerPupil;
    } else if (_contentLookRemaining > 0 && _contentLookTarget != null) {
      _contentLookRemaining -= dt;
      desiredPupil = _contentLookTarget!;
    } else {
      switch (mood) {
        case AvatarMood.listening:
          desiredPupil = const Offset(0, 0.026);
        case AvatarMood.thinking:
          final scan = math.sin(_elapsed * 1.4) > 0.55
              ? math.sin(_elapsed * 4.0) * 0.016
              : 0.0;
          desiredPupil = Offset(0.020 + scan, -0.020);
        case AvatarMood.streaming:
          desiredPupil = Offset(math.sin(_elapsed * 3.6) * 0.026, 0.008);
        case AvatarMood.connecting:
          desiredPupil = Offset(math.sin(_elapsed * 5.2) * 0.030, 0.0);
        case AvatarMood.error:
          desiredPupil = Offset(
            math.sin(_elapsed * 32.0) * 0.006,
            math.cos(_elapsed * 27.0) * 0.005,
          );
        case AvatarMood.idle:
          if (_glanceRemaining > 0) {
            _glanceRemaining -= dt;
            desiredPupil = _glanceTarget;
          } else if (_elapsed >= _nextGlanceAt) {
            final angle = _random.nextDouble() * 2 * math.pi;
            final mag = 0.016 + _random.nextDouble() * 0.016;
            _glanceTarget = Offset(
              math.cos(angle) * mag,
              math.sin(angle) * mag * 0.75,
            );
            _glanceRemaining = 0.6 + _random.nextDouble() * 0.6;
            _scheduleNextGlance();
          }
        default:
          desiredPupil = Offset.zero;
      }
    }
    final pupilEase = (dt * 12.0).clamp(0.0, 1.0);
    _currentPupil = Offset.lerp(_currentPupil, desiredPupil, pupilEase)!;

    // 9. Spring-lagged antenna physics
    final tilt = tiltNotifier.value;
    var antennaTarget = Offset(
      -headTiltZ * 0.45 + tilt.dy * 0.22 - shakeX * 1.8,
      -floatY * 0.85 + tilt.dx * 0.14,
    );
    if (_activeFidgetKind == 2 && _fidgetRemaining > 0) {
      antennaTarget += Offset(
        math.cos(_elapsed * 10.0) * 0.06,
        math.sin(_elapsed * 10.0) * 0.04,
      );
    }
    const kStiffness = 140.0;
    const kDamping = 11.5;
    final ax = (antennaTarget.dx - _antennaPos.dx) * kStiffness -
        _antennaVel.dx * kDamping;
    final ay = (antennaTarget.dy - _antennaPos.dy) * kStiffness -
        _antennaVel.dy * kDamping;
    _antennaVel = Offset(
      _antennaVel.dx + ax * dt,
      _antennaVel.dy + ay * dt,
    );
    _antennaPos = Offset(
      (_antennaPos.dx + _antennaVel.dx * dt).clamp(-0.11, 0.11),
      (_antennaPos.dy + _antennaVel.dy * dt).clamp(-0.08, 0.08),
    );

    // Antenna glow pulse
    final antennaPulse = switch (mood) {
      AvatarMood.thinking =>
        0.75 + 0.35 * ((math.sin((_elapsed * 2 * math.pi) / 1.2) + 1) * 0.5),
      AvatarMood.streaming =>
        0.80 + 0.40 * ((math.sin(_elapsed * 9.0) + 1) * 0.5),
      AvatarMood.connecting =>
        0.65 + 0.45 * ((math.sin(_elapsed * 6.5) + 1) * 0.5),
      AvatarMood.error => _moodAge < 0.8
          ? (math.sin(_moodAge * 16.0) > 0 ? 1.2 : 0.35)
          : 0.85,
      _ => 0.92 + 0.08 * math.sin(_elapsed * 2.0),
    };

    // 10. Smooth hand interpolation + pose animation (wave / type / idle wave fidget)
    var effectiveArmPose = _currentExpression.armPose;
    if (_activeFidgetKind == 0 && _fidgetRemaining > 0) {
      effectiveArmPose = ArmPose.wave;
    } else if (_activeFidgetKind == 1 && _fidgetRemaining > 0) {
      effectiveArmPose = ArmPose.chin;
    }
    var (targetL, targetR) = handTargetsForPose(effectiveArmPose);
    if (effectiveArmPose == ArmPose.wave) {
      targetR = Offset(
        targetR.dx + math.sin(_elapsed * 12.0) * 0.045,
        targetR.dy + math.cos(_elapsed * 12.0) * 0.028,
      );
    } else if (effectiveArmPose == ArmPose.type) {
      final tap = math.sin(_elapsed * 18.0) * 0.038;
      targetL = Offset(targetL.dx, targetL.dy + tap);
      targetR = Offset(targetR.dx, targetR.dy - tap);
    } else if (effectiveArmPose == ArmPose.cheer) {
      final bounce = math.sin(_elapsed * 10.0) * 0.025;
      targetL = Offset(targetL.dx, targetL.dy + bounce);
      targetR = Offset(targetR.dx, targetR.dy - bounce);
    }
    final handEase = (dt * 11.0).clamp(0.0, 1.0);
    _leftHandPos = Offset.lerp(_leftHandPos, targetL, handEase)!;
    _rightHandPos = Offset.lerp(_rightHandPos, targetR, handEase)!;

    // 11. Ambient mood particles & particle physics update
    _updateParticles(dt, mood);

    _frame = AvatarFrame(
      breatheScaleY: breatheScaleY,
      floatY: floatY,
      headTiltZ: headTiltZ,
      shakeX: shakeX,
      tilt: tilt,
      pupilOffset: _currentPupil,
      squashX: squashX,
      squashY: squashY,
      antennaOffset: _antennaPos,
      antennaPulse: antennaPulse,
      blinkAmount: blinkAmount,
      mouthTalkBoost: mouthTalkBoost,
      leftHandPos: _leftHandPos,
      rightHandPos: _rightHandPos,
      bodyScale: mood == AvatarMood.listening ? 1.04 : 1.0,
    );

    notifyListeners();
  }

  void _updateParticles(double dt, AvatarMood mood) {
    if (_sizeConfig.maxParticles > 0) {
      _ambientParticleCooldown -= dt;
      if (_ambientParticleCooldown <= 0) {
        if (mood == AvatarMood.offline || mood == AvatarMood.sleepy) {
          _spawnParticle(
            AvatarParticle(
              kind: AvatarParticleKind.sleepZ,
              position: const Offset(0.80, 0.28),
              velocity: const Offset(0.035, -0.11),
              age: 0,
              lifetime: 1.8,
              scale: 0.9 + _random.nextDouble() * 0.25,
              color: AppColors.textSecondary,
              label: _random.nextBool() ? 'zZ' : 'z',
            ),
          );
          _ambientParticleCooldown = 1.45;
        } else if (mood == AvatarMood.thinking) {
          _spawnParticle(
            AvatarParticle(
              kind: AvatarParticleKind.thinkingDot,
              position: const Offset(0.87, 0.26),
              velocity: const Offset(0.015, -0.06),
              age: 0,
              lifetime: 1.25,
              scale: 1.0,
              color: AppColors.tintBlueFg,
            ),
          );
          _ambientParticleCooldown = 1.2;
        } else {
          _ambientParticleCooldown = 0.6;
        }
      }
    }

    if (_particles.isNotEmpty) {
      var changed = false;
      for (var i = _particles.length - 1; i >= 0; i--) {
        final p = _particles[i];
        final nextAge = p.age + dt;
        if (nextAge >= p.lifetime) {
          _particles.removeAt(i);
          changed = true;
        } else {
          _particles[i] = p.copyWith(
            age: nextAge,
            position: p.position + p.velocity * dt,
          );
          changed = true;
        }
      }
      if (changed) _effectsVersion++;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    tiltNotifier.dispose();
    super.dispose();
  }
}
