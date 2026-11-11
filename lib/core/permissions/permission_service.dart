import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di.dart';

/// Which capability a permission row refers to.
enum NaraPermission {
  microphone,
  notifications,
  accessibility,
  notificationListener,
}

class PermissionStatusInfo {
  const PermissionStatusInfo({
    required this.permission,
    required this.granted,
    required this.canRequest,
  });

  final NaraPermission permission;
  final bool granted;

  /// False for system-service toggles that only Android settings can change.
  final bool canRequest;
}

/// Central, transparent permission state (spec §14 permission center).
class PermissionService {
  PermissionService(this._ref);

  final Ref _ref;

  Future<List<PermissionStatusInfo>> statusAll() async {
    final status = await _ref.read(permissionsPlatformProvider).getStatus();
    final accessibility =
        await _ref.read(accessibilityPlatformProvider).isEnabled();
    final listener =
        await _ref.read(notificationsPlatformProvider).isEnabled();
    return <PermissionStatusInfo>[
      PermissionStatusInfo(
        permission: NaraPermission.microphone,
        granted: (status['microphone'] as bool?) ?? false,
        canRequest: true,
      ),
      PermissionStatusInfo(
        permission: NaraPermission.notifications,
        granted: (status['notifications'] as bool?) ?? false,
        canRequest: true,
      ),
      PermissionStatusInfo(
        permission: NaraPermission.accessibility,
        granted: accessibility,
        canRequest: false,
      ),
      PermissionStatusInfo(
        permission: NaraPermission.notificationListener,
        granted: listener,
        canRequest: false,
      ),
    ];
  }

  Future<bool> request(NaraPermission permission) async {
    switch (permission) {
      case NaraPermission.microphone:
        return _ref.read(permissionsPlatformProvider).requestMicrophone();
      case NaraPermission.notifications:
        return _ref.read(permissionsPlatformProvider).requestNotifications();
      case NaraPermission.accessibility:
        await _ref.read(accessibilityPlatformProvider).openAccessibilitySettings();
        return false; // The user toggles it in Android settings.
      case NaraPermission.notificationListener:
        await _ref.read(notificationsPlatformProvider).openListenerSettings();
        return false;
    }
  }

  Future<void> openAppSettings() =>
      _ref.read(permissionsPlatformProvider).openAppSettings();
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService(ref);
});
