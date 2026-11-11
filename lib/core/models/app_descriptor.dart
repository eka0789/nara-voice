/// Immutable description of an installed application as discovered by the
/// native App Discovery Engine.
class AppDescriptor {
  const AppDescriptor({
    required this.appName,
    required this.packageName,
    required this.launchable,
    required this.enabled,
    required this.isSystem,
    this.versionName,
    this.versionCode,
    this.category,
    this.capabilities = const <String>[],
    this.supportedDeepLinks = const <String>[],
  });

  final String appName;
  final String packageName;
  final bool launchable;
  final bool enabled;
  final bool isSystem;
  final String? versionName;
  final int? versionCode;
  final String? category;

  /// Capability keys assigned by the integration registry
  /// (e.g. `messaging`, `email`, `maps`, `media`, `browser`).
  final List<String> capabilities;

  /// Deep-link templates supported for this app (uri scheme roots).
  final List<String> supportedDeepLinks;

  bool get isUserApp => !isSystem;

  static AppDescriptor fromMap(Map<Object?, Object?> map) {
    return AppDescriptor(
      appName: (map['appName'] as String?) ?? (map['packageName'] as String? ?? ''),
      packageName: (map['packageName'] as String?) ?? '',
      launchable: (map['launchable'] as bool?) ?? false,
      enabled: (map['enabled'] as bool?) ?? false,
      isSystem: (map['isSystem'] as bool?) ?? false,
      versionName: map['versionName'] as String?,
      versionCode: (map['versionCode'] as num?)?.toInt(),
      category: map['category'] as String?,
    );
  }

  /// Lower-cased searchable keys (name + package) used by the fuzzy matcher.
  List<String> get searchTokens => <String>[
        appName.toLowerCase(),
        packageName.toLowerCase().replaceAll('.', ' ').split(' ').join(' '),
        packageName.toLowerCase(),
      ];
}
