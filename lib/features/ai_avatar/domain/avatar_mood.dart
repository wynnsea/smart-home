/// Semantic moods driven by app state (ordered in priority inside avatarMoodProvider).
enum AvatarMood {
  idle('Siap'),
  listening('Mendengarkan'),
  thinking('Sedang berpikir'),
  streaming('Sedang menjawab'),
  success('Berhasil'),
  error('Terjadi kesalahan'),
  offline('Host terputus'),
  connecting('Menyambungkan'),
  sleepy('Mengantuk');

  const AvatarMood(this.semanticLabel);
  final String semanticLabel;
}

/// Short transient reactions triggered by touch gestures or app events.
enum AvatarReaction {
  boop,
  wink,
  giggle,
  pet,
  wave,
  nod,
  success,
  errorShake,
  startle,
}

/// Hand / sleeve placement poses for chibi Wynn v2.
enum ArmPose {
  rest,
  peek,
  chin,
  wave,
  cheer,
  type,
  worry,
  coverMouth,
}

/// Expressive anime eye shape variations.
enum EyeShape {
  normal,
  happy,
  squeeze,
  wide,
}

/// Overall body placement mode: standalone standing vs peeking over a card edge.
enum AvatarPoseMode {
  standing,
  peek,
}

/// Standardized display sizes with tuned framing, detail & particle budgets.
enum AvatarSize {
  xs(34, maxParticles: 0, showHands: false, swayHair: false),
  sm(48, maxParticles: 3, showHands: true, swayHair: true),
  md(88, maxParticles: 6, showHands: true, swayHair: true),
  lg(168, maxParticles: 8, showHands: true, swayHair: true);

  const AvatarSize(
    this.dp, {
    required this.maxParticles,
    required this.showHands,
    required this.swayHair,
  });

  final double dp;
  final int maxParticles;
  final bool showHands;
  final bool swayHair;
}
