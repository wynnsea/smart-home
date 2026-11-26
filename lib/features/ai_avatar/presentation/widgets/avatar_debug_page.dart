import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ethereal_background.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../domain/avatar_expression.dart';
import '../../domain/avatar_mood.dart';
import 'wynn_ai_avatar.dart';

/// Debug-only gallery showcasing all 9 moods across sizes (`xs`..`lg`),
/// live expression parameter sliders, and reaction triggers.
class AvatarDebugPage extends StatefulWidget {
  const AvatarDebugPage({super.key});

  @override
  State<AvatarDebugPage> createState() => _AvatarDebugPageState();
}

class _AvatarDebugPageState extends State<AvatarDebugPage> {
  AvatarSize _selectedSize = AvatarSize.md;
  AvatarPoseMode _poseMode = AvatarPoseMode.standing;
  bool _useCustomSliders = false;
  AvatarMood _previewMood = AvatarMood.idle;
  AvatarExpression _customExpression = kMoodExpressions[AvatarMood.idle]!;
  AvatarReaction? _lastReaction;
  int _reactionSeq = 0;

  @override
  Widget build(BuildContext context) {
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
                        'Preview Avatar "Wynn"',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                  children: [
                    // Hero stage preview
                    GlassCard(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 196,
                            child: Center(
                              child: WynnAiAvatar(
                                size: AvatarSize.lg,
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
                          const SizedBox(height: 8),
                          Text(
                            _useCustomSliders
                                ? 'Custom Sliders'
                                : '${_previewMood.name} (${_previewMood.semanticLabel})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
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
                          selected: {_selectedSize == AvatarSize.lg ? AvatarSize.md : _selectedSize},
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
                              label: 'earPerk',
                              value: _customExpression.earPerk,
                              min: 0,
                              max: 1,
                              onChanged: (v) => setState(
                                () => _customExpression = _customExpression
                                    .copyWith(earPerk: v),
                              ),
                            ),
                            _ExprSlider(
                              label: 'antennaGlow',
                              value: _customExpression.antennaGlow,
                              min: 0,
                              max: 1,
                              onChanged: (v) => setState(
                                () => _customExpression = _customExpression
                                    .copyWith(antennaGlow: v),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
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
