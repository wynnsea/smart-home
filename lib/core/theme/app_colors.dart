import 'package:material_ui/material_ui.dart';

/// WynnDiff iOS Liquid Glass color tokens:
/// Vivid pastel aurora canvas underneath high-clarity translucent glass layers
/// with bright specular rims and vibrant violet accents.
abstract final class AppColors {
  // Primary brand violets
  static const Color primary = Color(0xFF7E52FF);
  static const Color primaryLight = Color(0xFFA986FF);
  static const Color primaryDark = Color(0xFF5D34E0);
  static const Color primarySoft = Color(0xFFECE5FF);

  // Vivid-pastel aurora mesh stops (richer so Liquid Glass refraction pops!)
  static const Color meshLavender = Color(0xFFCBB8FF);
  static const Color meshSky = Color(0xFFA8DBFF);
  static const Color meshPeach = Color(0xFFFFD4BE);
  static const Color meshLilac = Color(0xFFF3C6FF);
  static const Color meshBase = Color(0xFFF1EFFB);

  // Liquid Glass translucent fills
  static const Color glassFillTop = Color(0xA6FFFFFF); // ~65% white highlight
  static const Color glassFillMid = Color(0x5CFFFFFF); // ~36% clear refractive core
  static const Color glassFillBottom = Color(0x82FFFFFF); // ~51% bounce light
  static const Color glassSheetFill = Color(0xBFFFFFFF); // ~75% frosted sheet

  static const Color surfaceCard = Color(0x99FFFFFF);
  static const Color surfaceCardStrong = Color(0xCCFFFFFF);
  static const Color surfaceSubtle = Color(0x88F2EEFF);
  static const Color borderSoft = Color(0xCCFFFFFF);
  static const Color borderDivider = Color(0x447B61FF);

  // Typography (WCAG AA >= 4.5:1 on white & meshBase)
  static const Color textPrimary = Color(0xFF141524);
  static const Color textSecondary = Color(0xFF4F5268);
  static const Color textMuted = Color(0xFF63667E);

  // Category tints
  static const Color tintPurpleBg = Color(0xCCEDE6FF);
  static const Color tintPurpleFg = Color(0xFF7448F5);

  static const Color tintGreenBg = Color(0xCCE0F9EA);
  static const Color tintGreenFg = Color(0xFF1F9D63);

  static const Color tintAmberBg = Color(0xCCFFF1D6);
  static const Color tintAmberFg = Color(0xFFD98418);

  static const Color tintBlueBg = Color(0xCCDEEEFF);
  static const Color tintBlueFg = Color(0xFF2D78F2);

  static const Color tintTealBg = Color(0xCCDCF6F3);
  static const Color tintTealFg = Color(0xFF0A968A);

  // Semantic git diff tokens
  static const Color diffAddBg = Color(0xFFE7FAEE);
  static const Color diffAddGutter = Color(0xFFCFF3DC);
  static const Color diffAddText = Color(0xFF136E42);

  static const Color diffDelBg = Color(0xFFFEEBEB);
  static const Color diffDelGutter = Color(0xFFFCD5D5);
  static const Color diffDelText = Color(0xFFBA2535);

  static const Color diffHunkBg = Color(0xFFEEE9FF);
  static const Color diffHunkText = Color(0xFF6340CF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA580FF), Color(0xFF7547FF)],
  );

  static const LinearGradient userBubbleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xE69B76FF), Color(0xE67447FF)],
  );

  static const LinearGradient progressGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF7447FF), Color(0xFFB596FF)],
  );

  // AI avatar (Wynn Pixar 3D character palette — glossy black bob, glasses, cream/navy knit)
  static const Color avatarHoodLight = Color(0xFFF7F5F1);
  static const Color avatarHood = Color(0xFFEBE7DF);
  static const Color avatarHoodDark = Color(0xFFD2CCC2);
  static const Color avatarSweaterStripe = Color(0xFF343C66);
  static const Color avatarGlasses = Color(0xFF17181E);
  static const Color avatarSkin = Color(0xFFFAD3BC);
  static const Color avatarSkinShade = Color(0xFFE3A38B);
  static const Color avatarHair = Color(0xFF1C1D25);
  static const Color avatarHairShade = Color(0xFF0E0F14);
  static const Color avatarHairHighlight = Color(0xFF565D78);
  static const Color avatarIris = Color(0xFF2B1C18);
  static const Color avatarIrisLight = Color(0xFF5A3D33);
  static const Color avatarStarClip = Color(0xFFFFD66B);
  static const Color avatarBlush = Color(0xFFF4988C);
  static const Color avatarInk = Color(0xFF14151C);
  static const Color avatarMouth = Color(0xFFD96F5A);
  static const Color avatarTongue = Color(0xFFF49584);
}
