import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/nara_app.dart';
import '../../../app/theme.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../l10n/app_localizations.dart';

/// Transparent permission center (spec §14): review, enable, revoke.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  List<PermissionStatusInfo>? _statuses;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final statuses = await ref.read(permissionServiceProvider).statusAll();
    if (mounted) setState(() => _statuses = statuses);
  }

  Future<void> _toggle(PermissionStatusInfo info) async {
    final service = ref.read(permissionServiceProvider);
    if (info.granted) {
      // Revocation always happens in system settings — no silent changes.
      await service.openAppSettings();
    } else {
      await service.request(info.permission);
    }
    // Give the OS a beat when the user returns from system settings.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.permissionCenter)),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              l10n.permissionExplanation,
              style: TextStyle(color: NaraTheme.textSecondary, height: 1.5),
            ),
          ),
          if (_statuses == null)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else
            for (final info in _statuses!) _PermissionTile(info: info, onToggle: _toggle),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              l10n.securityNote,
              style: TextStyle(color: NaraTheme.textSecondary, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const NaraNavigationBar(current: '/permissions'),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({required this.info, required this.onToggle});

  final PermissionStatusInfo info;
  final Future<void> Function(PermissionStatusInfo) onToggle;

  (String, String, IconData) _copy(AppLocalizations l10n) {
    switch (info.permission) {
      case NaraPermission.microphone:
        return (l10n.permMicrophone, l10n.permMicrophoneDesc, Icons.mic_rounded);
      case NaraPermission.notifications:
        return (l10n.permNotifications, l10n.permNotificationsDesc, Icons.notifications_rounded);
      case NaraPermission.accessibility:
        return (l10n.permAccessibility, l10n.permAccessibilityDesc, Icons.visibility_rounded);
      case NaraPermission.notificationListener:
        return (l10n.permListener, l10n.permListenerDesc, Icons.mark_email_unread_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (title, subtitle, icon) = _copy(l10n);
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 26),
        title: Text(title),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: NaraTheme.textSecondary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              info.granted ? l10n.granted : l10n.notGranted,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: info.granted ? NaraTheme.success : NaraTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                backgroundColor: info.granted
                    ? NaraTheme.card
                    : NaraTheme.accentPurple.withValues(alpha: 0.25),
              ),
              onPressed: () => onToggle(info),
              child: Text(info.granted ? l10n.openSystemSettings : l10n.enable,
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
