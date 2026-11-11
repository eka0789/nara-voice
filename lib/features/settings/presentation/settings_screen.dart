import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/nara_app.dart';
import '../../../app/theme.dart';
import '../../../core/di.dart';
import '../../../core/platform/firebase_service.dart';
import '../../../l10n/app_localizations.dart';
import '../settings_store.dart';

/// Settings: language, TTS, optional cloud AI (BYO endpoint), memory, about.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _endpointController = TextEditingController();
  final _modelController = TextEditingController();
  final _keyController = TextEditingController();
  String? _appVersion;
  bool? _firebaseActive;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
    _loadVersion();
    _loadFirebase();
  }

  Future<void> _loadCredentials() async {
    final controller = ref.read(settingsProvider.notifier);
    final credentials = await controller.credentials();
    if (mounted) {
      setState(() {
        _endpointController.text = credentials.endpoint;
        _modelController.text = credentials.model;
      });
    }
  }

  Future<void> _loadVersion() async {
    final device = ref.read(devicePlatformProvider);
    final info = await device.getDeviceInfo();
    if (mounted) {
      setState(() => _appVersion = '${info['appVersionName'] ?? '1.0.0'} (Android ${info['androidRelease'] ?? ''})');
    }
  }

  Future<void> _loadFirebase() async {
    final service = ref.read(firebaseServiceProvider);
    if (mounted) {
      setState(() => _firebaseActive = service.cloudAvailable);
    }
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _modelController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.asData?.value ?? const NaraSettings();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          _sectionTitle(l10n.language),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'id', label: Text('Bahasa Indonesia')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {settings.locale},
                onSelectionChanged: (selection) => ref
                    .read(settingsProvider.notifier)
                    .update(settings.copyWith(locale: selection.first)),
              ),
            ),
          ),
          _sectionTitle(l10n.voiceResponses),
          SwitchListTile(
            title: Text(l10n.voiceResponses),
            value: settings.ttsEnabled,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).update(settings.copyWith(ttsEnabled: v)),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _sliderTile(l10n.speechRate, settings.ttsRate, 0.5, 2.0,
                      (v) => settings.copyWith(ttsRate: v)),
                  _sliderTile(l10n.speechPitch, settings.ttsPitch, 0.5, 2.0,
                      (v) => settings.copyWith(ttsPitch: v)),
                ],
              ),
            ),
          ),
          _sectionTitle(l10n.cloudAi),
          SwitchListTile(
            title: Text(l10n.cloudAi),
            subtitle: FutureBuilder<String>(
              future: ref.read(settingsProvider.notifier).cloudStatus(settings.cloudEnabled),
              builder: (context, snapshot) {
                final status = snapshot.data ?? (settings.cloudEnabled ? 'ready' : 'off');
                return Text(
                  switch (status) {
                    'ready' => l10n.cloudReady,
                    'missing_key' => l10n.cloudMissingKey,
                    _ => l10n.cloudOff,
                  },
                  style: TextStyle(
                    fontSize: 12,
                    color: status == 'ready' ? NaraTheme.success : NaraTheme.textSecondary,
                  ),
                );
              },
            ),
            value: settings.cloudEnabled,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).update(settings.copyWith(cloudEnabled: v)),
          ),
          if (settings.cloudEnabled)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.cloudAiDesc,
                        style: TextStyle(fontSize: 12, color: NaraTheme.textSecondary, height: 1.5)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _endpointController,
                      decoration: InputDecoration(labelText: l10n.cloudEndpoint),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _modelController,
                      decoration: InputDecoration(labelText: l10n.cloudModel),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _keyController,
                      decoration: InputDecoration(labelText: l10n.cloudApiKey),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () async {
                          await ref.read(settingsProvider.notifier).saveCredentials(
                                CloudCredentials(
                                  endpoint: _endpointController.text.trim(),
                                  model: _modelController.text.trim(),
                                  apiKey: _keyController.text.trim(),
                                ),
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.cloudReady)),
                            );
                          }
                        },
                        child: Text(l10n.confirm),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _sectionTitle(l10n.cloudSync),
          ListTile(
            leading: Icon(
              _firebaseActive == true ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: _firebaseActive == true ? NaraTheme.success : NaraTheme.textSecondary,
            ),
            title: Text(l10n.cloudSync),
            subtitle: Text(
              _firebaseActive == true ? l10n.cloudSyncOn : l10n.cloudSyncOff,
              style: TextStyle(fontSize: 12, color: NaraTheme.textSecondary),
            ),
          ),
          _sectionTitle(l10n.memory),
          SwitchListTile(
            title: Text(l10n.memory),
            subtitle: Text(l10n.memoryDesc,
                style: TextStyle(fontSize: 12, color: NaraTheme.textSecondary)),
            value: settings.memoryEnabled,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).update(settings.copyWith(memoryEnabled: v)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_rounded),
            title: Text(l10n.clearMemory),
            onTap: () {
              ref.read(conversationMemoryProvider).clear();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.memoryCleared)),
              );
            },
          ),
          _sectionTitle(l10n.about),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(l10n.appName),
            subtitle: Text(
              '${l10n.version} $_appVersion',
              style: TextStyle(fontSize: 12, color: NaraTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: const NaraNavigationBar(current: '/settings'),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
        child: Text(
          text,
          style: TextStyle(
            color: NaraTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _sliderTile(String label, double value, double min, double max, NaraSettings Function(double) map) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: 15,
            onChanged: (v) => ref.read(settingsProvider.notifier).update(map(v)),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(value.toStringAsFixed(2), textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
