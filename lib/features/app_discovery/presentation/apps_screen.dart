import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/nara_app.dart';
import '../../../app/theme.dart';
import '../../../core/di.dart';
import '../../../core/models/app_descriptor.dart';
import '../../../l10n/app_localizations.dart';

/// App management dashboard (spec §13): the installed catalog with search,
/// capability badges and launch/details actions.
class AppsScreen extends ConsumerStatefulWidget {
  const AppsScreen({super.key});

  @override
  ConsumerState<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends ConsumerState<AppsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final catalog = ref.watch(appCatalogProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.installedApps)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: l10n.searchApps,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: catalog.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Katalog aplikasi tidak dapat dimuat:\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: NaraTheme.danger),
                  ),
                ),
              ),
              data: (apps) {
                final filtered = apps
                    .where((a) => a.launchable && a.enabled)
                    .where((a) =>
                        _query.isEmpty ||
                        a.appName.toLowerCase().contains(_query) ||
                        a.packageName.contains(_query))
                    .toList()
                  ..sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
                if (filtered.isEmpty) {
                  return Center(child: Text(l10n.noAppsFound));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(appCatalogProvider.future),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _AppTile(app: filtered[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const NaraNavigationBar(current: '/apps'),
    );
  }
}

class _AppTile extends ConsumerStatefulWidget {
  const _AppTile({required this.app});

  final AppDescriptor app;

  @override
  ConsumerState<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends ConsumerState<_AppTile> {
  Uint8List? _icon;

  @override
  void initState() {
    super.initState();
    _loadIcon();
  }

  Future<void> _loadIcon() async {
    try {
      final icon = await ref
          .read(appsPlatformProvider)
          .getAppIcon(widget.app.packageName, size: 64);
      if (mounted) setState(() => _icon = icon);
    } catch (_) {
      // Fallback icon renders instead.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final caps = widget.app.capabilities;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _icon != null
            ? Image.memory(_icon!, width: 40, height: 40, fit: BoxFit.cover)
            : Container(
                width: 40,
                height: 40,
                color: NaraTheme.card,
                child: const Icon(Icons.android_rounded, size: 22),
              ),
      ),
      title: Text(widget.app.appName, style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        caps.isEmpty ? widget.app.packageName : caps.join(' · '),
        style: TextStyle(fontSize: 12, color: NaraTheme.textSecondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.app.isSystem)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(l10n.system,
                  style: TextStyle(fontSize: 10, color: NaraTheme.textSecondary)),
            ),
          IconButton(
            tooltip: l10n.appDetails,
            icon: const Icon(Icons.info_outline_rounded, size: 20),
            onPressed: () {
              ref
                  .read(intentsPlatformProvider)
                  .openAppDetails(widget.app.packageName);
            },
          ),
          IconButton(
            tooltip: l10n.openApp,
            icon: const Icon(Icons.play_arrow_rounded),
            onPressed: () {
              ref.read(appsPlatformProvider).launchApp(widget.app.packageName);
            },
          ),
        ],
      ),
    );
  }
}
