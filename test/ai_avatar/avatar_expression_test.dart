import 'package:flutter_test/flutter_test.dart';
import 'package:wynndiff/features/ai_avatar/domain/avatar_expression.dart';
import 'package:wynndiff/features/ai_avatar/domain/avatar_mood.dart';

void main() {
  group('AvatarExpression.lerp', () {
    test('returns exact endpoints at t=0 and t=1', () {
      final a = kMoodExpressions[AvatarMood.idle]!;
      final b = kMoodExpressions[AvatarMood.success]!;

      expect(AvatarExpression.lerp(a, b, 0.0), equals(a));
      expect(AvatarExpression.lerp(a, b, 1.0), equals(b));
    });

    test('interpolates scalar values including headTilt and switches enums at 0.5', () {
      final a = kMoodExpressions[AvatarMood.offline]!;
      final b = kMoodExpressions[AvatarMood.thinking]!;

      final early = AvatarExpression.lerp(a, b, 0.25);
      final mid = AvatarExpression.lerp(a, b, 0.5);

      expect(early.eyeOpen, greaterThan(a.eyeOpen));
      expect(early.eyeOpen, lessThan(b.eyeOpen));
      expect(early.headTilt, greaterThan(a.headTilt));
      expect(early.headTilt, lessThan(b.headTilt));
      expect(early.eyeShape, equals(a.eyeShape));
      expect(early.armPose, equals(a.armPose));

      expect(mid.mouthCurve, closeTo((a.mouthCurve + b.mouthCurve) / 2, 1e-6));
      expect(mid.blush, closeTo((a.blush + b.blush) / 2, 1e-6));
      expect(mid.ahogePerk, closeTo((a.ahogePerk + b.ahogePerk) / 2, 1e-6));
      expect(mid.accentGlow, closeTo((a.accentGlow + b.accentGlow) / 2, 1e-6));
      expect(mid.headTilt, closeTo((a.headTilt + b.headTilt) / 2, 1e-6));
      expect(mid.eyeShape, equals(b.eyeShape));
      expect(mid.armPose, equals(b.armPose));
    });

    test('provides valid presets for every AvatarMood and AvatarReaction', () {
      for (final mood in AvatarMood.values) {
        final expr = expressionForMood(mood);
        expect(expr.eyeOpen, inInclusiveRange(0.0, 1.0));
        expect(expr.blush, inInclusiveRange(0.0, 1.0));
        expect(expr.ahogePerk, inInclusiveRange(0.0, 1.0));
        expect(expr.accentGlow, inInclusiveRange(0.0, 1.0));
        expect(expr.headTilt, inInclusiveRange(-1.0, 1.0));
      }

      final base = kMoodExpressions[AvatarMood.idle]!;
      for (final reaction in AvatarReaction.values) {
        final expr = expressionForReaction(reaction, base);
        expect(expr.eyeOpen, inInclusiveRange(0.0, 1.0));
        expect(expr.blush, inInclusiveRange(0.0, 1.0));
        expect(expr.ahogePerk, inInclusiveRange(0.0, 1.0));
      }

      // Reference wink reaction uses chin pose + winkRight
      final winkExpr = expressionForReaction(AvatarReaction.wink, base);
      expect(winkExpr.winkRight, isTrue);
      expect(winkExpr.armPose, equals(ArmPose.chin));
      expect(winkExpr.headTilt, greaterThan(0.2));
    });
  });
}
