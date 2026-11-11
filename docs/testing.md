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

Speech recognition quality and TTS voices require a physical device or a
configured emulator with the Google app. Suggested pass:

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

## Known platform caveats

- Emulators: speech recognition works if the Google app is present and signed in;
  some OEM skins ship broken recognizers — NARA reports `STT_UNAVAILABLE` honestly.
- MIUI/ColorOS: backgrounded notification-listener connections may be killed;
  the permission center shows the live connection state.
