import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/app_integrations/integration_registry.dart';
import '../features/settings/settings_store.dart';
import 'ai/app_lookup.dart';
import 'ai/cloud/cloud_client.dart';
import 'ai/conversation_memory.dart';
import 'ai/nlu/nlu_engine.dart';
import 'ai/orchestrator.dart';
import 'models/app_descriptor.dart';
import 'platform/accessibility_platform.dart';
import 'platform/apps_platform.dart';
import 'platform/device_platform.dart';
import 'platform/intents_platform.dart';
import 'platform/notifications_platform.dart';
import 'platform/permissions_platform.dart';
import 'platform/voice_platform.dart';
import 'tools/tool_registry.dart';

// ===== Platform bridges =====

final appsPlatformProvider = Provider<AppsPlatform>((_) => AppsPlatform());
final intentsPlatformProvider = Provider<IntentsPlatform>((_) => IntentsPlatform());
final voicePlatformProvider = Provider<VoicePlatform>((ref) {
  final platform = VoicePlatform();
  ref.onDispose(platform.dispose);
  return platform;
});
final accessibilityPlatformProvider =
    Provider<AccessibilityPlatform>((_) => AccessibilityPlatform());
final notificationsPlatformProvider =
    Provider<NotificationsPlatform>((_) => NotificationsPlatform());
final permissionsPlatformProvider =
    Provider<PermissionsPlatform>((_) => PermissionsPlatform());
final devicePlatformProvider = Provider<DevicePlatform>((_) => DevicePlatform());

// ===== Settings =====

final settingsStoreProvider = Provider<SettingsStore>((_) => SettingsStore());

/// Riverpod state for the settings screen + consumers (voice locale, TTS).
class SettingsController extends StateNotifier<AsyncValue<NaraSettings>> {
  SettingsController(this._store, this._cloudClient) : super(const AsyncValue.loading()) {
    _bootstrap();
  }

  final SettingsStore _store;
  final CloudAiClient _cloudClient;

  Future<void> _bootstrap() async {
    try {
      final settings = await _store.load();
      state = AsyncValue.data(settings);
      await _applyCloud(settings.cloudEnabled);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _applyCloud(bool enabled) async {
    if (!enabled) return;
    final credentials = await _store.loadCredentials();
    _cloudClient.configure(CloudAiConfig(
      endpoint: credentials.endpoint,
      apiKey: credentials.apiKey,
      model: credentials.model,
      enabled: credentials.apiKey.isNotEmpty,
    ));
  }

  Future<void> update(NaraSettings settings) async {
    state = AsyncValue.data(settings);
    await _store.save(settings);
    await _applyCloud(settings.cloudEnabled);
  }

  Future<CloudCredentials> credentials() => _store.loadCredentials();

  Future<void> saveCredentials(CloudCredentials credentials) async {
    await _store.saveCredentials(credentials);
    await _applyCloud(true);
  }

  /// Honest status for the Settings screen: 'ready' | 'missing_key' | 'off'.
  Future<String> cloudStatus(bool enabled) async {
    if (!enabled) return 'off';
    final credentials = await _store.loadCredentials();
    if (credentials.apiKey.isEmpty) return 'missing_key';
    return 'ready';
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AsyncValue<NaraSettings>>(
  (ref) => SettingsController(
    ref.watch(settingsStoreProvider),
    ref.watch(cloudAiClientProvider),
  ),
);

final appCatalogProvider = FutureProvider<List<AppDescriptor>>((ref) async {
  final apps = await ref.watch(appsPlatformProvider).getInstalledApps();
  return apps
      .map((a) => AppDescriptor(
            appName: a.appName,
            packageName: a.packageName,
            launchable: a.launchable,
            enabled: a.enabled,
            isSystem: a.isSystem,
            versionName: a.versionName,
            versionCode: a.versionCode,
            category: a.category,
            capabilities: IntegrationRegistry.capabilitiesFor(a.packageName),
            supportedDeepLinks: IntegrationRegistry.deepLinksFor(a.packageName),
          ))
      .toList(growable: false);
});

// ===== AI core =====

final appLookupProvider = Provider<AppCatalogLookup>((ref) {
  final lookup = AppCatalogLookup(
    () => ref.read(appCatalogProvider.future),
  );
  lookup.startCacheTimer();
  ref.onDispose(lookup.dispose);
  return lookup;
});

final cloudAiClientProvider = Provider<CloudAiClient>((ref) {
  final client = CloudAiClient();
  ref.onDispose(client.dispose);
  return client;
});

final nluEngineProvider = Provider<NluEngine>((ref) {
  final lookup = ref.watch(appLookupProvider);
  // The NLU resolves synchronously: registry names are deterministic and the
  // catalog cache is warmed by the controller at startup.
  return NluEngine(appLookup: lookup.lookupSync);
});

final toolRegistryProvider = Provider<ToolRegistry>((ref) {
  return ToolRegistry(
    apps: ref.watch(appsPlatformProvider),
    intents: ref.watch(intentsPlatformProvider),
    accessibility: ref.watch(accessibilityPlatformProvider),
    notifications: ref.watch(notificationsPlatformProvider),
    device: ref.watch(devicePlatformProvider),
    catalogSource: () => ref.read(appCatalogProvider.future),
  );
});

final conversationMemoryProvider = Provider<ConversationMemory>((_) {
  return ConversationMemory();
});

final orchestratorProvider = Provider<Orchestrator>((ref) {
  return Orchestrator(
    nlu: ref.watch(nluEngineProvider),
    registry: ref.watch(toolRegistryProvider),
    memory: ref.watch(conversationMemoryProvider),
    appLookup: ref.watch(appLookupProvider),
    cloudClient: ref.watch(cloudAiClientProvider),
  );
});
