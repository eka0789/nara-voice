# Testing Guide

## Automated (CI-ready, all green)

```bash
flutter analyze        # 0 issues
flutter test           # 53 tests
flutter build apk --release
```

| Suite | Covers |
|---|---|
| `test/nlu_engine_test.dart` | ID+EN intent parsing, compound commands, slot filling, ambiguity → clarify (never guesses), risk tagging |
| `test/risk_policy_test.dart` | LOW/MEDIUM/HIGH classification, confirmation gating, plan outcome labels |
| `test/workflow_engine_test.dart` | run states, HIGH-risk → awaitingApproval, retry re-runs **only** failed steps, cancel |
| `test/cloud_client_test.dart` | OpenAI-compatible parsing (tool_calls / content), HTTP + malformed + exception → null fallback |
| `test/app_match_test.dart` | fuzzy app-name scoring |
| `test/tool_validation_test.dart` | tool input schema validation, unknown-arg rejection, single execution |
| `test/screen_context_test.dart` | ScreenContext parsing, ScreenMemory lookup |
| `test/widget_test.dart` | VoiceOrb states + tap, ConfirmationCard actions, QuickCommands |

## Manual device checklist (needs real hardware)

**Already verified on Android 16 emulator (API 36, 2026-11-11):** install,
cold launch without crash, full UI render (home/orb/chips/nav + apps catalog
with real icons and capability badges), command → NLU → intent → YouTube
launched with honest localized response, **honest-failure path** (WhatsApp
absent → progress card `APP_NOT_LAUNCHABLE`, no fake success), tab navigation.

Remaining items below need a physical device (mic/TTS quality, permissions
dialogs on real OEM skins, notifications from real apps):

1. **Install**: `flutter install` or `adb install build/app/outputs/flutter-apk/app-release.apk`.
2. **First run**: mic permission dialog appears on first mic tap; permission center
   lists all four capabilities with honest on/off states.
3. **Discovery**: Apps tab shows all launchable apps with icons; search works;
   Details opens the system page.
4. **Voice round (Indonesian)**:
   - "Buka WhatsApp" → app opens, NARA says so.
   - "Buka pengaturan wifi" → Wi-Fi settings.
   - "Navigasi ke rumah sakit terdekat" → Maps directions.
   - "Cari tutorial Flutter di YouTube" → YouTube search.
   - "Kirim pesan WhatsApp isi saya sudah di jalan" → asks for content if missing;
     with content → share target (user picks chat, user sends).
   - "Kirim pesan WhatsApp ke 08123456789 isi tes" → **confirmation card** →
     "ya" opens the direct chat draft; "tidak" cancels.
   - "Jadwalkan rapat besok jam 3" → calendar draft at 15:00 next day.
   - "Buka YouTube dan cari tutorial Flutter" → 2 steps, Automations tab shows a
     partially/completed run with per-step status.
5. **Voice round (English)**: "Open bluetooth settings", "What can you do".
6. **Screen reading** (after enabling accessibility): "Baca isi layar" → result
   card with visible text; open a password field first to verify it is excluded.
7. **Notifications** (after granting listener): "Baca notifikasi terbaru".
8. **Failure honesty**: uninstall YouTube then "Cari X di YouTube" → NARA reports
   the app is unavailable instead of pretending.
9. **Interruption**: tap mic while TTS is speaking → speech stops (barge-in flush).
10. **Airplane mode**: cloud AI enabled → response falls back to offline NLU.

## Sideload install on a real phone (release APK)

The release APK (`build/app/outputs/flutter-apk/app-release.apk`, ~25 MB,
signed with the debug key) is verified installable and launchable on a fresh
device. If installation fails on a specific phone, work through this list —
the APK itself has been ruled out as the cause (2026-11-15 audit):

1. **Uninstall any previous NARA first** (`id.nara.voice`). A build signed
   with a different key (e.g. from another machine's debug keystore) is
   rejected with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` — the most common cause
   of a silent "App not installed".
2. **Transfer the file intact**: USB cable, Google Drive, or a zip archive.
   Chat apps (WhatsApp/Telegram) re-encode or truncate APKs → "There was a
   problem parsing the package".
3. **Play Protect**: Android 9+ may warn "App blocked by Play Protect" for a
   sideloaded debug-signed app. Tap *More details → Install anyway*.
4. **"Install unknown apps"**: grant the file manager/browser you installed
   from the per-source sideload permission (Settings → Apps → Special access).
5. **Device OS version**: Android 7.0+ required (`minSdk 24`).
6. **Diagnosis shortcut**: enable Developer Options → USB debugging, connect,
   run `adb install -r app-release.apk` — adb prints the exact
   `INSTALL_FAILED_*` reason instead of the installer's generic message.

Build config note: `useLegacyPackaging = true` (android/app/build.gradle.kts)
keeps native libraries compressed inside the APK — some OEM/Go device
installers reject APKs whose `.so` files are stored uncompressed
(`INSTALL_FAILED_INVALID_APK`), so this stays on deliberately.

## Known platform caveats

- Emulators: speech recognition works if the Google app is present and signed in;
  some OEM skins ship broken recognizers — NARA reports `STT_UNAVAILABLE` honestly.
- **Software-GPU emulators (`swiftshader`)**: animated Flutter UIs can occasionally
  trigger "app isn't responding" (ANR) dialogs because the rasterizer runs on CPU.
  Verified during smoke testing: NARA's process survives (same pid), the state
  machine keeps working, and actions complete correctly — the dialog is a
  rendering-environment artifact, not an app defect. Real devices with hardware
  GPUs are not affected. Use a hardware-GPU emulator profile or a physical device
  for longer interactive sessions.
- MIUI/ColorOS: backgrounded notification-listener connections may be killed;
  the permission center shows the live connection state.
