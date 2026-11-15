import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/platform_exception.dart';
import '../platform/routines_platform.dart';

/// A scheduled routine: at [time]'s hour:minute NARA posts a tap-to-run
/// notification with the stored [commands]. Execution always happens in the
/// foreground after the user taps — never silently in the background.
class Routine {
  const Routine({
    required this.id,
    required this.time,
    required this.daily,
    required this.title,
    required this.commands,
    this.enabled = true,
  });

  final String id;
  final DateTime time; // date part is ignored — only hour/minute are scheduled
  final bool daily;
  final String title;
  final List<String> commands;
  final bool enabled;

  Routine copyWith({bool? enabled, DateTime? time, String? title, List<String>? commands}) =>
      Routine(
        id: id,
        time: time ?? this.time,
        daily: daily,
        title: title ?? this.title,
        commands: commands ?? this.commands,
        enabled: enabled ?? this.enabled,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        'daily': daily,
        'title': title,
        'commands': commands,
        'enabled': enabled,
      };

  static Routine fromMap(Map<Object?, Object?> map) {
    final parts = ((map['time'] as String?) ?? '07:00').split(':');
    final now = DateTime.now();
    return Routine(
      id: (map['id'] as String?) ?? '',
      time: DateTime(
        now.year,
        now.month,
        now.day,
        int.tryParse(parts.first) ?? 7,
        int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      ),
      daily: (map['daily'] as bool?) ?? true,
      title: (map['title'] as String?) ?? 'Routine',
      commands: ((map['commands'] as List<Object?>?) ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      enabled: (map['enabled'] as bool?) ?? true,
    );
  }
}

/// Persisted list of routines (SharedPreferences JSON). Arming/cancelling the
/// native alarm goes through [RoutinesPlatform] on every mutation.
class RoutineStore extends StateNotifier<List<Routine>> {
  RoutineStore(this._routines) : super(const <Routine>[]) {
    _load();
  }

  final RoutinesPlatform _routines;

  static const _prefsKey = 'nara.routines';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString(_prefsKey) ?? '[]');
      if (decoded is! List) return;
      state = decoded
          .whereType<Map<Object?, Object?>>()
          .map(Routine.fromMap)
          .where((r) => r.commands.isNotEmpty)
          .toList(growable: false);
      // Alarms die with the process — make sure each enabled routine is armed.
      for (final routine in state) {
        if (routine.enabled) {
          await _arm(routine);
        }
      }
    } catch (_) {
      // Corrupt store: start empty rather than crash.
    }
  }

  /// Creates a routine and arms its native alarm.
  Future<Routine> add({
    required DateTime time,
    required bool daily,
    required String title,
    required List<String> commands,
  }) async {
    final routine = Routine(
      id: 'r${DateTime.now().microsecondsSinceEpoch}',
      time: time,
      daily: daily,
      title: title.trim().isEmpty ? commands.first : title.trim(),
      commands: commands,
    );
    state = [...state, routine];
    await _persist();
    await _arm(routine);
    return routine;
  }

  Future<void> setEnabled(Routine routine, {required bool enabled}) async {
    final updated = routine.copyWith(enabled: enabled);
    state = [
      for (final r in state) if (r.id == routine.id) updated else r,
    ];
    await _persist();
    if (enabled) {
      await _arm(updated);
    } else {
      await _routines.cancel(routine.id);
    }
  }

  Future<void> remove(Routine routine) async {
    state = state.where((r) => r.id != routine.id).toList(growable: false);
    await _persist();
    try {
      await _routines.cancel(routine.id);
    } on NaraPlatformException {
      // Alarm may already be gone; the local entry is removed regardless.
    }
  }

  Future<void> _arm(Routine routine) async {
    if (!routine.enabled) return;
    await _routines.save(
      id: routine.id,
      hour: routine.time.hour,
      minute: routine.time.minute,
      daily: routine.daily,
      title: routine.title,
      commands: routine.commands,
    );
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state.map((r) => r.toMap()).toList()));
    } catch (_) {
      // Best-effort persistence; the in-memory list keeps working.
    }
  }
}

final routinesPlatformProvider =
    Provider<RoutinesPlatform>((_) => RoutinesPlatform());

final routineStoreProvider = StateNotifierProvider<RoutineStore, List<Routine>>(
  (ref) => RoutineStore(ref.watch(routinesPlatformProvider)),
);
