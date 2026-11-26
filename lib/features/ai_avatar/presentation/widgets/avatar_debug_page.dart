import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ethereal_background.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../domain/avatar_expression.dart';
import '../../domain/avatar_mood.dart';
import 'wynn_ai_avatar.dart';

/// Debug-only gallery showcasing all 9 moods across sizes (`xs`..`lg`),
/// light/dark preview stage background toggle, framing preview toggle,
/// live expression parameter sliders, and reaction triggers.
class AvatarDebugPage extends StatefulWidget {
  const AvatarDebugPage({super.key});

  @override
  State<AvatarDebugPage> createState() => _AvatarDebugPageState();
}

class _AvatarDebugPageState extends State<AvatarDebugPage> {
  AvatarSize _selectedSize = AvatarSize.md;
  AvatarSize _stageFraming = AvatarSize.lg;
  AvatarPoseMode _poseMode = AvatarPoseMode.standing;
  bool _darkPreviewBg = false;
  bool _useCustomSliders = false;
  AvatarMood _previewMood = AvatarMood.idle;
  AvatarExpression _customExpression = kMoodExpressions[AvatarMood.idle]!;
  AvatarReaction? _lastReaction;
  int _reactionSeq = 0;

  @override
  Widget build(BuildContext context) {
    final stageBgColor = _darkPreviewBg
        ? const Color(0xFF1A162B)
        : Colors.white.withValues(alpha: 0.72);
    final stageBorderColor = _darkPreviewBg
        ? AppColors.primaryLight.withValues(alpha: 0.32)
        : AppColors.borderSoft;

    return Scaffold(
      body: EtherealBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    GlassCircleButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Kembali',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Preview Avatar "Wynn" v2',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    GlassCircleButton(
                      icon: _darkPreviewBg
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      tooltip: _darkPreviewBg
                          ? 'Background terang'
                          : 'Background gelap',
                      onTap: () =>
                          setState(() => _darkPreviewBg = !_darkPreviewBg),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                  children: [
                    // Hero stage preview with light/dark surface & framing toggle
                    GlassCard(
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: 204,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: stageBgColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: stageBorderColor),
                            ),
                            child: Center(
                              child: WynnAiAvatar(
                                size: _stageFraming,
                                customSize: _stageFraming == AvatarSize.lg
                                    ? 168
                                    : _stageFraming == AvatarSize.md
                                    ? 124
                                    : _stageFraming == AvatarSize.sm
                                    ? 88
                                    : 64,
                                pose: _poseMode,
                                moodOverride: _previewMood,
                                expressionOverride: _useCustomSliders
                                    ? _customExpression
                                    : null,
                                debugReaction: _lastReaction,
                                debugReactionSeq: _reactionSeq,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _useCustomSliders
                                ? 'Custom Sliders · framing ${_stageFraming.name}'
                                : '${_previewMood.name} (${_previewMood.semanticLabel}) · framing ${_stageFraming.name}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final framing in AvatarSize.values)
                                ChoiceChip(
                                  label: Text('Frame: ${framing.name}'),
                                  selected: _stageFraming == framing,
                                  selectedColor: AppColors.primarySoft,
                                  onSelected: (_) =>
                                      setState(() => _stageFraming = framing),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final pose in AvatarPoseMode.values)
                                ChoiceChip(
                                  label: Text('Pose: ${pose.name}'),
                                  selected: _poseMode == pose,
                                  selectedColor: AppColors.primarySoft,
                                  onSelected: (_) =>
                                      setState(() => _poseMode = pose),
                                ),
                              FilterChip(
                                label: Text(
                                  _darkPreviewBg ? 'BG: Gelap' : 'BG: Terang',
                                ),
                                selected: _darkPreviewBg,
                                selectedColor: AppColors.primarySoft,
                                onSelected: (v) =>
                                    setState(() => _darkPreviewBg = v),
                              ),
                              FilterChip(
                                label: const Text('Custom sliders'),
                                selected: _useCustomSliders,
                                selectedColor: AppColors.primarySoft,
                                onSelected: (v) =>
                                    setState(() => _useCustomSliders = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final reaction in AvatarReaction.values)
                                ActionChip(
                                  label: Text(
                                    reaction.name,
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  backgroundColor: AppColors.surfaceSubtle,
                                  onPressed: () => setState(() {
                                    _lastReaction = reaction;
                                    _reactionSeq++;
                                  }),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Mood grid across selectable sizes
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Semua 9 Mood',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        SegmentedButton<AvatarSize>(
                          segments: const [
                            ButtonSegment(value: AvatarSize.xs, label: Text('xs')),
                            ButtonSegment(value: AvatarSize.sm, label: Text('sm')),
                            ButtonSegment(value: AvatarSize.md, label: Text('md')),
                          ],
                          selected: {
                            _selectedSize == AvatarSize.lg
                                ? AvatarSize.md
                                : _selectedSize,
                          },
                          onSelectionChanged: (set) =>
                              setState(() => _selectedSize = set.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: AvatarMood.values.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.86,
                          ),
                      itemBuilder: (context, index) {
                        final mood = AvatarMood.values[index];
                        final selected = !_useCustomSliders && _previewMood == mood;
                        return GlassCard(
                          blur: false,
                          padding: const EdgeInsets.all(8),
                          borderRadius: 18,
                          borderColor: selected ? AppColors.primary : null,
                          onTap: () => setState(() {
                            _useCustomSliders = false;
                            _previewMood = mood;
                            _customExpression = expressionForMood(
                              mood,
                              poseMode: _poseMode,
                            );
                          }),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: _darkPreviewBg
                                        ? const Color(0xFF1F1A33)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: WynnAiAvatar(
                                      size: _selectedSize,
                                      customSize: _selectedSize == AvatarSize.md
                                          ? 68
                                          : null,
                                      pose: _poseMode,
                                      moodOverride: mood,
                                      interactive: false,
                                      animate: false,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mood.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (_useCustomSliders) ...[
                      const SizedBox(height: 16),
                      GlassCard(
                        blur: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Slider Ekspresi',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            _ExprSlider(
                              label: 'eyeOpen',
                              value: _customExpression.eyeOpen,
                              min: 0,
                              max: 1,
                              onChanged: (v) => setState(
                                () => _customExpression = _customExpression
                                    .copyWith(eyeOpen: v),
                              ),
                            ),
                            _ExprSlider(
                              label: 'browTilt',
                              value: _customExpression.browTilt,
                              min: -1,
                              max: 1,
                              onChanged: (v) => setState(
                                () => _customExpression = _customExpression
                                    .copyWith(browTilt: v),
                              ),
                            ),
                            _ExprSlider(
                              label: 'browRaise',
                              value: _customExpression.browRaise,
                              min: -1,
                              max: 1,
                              onChanged: (v) => setState(
                                () => _customExpression = _customExpression
                                    .copyWith(browRaise: v),
                              ),
                            ),
                            _ExprSlider(
                              label: 'mouthCurve',
                              value: _customExpression.mouthCurve,
                              min: -1,
                              max: 1,
                              onChanged: (v) => setState(
                                () => _customExpression = _customExpression
                                    .copyWith(mouthCurve: v),
                              ),
                            ),
                            _ExprSlider(
                              label: 'mouthOpen',
                              value: _customExpression.mouthOpen,
                              min: 0,
                              max: 1,
                              onChanged: (v) => setState(
                                () => _customExpression = _customExpression
                                    .copyWith(mouthOpen: v),
                              ),
                            ),
                            _ExprSlider(
                              label: 'blush',
                              value: _customExpression.blush,
                              min: 0,
                              max: 1,
                              onChanged: (v) => setState(
                                () => _customExpression = _customExpression
                                    .copyWith(blush: v),
                              ),
                            ),
                            _ExprSlider(
                              label: 'ahogePerk',
                              value: _customExpression.ahogePerk,
                              min: 0,
                              max: 1,
                              onChanged: (v) => setState(
                                () => _customExpression = _customExpression
                                    .copyWith(ahogePerk: v),
                              ),
                            ),
                            _ExprSlider(
                              label: 'accentGlow',
                              value: _customExpression.accentGlow,
                              min: 0,
                              max: 1,
                              onChanged: (v) => setState(
                                () => _customExpression = _customExpression
                                    .copyWith(accentGlow: v),
                              ),
                            ),
                            _ExprSlider(
                              label: 'headTilt',
                              value: _customExpression.headTilt,
                              min: -1,
                              max: 1,
                              onChanged: (v) => setState(
                                () => _customExpression = _customExpression
                                    .copyWith(headTilt: v),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                FilterChip(
                                  label: const Text('winkRight'),
                                  selected: _customExpression.winkRight,
                                  selectedColor: AppColors.primarySoft,
                                  onSelected: (v) => setState(
                                    () => _customExpression = _customExpression
                                        .copyWith(winkRight: v),
                                  ),
                                ),
                                for (final shape in EyeShape.values)
                                  ChoiceChip(
                                    label: Text('Eye: ${shape.name}'),
                                    selected:
                                        _customExpression.eyeShape == shape,
                                    onSelected: (_) => setState(
                                      () => _customExpression =
                                          _customExpression.copyWith(
                                            eyeShape: shape,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final arm in ArmPose.values)
                                  ChoiceChip(
                                    label: Text('Arm: ${arm.name}'),
                                    selected: _customExpression.armPose == arm,
                                    onSelected: (_) => setState(
                                      () => _customExpression =
                                          _customExpression.copyWith(
                                            armPose: arm,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExprSlider extends StatelessWidget {
  const _ExprSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}
