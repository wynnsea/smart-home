import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/network/wynn_bridge_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/motion_widgets.dart';
import '../../../agent_chat/presentation/providers/agent_chat_provider.dart';
import '../../../git_diff/presentation/providers/git_diff_provider.dart';
import '../providers/workspace_provider.dart';
import '../widgets/server_file_browser_sheet.dart';

/// Displays all project folders discovered on the remote Server Bridge and
/// allows 1-tap switching of the active target repository without restarting.
class ReposPage extends ConsumerStatefulWidget {
  const ReposPage({
    super.key,
    required this.onOpenHostTab,
    required this.onOpenChatTab,
  });

  final VoidCallback onOpenHostTab;
  final VoidCallback onOpenChatTab;

  @override
  ConsumerState<ReposPage> createState() => _ReposPageState();
}

class _ReposPageState extends ConsumerState<ReposPage> {
  List<ServerRepoItem> _repos = const [];
  bool _loading = false;
  String? _switchingName;
  String? _pullingName;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRepos());
  }

  Future<void> _loadRepos() async {
    final cfg = ref.read(bridgeConfigProvider);
    if (!cfg.isActive) {
      if (mounted) {
        setState(() {
          _repos = const [];
          _loading = false;
          _error = null;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await WynnBridgeClient().fetchRepos(cfg);
      if (!mounted) return;
      setState(() {
        _repos = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pullRepo(ServerRepoItem repo) async {
    final cfg = ref.read(bridgeConfigProvider);
    if (!cfg.isActive || _pullingName != null) return;
    setState(() => _pullingName = repo.name);
    try {
      final out = await WynnBridgeClient().pullRepo(cfg, repoName: repo.name);
      await _loadRepos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('git pull (${repo.name}): $out'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'git pull gagal: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _pullingName = null);
    }
  }

  Future<void> _selectRepo(ServerRepoItem item) async {
    final cfg = ref.read(bridgeConfigProvider);
    if (!cfg.isActive || _switchingName != null) return;

    setState(() => _switchingName = item.name);
    try {
      await WynnBridgeClient().selectRepo(cfg, item.name);
      await ref.read(workspaceOverviewProvider.notifier).reconnect();
      await ref.read(gitDiffProvider.notifier).refresh();
      ref
          .read(agentChatProvider.notifier)
          .newSession(
            repoFullName: item.name,
            branch: item.branch.isNotEmpty ? item.branch : 'main',
          );
      await _loadRepos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berpindah ke project "${item.name}"'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal pindah repo: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _switchingName = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bridgeCfg = ref.watch(bridgeConfigProvider);
    final status = ref.watch(workspaceOverviewProvider).hostStatus;
    final filtered = _query.isEmpty
        ? _repos
        : _repos
              .where((r) => r.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadRepos,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 118),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Repositories',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bridgeCfg.isActive
                            ? 'Daftar project di Server (${bridgeCfg.hostAddress})'
                            : 'Hubungkan Server Bridge di tab Host untuk melihat daftar repo',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                GlassCircleButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Muat ulang repo',
                  onTap: _loadRepos,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!bridgeCfg.isActive)
              GlassCard(
                blur: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.tintAmberBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.dns_outlined,
                            color: AppColors.tintAmberFg,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Server Bridge belum aktif',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'Aktifkan Remote Bridge di tab Host untuk memilih project langsung dari HP.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: widget.onOpenHostTab,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.settings_ethernet_rounded, size: 18),
                        label: const Text('Buka Pengaturan Host'),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Cari nama project...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  filled: true,
                  fillColor: AppColors.adaptiveInputFill(context),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppColors.adaptiveBorder(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                GlassCard(
                  blur: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gagal memuat daftar repo',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.diffDelText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Repo aktif saat ini: ${status.repoFullName} (${status.branch})',
                        style: AppTheme.monoStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else if (filtered.isEmpty)
                GlassCard(
                  blur: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Tidak ada project yang cocok',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                )
              else
                ...filtered.map(
                  (repo) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: BouncyTap(
                      onTap: () => repo.isActive
                          ? widget.onOpenChatTab()
                          : _selectRepo(repo),
                      child: GlassCard(
                        blur: false,
                        padding: const EdgeInsets.all(14),
                        borderRadius: 20,
                        borderColor: repo.isActive ? AppColors.primary : null,
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: repo.isActive
                                    ? AppColors.primarySoft
                                    : AppColors.tintBlueBg,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                repo.isGit
                                    ? Icons.folder_special_rounded
                                    : Icons.folder_outlined,
                                color: repo.isActive
                                    ? AppColors.primary
                                    : AppColors.tintBlueFg,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          repo.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      if (repo.isActive) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.tintGreenBg,
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                          child: const Text(
                                            'AKTIF',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.tintGreenFg,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (repo.dirtyCount > 0) ...[
                                        const SizedBox(width: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.tintAmberBg,
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                          child: Text(
                                            '${repo.dirtyCount} ubah',
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.tintAmberFg,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    repo.isGit && repo.branch.isNotEmpty
                                        ? 'git · ${repo.branch}${repo.lastCommitTime.isNotEmpty ? ' · ${repo.lastCommitTime}' : ''}'
                                        : 'Folder lokal',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.monoStyle(
                                      fontSize: 11.2,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (repo.lastCommit.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      repo.lastCommit,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontSize: 11),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (repo.isActive)
                              IconButton(
                                tooltip: 'Lihat file project',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Icons.folder_copy_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                onPressed: () =>
                                    showServerFileBrowserSheet(context),
                              ),
                            if (repo.isGit)
                              _pullingName == repo.name
                                  ? const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: 'Git Pull',
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.cloud_download_outlined,
                                        size: 19,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () => _pullRepo(repo),
                                    ),
                            if (_switchingName == repo.name)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Icon(
                                repo.isActive
                                    ? Icons.chat_bubble_outline_rounded
                                    : Icons.swap_horiz_rounded,
                                size: 19,
                                color: repo.isActive
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
