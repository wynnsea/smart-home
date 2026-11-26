import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/motion_widgets.dart';
import '../../../ai_avatar/presentation/widgets/avatar_debug_page.dart';
import '../../domain/entities/workspace_entities.dart';
import '../providers/workspace_provider.dart';

/// Host & Bridge configuration page with editable address/port validation,
/// connection test, disconnect control, and collapsed developer endpoint info (T7.2).
class HostSettingsPage extends ConsumerStatefulWidget {
  const HostSettingsPage({super.key});

  @override
  ConsumerState<HostSettingsPage> createState() => _HostSettingsPageState();
}

class _HostSettingsPageState extends ConsumerState<HostSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressController;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final status = ref.read(workspaceOverviewProvider).hostStatus;
    _addressController = TextEditingController(text: status.hostAddress);
    _portController = TextEditingController(text: '${status.hostPort}');
  }

  @override
  void dispose() {
    _addressController.dispose();
    _portController.dispose();
    super.dispose();
  }

  String? _validateAddress(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Alamat host wajib diisi';
    final pattern = RegExp(r'^[a-zA-Z0-9.-]+$');
    if (!pattern.hasMatch(v)) {
      return 'Gunakan IP atau hostname valid tanpa spasi';
    }
    return null;
  }

  String? _validatePort(String? value) {
    final v = value?.trim() ?? '';
    final port = int.tryParse(v);
    if (port == null || port < 1 || port > 65535) {
      return 'Port harus 1–65535';
    }
    return null;
  }

  Future<void> _testConnection() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final address = _addressController.text.trim();
    final port = int.parse(_portController.text.trim());
    final notifier = ref.read(workspaceOverviewProvider.notifier);
    notifier.updateHostEndpoint(address: address, port: port);
    final latency = await notifier.reconnect();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Terhubung ke $address:$port (${latency}ms)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(workspaceOverviewProvider).hostStatus;
    final (badgeBg, badgeFg) = switch (status.connectionState) {
      HostConnectionState.connected => (
        AppColors.tintGreenBg,
        AppColors.tintGreenFg,
      ),
      HostConnectionState.connecting => (
        AppColors.tintAmberBg,
        AppColors.tintAmberFg,
      ),
      HostConnectionState.disconnected => (
        AppColors.diffDelBg,
        AppColors.diffDelText,
      ),
    };

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 118),
        children: [
          Text(
            'Host & Bridge',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Koneksi privat antar perangkat ke mesin host repository',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          status.isConnected
                              ? Icons.vpn_lock_rounded
                              : Icons.wifi_off_rounded,
                          color: badgeFg,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status.hostName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              status.isConnected
                                  ? '${status.endpointLabel} · ${status.latencyMs}ms'
                                  : status.endpointLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.monoStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.connectionLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: badgeFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _addressController,
                          validator: _validateAddress,
                          keyboardType: TextInputType.url,
                          style: AppTheme.monoStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            labelText: 'Alamat Host (Tailscale / IP)',
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.78),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.borderDivider,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _portController,
                          validator: _validatePort,
                          keyboardType: TextInputType.number,
                          style: AppTheme.monoStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            labelText: 'Port',
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.78),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.borderDivider,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: status.connectionState ==
                                  HostConnectionState.connecting
                              ? null
                              : _testConnection,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.network_check_rounded, size: 18),
                          label: Text(
                            status.connectionState ==
                                    HostConnectionState.connecting
                                ? 'Menyambung…'
                                : 'Tes koneksi',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: status.connectionState ==
                                HostConnectionState.disconnected
                            ? null
                            : () => ref
                                  .read(workspaceOverviewProvider.notifier)
                                  .simulateDisconnect(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.diffDelText,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          side: BorderSide(
                            color: AppColors.diffDelText.withValues(alpha: 0.35),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Putuskan'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _HostMetaRow(label: 'Repository', value: status.repoFullName),
                  const SizedBox(height: 8),
                  _HostMetaRow(label: 'Active Branch', value: status.branch),
                  const SizedBox(height: 8),
                  const _HostMetaRow(
                    label: 'Transport',
                    value: 'Tailscale Private Mesh',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            blur: false,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                initiallyExpanded: false,
                title: const Text(
                  'Info developer',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Daftar endpoint bridge (mock mode)',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                children: [
                  if (kDebugMode) ...[
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.face_retouching_natural_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Preview avatar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Galeri 9 mood, slider ekspresi & reaksi Wynn',
                        style: TextStyle(fontSize: 11.2),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        EtherealPageRoute<void>(
                          builder: (_) => const AvatarDebugPage(),
                        ),
                      ),
                    ),
                    const Divider(height: 12),
                  ],
                  const _EndpointRow(
                    method: 'POST',
                    path: '/prompt',
                    desc: 'SSE real-time stream',
                  ),
                  const _EndpointRow(
                    method: 'GET',
                    path: '/git/status',
                    desc: 'Modified files list',
                  ),
                  const _EndpointRow(
                    method: 'GET',
                    path: '/git/diff',
                    desc: 'Unified diff hunks',
                  ),
                  const _EndpointRow(
                    method: 'POST',
                    path: '/git/commit',
                    desc: 'Approve & push',
                  ),
                  const _EndpointRow(
                    method: 'POST',
                    path: '/git/reset',
                    desc: 'Discard / rollback',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostMetaRow extends StatelessWidget {
  const _HostMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.method,
    required this.path,
    required this.desc,
  });

  final String method;
  final String path;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final isPost = method == 'POST';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: isPost ? AppColors.primarySoft : AppColors.tintBlueBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              method,
              style: AppTheme.monoStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isPost ? AppColors.primaryDark : AppColors.tintBlueFg,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            path,
            style: AppTheme.monoStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              desc,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
