import 'package:go_router/go_router.dart';

import '../../features/app_discovery/presentation/apps_screen.dart';
import '../../features/automation/presentation/automations_screen.dart';
import '../../features/permissions/presentation/permissions_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/voice_assistant/presentation/home_screen.dart';

/// App navigation: Home (voice), Apps, Automations, Permissions, Settings.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/apps', builder: (_, _) => const AppsScreen()),
    GoRoute(path: '/automations', builder: (_, _) => const AutomationsScreen()),
    GoRoute(path: '/permissions', builder: (_, _) => const PermissionsScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
  ],
);
