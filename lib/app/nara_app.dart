import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/di.dart';
import '../core/navigation/app_router.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

/// Root widget: Material 3 dark theme, locale-aware, GoRouter navigation.
class NaraApp extends ConsumerWidget {
  const NaraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return settings.maybeWhen(
      data: (s) => MaterialApp.router(
        title: 'NARA Voice',
        debugShowCheckedModeBanner: false,
        theme: NaraTheme.dark(),
        locale: Locale(s.locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: appRouter,
      ),
      orElse: () => MaterialApp(
        title: 'NARA Voice',
        debugShowCheckedModeBanner: false,
        theme: NaraTheme.dark(),
        home: const _BootScaffold(),
      ),
    );
  }
}

class _BootScaffold extends StatelessWidget {
  const _BootScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Shared bottom navigation used by every screen.
class NaraNavigationBar extends ConsumerWidget {
  const NaraNavigationBar({super.key, required this.current});

  final String current;

  static const _items = <(String, String, IconData)>[
    ('/', 'navHome', Icons.graphic_eq_rounded),
    ('/apps', 'navApps', Icons.apps_rounded),
    ('/automations', 'navAutomations', Icons.auto_mode_rounded),
    ('/permissions', 'navPermissions', Icons.verified_user_rounded),
    ('/settings', 'navSettings', Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return NavigationBar(
      selectedIndex: _items.indexWhere((i) => i.$1 == current).clamp(0, _items.length - 1),
      onDestinationSelected: (index) => context.go(_items[index].$1),
      destinations: [
        for (final item in _items)
          NavigationDestination(
            icon: Icon(item.$3),
            label: l10n.getString(item.$2),
          ),
      ],
    );
  }
}

extension on AppLocalizations {
  /// Navigation labels are keyed to keep the bar terse; generated getters
  /// already exist for each — resolve by key for the shared widget.
  String getString(String key) => switch (key) {
        'navHome' => navHome,
        'navApps' => navApps,
        'navAutomations' => navAutomations,
        'navPermissions' => navPermissions,
        'navSettings' => navSettings,
        _ => key,
      };
}
