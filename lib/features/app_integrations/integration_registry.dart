/// Registry of well-known application integrations with their capabilities
/// and deep-link schemes. This is the *fallback* strategy required by the
/// engineering rules: package names are never hardcoded into NLU logic
/// directly; they are resolved through this registry plus live discovery.
class IntegrationEntry {
  const IntegrationEntry({
    required this.packageName,
    required this.displayName,
    required this.aliases,
    required this.capabilities,
    this.deepLinks = const <String>[],
  });

  final String packageName;
  final String displayName;

  /// Alternate names/synonyms the fuzzy matcher understands.
  final List<String> aliases;
  final List<String> capabilities;
  final List<String> deepLinks;
}

class IntegrationRegistry {
  const IntegrationRegistry._();

  static const List<IntegrationEntry> known = <IntegrationEntry>[
    IntegrationEntry(
      packageName: 'com.whatsapp',
      displayName: 'WhatsApp',
      aliases: ['whatsapp', 'wa'],
      capabilities: ['messaging'],
      deepLinks: ['https://wa.me', 'whatsapp://'],
    ),
    IntegrationEntry(
      packageName: 'org.telegram.messenger',
      displayName: 'Telegram',
      aliases: ['telegram'],
      capabilities: ['messaging'],
      deepLinks: ['tg://'],
    ),
    IntegrationEntry(
      packageName: 'com.google.android.gm',
      displayName: 'Gmail',
      aliases: ['gmail', 'surel', 'email'],
      capabilities: ['email'],
      deepLinks: ['googlegmail://'],
    ),
    IntegrationEntry(
      packageName: 'com.google.android.apps.maps',
      displayName: 'Google Maps',
      aliases: ['maps', 'peta', 'google maps'],
      capabilities: ['maps', 'navigation'],
      deepLinks: ['geo:', 'google.navigation:'],
    ),
    IntegrationEntry(
      packageName: 'com.google.android.youtube',
      displayName: 'YouTube',
      aliases: ['youtube', 'yt'],
      capabilities: ['media', 'video'],
      deepLinks: ['vnd.youtube://', 'https://www.youtube.com'],
    ),
    IntegrationEntry(
      packageName: 'com.spotify.music',
      displayName: 'Spotify',
      aliases: ['spotify'],
      capabilities: ['media', 'music'],
      deepLinks: ['spotify:'],
    ),
    IntegrationEntry(
      packageName: 'com.google.android.calendar',
      displayName: 'Google Calendar',
      aliases: ['kalender', 'calendar', 'agenda'],
      capabilities: ['productivity', 'calendar'],
      deepLinks: ['content://com.android.calendar'],
    ),
    IntegrationEntry(
      packageName: 'com.android.chrome',
      displayName: 'Chrome',
      aliases: ['chrome', 'browser', 'peramban'],
      capabilities: ['browser'],
      deepLinks: ['http://', 'https://'],
    ),
    IntegrationEntry(
      packageName: 'com.instagram.android',
      displayName: 'Instagram',
      aliases: ['instagram', 'ig'],
      capabilities: ['social'],
      deepLinks: ['instagram://'],
    ),
    IntegrationEntry(
      packageName: 'com.facebook.katana',
      displayName: 'Facebook',
      aliases: ['facebook', 'fb'],
      capabilities: ['social'],
      deepLinks: ['fb://'],
    ),
    IntegrationEntry(
      packageName: 'com.google.android.apps.photos',
      displayName: 'Google Photos',
      aliases: ['photos', 'galeri', 'foto'],
      capabilities: ['media', 'photos'],
      deepLinks: ['googlephotos://'],
    ),
    IntegrationEntry(
      packageName: 'com.google.android.apps.docs',
      displayName: 'Google Drive',
      aliases: ['drive', 'google drive'],
      capabilities: ['productivity', 'files'],
      deepLinks: ['googledrive://'],
    ),
    IntegrationEntry(
      packageName: 'com.google.android.dialer',
      displayName: 'Phone',
      aliases: ['telepon', 'phone', 'dialer'],
      capabilities: ['calls'],
      deepLinks: ['tel:'],
    ),
    IntegrationEntry(
      packageName: 'com.google.android.apps.messaging',
      displayName: 'Messages',
      aliases: ['pesan', 'sms', 'messages'],
      capabilities: ['messaging', 'sms'],
      deepLinks: ['sms:'],
    ),
    IntegrationEntry(
      packageName: 'com.google.android.googlequicksearchbox',
      displayName: 'Google',
      aliases: ['google'],
      capabilities: ['search', 'assistant'],
      deepLinks: ['google://'],
    ),
    // Popular third-party apps (Indonesia + global). Launch goes through the
    // live app catalog; deep links give direct entry points.
    IntegrationEntry(
      packageName: 'com.shopee.id',
      displayName: 'Shopee',
      aliases: ['shopee'],
      capabilities: ['shopping'],
      deepLinks: ['shopee://'],
    ),
    IntegrationEntry(
      packageName: 'com.shopee.app',
      displayName: 'Shopee Global',
      aliases: ['shopee global'],
      capabilities: ['shopping'],
      deepLinks: ['shopee://'],
    ),
    IntegrationEntry(
      packageName: 'com.tokopedia.tkpd',
      displayName: 'Tokopedia',
      aliases: ['tokopedia', 'toped'],
      capabilities: ['shopping'],
      deepLinks: ['tokopedia://'],
    ),
    IntegrationEntry(
      packageName: 'com.gojek.app',
      displayName: 'Gojek',
      aliases: ['gojek', 'go jek'],
      capabilities: ['transport', 'payments'],
      deepLinks: ['gojek://'],
    ),
    IntegrationEntry(
      packageName: 'com.grabtaxi.passenger',
      displayName: 'Grab',
      aliases: ['grab'],
      capabilities: ['transport', 'payments'],
      deepLinks: ['grab://'],
    ),
    IntegrationEntry(
      packageName: 'id.dana',
      displayName: 'DANA',
      aliases: ['dana'],
      capabilities: ['payments'],
      deepLinks: ['dana://'],
    ),
    IntegrationEntry(
      packageName: 'com.netflix.mediaclient',
      displayName: 'Netflix',
      aliases: ['netflix'],
      capabilities: ['media', 'video'],
      deepLinks: ['nflx://'],
    ),
    IntegrationEntry(
      packageName: 'com.zhiliaoapp.musically',
      displayName: 'TikTok',
      aliases: ['tiktok', 'tik tok'],
      capabilities: ['social', 'media'],
      deepLinks: ['snssdk1128://', 'tiktok://'],
    ),
    IntegrationEntry(
      packageName: 'com.twitter.android',
      displayName: 'X',
      aliases: ['x', 'twitter'],
      capabilities: ['social'],
      deepLinks: ['twitter://'],
    ),
    IntegrationEntry(
      packageName: 'com.discord',
      displayName: 'Discord',
      aliases: ['discord'],
      capabilities: ['social', 'messaging'],
      deepLinks: ['discord://'],
    ),
    IntegrationEntry(
      packageName: 'us.zoom.videomeetings',
      displayName: 'Zoom',
      aliases: ['zoom'],
      capabilities: ['productivity', 'calls'],
      deepLinks: ['zoomus://'],
    ),
  ];

  /// Finds a known integration by any of its names (already lowercased).
  static IntegrationEntry? byName(String token) {
    final t = token.trim().toLowerCase();
    for (final entry in known) {
      if (entry.aliases.any((a) => a == t) ||
          entry.displayName.toLowerCase() == t) {
        return entry;
      }
    }
    return null;
  }

  /// Capabilities assigned to an installed app, or empty for unknown apps.
  static List<String> capabilitiesFor(String packageName) => known
      .where((e) => e.packageName == packageName)
      .expand((e) => e.capabilities)
      .toList(growable: false);

  /// Deep-link roots registered for an installed app.
  static List<String> deepLinksFor(String packageName) => known
      .where((e) => e.packageName == packageName)
      .expand((e) => e.deepLinks)
      .toList(growable: false);
}
