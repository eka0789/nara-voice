import 'dart:async';

import '../../features/app_integrations/integration_registry.dart';
import '../models/app_descriptor.dart';
import '../tools/tools/app_tools.dart';

/// Resolves a free-text app name to a package using:
/// 1. The integration registry aliases (instant, offline).
/// 2. A fuzzy match over the live installed-app catalog (cached).
class AppCatalogLookup {
  AppCatalogLookup(this._catalogSource);

  static const _cacheTtl = Duration(minutes: 10);

  final Future<List<AppDescriptor>> Function() _catalogSource;
  Timer? _cacheTimer;
  List<AppDescriptor>? _cached;
  bool _started = false;

  /// Must be called right after construction (the Riverpod provider does it).
  void startCacheTimer() {
    if (_started) return;
    _started = true;
    _cacheTimer = Timer.periodic(_cacheTtl, (_) => _cached = null);
  }

  Future<List<AppDescriptor>> _catalog() async {
    final cached = _cached;
    if (cached != null) return cached;
    final apps = await _catalogSource();
    _cached = apps;
    return apps;
  }

  /// Returns the best (packageName, score) match, or null.
  Future<(String, double)?> lookup(String query) async {
    final sync = lookupSync(query);
    if (sync != null && sync.$2 >= 1.0) return sync;
    final token = query.trim().toLowerCase();
    if (token.isEmpty) return null;

    // Live catalog fuzzy match.
    try {
      final apps = await _catalog();
      (String, double)? best = sync;
      for (final app in apps) {
        if (!app.launchable || !app.enabled) continue;
        final score = SearchAppTool.scoreAppMatch(app, token);
        if (score > 0 && (best == null || score > best.$2)) {
          best = (app.packageName, score);
        }
      }
      return best;
    } catch (_) {
      return sync;
    }
  }

  /// Synchronous resolution used by the NLU: registry names first, then the
  /// warmed-up catalog cache. Call [warmUp] when the app starts and whenever
  /// applications may have changed.
  (String, double)? lookupSync(String query) {
    final token = query.trim().toLowerCase();
    if (token.isEmpty) return null;

    // 1. Registry aliases — deterministic and fast.
    for (final e in IntegrationRegistry.known) {
      if (e.aliases.contains(token) || e.displayName.toLowerCase() == token) {
        return (e.packageName, 1.0);
      }
    }

    // Partial registry alias containment ("buka google maps").
    for (final e in IntegrationRegistry.known) {
      for (final alias in e.aliases) {
        if (alias.length > 3 && (token.startsWith('$alias ') || token.endsWith(' $alias'))) {
          return (e.packageName, 0.95);
        }
      }
    }

    // 2. Warmed catalog fuzzy match (only when the cache is populated).
    final cached = _cached;
    if (cached == null) return null;
    (String, double)? best;
    for (final app in cached) {
      if (!app.launchable || !app.enabled) continue;
      final score = SearchAppTool.scoreAppMatch(app, token);
      if (score > 0 && (best == null || score > best.$2)) {
        best = (app.packageName, score);
      }
    }
    return best;
  }

  /// Preloads the catalog cache so [lookupSync] can fuzzy-match offline.
  Future<void> warmUp() async {
    try {
      _cached = await _catalogSource();
    } catch (_) {
      _cached = _cached ?? const <AppDescriptor>[];
    }
  }

  void dispose() => _cacheTimer?.cancel();
}
