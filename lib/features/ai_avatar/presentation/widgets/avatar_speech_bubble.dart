import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../agent_chat/presentation/providers/agent_chat_provider.dart';
import '../../../git_diff/presentation/providers/git_diff_provider.dart';
import '../../../git_diff/presentation/widgets/git_diff_bottom_sheet.dart';
import '../../../workspace/domain/entities/workspace_entities.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';

class AvatarSpeechPayload {
  const AvatarSpeechPayload({
    required this.text,
    this.onTap,
    this.actionHint,
  });

  final String text;
  final void Function(BuildContext context)? onTap;
  final String? actionHint;
}

const List<String> _kIdleTips = [
  'Ketuk judul sesi di Chat untuk buat sesi baru atau pindah thread ✨',
  'Tekan lama aku kapan saja untuk cek status repo cepat!',
  'Ketuk chip file di pesan agent untuk langsung buka diff-nya.',
  'Kamu bisa commit sebagian file saja lewat dialog Commit & Push.',
  'Tarik layar ke bawah di Home atau Diff untuk refresh status host.',
];

String _greetingForNow(DateTime now) {
  final h = now.hour;
  if (h < 11) return 'Selamat pagi';
  if (h < 15) return 'Selamat siang';
  if (h < 18) return 'Selamat sore';
  return 'Selamat malam';
}

/// Computes contextual speech bubble content and tap action from current app state (2.1).
AvatarSpeechPayload buildContextualSpeech(
  WidgetRef ref, {
  bool preferGreeting = false,
  math.Random? random,
}) {
  final hostStatus = ref.read(workspaceOverviewProvider).hostStatus;
  final diffSnapshot = ref.read(gitDiffProvider).snapshot;
  final chatState = ref.read(agentChatProvider);

  if (hostStatus.connectionState == HostConnectionState.disconnected) {
    return AvatarSpeechPayload(
      text: 'Host-nya lagi nggak nyambung. Coba sambungkan ulang?',
      actionHint: 'Ketuk untuk sambungkan',
      onTap: (_) => ref.read(workspaceOverviewProvider.notifier).reconnect(),
    );
  }

  final lastErrorIdx = chatState.messages.lastIndexWhere(
    (m) => !m.isUser && m.isError,
  );
  if (chatState.errorMessage != null || lastErrorIdx != -1) {
    final errorMsgId = lastErrorIdx != -1
        ? chatState.messages[lastErrorIdx].id
        : null;
    return AvatarSpeechPayload(
      text: 'Barusan ada yang gagal. Mau aku coba lagi?',
      actionHint: errorMsgId != null ? 'Ketuk untuk ulangi' : null,
      onTap: errorMsgId == null
          ? null
          : (_) =>
                ref.read(agentChatProvider.notifier).retryMessage(errorMsgId),
    );
  }

  if (preferGreeting) {
    final greet = _greetingForNow(DateTime.now());
    return AvatarSpeechPayload(
      text: '$greet, ${hostStatus.userName}! Mau ngoding apa hari ini?',
    );
  }

  if (diffSnapshot.hasChanges) {
    final n = diffSnapshot.files.length;
    return AvatarSpeechPayload(
      text: 'Ada $n file yang nunggu direview 👀',
      actionHint: 'Ketuk untuk buka diff',
      onTap: (context) => showGitDiffBottomSheet(context),
    );
  }

  final rng = random ?? math.Random();
  return AvatarSpeechPayload(
    text: _kIdleTips[rng.nextInt(_kIdleTips.length)],
  );
}

/// Compact frosted glass speech bubble with a tail pointing toward Wynn.
/// Appears with scale + fade and dismisses on tap or after auto-hide timeout.
class AvatarSpeechBubble extends StatelessWidget {
  const AvatarSpeechBubble({
    super.key,
    required this.text,
    required this.visible,
    this.actionHint,
    this.onTap,
    this.maxWidth = 236,
  });

  final String text;
  final bool visible;
  final String? actionHint;
  final VoidCallback? onTap;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: visible ? 1.0 : 0.88,
          duration: duration,
          alignment: Alignment.bottomCenter,
          curve: Curves.easeOutBack,
          child: Semantics(
            liveRegion: true,
            button: onTap != null,
            label: actionHint != null ? '$text $actionHint' : text,
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.94),
                            AppColors.primarySoft.withValues(alpha: 0.86),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.96),
                          width: 1.3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.14),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (actionHint != null) ...[
                            const SizedBox(height: 3),
                            Center(
                              child: Text(
                                actionHint!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  CustomPaint(
                    size: const Size(14, 7),
                    painter: _BubbleTailPainter(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) => false;
}
