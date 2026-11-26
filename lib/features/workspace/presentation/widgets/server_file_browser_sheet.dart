import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/network/wynn_bridge_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_surface.dart';

/// Opens a live Server File Browser & Read-Only Code Viewer bottom sheet.
Future<void> showServerFileBrowserSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ServerFileBrowserSheet(),
  );
}

class _ServerFileBrowserSheet extends ConsumerStatefulWidget {
  const _ServerFileBrowserSheet();

  @override
  ConsumerState<_ServerFileBrowserSheet> createState() =>
      _ServerFileBrowserSheetState();
}

class _ServerFileBrowserSheetState
    extends ConsumerState<_ServerFileBrowserSheet> {
  String _currentDir = '.';
  List<ServerFileEntry> _entries = const [];
  ServerFileContent? _openedFile;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDir('.'));
  }

  Future<void> _loadDir(String dir) async {
    final cfg = ref.read(bridgeConfigProvider);
    if (!cfg.isActive) {
      setState(() {
        _error = 'Aktifkan Remote Bridge di tab Host untuk melihat file server.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _openedFile = null;
    });
    try {
      final list = await WynnBridgeClient().fetchFiles(cfg, dir: dir);
      if (!mounted) return;
      setState(() {
        _currentDir = dir;
        _entries = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openFile(ServerFileEntry entry) async {
    if (entry.isDir) {
      await _loadDir(entry.path);
      return;
    }
    final cfg = ref.read(bridgeConfigProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final content = await WynnBridgeClient().readFile(cfg, entry.path);
      if (!mounted) return;
      setState(() {
        _openedFile = content;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _goUp() {
    if (_openedFile != null) {
      setState(() => _openedFile = null);
      return;
    }
    if (_currentDir == '.' || _currentDir.isEmpty) return;
    final parts = _currentDir.split('/')..removeLast();
    _loadDir(parts.isEmpty ? '.' : parts.join('/'));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canGoUp = _openedFile != null || _currentDir != '.';

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF15192E) : const Color(0xFFF7F7FD),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    if (canGoUp)
                      IconButton(
                        tooltip: 'Kembali',
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        onPressed: _goUp,
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _openedFile != null
                                ? _openedFile!.path.split('/').last
                                : 'File Explorer Server',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            _openedFile?.path ?? _currentDir,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.monoStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_openedFile != null)
                      IconButton(
                        tooltip: 'Salin isi file',
                        icon: const Icon(Icons.copy_rounded, size: 19),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: _openedFile!.content),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Isi file disalin ke clipboard'),
                            ),
                          );
                        },
                      ),
                    IconButton(
                      tooltip: 'Tutup',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      )
                    : _openedFile != null
                    ? _CodeContentView(
                        file: _openedFile!,
                        scrollController: scrollController,
                      )
                    : _entries.isEmpty
                    ? Center(
                        child: Text(
                          'Folder kosong',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _entries[index];
                          return GlassCard(
                            blur: false,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            borderRadius: 16,
                            onTap: () => _openFile(item),
                            child: Row(
                              children: [
                                Icon(
                                  item.isDir
                                      ? Icons.folder_rounded
                                      : Icons.description_outlined,
                                  size: 20,
                                  color: item.isDir
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.monoStyle(
                                      fontSize: 12.5,
                                      fontWeight: item.isDir
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color ??
                                          AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (!item.isDir)
                                  Text(
                                    _formatBytes(item.size),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontSize: 10.5),
                                  )
                                else
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

class _CodeContentView extends StatelessWidget {
  const _CodeContentView({
    required this.file,
    required this.scrollController,
  });

  final ServerFileContent file;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final lines = file.content.replaceAll('\r\n', '\n').split('\n');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFE9ECFF) : AppColors.textPrimary;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.right,
                  style: AppTheme.monoStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableText(
                  lines[index],
                  style: AppTheme.monoStyle(
                    fontSize: 11.8,
                    color: textColor,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
