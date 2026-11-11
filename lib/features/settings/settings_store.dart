import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ai/cloud/cloud_client.dart';

/// User preferences persisted with shared_preferences; the cloud AI API key
/// lives in flutter_secure_storage only.
class NaraSettings {
  const NaraSettings({
    this.locale = 'id',
    this.ttsEnabled = true,
    this.ttsRate = 1.0,
    this.ttsPitch = 1.0,
    this.cloudEnabled = false,
    this.memoryEnabled = true,
  });

  final String locale; // 'id' | 'en'
  final bool ttsEnabled;
  final double ttsRate;
  final double ttsPitch;
  final bool cloudEnabled;
  final bool memoryEnabled;

  NaraSettings copyWith({
    String? locale,
    bool? ttsEnabled,
    double? ttsRate,
    double? ttsPitch,
    bool? cloudEnabled,
    bool? memoryEnabled,
  }) {
    return NaraSettings(
      locale: locale ?? this.locale,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      ttsRate: ttsRate ?? this.ttsRate,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      cloudEnabled: cloudEnabled ?? this.cloudEnabled,
      memoryEnabled: memoryEnabled ?? this.memoryEnabled,
    );
  }
}

class CloudCredentials {
  const CloudCredentials({this.endpoint = CloudAiConfig.defaultEndpoint, this.model = CloudAiConfig.defaultModel, this.apiKey = ''});
  final String endpoint;
  final String model;
  final String apiKey;
}

/// Loads/saves settings and configures the cloud client.
class SettingsStore {
  static const _prefsLocale = 'nara.locale';
  static const _prefsTtsEnabled = 'nara.tts.enabled';
  static const _prefsTtsRate = 'nara.tts.rate';
  static const _prefsTtsPitch = 'nara.tts.pitch';
  static const _prefsCloudEnabled = 'nara.cloud.enabled';
  static const _prefsMemory = 'nara.memory.enabled';
  static const _prefsEndpoint = 'nara.cloud.endpoint';
  static const _prefsModel = 'nara.cloud.model';
  static const _secureKey = 'nara.cloud.apiKey';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<NaraSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NaraSettings(
      locale: prefs.getString(_prefsLocale) ?? 'id',
      ttsEnabled: prefs.getBool(_prefsTtsEnabled) ?? true,
      ttsRate: prefs.getDouble(_prefsTtsRate) ?? 1.0,
      ttsPitch: prefs.getDouble(_prefsTtsPitch) ?? 1.0,
      cloudEnabled: prefs.getBool(_prefsCloudEnabled) ?? false,
      memoryEnabled: prefs.getBool(_prefsMemory) ?? true,
    );
  }

  Future<void> save(NaraSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLocale, settings.locale);
    await prefs.setBool(_prefsTtsEnabled, settings.ttsEnabled);
    await prefs.setDouble(_prefsTtsRate, settings.ttsRate);
    await prefs.setDouble(_prefsTtsPitch, settings.ttsPitch);
    await prefs.setBool(_prefsCloudEnabled, settings.cloudEnabled);
    await prefs.setBool(_prefsMemory, settings.memoryEnabled);
  }

  Future<CloudCredentials> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _secure.read(key: _secureKey) ?? '';
    return CloudCredentials(
      endpoint: prefs.getString(_prefsEndpoint) ?? CloudAiConfig.defaultEndpoint,
      model: prefs.getString(_prefsModel) ?? CloudAiConfig.defaultModel,
      apiKey: key,
    );
  }

  Future<void> saveCredentials(CloudCredentials credentials) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsEndpoint, credentials.endpoint);
    await prefs.setString(_prefsModel, credentials.model);
    if (credentials.apiKey.isEmpty) {
      await _secure.delete(key: _secureKey);
    } else {
      await _secure.write(key: _secureKey, value: credentials.apiKey);
    }
  }
}
