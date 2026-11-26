import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/motion_widgets.dart';
import '../../../ai_avatar/domain/avatar_mood.dart';
import '../../../ai_avatar/presentation/widgets/wynn_ai_avatar.dart';
import '../../domain/entities/workspace_entities.dart';

/// Hero status card at the top of Home Dashboard with animated progress sweep,
/// pulsing online beacon, Hero-linked AI orb, and springy tap response.
class HostHeroCard extends StatelessWidget {
  const HostHeroCard({
    super.key,
    required this.status,
    required this.changedFilesCount,
    required this.onTap,
  });

  final HostStatus status;
  final int changedFilesCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (status.connectionState) {
      HostConnectionState.connected => AppColors.tintGreenFg,
      HostConnectionState.connecting => AppColors.tintAmberFg,
      HostConnectionState.disconnected => AppColors.diffDelText,
    };

    return BouncyTap(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
        borderRadius: 26,
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (status.connectionState ==
                          HostConnectionState.connecting)
                        const PulsingDot(
                          size: 7.5,
                          color: AppColors.tintAmberFg,
                        )
                      else if (status.connectionState ==
                          HostConnectionState.connected)
                        const PulsingDot(size: 7.5)
                      else
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.diffDelText,
                          ),
                        ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Active Host Session',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: status.progress),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedProgress, _) {
                      final pct = (animatedProgress * 100).round();
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${status.completedTasks} / ${status.totalTasks} checks',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$pct%',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: Container(
                              height: 8.5,
                              color: AppColors.primarySoft,
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: animatedProgress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.progressGradient,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 11),
                  Text(
                    status.isConnected
                        ? '${status.repoFullName} · $changedFilesCount diffs · ${status.latencyMs}ms'
                        : '${status.repoFullName} · ${status.connectionLabel}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              height: 98,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const WynnAiAvatar(
                    size: AvatarSize.md,
                    customSize: 82,
                    heroTag: 'wynn-agent-orb',
                    showBubbleOnTap: true,
                  ),
                  Positioned(
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          status.connectionLabel.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2x2 Quick Metric card with bouncy tap micro-interaction and animated circular gauge.
class QuickMetricCard extends StatelessWidget {
  const QuickMetricCard({
    super.key,
    required this.metric,
    required this.onTap,
  });

  final QuickMetric metric;
  final VoidCallback onTap;

  (Color bg, Color fg, IconData icon) _toneConfig() {
    return switch (metric.tone) {
      MetricTone.purple => (
        AppColors.tintPurpleBg,
        AppColors.tintPurpleFg,
        Icons.auto_awesome_rounded,
      ),
      MetricTone.green => (
        AppColors.tintGreenBg,
        AppColors.tintGreenFg,
        Icons.difference_rounded,
      ),
      MetricTone.amber => (
        AppColors.tintAmberBg,
        AppColors.tintAmberFg,
        Icons.terminal_rounded,
      ),
      MetricTone.blue => (
        AppColors.tintBlueBg,
        AppColors.tintBlueFg,
        Icons.hub_rounded,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = _toneConfig();

    return BouncyTap(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(15),
        borderRadius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 19, color: fg),
                ),
                const Spacer(),
                const Icon(
                  Icons.north_east_rounded,
                  size: 17,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metric.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        metric.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _CircularRingGauge(
                  progress: metric.progressPercent / 100,
                  label: metric.ringLabel,
                  color: fg,
                  trackColor: bg,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularRingGauge extends StatelessWidget {
  const _CircularRingGauge({
    required this.progress,
    required this.label,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final String label;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (context, animatedVal, child) {
        return SizedBox(
          width: 44,
          height: 44,
          child: CustomPaint(
            painter: _RingPainter(
              progress: animatedVal,
              color: color,
              trackColor: trackColor,
            ),
            child: child,
          ),
        );
      },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 6) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8;

    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Recent session card with animated progress bar and bouncy tap feedback.
class SessionContinueCard extends StatelessWidget {
  const SessionContinueCard({
    super.key,
    required this.session,
    required this.onTap,
  });

  final CodingSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 22,
        blur: false,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFECE4FF), Color(0xFFD6E9FF)],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.code_rounded,
                    color: AppColors.primaryDark,
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      session.languageTag.split(' ').first,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontSize: 14.2,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${session.branch} · ${session.changedFilesCount} diffs · ${session.updatedAtLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: (session.progressPercent / 100).clamp(0.0, 1.0),
                    ),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, _) {
                      return Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: Container(
                                height: 6,
                                color: AppColors.primarySoft,
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: val,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.progressGradient,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(val * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating translucent pill navigation bar + breathing purple Sparkle FAB.
class FloatingBottomNav extends StatefulWidget {
  const FloatingBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
    required this.onSparkleFabTap,
    this.diffBadgeCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onSparkleFabTap;
  final int diffBadgeCount;

  @override
  State<FloatingBottomNav> createState() => _FloatingBottomNavState();
}

class _FloatingBottomNavState extends State<FloatingBottomNav>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _fabGlowController;
  bool _appPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fabGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  void _syncFabAnimation() {
    if (!mounted) return;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations || _appPaused) {
      _fabGlowController.stop();
    } else if (!_fabGlowController.isAnimating) {
      _fabGlowController.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFabAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appPaused =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;
    _syncFabAnimation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fabGlowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final items = [
      (Icons.home_rounded, 'Home'),
      (Icons.chat_bubble_outline_rounded, 'Chat'),
      (Icons.difference_outlined, 'Diff'),
      (Icons.dns_outlined, 'Host'),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Row(
          children: [
            Expanded(
              child: LiquidGlassPill(
                height: 64,
                blurSigma: 28,
                padding: const EdgeInsets.all(6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final slotWidth = constraints.maxWidth / items.length;
                    return Stack(
                      children: [
                        // iOS 26 sliding Liquid Glass capsule lens behind active tab
                        AnimatedPositioned(
                          duration: disableAnimations
                              ? Duration.zero
                              : const Duration(milliseconds: 340),
                          curve: Curves.easeOutBack,
                          left: widget.currentIndex * slotWidth + 3,
                          top: 2,
                          bottom: 2,
                          width: slotWidth - 6,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.92),
                                  AppColors.primarySoft.withValues(alpha: 0.65),
                                  Colors.white.withValues(alpha: 0.78),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.95),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.16,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(items.length, (index) {
                            final selected = index == widget.currentIndex;
                            final (icon, label) = items[index];
                            final hasDiffBadge =
                                index == 2 && widget.diffBadgeCount > 0;
                            final semanticLabel = hasDiffBadge
                                ? 'Diff, ${widget.diffBadgeCount} file berubah'
                                : label;
                            final badgeLabel = widget.diffBadgeCount > 99
                                ? '99+'
                                : '${widget.diffBadgeCount}';
                            return Expanded(
                              child: Semantics(
                                button: true,
                                selected: selected,
                                label: semanticLabel,
                                child: Tooltip(
                                  message: semanticLabel,
                                  child: GestureDetector(
                                    onTap: () => widget.onSelectTab(index),
                                    behavior: HitTestBehavior.opaque,
                                    child: Center(
                                      child: AnimatedScale(
                                        scale: (selected && !disableAnimations)
                                            ? 1.14
                                            : 1.0,
                                        duration: disableAnimations
                                            ? Duration.zero
                                            : const Duration(milliseconds: 240),
                                        curve: Curves.easeOutBack,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          alignment: Alignment.center,
                                          children: [
                                            Icon(
                                              icon,
                                              size: 22,
                                              color: selected
                                                  ? AppColors.primary
                                                  : AppColors.textSecondary,
                                            ),
                                            if (hasDiffBadge)
                                              Positioned(
                                                top: -7,
                                                right: -11,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4.5,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    gradient: AppColors
                                                        .primaryGradient,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          99,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 1.3,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    badgeLabel,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      height: 1.05,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 14),
            BouncyTap(
              pressedScale: 0.91,
              semanticLabel: 'Buka WynnDiff Agent',
              onTap: widget.onSparkleFabTap,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _fabGlowController,
                  builder: (context, child) {
                    final glow = _fabGlowController.value;
                    return Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xE8B392FF),
                            Color(0xE87A4EFF),
                            Color(0xE86338EB),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.92),
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(
                              alpha: 0.34 + glow * 0.22,
                            ),
                            blurRadius: 18 + glow * 10,
                            spreadRadius: glow * 1.5,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glossy top-left Liquid Glass specular crescent
                          Positioned(
                            top: 5,
                            left: 11,
                            right: 17,
                            height: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.52),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          child!,
                        ],
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
